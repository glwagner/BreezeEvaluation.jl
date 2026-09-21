# Matched GABLS1 control and SurfaceLayerDiffusivity evaluation runner.
# Development-only until an immutable source/dependency freeze and GPU contract pass.

using Breeze
using CUDA
using Oceananigans
using Oceananigans.Units
using Printf
using Random
using SHA
import Dates

const EVALUATION_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
const FROZEN_GABLS1 = joinpath(EVALUATION_REPO, "source_snapshots", "gabls1", "original")
const FROZEN_SURFACE_LAW = joinpath(
    FROZEN_GABLS1, "source", "src", "BoundaryConditions", "gabls_rough_wall_coefficient.jl")
const FROZEN_DIAGNOSTICS = joinpath(
    FROZEN_GABLS1, "source", "examples", "gabls_diagnostics.jl")

# GABLS1's surface law was an audited campaign overlay rather than part of the feature base.
# Load that exact preserved source into its original module without modifying either repository.
if !isdefined(Breeze.BoundaryConditions, :GABLSRoughWallCoefficient)
    @eval Breeze.BoundaryConditions using DocStringExtensions: TYPEDEF,
                                                               TYPEDFIELDS,
                                                               TYPEDSIGNATURES
    Base.include(Breeze.BoundaryConditions, FROZEN_SURFACE_LAW)
end
const GABLSRoughWallCoefficient = Breeze.BoundaryConditions.GABLSRoughWallCoefficient

struct GABLS1SurfaceTemperature{FT}
    initial :: FT
    cooling_rate :: FT
end

@inline (surface::GABLS1SurfaceTemperature)(x, y, t) =
    surface.initial - surface.cooling_rate * t

Breeze.BoundaryConditions.materialize_surface_field(
    surface::GABLS1SurfaceTemperature, grid, side) = surface

@inline Breeze.BoundaryConditions.wall_value(
    i, j, grid, side, surface::GABLS1SurfaceTemperature, clock) =
        surface.initial - surface.cooling_rate * clock.time

include(joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "LegacyGABLSDiagnosticsAdaptation.jl"))
LegacyGABLSDiagnosticsAdaptation.load_adapted_gabls_diagnostics!(
    @__MODULE__, FROZEN_DIAGNOSTICS)
include(joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "SurfaceLayerDiagnostics.jl"))
include(joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "GABLS1SurfaceLayerDiagnostics.jl"))
using .GABLS1SurfaceLayerDiagnostics

function environment_choice(name, valid, default)
    choice = get(ENV, name, default)
    choice in valid || error("$name=$choice is not one of $(join(valid, ", "))")
    return choice
end

function architecture_from_environment()
    name = environment_choice("GABLS1_SLD_ARCH", ("cpu", "gpu"), "cpu")
    if name == "gpu"
        CUDA.functional() || error("GABLS1_SLD_ARCH=gpu but CUDA is not functional")
    end
    return name == "gpu" ? GPU() : CPU()
end

function capture_provenance(directory, case_id, settings)
    provenance = joinpath(directory, "provenance")
    mkpath(provenance)
    breeze_repository = pkgdir(Breeze)
    git(repository, args...) = try
        readchomp(Cmd(["git", "-C", repository, args...]))
    catch error
        "UNAVAILABLE: $error"
    end
    filehash(path) = bytes2hex(open(sha256, path))

    open(joinpath(provenance, "git.txt"), "w") do io
        println(io, "commit: ", git(EVALUATION_REPO, "rev-parse", "HEAD"))
        println(io, "status:\n", git(EVALUATION_REPO, "status", "--short"))
    end
    open(joinpath(provenance, "breeze_git.txt"), "w") do io
        println(io, "repository: ", breeze_repository)
        println(io, "commit: ", git(breeze_repository, "rev-parse", "HEAD"))
        println(io, "tree: ", git(breeze_repository, "rev-parse", "HEAD^{tree}"))
        println(io, "branch: ", git(breeze_repository, "rev-parse", "--abbrev-ref", "HEAD"))
        println(io, "status:\n", git(breeze_repository, "status", "--short"))
        println(io, "untracked_files:\n",
                git(breeze_repository, "ls-files", "--others", "--exclude-standard"))
    end
    write(joinpath(provenance, "breeze_uncommitted.diff"),
          git(breeze_repository, "diff", "HEAD"))
    open(joinpath(provenance, "run.txt"), "w") do io
        println(io, "case_id: ", case_id)
        println(io, "julia: ", Base.julia_cmd()[1])
        println(io, "version: ", VERSION)
        println(io, "active_project: ", Base.active_project())
        println(io, "started_utc: ", Dates.now(Dates.UTC))
        for (name, value) in pairs(settings)
            println(io, name, ": ", value)
        end
    end
    environment_files = (
        "active.Project.toml" => Base.active_project(),
        "active.Manifest.toml" => joinpath(dirname(Base.active_project()), "Manifest.toml"),
        "Breeze.Project.toml" => joinpath(breeze_repository, "Project.toml"),
        "Breeze.Manifest.toml" => joinpath(breeze_repository, "Manifest.toml"))
    open(joinpath(provenance, "environment_hashes.txt"), "w") do io
        for (name, source) in environment_files
            if isfile(source)
                cp(source, joinpath(provenance, name); force=true)
                println(io, name, " ", filehash(source), " ", source)
            else
                println(io, name, " MISSING ", source)
            end
        end
    end
    sources = (
        joinpath(@__DIR__, "gabls1_case.jl"),
        FROZEN_SURFACE_LAW,
        FROZEN_DIAGNOSTICS,
        joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "SurfaceLayerDiagnostics.jl"),
        joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "LegacyGABLSDiagnosticsAdaptation.jl"),
        joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "GABLS1SurfaceLayerDiagnostics.jl"))
    open(joinpath(provenance, "source_hashes.txt"), "w") do io
        for source in sources
            cp(source, joinpath(provenance, basename(source)); force=true)
            println(io, basename(source), " ", filehash(source), " ", source)
        end
    end
    return nothing
end

function build_simulation(; run_directory=pwd())
    architecture = architecture_from_environment()
    FT = Float32
    Oceananigans.defaults.FloatType = FT
    nx = parse(Int, get(ENV, "GABLS1_SLD_NX", "32"))
    nx == 32 || error("the bounded SurfaceLayerDiffusivity study currently authorizes nx=32")
    closure_name = environment_choice("GABLS1_SLD_CLOSURE",
                                      ("none", "surface_layer"), "none")
    filter_seconds = parse(Float64, get(ENV, "GABLS1_SLD_FILTER_SECONDS", "300"))
    support = parse(Int, get(ENV, "GABLS1_SLD_SUPPORT", "1"))
    resolved_flux_factor = parse(Float64, get(ENV, "GABLS1_SLD_RESOLVED_FLUX_FACTOR", "1"))
    isfinite(resolved_flux_factor) && resolved_flux_factor >= 0 ||
        error("GABLS1_SLD_RESOLVED_FLUX_FACTOR must be finite and nonnegative")
    filter_seconds > 0 || error("GABLS1_SLD_FILTER_SECONDS must be positive")
    support in (1, 2) || error("GABLS1_SLD_SUPPORT must be 1 or 2")
    stop_time = parse(Float64, get(ENV, "GABLS1_SLD_STOP_SECONDS", "32400"))
    seed = parse(Int, get(ENV, "GABLS1_SLD_SEED", "123"))
    Random.seed!(seed)
    diagnostics_enabled = get(ENV, "GABLS1_SLD_DIAGNOSTICS", "1") == "1"

    domain_length = FT(400)
    spacing = domain_length / nx
    grid = RectilinearGrid(architecture; size=(nx, nx, nx),
        x=(0, domain_length), y=(0, domain_length), z=(0, domain_length),
        halo=(5, 5, 5), topology=(Periodic, Periodic, Bounded))

    reference_temperature = FT(263.5)
    constants = ThermodynamicConstants(FT)
    reference_state = ReferenceState(grid, constants;
        base_pressure=FT(100000), potential_temperature=reference_temperature)
    dynamics = AnelasticDynamics(reference_state)
    surface_temperature = GABLS1SurfaceTemperature(FT(265), FT(0.25 / 3600))
    surface_coefficient = GABLSRoughWallCoefficient(FT;
        reference_temperature=reference_temperature)
    ρu_bcs = FieldBoundaryConditions(bottom=Breeze.BulkDrag(
        coefficient=surface_coefficient, surface_temperature=surface_temperature))
    ρv_bcs = FieldBoundaryConditions(bottom=Breeze.BulkDrag(
        coefficient=surface_coefficient, surface_temperature=surface_temperature))
    ρE_bcs = FieldBoundaryConditions(bottom=BulkSensibleHeatFlux(
        coefficient=surface_coefficient, surface_temperature=surface_temperature))
    boundary_conditions = (ρu=ρu_bcs, ρv=ρv_bcs, ρE=ρE_bcs)

    coriolis = FPlane(f=FT(1.39e-4))
    geostrophic = geostrophic_forcings(z -> FT(8), z -> FT(0))
    damping_mask = PiecewiseLinearMask{:z}(center=domain_length, width=FT(100))
    sponge = Relaxation(rate=FT(1 / 60), mask=damping_mask)
    forcing = (; u=geostrophic.u, v=geostrophic.v, w=sponge)
    scheme = WENO(order=9)
    closure = closure_name == "surface_layer" ? SurfaceLayerDiffusivity(FT;
        filter_timescale=filter_seconds, support, resolved_flux_factor,
        minimum_scalar_fluxes=(ρθ=FT(1e-8),)) : nothing

    model = AtmosphereModel(grid; dynamics, coriolis, microphysics=nothing,
        momentum_advection=scheme, scalar_advection=scheme, closure,
        thermodynamic_constants=constants, forcing, boundary_conditions)

    z = collect(znodes(grid, Center(), Center(), Center()))
    # Reproduce the original frozen GABLS1 host initialization exactly: Float64 draws from
    # the explicitly seeded default RNG, later converted by `set!` onto the Float32 model.
    theta_initial = Array{Float64}(undef, nx, nx, nx)
    for k in 1:nx, j in 1:nx, i in 1:nx
        base = z[k] <= 100 ? 265.0 : 265.0 + 0.01 * (z[k] - 100)
        perturbation = z[k] < 50 ? 0.1 * (rand() - 0.5) : 0.0
        theta_initial[i, j, k] = base + perturbation
    end
    theta_initial_sha256 = bytes2hex(sha256(reinterpret(UInt8, vec(theta_initial))))
    set!(model, θ=theta_initial, u=FT(8), v=FT(0), w=FT(0))

    initial_dt = min(FT(0.5), FT(0.5) * spacing / FT(8))
    simulation = Simulation(model; Δt=initial_dt, stop_time)
    conjure_time_step_wizard!(simulation, cfl=FT(0.7), max_Δt=FT(5))
    Oceananigans.Diagnostics.erroring_NaNChecker!(simulation)

    closure_id = closure_name == "surface_layer" ?
        @sprintf("surface_layer_t%03d_s%d", round(Int, filter_seconds), support) : "control"
    # Explicit sensitivity runs have unique identities, including the factor-one
    # matched baseline. Unscaled covariance/flux diagnostics remain physical.
    if closure_name == "surface_layer" && haskey(ENV, "GABLS1_SLD_RESOLVED_FLUX_FACTOR")
        closure_id *= "_rf" * replace(string(resolved_flux_factor), "." => "p")
    end
    case_id = @sprintf("gabls1_n%03d_weno9_%s", nx, closure_id)
    mkpath(run_directory)
    settings = (; nx, spacing, closure_name, filter_seconds, support, resolved_flux_factor, stop_time,
        seed, theta_initial_sha256, initial_dt, wizard_cfl=0.7,
        architecture=summary(architecture),
        diagnostics_enabled, surface_law_source=FROZEN_SURFACE_LAW)
    capture_provenance(run_directory, case_id, settings)

    if diagnostics_enabled
        install_gabls1_surface_layer_diagnostics!(simulation;
            dir=run_directory, prefix="$(case_id)_diag",
            reference_temperature,
            surface_temperature_initial=FT(265),
            surface_cooling_rate=FT(0.25 / 3600),
            momentum_roughness_length=FT(0.1),
            heat_roughness_length=FT(0.1),
            minimum_surface_wind_speed=FT(0.01),
            maximum_surface_stability=FT(10))
    end

    simulation.output_writers[:checkpoint] = Checkpointer(model;
        prefix="$(case_id)_checkpoint", schedule=TimeInterval(1hour),
        dir=run_directory, overwrite_files=true)
    theta = liquid_ice_potential_temperature(model)
    simulation.output_writers[:state_bounds] = JLD2Writer(model,
        (; theta_min=m -> minimum(liquid_ice_potential_temperature(m)),
           theta_max=m -> maximum(liquid_ice_potential_temperature(m)),
           max_u=m -> maximum(abs, m.velocities.u),
           max_v=m -> maximum(abs, m.velocities.v),
           max_w=m -> maximum(abs, m.velocities.w));
        filename="$(case_id)_state_bounds.jld2", dir=run_directory,
        schedule=TimeInterval(60), overwrite_files=true)

    wall_clock = Ref(time_ns())
    last_iteration = Ref(0)
    function progress(sim)
        elapsed = 1e-9 * (time_ns() - wall_clock[])
        steps = iteration(sim) - last_iteration[]
        @info @sprintf("[%s] iter %d t=%s dt=%s %.4f s/step max|w|=%.3g theta=[%.3f,%.3f] CFL target=.7",
            case_id, iteration(sim), prettytime(sim), prettytime(sim.Δt),
            steps > 0 ? elapsed / steps : NaN, maximum(abs, model.velocities.w),
            minimum(theta), maximum(theta))
        wall_clock[] = time_ns()
        last_iteration[] = iteration(sim)
        return nothing
    end
    add_callback!(simulation, progress, IterationInterval(1000))
    return (; simulation, model, case_id, settings)
end

function main()
    run_directory = abspath(get(ENV, "GABLS1_SLD_RUN_DIR", pwd()))
    setup = build_simulation(; run_directory)
    @info "GABLS1_SLD_RUN_START" case_id=setup.case_id settings=setup.settings
    run!(setup.simulation)
    open(joinpath(run_directory, "CASE_DONE"), "w") do io
        println(io, "case_id=", setup.case_id)
        println(io, "final_time_s=", time(setup.simulation))
        println(io, "finished_utc=", Dates.now(Dates.UTC))
    end
    @info "GABLS1_SLD_RUN_DONE" case_id=setup.case_id final_time=time(setup.simulation)
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
