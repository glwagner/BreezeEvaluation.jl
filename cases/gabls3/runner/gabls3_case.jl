# GABLS3 revised nine-hour LES case. This runner is CPU-validation-only until the
# GABLS1 campaign releases GPU capacity and the GPU diagnostic contract passes.

using Breeze
using CUDA
using Oceananigans
using Oceananigans: TimeStepCallsite
using Oceananigans.Units
using Printf
using Random
using SHA
using TOML
import Dates

const EVALUATION_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(EVALUATION_REPO, "cases", "gabls3", "preparation", "GABLS3Forcing.jl"))
include(joinpath(EVALUATION_REPO, "cases", "gabls3", "forcing", "GABLS3ModelForcing.jl"))
include(joinpath(EVALUATION_REPO, "cases", "gabls3", "diagnostics", "GABLS3Diagnostics.jl"))

using .GABLS3Forcing
using .GABLS3ModelForcing
using .GABLS3Diagnostics
using Oceananigans: UpdateStateCallsite

function environment_choice(name, valid, default)
    choice = get(ENV, name, default)
    choice in valid || error("$name=$choice is not one of $(join(valid, ", "))")
    return choice
end

function architecture_from_environment()
    name = environment_choice("GABLS3_ARCH", ("cpu", "gpu"), "cpu")
    if name == "gpu"
        CUDA.functional() || error("GABLS3_ARCH=gpu but CUDA is not functional")
    end
    return name == "gpu" ? GPU() : CPU()
end

function advection_scheme(name)
    name == "weno9" && return WENO(order=9)
    name == "weno5" && return WENO(order=5)
    error("unsupported advection scheme $name")
end

function perturbed_initial_arrays(inputs, seed, Nx, Ny, z, FT)
    Nz = length(z)
    rng = MersenneTwister(seed)

    function initialize_component(base, standard_deviation)
        values = Array{FT}(undef, Nx, Ny, Nz)
        for k in 1:Nz, j in 1:Ny, i in 1:Nx
            values[i, j, k] = FT(base(z[k]) + standard_deviation(z[k]) * randn(rng))
        end
        return values
    end

    velocity_deviation(z) = z < 200 ? sqrt(0.2) * (1 - z / 200) : 0.0
    theta_deviation(z) = z < 200 ? sqrt(0.1) : 0.0
    u = initialize_component(z -> initial_u(inputs, z), velocity_deviation)
    v = initialize_component(z -> initial_v(inputs, z), velocity_deviation)
    theta = initialize_component(z -> initial_theta(inputs, z), theta_deviation)
    q = Array{FT}(undef, Nx, Ny, Nz)
    w = zeros(FT, Nx, Ny, Nz + 1)
    for k in 1:Nz, j in 1:Ny, i in 1:Nx
        q[i, j, k] = FT(initial_q(inputs, z[k]))
    end
    return (; u, v, theta, q, w)
end

function initialize_perturbed_state!(model, inputs, seed)
    grid = model.grid
    FT = eltype(grid)
    Nx, Ny, _ = size(grid)
    z = collect(znodes(grid, Center(), Center(), Center()))
    initial = perturbed_initial_arrays(inputs, seed, Nx, Ny, z, FT)
    set!(model, u=initial.u, v=initial.v, θ=initial.theta, qᵗ=initial.q, w=0)
    array_digest(values) = bytes2hex(sha256(reinterpret(UInt8, vec(values))))
    return (;
        u_sha256=array_digest(initial.u),
        v_sha256=array_digest(initial.v),
        theta_sha256=array_digest(initial.theta),
        q_sha256=array_digest(initial.q),
        w_sha256=array_digest(initial.w))
end

function materialized_surface_coefficient(model)
    condition = model.momentum.ρu.boundary_conditions.bottom.condition
    hasproperty(condition, :coefficient) || error("materialized bottom drag lacks coefficient")
    return condition.coefficient
end

function capture_provenance(directory, case_id, settings)
    mkpath(directory)
    provenance = joinpath(directory, "provenance")
    mkpath(provenance)
    breeze_repository = normpath(joinpath(dirname(pathof(Breeze)), ".."))
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
        println(io, "untracked_files:\n", git(breeze_repository, "ls-files", "--others", "--exclude-standard"))
    end
    write(joinpath(provenance, "breeze_uncommitted.diff"), git(breeze_repository, "diff", "HEAD"))
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
    for source in (joinpath(@__DIR__, "gabls3_case.jl"),
                   joinpath(EVALUATION_REPO, "cases", "gabls3", "forcing", "GABLS3ModelForcing.jl"),
                   joinpath(EVALUATION_REPO, "cases", "gabls3", "diagnostics", "GABLS3Diagnostics.jl"),
                   joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics", "SurfaceLayerDiagnostics.jl"),
                   joinpath(EVALUATION_REPO, "cases", "surface_layer", "diagnostics", "LegacyGABLSDiagnosticsAdaptation.jl"),
                   joinpath(EVALUATION_REPO, "cases", "gabls3", "preparation", "GABLS3Forcing.jl"),
                   joinpath(EVALUATION_REPO, "cases", "gabls3", "preparation", "inputs.toml"))
        cp(source, joinpath(provenance, basename(source)); force=true)
    end
    return nothing
end

function build_simulation(; run_directory=pwd())
    architecture = architecture_from_environment()
    FT = Float32
    Oceananigans.defaults.FloatType = FT
    nx = parse(Int, get(ENV, "GABLS3_NX", "64"))
    nx in (64, 128, 256) || error("GABLS3_NX must be 64, 128, or 256")
    scheme_name = environment_choice("GABLS3_SCHEME", ("weno9", "weno5"), "weno9")
    closure_name = environment_choice(
        "GABLS3_CLOSURE", ("none", "smagorinsky", "surface_layer"), "none")
    closure_name == "smagorinsky" && scheme_name != "weno9" &&
        error("the authorized matrix has Smagorinsky only with WENO9")
    closure_name == "surface_layer" && scheme_name != "weno9" &&
        error("the authorized SurfaceLayerDiffusivity matrix uses WENO9 only")
    surface_layer_filter_seconds = parse(Float64,
        get(ENV, "GABLS3_SLD_FILTER_SECONDS", "300"))
    surface_layer_support = parse(Int, get(ENV, "GABLS3_SLD_SUPPORT", "1"))
    surface_layer_filter_seconds > 0 ||
        error("GABLS3_SLD_FILTER_SECONDS must be positive")
    surface_layer_support in (1, 2) || error("GABLS3_SLD_SUPPORT must be 1 or 2")
    stop_time = parse(Float64, get(ENV, "GABLS3_STOP_SECONDS", "32400"))
    seed = parse(Int, get(ENV, "GABLS3_SEED", "20260702"))
    diagnostics_enabled = get(ENV, "GABLS3_DIAGNOSTICS", "1") == "1"

    data_path = joinpath(EVALUATION_REPO, "cases", "gabls3", "preparation", "inputs.toml")
    data = load_case(data_path)
    inputs = GABLS3InputTables(data, FT)
    domain_length = FT(800)
    spacing = domain_length / nx
    halo = scheme_name == "weno9" ? 5 : 3
    grid = RectilinearGrid(architecture; size=(nx, nx, nx),
        x=(0, domain_length), y=(0, domain_length), z=(0, domain_length),
        halo=(halo, halo, halo), topology=(Periodic, Periodic, Bounded))

    constants = ThermodynamicConstants(FT)
    p₀ = FT(inputs.surface_pressure(0))
    reference_state = ReferenceState(grid, constants;
        base_pressure=p₀, potential_temperature=z -> initial_theta(inputs, z),
        vapor_mass_fraction=0)
    Breeze.Thermodynamics.compute_reference_state!(reference_state,
        z -> initial_temperature(inputs, constants, z),
        z -> initial_q(inputs, z), constants)
    dynamics = AnelasticDynamics(reference_state)

    surface_q = Field{Center, Center, Nothing}(grid)
    update_surface_humidity!(surface_q, inputs, 0)
    surface_temperature = SurfaceTemperature(inputs, constants)
    anelastic_surface_pressure = FT(reference_state.base_pressure)
    surface_relative_humidity = SurfaceRelativeHumidity(
        inputs, constants, anelastic_surface_pressure)
    coefficient = GABLS3MOSTCoefficient(surface_q;
        momentum_roughness=inputs.momentum_roughness,
        scalar_reference_height=inputs.scalar_reference_height)

    ρu_bcs = FieldBoundaryConditions(bottom=Breeze.BulkDrag(
        coefficient=coefficient, surface_temperature=surface_temperature))
    ρv_bcs = FieldBoundaryConditions(bottom=Breeze.BulkDrag(
        coefficient=coefficient, surface_temperature=surface_temperature))
    ρE_bcs = FieldBoundaryConditions(bottom=BulkSensibleHeatFlux(
        coefficient=coefficient, surface_temperature=surface_temperature))
    ρq_bcs = FieldBoundaryConditions(bottom=BulkVaporFlux(
        coefficient=coefficient, surface_temperature=surface_temperature,
        surface_relative_humidity=surface_relative_humidity,
        moisture_availability=1))
    boundary_conditions = (ρu=ρu_bcs, ρv=ρv_bcs, ρE=ρE_bcs, ρqᵗ=ρq_bcs)

    latitude = FT(51.9711)
    rotation_rate = FT(7.292115e-5)
    coriolis_parameter = 2rotation_rate * sind(latitude)
    coriolis = FPlane(f=coriolis_parameter)
    geostrophic = geostrophic_forcings(
        z -> geostrophic_u(inputs, z, 0),
        z -> geostrophic_v(inputs, z, 0))
    # Replace the helper's static profiles with exact stage-time functions while preserving
    # its sign convention: Fu=-f*v_g and Fv=+f*u_g.
    geostrophic_u_forcing(x, y, z, t) = -coriolis_parameter * geostrophic_v(inputs, z, t)
    geostrophic_v_forcing(x, y, z, t) = +coriolis_parameter * geostrophic_u(inputs, z, t)
    # These four prescribed tendencies do not use their first argument. Passing
    # `nothing` keeps the exact forcing values and event times, without capturing
    # the entire input-table object in each GPU forcing callable.
    u_advection(x, y, z, t) = advective_u_tendency(nothing, z, t)
    v_advection(x, y, z, t) = advective_v_tendency(nothing, z, t)
    theta_advection(x, y, z, t) = advective_theta_tendency(nothing, z, t)
    q_advection(x, y, z, t) = advective_q_tendency(nothing, z, t)

    damping_mask = PiecewiseLinearMask{:z}(center=domain_length, width=FT(200))
    vertical_sponge = Relaxation(rate=FT(1 / 300), mask=damping_mask)
    forcing = (;
        u=(geostrophic_u_forcing, u_advection),
        v=(geostrophic_v_forcing, v_advection),
        w=vertical_sponge,
        θ=theta_advection,
        qᵗ=q_advection)

    scheme = advection_scheme(scheme_name)
    closure = if closure_name == "smagorinsky"
        SmagorinskyLilly(C=FT(0.16), Cb=FT(1), Pr=FT(1))
    elseif closure_name == "surface_layer"
        SurfaceLayerDiffusivity(FT;
            filter_timescale=surface_layer_filter_seconds,
            support=surface_layer_support,
            minimum_scalar_fluxes=(ρθ=FT(1e-8), ρqᵉ=FT(1e-12)))
    else
        nothing
    end
    microphysics = SaturationAdjustment(equilibrium=WarmPhaseEquilibrium())
    model = AtmosphereModel(grid; dynamics, coriolis, microphysics,
        momentum_advection=scheme, scalar_advection=scheme, closure,
        thermodynamic_constants=constants, forcing, boundary_conditions)

    initial_state_sha256 = initialize_perturbed_state!(model, inputs, seed)
    maximum_initial_speed = FT(15)
    initial_dt = min(FT(0.5), FT(0.5) * spacing / maximum_initial_speed)
    simulation = Simulation(model; Δt=initial_dt, stop_time)
    conjure_time_step_wizard!(simulation, cfl=FT(0.7), max_Δt=FT(5))
    Oceananigans.Diagnostics.erroring_NaNChecker!(simulation)

    update_q(model) = update_surface_humidity!(surface_q, inputs, model.clock.time)
    add_callback!(simulation, update_q, IterationInterval(1); callsite=UpdateStateCallsite())
    # This no-op exists only to align steps with discontinuous prescribed forcing.
    # A TimeStep callback advances its SpecifiedTimes schedule after each event;
    # UpdateState callbacks run at RK stages without advancing that schedule.
    event_callback(simulation) = nothing
    add_callback!(simulation, event_callback, SpecifiedTimes(collect(forcing_events()));
                  callsite=TimeStepCallsite())

    closure_id = closure_name == "surface_layer" ?
        @sprintf("surface_layer_t%03d_s%d",
                 round(Int, surface_layer_filter_seconds), surface_layer_support) : closure_name
    case_id = @sprintf("n%03d_%s_%s", nx, scheme_name, closure_id)
    mkpath(run_directory)
    checkpoint_interval = parse(Float64,
        get(ENV, "GABLS3_CHECKPOINT_SECONDS", "3600"))
    checkpoint_interval > 0 || error("GABLS3_CHECKPOINT_SECONDS must be positive")
    settings = (; nx, spacing, scheme_name, closure_name,
        surface_layer_filter_seconds, surface_layer_support, stop_time, seed,
        initial_dt, wizard_cfl=0.7, latitude, coriolis_parameter,
        diagnostics_enabled, architecture=summary(architecture), initial_state_sha256,
        checkpoint_interval)
    capture_provenance(run_directory, case_id, settings)

    materialized_coefficient = materialized_surface_coefficient(model)
    if diagnostics_enabled
        install_gabls3_diagnostics!(simulation, materialized_coefficient,
            surface_temperature, inputs; dir=run_directory, prefix="$(case_id)_diag")
    end

    simulation.output_writers[:checkpoint] = Checkpointer(model;
        prefix="$(case_id)_checkpoint", schedule=TimeInterval(checkpoint_interval),
        dir=run_directory, overwrite_files=true)

    theta = liquid_ice_potential_temperature(model)
    q = Breeze.AtmosphereModels.specific_prognostic_moisture(model)
    wall_clock = Ref(time_ns())
    last_iteration = Ref(0)
    function progress(sim)
        elapsed = 1e-9 * (time_ns() - wall_clock[])
        steps = iteration(sim) - last_iteration[]
        @info @sprintf("[%s] iter %d t=%s dt=%s %.4f s/step max|w|=%.3g theta=[%.3f,%.3f] q=[%.6g,%.6g] CFL target=.7",
            case_id, iteration(sim), prettytime(sim), prettytime(sim.Δt),
            steps > 0 ? elapsed / steps : NaN, maximum(abs, model.velocities.w),
            minimum(theta), maximum(theta), minimum(q), maximum(q))
        wall_clock[] = time_ns()
        last_iteration[] = iteration(sim)
        return nothing
    end
    add_callback!(simulation, progress, IterationInterval(100))

    return (; simulation, model, inputs, coefficient=materialized_coefficient,
        surface_temperature, surface_q, case_id, settings)
end

function main()
    run_directory = abspath(get(ENV, "GABLS3_RUN_DIR", pwd()))
    setup = build_simulation(; run_directory)
    @info "GABLS3_RUN_START" case_id=setup.case_id settings=setup.settings
    run!(setup.simulation)
    open(joinpath(run_directory, "CASE_DONE"), "w") do io
        println(io, "case_id=", setup.case_id)
        println(io, "final_time_s=", time(setup.simulation))
        println(io, "finished_utc=", Dates.now(Dates.UTC))
    end
    @info "GABLS3_RUN_DONE" case_id=setup.case_id final_time=time(setup.simulation)
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
