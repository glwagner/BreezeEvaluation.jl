# One case of the GABLS1 stable boundary layer matrix (Beare et al. 2006).
#
# Selected entirely by environment variables so all 25 cases share one code path:
#
#   GABLS_NX       32 | 64 | 128 | 200 | 400      (isotropic; domain fixed at 400 m)
#   GABLS_SCHEME   weno9 | weno5 | centered2
#   GABLS_CLOSURE  none | smagorinsky
#   GABLS_STOP     hours of simulated time (default 9)
#   GABLS_REPO     source tree (default: the live checkout)
#   GABLS_DIAGNOSTICS  1 (default) | 0 -- 0 is for scaffold tests only; production errors
#                      rather than running without diagnostics
#
# The surface exchange is ACTIVE in every case, including closure=none: GABLS1's only forcing
# is the rough wall, so "no interior closure" means no interior SGS model, not a free-slip
# floor.

using Breeze
using Oceananigans: Oceananigans
using Oceananigans.Units
using CUDA
using Printf
using Statistics
using Random
import Dates  # `import`, not `using`: Dates exports lowercase minute/hour/second, which
              # collide with Oceananigans.Units

Random.seed!(123)
CUDA.functional() && CUDA.seed!(123)

Oceananigans.defaults.FloatType = Float32

const REPO = get(ENV, "GABLS_REPO", "/shared/home/greg/Projects/Breeze.jl")

nx = parse(Int, get(ENV, "GABLS_NX", "32"))
scheme_name = get(ENV, "GABLS_SCHEME", "weno9")
closure_name = get(ENV, "GABLS_CLOSURE", "none")
stop_hours = parse(Float64, get(ENV, "GABLS_STOP", "9"))

nx in (32, 64, 128, 200, 400) || error("unknown GABLS_NX=$nx")
scheme_name in ("weno9", "weno5", "centered2") || error("unknown GABLS_SCHEME=$scheme_name")
closure_name in ("none", "smagorinsky") || error("unknown GABLS_CLOSURE=$closure_name")

case = @sprintf("n%03d_%s_%s", nx, scheme_name, closure_name)

# ## Domain: fixed 400 m cube, isotropic spacing
L = 400.0
dx = L / nx

@info @sprintf("CASE %s | %d^3 | dx = dz = %.4f m | %.3f M cells | %.1f h",
               case, nx, dx, nx^3 / 1e6, stop_hours)

# ## Provenance
function capture_provenance(dir)
    prov = joinpath(dir, "provenance"); mkpath(prov)
    git(args...) = try readchomp(`git -C $REPO $args`) catch e; "UNAVAILABLE: $e" end

    open(joinpath(prov, "git.txt"), "w") do io
        println(io, "commit:  ", git("rev-parse", "HEAD"))
        println(io, "branch:  ", git("rev-parse", "--abbrev-ref", "HEAD"))
        println(io, "\n--- status ---\n", git("status", "--short"))
    end
    write(joinpath(prov, "uncommitted.diff"), git("diff", "HEAD"))

    open(joinpath(prov, "environment.txt"), "w") do io
        println(io, "julia:     ", Base.julia_cmd()[1])
        println(io, "version:   ", VERSION)
        println(io, "CUDA:      ", CUDA.functional() ? string(CUDA.runtime_version()) : "not functional")
        println(io, "hostname:  ", gethostname())
        println(io, "slurm job: ", get(ENV, "SLURM_JOB_ID", "-"))
        println(io, "started:   ", string(Dates.now()))
    end

    for src in (joinpath(REPO, "validation_output/gabls/gabls_case.jl"),
                joinpath(REPO, "examples/gabls_diagnostics.jl"),
                joinpath(REPO, "src/BoundaryConditions/gabls_rough_wall_coefficient.jl"),
                joinpath(REPO, "Project.toml"),
                joinpath(REPO, "Manifest.toml"))
        isfile(src) && cp(src, joinpath(prov, basename(src)); force=true)
    end
    return prov
end

capture_provenance(".")

grid = RectilinearGrid(GPU(); x=(0, L), y=(0, L), z=(0, L),
                       size = (nx, nx, nx), halo = (5, 5, 5),
                       topology = (Periodic, Periodic, Bounded))

# ## Thermodynamics and reference state
#
# GABLS1 gives rho_r = 1.3223 kg/m^3 at theta_r = 263.5 K, which implies a surface pressure of
# rho_r Rd theta_r = 99999.15 Pa. We use exactly 1e5 Pa instead, because Breeze's
# `standard_pressure` is 1e5: the Exner factor at the surface is then exactly 1, and the
# prescribed surface forcing theta_s = 265 - 0.25 t[h] is reproduced EXACTLY rather than to
# +0.00064 K. The cost is an effective rho_r of 1.32231 against the specification's rounded
# 1.3223 -- a relative difference of 8e-6.
#
# Breeze is ANELASTIC; the GABLS1 archive submissions are predominantly Boussinesq. Over a
# 400 m domain the density varies by ~4%, so the two are close but not identical. Flagged.

θᵣ = 263.5
ρᵣ_spec = 1.3223
constants = ThermodynamicConstants()
Rᵈ = Breeze.Thermodynamics.dry_air_gas_constant(constants)
p₀ = 100000.0

@info @sprintf("reference: θᵣ=%.1f K, p₀=%.1f Pa (ρᵣ spec %.4f implies %.2f Pa; effective ρᵣ=%.5f)",
               θᵣ, p₀, ρᵣ_spec, ρᵣ_spec * Rᵈ * θᵣ, p₀ / (Rᵈ * θᵣ))

reference_state = ReferenceState(grid, constants, base_pressure=p₀, potential_temperature=θᵣ)
dynamics = AnelasticDynamics(reference_state)

# ## Surface: rough-wall Monin-Obukhov, active in every case
#
# theta_s(t) = 265 - 0.25 t[h]. The cooling is prescribed; the heat flux is DIAGNOSED from
# similarity, not imposed. With p_surface == p_standard == 1e5 the Exner conversion inside
# both the drag and the heat-flux path is the identity, so the value below IS theta_s.

surface_temperature(x, y, t) = 265.0 - 0.25 * t / 3600

gabls_coefficient = GABLSRoughWallCoefficient(; reference_temperature = θᵣ)

ρu_bcs = FieldBoundaryConditions(bottom = BulkDrag(coefficient = gabls_coefficient,
                                                   surface_temperature = surface_temperature))
ρv_bcs = FieldBoundaryConditions(bottom = BulkDrag(coefficient = gabls_coefficient,
                                                   surface_temperature = surface_temperature))
ρE_bcs = FieldBoundaryConditions(bottom = BulkSensibleHeatFlux(coefficient = gabls_coefficient,
                                                               surface_temperature = surface_temperature))

boundary_conditions = (ρu = ρu_bcs, ρv = ρv_bcs, ρE = ρE_bcs)

# ## Coriolis and geostrophic forcing (73 N)
coriolis = FPlane(f = 1.39e-4)
geostrophic = geostrophic_forcings(z -> 8.0, z -> 0.0)

# ## Rayleigh damping above 300 m
#
# GABLS1 recommends wave damping above 300 m without prescribing a form. `PiecewiseLinearMask`
# is exactly zero for z <= center - width and ramps linearly to 1 at the top, so this is a
# genuine >300 m sponge. A GaussianMask(center=400, width=100) would be exp(-0.5) = 0.607 at
# z = 300 m and nonzero everywhere, damping the whole boundary layer -- not usable here.

damping_rate = 1 / 60                                            # s^-1, 60 s timescale at top
damping_mask = PiecewiseLinearMask{:z}(center = L, width = 100)  # exactly 0 for z <= 300 m
sponge = Relaxation(rate = damping_rate, mask = damping_mask)

forcing = (; u = geostrophic.u, v = geostrophic.v, w = sponge)

# ## Advection and closure
if scheme_name == "weno9"
    momentum_scheme = WENO(order=9); scalar_scheme = WENO(order=9)
elseif scheme_name == "weno5"
    momentum_scheme = WENO(order=5); scalar_scheme = WENO(order=5)
else
    momentum_scheme = Centered(order=2); scalar_scheme = Centered(order=2)
end

# Cs, the buoyancy/stability reduction, and the SGS Prandtl number stated EXPLICITLY via the
# documented constructor (Smagorinskys/lilly_coefficient.jl:109), not left to defaults.
closure = closure_name == "smagorinsky" ? SmagorinskyLilly(C = 0.16, Cb = 1, Pr = 1) : nothing

@info "advection: $scheme_name on momentum and the thermodynamic variable (dry)"
@info "closure: $(closure === nothing ? "nothing (surface exchange still ACTIVE)" : sprint(show, closure))"

model = AtmosphereModel(grid; dynamics, coriolis,
                        microphysics = nothing,
                        momentum_advection = momentum_scheme,
                        scalar_advection = scalar_scheme,
                        closure,
                        thermodynamic_constants = constants,
                        forcing, boundary_conditions)

# ## Initial condition
#
# theta = 265 K below 100 m, 265 + 0.01(z-100) above; zero-mean noise below 50 m. The
# perturbation is built on the HOST into a plain array and `set!` from it: calling `rand()`
# inside a coordinate function handed to `set!` is not reliable on GPU and would not be
# reproducible from `Random.seed!` there. "0.1 K amplitude" is read as zero-mean uniform on
# [-0.05, +0.05] K, i.e. 0.1 K peak-to-peak.
#
# The specification says the bottom grid point has zero wind. On a staggered C-grid the
# bottom face value of u is set by the wall stress boundary condition, not by the initial
# condition, so the initial interior field is uniformly geostrophic and the wall does the
# work. Documented as a staggered-grid interpretation.

θ₀(z) = z <= 100 ? 265.0 : 265.0 + 0.01 * (z - 100)

zc = Oceananigans.Grids.znodes(grid, Center())
θ_init = Array{Float64}(undef, nx, nx, nx)
for kk in 1:nx, jj in 1:nx, ii in 1:nx
    z = zc[kk]
    θ_init[ii, jj, kk] = θ₀(z) + (z < 50) * 0.1 * (rand() - 0.5)
end

set!(model, θ = θ_init, u = 8.0, v = 0.0)

# ## Simulation
simulation = Simulation(model; Δt = min(0.5, 0.5 * dx / 8), stop_time = stop_hours * hours)
conjure_time_step_wizard!(simulation, cfl = 0.7, max_Δt = 5)
Oceananigans.Diagnostics.erroring_NaNChecker!(simulation)

u, v, w = model.velocities
θ = liquid_ice_potential_temperature(model)   # a dry model has no `tracers`

wall_clock = Ref(time_ns()); last_iter = Ref(0)

function progress(sim)
    elapsed = 1e-9 * (time_ns() - wall_clock[])
    n = iteration(sim) - last_iter[]
    @info @sprintf("[%s] iter %d, t %s, dt %s, %.4f s/step, max|w| %.3f, theta in [%.2f, %.2f]",
                   case, iteration(sim), prettytime(sim), prettytime(sim.Δt),
                   n > 0 ? elapsed / n : NaN,
                   maximum(abs, sim.model.velocities.w),
                   minimum(θ), maximum(θ))
    wall_clock[] = time_ns(); last_iter[] = iteration(sim)
    return nothing
end

add_callback!(simulation, progress, IterationInterval(1000))

simulation.output_writers[:checkpoint] = Checkpointer(model;
                                                      prefix = "$(case)_checkpoint",
                                                      schedule = TimeInterval(1hour),
                                                      dir = ".",
                                                      overwrite_files = true)

# Finite-state guard: theta extrema and max velocities as a plain 60 s series, so an
# instability shows up as evidence rather than being silently smoothed away.
simulation.output_writers[:state_bounds] = JLD2Writer(model,
    (; theta_min = m -> minimum(liquid_ice_potential_temperature(m)),
       theta_max = m -> maximum(liquid_ice_potential_temperature(m)),
       max_u = m -> maximum(abs, m.velocities.u),
       max_v = m -> maximum(abs, m.velocities.v),
       max_w = m -> maximum(abs, m.velocities.w));
    filename = "$(case)_state_bounds.jld2",
    schedule = TimeInterval(60.0),
    overwrite_files = true)

if get(ENV, "GABLS_DIAGNOSTICS", "1") == "1"
    diagnostics_file = joinpath(REPO, "examples", "gabls_diagnostics.jl")
    (isfile(diagnostics_file) && filesize(diagnostics_file) > 2000) ||
        error("GABLS diagnostics missing or a stub at $diagnostics_file. Production must not " *
              "run without diagnostics; set GABLS_DIAGNOSTICS=0 only for a scaffold test.")

    include(diagnostics_file)
    using .GABLSDiagnostics: install_gabls_diagnostics!
    diagnostics = install_gabls_diagnostics!(simulation;
                                             dir = ".",
                                             prefix = "$(case)_diag",
                                             profile_interval = 1800.0,
                                             series_interval = 60.0)
    @info "diagnostics installed from $diagnostics_file"
end

@info "running $case"
t0 = time_ns()
run!(simulation)
wall = 1e-9 * (time_ns() - t0)

θmin = minimum(θ); θmax = maximum(θ)
wmax = maximum(abs, w)

@info @sprintf("CASE_DONE %s wall_s=%.1f iters=%d theta_min=%.4f theta_max=%.4f max_w=%.4f",
               case, wall, iteration(simulation), θmin, θmax, wmax)
println("GABLS_CASE_EXIT_SUCCESS")
