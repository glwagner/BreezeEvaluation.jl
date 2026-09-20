# One cell of the DYCOMS-II RF01 factorial.
#
# Selected entirely by environment variables so the 12 cases share one script and one
# code path -- nothing about a case lives anywhere but its environment:
#
#   DYCOMS_GRID     coarse | canonical | fine
#   DYCOMS_CLOSURE  none | smagorinsky
#   DYCOMS_WENO     9 | 5          (applied to ALL advected variables)
#   DYCOMS_STOP     hours of simulated time (default 4)
#
# Moisture advection always carries bounds=(0, 1), at whatever order the case specifies,
# so moisture bounding is identical across every comparison and cannot confound the
# advection-order factor.

using Breeze
using Oceananigans: Oceananigans
using Oceananigans.Units
using CUDA
using Printf
using Statistics
using Random
import Dates  # `import`, not `using`: Dates exports lowercase
              # minute/hour/second, which collide with Oceananigans.Units

Random.seed!(123)
CUDA.functional() && CUDA.seed!(123)

Oceananigans.defaults.FloatType = Float32

grid_name = get(ENV, "DYCOMS_GRID", "canonical")
closure_name = get(ENV, "DYCOMS_CLOSURE", "none")
weno_order = parse(Int, get(ENV, "DYCOMS_WENO", "9"))
stop_hours = parse(Float64, get(ENV, "DYCOMS_STOP", "4"))

# (Nx, Ny, Nz, Lx=Ly); Lz = 1500 m throughout
specs = Dict("coarse"    => (96,  96,  75,  7680.0),
             "canonical" => (96,  96,  300, 3360.0),
             "fine"      => (336, 336, 300, 3360.0))

haskey(specs, grid_name) || error("unknown DYCOMS_GRID=$grid_name")
weno_order ∈ (5, 9) || error("unknown DYCOMS_WENO=$weno_order")
closure_name ∈ ("none", "smagorinsky") || error("unknown DYCOMS_CLOSURE=$closure_name")

Nx, Ny, Nz, L = specs[grid_name]
case = "$(grid_name)_$(closure_name)_weno$(weno_order)"

@info @sprintf("CASE %s | %d x %d x %d | dx = %.1f m, dz = %.2f m | L = %.0f m | %.2f M cells | %.1f h",
               case, Nx, Ny, Nz, L / Nx, 1500 / Nz, L, Nx * Ny * Nz / 1e6, stop_hours)

# ## Provenance
#
# Three agents are editing this checkout concurrently, so outputs are meaningless without a
# record of exactly what produced them. Capture commit, the *uncommitted* diff, the resolved
# environment, and verbatim snapshots of every source file this run depends on.

# Source tree this case runs against. The desktop task freezes one snapshot and points every
# array task at it via DYCOMS_REPO, so all 12 cases share byte-identical source even if the
# working checkout keeps moving underneath them.
const REPO = get(ENV, "DYCOMS_REPO", "/shared/home/greg/Projects/Breeze.jl")

function capture_provenance(dir)
    prov = joinpath(dir, "provenance")
    mkpath(prov)

    git(args...) = try
        readchomp(`git -C $REPO $args`)
    catch e
        "UNAVAILABLE: $e"
    end

    open(joinpath(prov, "git.txt"), "w") do io
        println(io, "commit:  ", git("rev-parse", "HEAD"))
        println(io, "branch:  ", git("rev-parse", "--abbrev-ref", "HEAD"))
        println(io, "describe:", git("describe", "--always", "--dirty"))
        println(io, "
--- status ---
", git("status", "--short"))
    end

    # The dirty diff is the part a bare commit hash silently loses
    write(joinpath(prov, "uncommitted.diff"), git("diff", "HEAD"))

    open(joinpath(prov, "environment.txt"), "w") do io
        println(io, "julia:      ", Base.julia_cmd()[1])
        println(io, "version:    ", VERSION)
        println(io, "CUDA:       ", CUDA.functional() ? string(CUDA.runtime_version()) : "not functional")
        println(io, "device:     ", CUDA.functional() ? string(CUDA.device()) : "-")
        println(io, "hostname:   ", gethostname())
        println(io, "slurm job:  ", get(ENV, "SLURM_JOB_ID", "-"))
        println(io, "started:    ", string(Dates.now()))
    end

    for src in (joinpath(REPO, "validation_output/dycoms/factorial/dycoms_case.jl"),
                joinpath(REPO, "examples/dycoms_diagnostics.jl"),
                joinpath(REPO, "src/AtmosphereModels/dycoms_radiation.jl"),
                joinpath(REPO, "examples/Project.toml"),
                joinpath(REPO, "examples/Manifest.toml"))
        isfile(src) && cp(src, joinpath(prov, basename(src)); force=true)
    end

    @info "provenance captured in $prov"
    return prov
end

capture_provenance(".")

grid = RectilinearGrid(GPU(); x=(0, L), y=(0, L), z=(0, 1500),
                       size = (Nx, Ny, Nz), halo = (5, 5, 5),
                       topology = (Periodic, Periodic, Bounded))

constants = ThermodynamicConstants(dry_air_heat_capacity=1015)

reference_state = ReferenceState(grid, constants,
                                 base_pressure = 101780,
                                 potential_temperature = 289)

dynamics = AnelasticDynamics(reference_state)

# Surface: fixed fluxes of 15 and 115 W/m², bulk drag Cᴰ = 0.0011
ℒˡ = 2.47e6
ρE_bcs = FieldBoundaryConditions(bottom=FluxBoundaryCondition(15))
ρqᵗ_bcs = FieldBoundaryConditions(bottom=FluxBoundaryCondition(115 / ℒˡ))
ρu_bcs = FieldBoundaryConditions(bottom=BulkDrag(coefficient=0.0011))
ρv_bcs = FieldBoundaryConditions(bottom=BulkDrag(coefficient=0.0011))
boundary_conditions = (ρE=ρE_bcs, ρqᵗ=ρqᵗ_bcs, ρu=ρu_bcs, ρv=ρv_bcs)

D = 3.75e-6
wˢ = Field{Nothing, Nothing, Face}(grid)
set!(wˢ, z -> -D * z)
subsidence = SubsidenceForcing(wˢ)

coriolis = FPlane(latitude=31.5)
geostrophic = geostrophic_forcings(z -> 7, z -> -5.5)

# Identical in every case, so it cannot confound the comparison
sponge = Relaxation(rate=1/60, mask=GaussianMask{:z}(center=1500, width=150))

forcing = (; u = (subsidence, geostrophic.u),
             v = (subsidence, geostrophic.v),
             w = sponge,
             θ = subsidence,
             qᵉ = subsidence)

radiation = DYCOMSRadiation(grid; divergence = D,
                            heat_capacity = constants.dry_air.heat_capacity)

weno = WENO(order=weno_order)
bounded_weno = WENO(order=weno_order, bounds=(0, 1))

closure = closure_name == "smagorinsky" ? SmagorinskyLilly() : nothing

@info "closure = $(closure === nothing ? "nothing" : sprint(show, closure))"
@info "advection: WENO(order=$weno_order) everywhere; moisture additionally bounds=(0, 1)"

model = AtmosphereModel(grid; dynamics, coriolis,
                        microphysics = SaturationAdjustment(equilibrium=WarmPhaseEquilibrium()),
                        momentum_advection = weno,
                        scalar_advection = (ρθ = weno, ρqᵉ = bounded_weno),
                        closure,
                        thermodynamic_constants = constants,
                        radiation, forcing, boundary_conditions)

θˡⁱ₀ = z -> z <= 840 ? 289.0 : 297.5 + (z - 840)^(1/3)
qᵗ₀ = z -> z <= 840 ? 9.0e-3 : 1.5e-3

ϵ() = rand() - 1/2
θᵢ(x, y, z) = θˡⁱ₀(z) + 0.1 * ϵ() * (z < 200)

set!(model, θ=θᵢ, qᵗ=(x, y, z) -> qᵗ₀(z), u=7, v=-5.5)

qˡ = model.microphysical_fields.qˡ
qᵛ = model.microphysical_fields.qᵛ
ρ = total_density(model.dynamics)
θ = liquid_ice_potential_temperature(model)
ℐ = radiation.net_upward_flux
zᵢ = radiation.inversion_height
u, v, w = model.velocities

LWP = Field(Integral(ρ * qˡ, dims=3))

simulation = Simulation(model; Δt=0.5, stop_time=stop_hours * hours)
conjure_time_step_wizard!(simulation, cfl=0.7, max_Δt=2)
Oceananigans.Diagnostics.erroring_NaNChecker!(simulation)

wall_clock = Ref(time_ns())
steps = Ref(0)

function progress(sim)
    compute!(LWP)
    elapsed = 1e-9 * (time_ns() - wall_clock[])
    n = iteration(sim) - steps[]
    @info @sprintf("[%s] iter %d, t %s, Δt %s, %.4f s/step, max|w| %.2f, max qˡ %.2e, LWP %.4f kg/m²",
                   case, iteration(sim), prettytime(sim), prettytime(sim.Δt),
                   n > 0 ? elapsed / n : NaN,
                   maximum(abs, sim.model.velocities.w), maximum(qˡ), mean(LWP))
    wall_clock[] = time_ns()
    steps[] = iteration(sim)
    return nothing
end

add_callback!(simulation, progress, IterationInterval(500))

outputs = (; u, v, w, θ, qˡ, qᵛ)
avg_outputs = NamedTuple(name => Average(outputs[name], dims=(1, 2)) for name in keys(outputs))
avg_outputs = merge(avg_outputs, (; ℐ = Average(ℐ, dims=(1, 2)),
                                    zᵢ = Average(zᵢ, dims=(1, 2))))

# True 30-minute averages of instantaneous plane statistics
simulation.output_writers[:profiles] = JLD2Writer(model, avg_outputs;
                                                  filename = "$(case)_profiles.jld2",
                                                  schedule = AveragedTimeInterval(30minutes),
                                                  overwrite_files = true)

simulation.output_writers[:series] = JLD2Writer(model, (; LWP, zᵢ);
                                                filename = "$(case)_series.jld2",
                                                schedule = TimeInterval(1minute),
                                                overwrite_files = true)

simulation.output_writers[:checkpoint] = Checkpointer(model;
                                                      prefix = "$(case)_checkpoint",
                                                      schedule = TimeInterval(1hour),
                                                      dir = ".",
                                                      overwrite_files = true)

# ## Pane 48 diagnostics
#
# `install_dycoms_diagnostics!` adds the published Table B1 series and the true 30-minute
# averaged profiles, including native w-face moments/fluxes and both interpolated inversion
# definitions. Prefixed `<case>_diag` so its `_series.jld2` does not collide with the
# runner's own. Intervals are passed explicitly as seconds rather than relying on the
# module's defaults.
#
# Opt out with DYCOMS_DIAGNOSTICS=0.

if get(ENV, "DYCOMS_DIAGNOSTICS", "1") == "1"
    include(joinpath(REPO, "examples", "dycoms_diagnostics.jl"))
    using .DYCOMSDiagnostics: install_dycoms_diagnostics!

    diagnostics = install_dycoms_diagnostics!(simulation;
                                              dir = ".",
                                              prefix = "$(case)_diag",
                                              profile_interval = 1800.0,
                                              series_interval = 60.0)

    @info @sprintf("diagnostics installed: %d profile outputs, %d series outputs",
                   length(keys(diagnostics.profile_outputs)),
                   length(keys(diagnostics.series_outputs)))
else
    @info "diagnostics disabled (DYCOMS_DIAGNOSTICS=0)"
end

@info "running $case"
t0 = time_ns()
run!(simulation)
wall = 1e-9 * (time_ns() - t0)

@info @sprintf("CASE_DONE %s wall_s=%.1f iters=%d final_LWP=%.4f",
               case, wall, iteration(simulation), (compute!(LWP); mean(LWP)))
