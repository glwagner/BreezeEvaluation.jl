# Matched fixed-stress neutral ABL control and SurfaceLayerDiffusivity runner.
# Production use requires a separately reviewed immutable snapshot and GPU gate.

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
    FROZEN_GABLS1, "source", "src", "BoundaryConditions",
    "gabls_rough_wall_coefficient.jl")
const FROZEN_DIAGNOSTICS = joinpath(
    FROZEN_GABLS1, "source", "examples", "gabls_diagnostics.jl")
const ORIGINAL_NEUTRAL_EXAMPLE = joinpath(
    pkgdir(Breeze), "examples", "neutral_atmospheric_boundary_layer.jl")

if !isdefined(Breeze.BoundaryConditions, :gabls_stability_parameter)
    @eval Breeze.BoundaryConditions using DocStringExtensions: TYPEDEF,
                                                               TYPEDFIELDS,
                                                               TYPEDSIGNATURES
    Base.include(Breeze.BoundaryConditions, FROZEN_SURFACE_LAW)
end

include(joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "LegacyGABLSDiagnosticsAdaptation.jl"))
LegacyGABLSDiagnosticsAdaptation.load_adapted_gabls_diagnostics!(
    @__MODULE__, FROZEN_DIAGNOSTICS)
include(joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "SurfaceLayerDiagnostics.jl"))
include(joinpath(@__DIR__, "NeutralSurfaceLayerDiagnostics.jl"))
using .NeutralSurfaceLayerDiagnostics

function environment_choice(name, valid, default)
    choice = get(ENV, name, default)
    choice in valid || error("$name=$choice is not one of $(join(valid, ", "))")
    return choice
end

function architecture_from_environment()
    name = environment_choice("NEUTRAL_ABL_ARCH", ("cpu", "gpu"), "cpu")
    if name == "gpu"
        CUDA.functional() || error("NEUTRAL_ABL_ARCH=gpu but CUDA is not functional")
        CUDA.allowscalar(false)
    end
    return name == "gpu" ? GPU() : CPU()
end

@inline function fixed_ρu_drag(x, y, t, ρu, ρv, parameters)
    speed = max(sqrt(ρu^2 + ρv^2), 1e-6)
    return -parameters.surface_density * parameters.friction_velocity^2 * ρu / speed
end

@inline function fixed_ρv_drag(x, y, t, ρu, ρv, parameters)
    speed = max(sqrt(ρu^2 + ρv^2), 1e-6)
    return -parameters.surface_density * parameters.friction_velocity^2 * ρv / speed
end

@inline function inversion_energy_sponge(i, j, k, grid, clock, model_fields, parameters)
    z = znode(k, grid, Center())
    mask = parameters.mask(0, 0, z)
    difference = @inbounds parameters.target_ρθ[k] - model_fields.ρθ[i, j, k]
    exner = @inbounds parameters.reference_exner[k]
    return parameters.rate * mask * parameters.dry_heat_capacity * exner * difference
end

function neutral_initial_arrays(FT, nx, ny, nz, z_centers, seed;
                                geostrophic_u=15, geostrophic_v=0)
    rng = MersenneTwister(seed)
    u = Array{FT}(undef, nx, ny, nz)
    v = Array{FT}(undef, nx, ny, nz)
    theta = Array{FT}(undef, nx, ny, nz)
    for k in 1:nz, j in 1:ny, i in 1:nx
        active = z_centers[k] < FT(400)
        perturbation = active ? rand(rng) - 0.5 : 0.0
        u[i, j, k] = FT(geostrophic_u + 0.01 * perturbation)
    end
    for k in 1:nz, j in 1:ny, i in 1:nx
        active = z_centers[k] < FT(400)
        perturbation = active ? rand(rng) - 0.5 : 0.0
        v[i, j, k] = FT(geostrophic_v + 0.01 * perturbation)
    end
    for k in 1:nz, j in 1:ny, i in 1:nx
        active = z_centers[k] < FT(400)
        perturbation = active ? rand(rng) - 0.5 : 0.0
        theta[i, j, k] = neutral_reference_theta(FT(z_centers[k])) +
                         FT(0.1 * perturbation)
    end
    w = zeros(FT, nx, ny, nz + 1)
    return (; u, v, theta, w)
end

@inline function neutral_reference_theta(z)
    FT = typeof(z)
    theta0 = FT(300)
    inversion_base = FT(468)
    inversion_thickness = FT(62.5)
    inversion_top = inversion_base + inversion_thickness
    inversion_gradient = FT(8) / inversion_thickness
    free_troposphere_gradient = FT(0.003)
    below = theta0
    within = theta0 + inversion_gradient * (z - inversion_base)
    above = theta0 + FT(8) + free_troposphere_gradient * (z - inversion_top)
    return ifelse(z < inversion_base, below,
                  ifelse(z < inversion_top, within, above))
end

array_digest(values) = bytes2hex(sha256(reinterpret(UInt8, vec(values))))

function initial_state_digests(initial)
    return (;
        u_sha256=array_digest(initial.u),
        v_sha256=array_digest(initial.v),
        theta_sha256=array_digest(initial.theta),
        w_sha256=array_digest(initial.w))
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
        joinpath(@__DIR__, "neutral_abl_case.jl"),
        joinpath(@__DIR__, "NeutralSurfaceLayerDiagnostics.jl"),
        joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "SurfaceLayerDiagnostics.jl"),
        joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics",
                 "LegacyGABLSDiagnosticsAdaptation.jl"),
        FROZEN_SURFACE_LAW,
        FROZEN_DIAGNOSTICS,
        ORIGINAL_NEUTRAL_EXAMPLE)
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
    fixture = get(ENV, "NEUTRAL_ABL_FIXTURE", "0") == "1"
    nx = parse(Int, get(ENV, "NEUTRAL_ABL_NX", "96"))
    ny = parse(Int, get(ENV, "NEUTRAL_ABL_NY", string(nx)))
    nz = parse(Int, get(ENV, "NEUTRAL_ABL_NZ", string(nx)))
    !fixture && (nx, ny, nz) != (96, 96, 96) &&
        error("scientific neutral ABL cases require the original 96×96×96 grid")
    closure_name = environment_choice("NEUTRAL_ABL_CLOSURE",
                                      ("none", "surface_layer"), "none")
    filter_seconds = parse(Float64, get(ENV, "NEUTRAL_ABL_FILTER_SECONDS", "300"))
    support = parse(Int, get(ENV, "NEUTRAL_ABL_SUPPORT", "1"))
    closure_name == "surface_layer" && support != 1 &&
        error("the authorized neutral SLD comparison uses one-face support only")
    filter_seconds > 0 || error("NEUTRAL_ABL_FILTER_SECONDS must be positive")
    stop_time = parse(Float64, get(ENV, "NEUTRAL_ABL_STOP_SECONDS", "18000"))
    seed = parse(Int, get(ENV, "NEUTRAL_ABL_SEED", "1994"))
    diagnostics_enabled = get(ENV, "NEUTRAL_ABL_DIAGNOSTICS", "1") == "1"
    profile_interval = parse(Float64, get(ENV, "NEUTRAL_ABL_PROFILE_INTERVAL", "600"))
    series_interval = parse(Float64, get(ENV, "NEUTRAL_ABL_SERIES_INTERVAL", "60"))
    checkpoint_interval = parse(Float64,
        get(ENV, "NEUTRAL_ABL_CHECKPOINT_INTERVAL", "3600"))
    progress_interval = parse(Int, get(ENV, "NEUTRAL_ABL_PROGRESS_INTERVAL", "1000"))
    if !fixture
        filter_seconds == 300 ||
            error("scientific neutral cases require canonical filter_seconds=300")
        support == 1 || error("scientific neutral cases require support=1")
        stop_time == 18000 || error("scientific neutral cases require stop_time=18000 s")
        seed == 1994 || error("scientific neutral cases require seed=1994")
        diagnostics_enabled || error("scientific neutral cases require diagnostics")
        profile_interval == 600 ||
            error("scientific neutral cases require 600 s averaged profiles")
        series_interval == 60 || error("scientific neutral cases require 60 s series")
        checkpoint_interval == 3600 ||
            error("scientific neutral cases require 3600 s checkpoints")
    end

    grid = RectilinearGrid(architecture;
        size=(nx, ny, nz), x=(0, FT(3000)), y=(0, FT(3000)), z=(0, FT(1000)),
        halo=(5, 5, 5), topology=(Periodic, Periodic, Bounded))
    constants = ThermodynamicConstants(FT)
    reference_state = ReferenceState(grid, constants;
        base_pressure=FT(100000), potential_temperature=FT(300))
    dynamics = AnelasticDynamics(reference_state)

    friction_velocity = FT(0.5)
    q0 = zero(Breeze.Thermodynamics.MoistureMassFractions{FT})
    surface_density = Breeze.Thermodynamics.density(
        FT(300), FT(100000), q0, constants)
    drag_parameters = (; surface_density, friction_velocity)
    ρu_boundary = FluxBoundaryCondition(fixed_ρu_drag;
        field_dependencies=(:ρu, :ρv), parameters=drag_parameters)
    ρv_boundary = FluxBoundaryCondition(fixed_ρv_drag;
        field_dependencies=(:ρu, :ρv), parameters=drag_parameters)
    boundary_conditions = (;
        ρu=FieldBoundaryConditions(bottom=ρu_boundary),
        ρv=FieldBoundaryConditions(bottom=ρv_boundary))

    sponge_width = FT(200)
    sponge_rate = FT(0.01)
    sponge_mask = GaussianMask{:z}(center=FT(1000), width=sponge_width)
    target_ρθ = Field{Nothing, Nothing, Center}(grid)
    set!(target_ρθ, z -> neutral_reference_theta(z))
    set!(target_ρθ, reference_state.density * target_ρθ)
    target_ρθ_data = interior(target_ρθ, 1, 1, :)
    # This dry anelastic ReferenceState has constant base θ=300 K, so Tᵣ/300 is
    # its Exner function. Capture the field rather than recomputing pressure in a kernel.
    reference_exner_field = Field(reference_state.temperature / FT(300))
    reference_exner = interior(reference_exner_field, 1, 1, :)
    dry_heat_capacity = FT(constants.dry_air.heat_capacity /
                           constants.dry_air.molar_mass)
    energy_sponge = Forcing(inversion_energy_sponge; discrete_form=true,
        parameters=(; rate=sponge_rate, mask=sponge_mask,
                    target_ρθ=target_ρθ_data, reference_exner,
                    dry_heat_capacity))
    vertical_sponge = Relaxation(rate=sponge_rate, mask=sponge_mask)
    coriolis = FPlane(f=FT(1e-4))
    geostrophic = geostrophic_forcings(FT(15), FT(0))
    forcing = (; u=geostrophic.u, v=geostrophic.v,
               w=vertical_sponge, ρE=energy_sponge)
    scheme = WENO(order=9)
    closure = closure_name == "surface_layer" ? SurfaceLayerDiffusivity(FT;
        filter_timescale=filter_seconds, support=1,
        minimum_scalar_fluxes=(ρθ=FT(1e-8),)) : nothing
    model = AtmosphereModel(grid; dynamics, coriolis, microphysics=nothing,
        momentum_advection=scheme, scalar_advection=scheme, closure,
        thermodynamic_constants=constants, forcing, boundary_conditions)

    z_centers = collect(znodes(grid, Center(), Center(), Center()))
    initial = neutral_initial_arrays(FT, nx, ny, nz, z_centers, seed)
    initial_state_sha256 = initial_state_digests(initial)
    set!(model, θ=initial.theta, u=initial.u, v=initial.v, w=zero(FT))

    initial_dt = FT(0.5)
    simulation = Simulation(model; Δt=initial_dt, stop_time)
    conjure_time_step_wizard!(simulation; cfl=FT(0.7))
    Oceananigans.Diagnostics.erroring_NaNChecker!(simulation)
    if fixture
        closure_id = closure_name == "surface_layer" ?
            @sprintf("surface_layer_t%03d_s%d", round(Int, filter_seconds), support) :
            "control"
        configuration = join((nx, ny, nz, closure_name, filter_seconds, support,
                              stop_time, seed, diagnostics_enabled, profile_interval,
                              series_interval, checkpoint_interval), "|")
        configuration_hash = bytes2hex(sha256(configuration))[1:12]
        case_id = @sprintf("neutral_fixture_n%03d_weno9_%s_cfg%s",
                           nx, closure_id, configuration_hash)
    else
        closure_id = closure_name == "surface_layer" ? "surface_layer_t300_s1" : "control"
        case_id = @sprintf("neutral_n%03d_weno9_%s", nx, closure_id)
    end
    mkpath(run_directory)
    settings = (; nx, ny, nz, domain_m=(3000, 3000, 1000), closure_name,
        filter_seconds, support, stop_time, seed, initial_state_sha256,
        initial_dt, wizard_cfl=0.7, architecture=summary(architecture), fixture,
        oceananigans_version=string(Base.pkgversion(Oceananigans)),
        diagnostics_enabled, profile_interval, series_interval, checkpoint_interval,
        friction_velocity, surface_density, fixed_stress_no_roughness=true,
        surface_heat_flux=0.0, inversion_base_m=468.0,
        inversion_thickness_m=62.5, inversion_jump_K=8.0,
        free_troposphere_gradient_K_m=0.003,
        sponge_width_m=sponge_width, sponge_rate_s_inverse=sponge_rate,
        energy_sponge_interface="rhoE converted to rho-theta tendency by dry cp*Exner")
    capture_provenance(run_directory, case_id, settings)

    if diagnostics_enabled
        install_neutral_surface_layer_diagnostics!(simulation;
            dir=run_directory, prefix="$(case_id)_diag", profile_interval,
            series_interval, stop_time,
            prescribed_friction_velocity=friction_velocity)
    end
    simulation.output_writers[:checkpoint] = Checkpointer(model;
        prefix="$(case_id)_checkpoint", schedule=TimeInterval(checkpoint_interval),
        dir=run_directory, overwrite_files=true)
    theta = liquid_ice_potential_temperature(model)
    simulation.output_writers[:state_bounds] = JLD2Writer(model,
        (; theta_min=m -> minimum(liquid_ice_potential_temperature(m)),
           theta_max=m -> maximum(liquid_ice_potential_temperature(m)),
           max_u=m -> maximum(abs, m.velocities.u),
           max_v=m -> maximum(abs, m.velocities.v),
           max_w=m -> maximum(abs, m.velocities.w));
        filename="$(case_id)_state_bounds.jld2", dir=run_directory,
        schedule=TimeInterval(series_interval), overwrite_files=true)

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
    add_callback!(simulation, progress, IterationInterval(progress_interval))
    return (; simulation, model, case_id, settings, initial)
end

function main()
    run_directory = abspath(get(ENV, "NEUTRAL_ABL_RUN_DIR", pwd()))
    setup = build_simulation(; run_directory)
    @info "NEUTRAL_ABL_RUN_START" case_id=setup.case_id settings=setup.settings
    run!(setup.simulation)
    open(joinpath(run_directory, "CASE_DONE"), "w") do io
        println(io, "case_id=", setup.case_id)
        println(io, "final_time_s=", time(setup.simulation))
        println(io, "finished_utc=", Dates.now(Dates.UTC))
    end
    @info "NEUTRAL_ABL_RUN_DONE" case_id=setup.case_id final_time=time(setup.simulation)
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
