using Breeze
using CUDA
using Oceananigans
using JLD2
using SHA
using TOML
import Dates

using Breeze.TurbulenceClosures: SurfaceLayerDiffusivityDeviceFields
using Oceananigans.AbstractOperations: Average
using Oceananigans.Fields: AbstractField, Field
using Oceananigans.Grids: Center, Face, znodes

const VALIDATION_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const VALIDATION_MODE = get(ENV, "SLD_VALIDATION_MODE", "cpu_contract")
const OUTPUT_ROOT = abspath(get(ENV, "SLD_VALIDATION_OUTPUT", mktempdir(; cleanup=false)))
const PASS_COUNT = Ref(0)

module GABLS1ValidationRunner
    include(joinpath(@__DIR__, "..", "gabls1", "gabls1_case.jl"))
end

module GABLS3ValidationRunner
    include(joinpath(@__DIR__, "..", "..", "gabls3", "runner", "gabls3_case.jl"))
end

function require_contract(condition, message)
    condition || error(message)
    PASS_COUNT[] += 1
    return nothing
end

function validation_architecture()
    VALIDATION_MODE in ("cpu_contract", "gpu_full") ||
        error("SLD_VALIDATION_MODE must be cpu_contract or gpu_full")
    VALIDATION_MODE == "cpu_contract" && return CPU()
    CUDA.functional() || error("gpu_full requested but CUDA is not functional")
    CUDA.allowscalar(false)
    return GPU()
end

signed_energy_flux(x, y) = ifelse(x < 20, -0.1f0, 0.1f0)
guarded_moisture_flux(x, y) = ifelse(x < 20, 0.25f-12, 2f-8)

function build_contract_model(architecture; moist, support, closure_enabled=true,
                              energy_flux=:signed, filter_timescale=0.2f0,
                              return_fixture=false)
    FT = Float32
    Oceananigans.defaults.FloatType = FT
    grid = RectilinearGrid(architecture;
        size=(8, 8, 6), x=(0, 40), y=(0, 40), z=(0, 60),
        topology=(Periodic, Periodic, Bounded))
    constants = ThermodynamicConstants(FT)
    reference_state = ReferenceState(grid, constants;
        base_pressure=FT(100000), potential_temperature=FT(300),
        vapor_mass_fraction=moist ? FT(0.002) : FT(0))
    dynamics = AnelasticDynamics(reference_state)
    surface_energy_flux = Field{Center, Center, Nothing}(grid)
    energy_flux === :signed ? set!(surface_energy_flux, signed_energy_flux) :
                              set!(surface_energy_flux, FT(energy_flux))
    boundary_conditions = (;
        ρu=FieldBoundaryConditions(bottom=FluxBoundaryCondition(-0.04f0)),
        ρv=FieldBoundaryConditions(bottom=FluxBoundaryCondition(0f0)),
        ρE=FieldBoundaryConditions(bottom=FluxBoundaryCondition(surface_energy_flux)))
    if moist
        surface_moisture_flux = Field{Center, Center, Nothing}(grid)
        set!(surface_moisture_flux, guarded_moisture_flux)
        boundary_conditions = merge(boundary_conditions, (;
            ρqᵗ=FieldBoundaryConditions(
                bottom=FluxBoundaryCondition(surface_moisture_flux))))
    end
    guards = moist ? (ρθ=1f-8, ρqᵉ=1f-12) : (ρθ=1f-8,)
    closure = closure_enabled ? SurfaceLayerDiffusivity(FT;
        filter_timescale, support, minimum_scalar_fluxes=guards,
        maximum_viscosity=20f0, maximum_diffusivity=20f0) : nothing
    microphysics = moist ?
        SaturationAdjustment(equilibrium=WarmPhaseEquilibrium()) : nothing
    model = AtmosphereModel(grid; dynamics, microphysics, closure,
        thermodynamic_constants=constants, boundary_conditions, advection=nothing)

    u(x, y, z) = 1f0 + 0.02f0 * sinpi(2f0 * x / 40f0) + z^2 / 2000f0
    v(x, y, z) = 0.01f0 * cospi(2f0 * y / 40f0)
    w(x, y, z) = 0.02f0 * sinpi(2f0 * x / 40f0) * sinpi(z / 60f0)
    theta(x, y, z) = 300f0 + z^2 / 1000f0
    if moist
        set!(model; u, v, w, θ=theta, qᵗ=(x, y, z) -> 0.002f0 + z / 1f7)
    else
        set!(model; u, v, w, θ=theta)
    end
    fixture = (; model, surface_energy_flux)
    return return_fixture ? fixture : model
end

function host_field(field)
    return Array(interior(field))
end

function check_support_and_guards(model; moist, support)
    closure_fields = model.closure_fields
    require_contract(eltype(model.grid) === Float32, "contract grid is not Float32")
    viscosity = host_field(closure_fields.Kᵘ)
    require_contract(all(isfinite, viscosity), "non-finite surface-layer viscosity")
    require_contract(maximum(viscosity[:, :, 2]) > 0, "first supported face is inactive")
    if support == 1
        require_contract(all(iszero, viscosity[:, :, 3:end]),
                         "one-face support leaked above the first interior face")
    else
        require_contract(maximum(viscosity[:, :, 3]) > 0,
                         "two-face support did not activate the second interior face")
        require_contract(all(iszero, viscosity[:, :, 4:end]),
                         "two-face support leaked above the second interior face")
    end

    theta_flux = host_field(closure_fields.surface_scalar_flux.ρθ)
    require_contract(all(isfinite, theta_flux), "non-finite filtered heat flux")
    require_contract(minimum(theta_flux) < 0 < maximum(theta_flux),
                     "signed heat-flux kernel did not preserve both signs")
    theta_active = host_field(closure_fields.scalar_active.ρθ[1])
    require_contract(all(value -> value in (0f0, 1f0), theta_active),
                     "heat-flux activity mask is not Boolean-valued Float32")

    if moist
        q_flux = host_field(closure_fields.surface_scalar_flux.ρqᵉ)
        q_active = host_field(closure_fields.scalar_active.ρqᵉ[1])
        require_contract(all(isfinite, q_flux), "non-finite filtered moisture flux")
        require_contract(minimum(q_active) == 0f0 && maximum(q_active) == 1f0,
                         "moisture guard did not separate tiny and resolved fluxes")
    end
    return nothing
end

function column_conservation_check(architecture; moist, support)
    model = build_contract_model(architecture; moist, support, closure_enabled=true)
    control = build_contract_model(architecture; moist, support, closure_enabled=false)
    if architecture isa GPU
        device_fields = CUDA.cudaconvert(model.closure_fields)
        require_contract(device_fields isa SurfaceLayerDiffusivityDeviceFields,
                         "GPU closure adaptation did not select device-only fields")
        require_contract(isbitstype(typeof(device_fields)),
                         "GPU closure fields retain non-bitstype host state")
    end
    Oceananigans.time_step!(model, 0.1f0)
    Oceananigans.time_step!(control, 0.1f0)
    check_support_and_guards(model; moist, support)

    model_fields = Breeze.AtmosphereModels.prognostic_fields(model)
    control_fields = Breeze.AtmosphereModels.prognostic_fields(control)
    names = moist ? (:ρu, :ρθ, :ρqᵉ) : (:ρu, :ρθ)
    for name in names
        model_values = host_field(model_fields[name])
        control_values = host_field(control_fields[name])
        difference = model_values .- control_values
        column_error = maximum(abs, sum(difference; dims=3))
        state_column_scale = max(
            maximum(sum(abs, model_values; dims=3)),
            maximum(sum(abs, control_values; dims=3)))
        tolerance = 64f0 * eps(Float32) * state_column_scale
        require_contract(column_error <= tolerance,
                         "$name implicit transport is not column conservative")
        require_contract(maximum(abs, difference) > 0,
                         "$name implicit surface-layer transport was not exercised")
        if name === :ρqᵉ
            deliberately_nonconservative = copy(difference)
            deliberately_nonconservative[1, 1, 1] += max(10f0 * tolerance, eps(Float32))
            perturbed_error = maximum(abs, sum(deliberately_nonconservative; dims=3))
            require_contract(perturbed_error > tolerance,
                             "moisture conservation audit accepts a nonconservative perturbation")
        end
    end
    return model
end

function signed_heat_flux_crossing_check(architecture)
    crossing = build_contract_model(architecture;
        moist=false, support=1, energy_flux=-0.1f0,
        filter_timescale=0.01f0, return_fixture=true)
    Oceananigans.time_step!(crossing.model, 0.1f0)
    negative_flux = host_field(crossing.model.closure_fields.surface_scalar_flux.ρθ)
    require_contract(maximum(negative_flux) < 0,
                     "synthetic heat-flux crossing did not start negative")
    set!(crossing.surface_energy_flux, 0.1f0)
    Oceananigans.time_step!(crossing.model, 0.1f0)
    positive_flux = host_field(crossing.model.closure_fields.surface_scalar_flux.ρθ)
    require_contract(minimum(positive_flux) > 0,
                     "synthetic heat-flux crossing did not become positive")
    diffusivity = host_field(
        crossing.model.closure_fields.tupled_tracer_diffusivities.ρθ)
    require_contract(all(isfinite, diffusivity) && minimum(diffusivity) >= 0,
                     "signed heat-flux crossing produced invalid diffusivity")

    tiny = build_contract_model(architecture;
        moist=false, support=1, energy_flux=1f-10,
        filter_timescale=0.01f0, return_fixture=true)
    Oceananigans.time_step!(tiny.model, 0.1f0)
    tiny_flux = host_field(tiny.model.closure_fields.surface_scalar_flux.ρθ)
    tiny_active = host_field(tiny.model.closure_fields.scalar_active.ρθ[1])
    tiny_diffusivity = host_field(
        tiny.model.closure_fields.tupled_tracer_diffusivities.ρθ)
    require_contract(maximum(abs, tiny_flux) <= 1f-8,
                     "synthetic tiny heat flux did not remain below the guard")
    require_contract(all(iszero, tiny_active),
                     "synthetic tiny heat flux incorrectly activated the closure")
    require_contract(all(iszero, tiny_diffusivity),
                     "synthetic tiny heat flux produced nonzero diffusivity")
    return Dict(
        "fixture_is_synthetic" => true,
        "negative_filtered_theta_flux" => maximum(negative_flux),
        "positive_filtered_theta_flux" => minimum(positive_flux),
        "tiny_filtered_theta_flux_max_abs" => maximum(abs, tiny_flux))
end

function plane_mean(field)
    return Field(Average(field; dims=(1, 2)))
end

function install_native_profile_writer!(simulation, path)
    model = simulation.model
    w = model.velocities.w
    w_mean = plane_mean(w)
    w_prime = w - w_mean
    theta = liquid_ice_potential_temperature(model)
    outputs = (;
        theta_mean=plane_mean(theta),
        w_mean,
        w_variance=Field(Average(w_prime^2; dims=(1, 2))),
        w_third_central_moment=Field(Average(w_prime^3; dims=(1, 2))),
        surface_layer_viscosity=plane_mean(model.closure_fields.Kᵘ),
        surface_layer_theta_diffusivity=
            plane_mean(model.closure_fields.tupled_tracer_diffusivities.ρθ))
    if hasproperty(model.closure_fields.tupled_tracer_diffusivities, :ρqᵉ)
        q = Breeze.AtmosphereModels.specific_prognostic_moisture(model)
        outputs = merge(outputs, (;
            q_mean=plane_mean(q),
            surface_layer_q_diffusivity=
                plane_mean(model.closure_fields.tupled_tracer_diffusivities.ρqᵉ)))
    end
    z_center = collect(znodes(model.grid, Center(), Center(), Center()))
    z_face = collect(znodes(model.grid, Center(), Center(), Face()))
    initializer = (file, model) -> begin
        file["contract/z_center_m"] = z_center
        file["contract/z_face_m"] = z_face
        file["contract/w_moment_location"] = "native_z_face"
        file["contract/scalar_location"] = "native_z_center"
    end
    simulation.output_writers[:native_profiles] = JLD2Writer(model, outputs;
        filename=basename(path), dir=dirname(path),
        schedule=SpecifiedTimes([0.0, 0.1, 0.2]), with_halos=false,
        overwrite_files=true, init=initializer)
    return outputs
end

function raw_times(path)
    return jldopen(path, "r") do file
        group = file["timeseries/t"]
        sort([Float64(group[key]) for key in keys(group)])
    end
end

function audit_native_profile_writer(path, Nz; moist)
    expected_times = Float64.(Float32.([0.0, 0.1, 0.2]))
    require_contract(raw_times(path) == expected_times,
                     "native profile writer missed an exact scheduled time")
    jldopen(path, "r") do file
        require_contract(length(file["contract/z_center_m"]) == Nz,
                         "center coordinate length mismatch")
        require_contract(length(file["contract/z_face_m"]) == Nz + 1,
                         "face coordinate length mismatch")
        require_contract(file["contract/w_moment_location"] == "native_z_face",
                         "native w location metadata missing")
        expected = Dict(
            "theta_mean" => Nz,
            "w_mean" => Nz + 1,
            "w_variance" => Nz + 1,
            "w_third_central_moment" => Nz + 1,
            "surface_layer_viscosity" => Nz + 1,
            "surface_layer_theta_diffusivity" => Nz + 1)
        moist && merge!(expected, Dict(
            "q_mean" => Nz,
            "surface_layer_q_diffusivity" => Nz + 1))
        for (name, vertical_length) in expected
            group = file["timeseries/$name"]
            record_keys = filter(key -> key != "serialized", collect(keys(group)))
            require_contract(length(record_keys) == 3,
                             "$name does not have three scheduled records")
            for key in record_keys
                values = group[key]
                require_contract(length(values) == vertical_length,
                                 "$name has the wrong native vertical length")
                require_contract(all(isfinite, values), "$name is not finite")
            end
        end
    end
    return nothing
end

function flatten_state!(flat, prefix, state)
    if state isa Nothing
        return flat
    elseif state isa Oceananigans.TimeSteppers.Clock
        for name in propertynames(state)
            flatten_state!(flat, "$prefix.$name", getproperty(state, name))
        end
    elseif state isa AbstractField
        flat[prefix] = host_field(state)
    elseif state isa AbstractArray
        flat[prefix] = Array(state)
    elseif state isa NamedTuple
        for name in keys(state)
            flatten_state!(flat, isempty(prefix) ? string(name) : "$prefix.$name",
                           getproperty(state, name))
        end
    elseif state isa Tuple
        for (index, value) in enumerate(state)
            flatten_state!(flat, "$prefix[$index]", value)
        end
    elseif state isa Base.RefValue
        flatten_state!(flat, prefix, state[])
    elseif state isa Number || state isa Bool
        flat[prefix] = state
    else
        error("unsupported checkpoint-state leaf $(typeof(state)) at $prefix")
    end
    return flat
end

function host_prognostic_state(model)
    return flatten_state!(Dict{String, Any}(), "", Oceananigans.prognostic_state(model))
end

function require_identical_states(reference, restarted)
    require_contract(Set(keys(reference)) == Set(keys(restarted)),
                     "restart changed prognostic-state keys")
    for key in keys(reference)
        require_contract(reference[key] == restarted[key],
                         "serialized restart mismatch at $key")
    end
    return nothing
end

function serialized_restart_check(architecture; moist, support, directory)
    mkpath(directory)
    reference_model = build_contract_model(architecture; moist, support)
    reference = Simulation(reference_model; Δt=0.1f0, stop_iteration=4)
    run!(reference)

    split_model = build_contract_model(architecture; moist, support)
    split = Simulation(split_model; Δt=0.1f0, stop_iteration=2)
    prefix = "serialized_$(moist ? "moist" : "dry")_s$(support)"
    split.output_writers[:checkpoint] = Checkpointer(split_model;
        prefix, dir=directory, schedule=IterationInterval(2), overwrite_files=true)
    run!(split)
    checkpoint_files = filter(
        name -> name == "$(prefix)_iteration2.jld2", readdir(directory))
    require_contract(length(checkpoint_files) == 1,
                     "expected the serialized iteration-2 checkpoint for $prefix")
    checkpoint_path = joinpath(directory, only(checkpoint_files))
    require_contract(filesize(checkpoint_path) > 0, "serialized checkpoint is empty")

    restarted_model = build_contract_model(architecture; moist, support)
    restarted = Simulation(restarted_model; Δt=0.1f0, stop_iteration=4)
    restarted.output_writers[:checkpoint] = Checkpointer(restarted_model;
        prefix="restored_$prefix", dir=directory,
        schedule=IterationInterval(2), overwrite_files=true)
    set!(restarted; checkpoint=checkpoint_path)
    require_contract(iteration(restarted) == 2 && time(restarted) == 0.2f0,
                     "serialized checkpoint did not restore clock/iteration")
    run!(restarted)
    require_contract(iteration(reference) == iteration(restarted) == 4,
                     "restarted continuation ended at the wrong iteration")
    require_contract(time(reference) == time(restarted),
                     "restarted continuation ended at the wrong time")
    require_identical_states(host_prognostic_state(reference_model),
                             host_prognostic_state(restarted_model))
    return Dict(
        "checkpoint_sha256" => bytes2hex(open(sha256, checkpoint_path)),
        "checkpoint_bytes" => filesize(checkpoint_path))
end

function tiny_model_contract(architecture)
    restart_evidence = Dict{String, Any}()
    for moist in (false, true), support in (1, 2)
        label = "$(moist ? "moist" : "dry")_support$(support)"
        model = column_conservation_check(architecture; moist, support)
        writer_directory = joinpath(OUTPUT_ROOT, "native_writers", label)
        mkpath(writer_directory)
        writer_model = build_contract_model(architecture; moist, support)
        writer_simulation = Simulation(writer_model; Δt=0.1f0, stop_iteration=2)
        writer_path = joinpath(writer_directory, "native_profiles.jld2")
        install_native_profile_writer!(writer_simulation, writer_path)
        run!(writer_simulation)
        audit_native_profile_writer(writer_path, writer_model.grid.Nz; moist)
        restart_evidence[label] = serialized_restart_check(
            architecture; moist, support,
            directory=joinpath(OUTPUT_ROOT, "restart", label))
        require_contract(all(isfinite, host_field(model.closure_fields.Kᵘ)),
                         "$label left non-finite closure coefficients")
    end
    restart_evidence["synthetic_signed_heat_flux"] =
        signed_heat_flux_crossing_check(architecture)
    return restart_evidence
end

function skip_past_specified_times!(simulation, current_time)
    activities = (values(simulation.output_writers)..., values(simulation.callbacks)...)
    for activity in activities
        schedule = activity.schedule
        if schedule isa SpecifiedTimes
            schedule.previous_actuation = searchsortedlast(schedule.times, current_time)
        end
    end
    return nothing
end

function audit_full_profile_file(path, expected_time, Nz; minimum_variables)
    require_contract(raw_times(path) == [expected_time],
                     "$path does not contain exactly the scheduled record $expected_time")
    jldopen(path, "r") do file
        variables = filter(name -> name != "t" && name != "serialized",
                           String.(collect(keys(file["timeseries"]))))
        require_contract(length(variables) >= minimum_variables,
                         "$path has too few profile variables")
        for variable in variables
            group = file["timeseries/$variable"]
            for key in filter(key -> key != "serialized", collect(keys(group)))
                values = group[key]
                require_contract(length(values) in (Nz, Nz + 1),
                                 "$variable has unexpected vertical length $(length(values))")
                require_contract(all(isfinite, values), "$variable contains non-finite values")
            end
        end
    end
    return nothing
end

function audit_reduced_file(path, expected_time)
    require_contract(raw_times(path) == [expected_time],
                     "$path does not contain exactly the scheduled record $expected_time")
    jldopen(path, "r") do file
        variables = filter(name -> name != "t" && name != "serialized",
                           String.(collect(keys(file["timeseries"]))))
        require_contract(!isempty(variables), "$path has no reduced diagnostics")
        for variable in variables
            group = file["timeseries/$variable"]
            for key in filter(key -> key != "serialized", collect(keys(group)))
                require_contract(all(isfinite, group[key]),
                                 "$variable contains non-finite reduced output")
            end
        end
    end
    return nothing
end

function gabls3_serialized_restart_contract(directory)
    mkpath(directory)
    ENV["GABLS3_ARCH"] = "gpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno9"
    ENV["GABLS3_CLOSURE"] = "surface_layer"
    ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
    ENV["GABLS3_SLD_SUPPORT"] = "1"
    ENV["GABLS3_STOP_SECONDS"] = "10"
    ENV["GABLS3_DIAGNOSTICS"] = "0"

    reference_directory = joinpath(directory, "uninterrupted")
    reference = GABLS3ValidationRunner.build_simulation(
        ; run_directory=reference_directory)
    delete!(reference.simulation.output_writers, :checkpoint)
    reference.simulation.stop_iteration = 2
    run!(reference.simulation)
    reference_state = host_prognostic_state(reference.model)
    reference_time = time(reference.simulation)
    reference_digest = reference.settings.initial_state_sha256
    reference = nothing
    GC.gc(true)
    CUDA.reclaim()

    split_directory = joinpath(directory, "split")
    split = GABLS3ValidationRunner.build_simulation(; run_directory=split_directory)
    delete!(split.simulation.output_writers, :checkpoint)
    split.simulation.stop_iteration = 1
    prefix = "gabls3_sld_serialized"
    split.simulation.output_writers[:validation_checkpoint] = Checkpointer(split.model;
        prefix, dir=split_directory, schedule=IterationInterval(1),
        overwrite_files=true)
    run!(split.simulation)
    checkpoint_path = joinpath(split_directory, "$(prefix)_iteration1.jld2")
    require_contract(isfile(checkpoint_path),
                     "GABLS3 runner did not serialize its iteration-1 checkpoint")
    require_contract(split.settings.initial_state_sha256 == reference_digest,
                     "GABLS3 split branch did not use the paired initial arrays")
    split = nothing
    GC.gc(true)
    CUDA.reclaim()

    restart_directory = joinpath(directory, "restarted")
    restarted = GABLS3ValidationRunner.build_simulation(; run_directory=restart_directory)
    delete!(restarted.simulation.output_writers, :checkpoint)
    restarted.simulation.stop_iteration = 2
    set!(restarted.simulation; checkpoint=checkpoint_path)
    require_contract(iteration(restarted.simulation) == 1,
                     "GABLS3 runner checkpoint did not restore iteration 1")
    # Oceananigans checkpoints the model clock (including its applied last_Δt),
    # but not Simulation.Δt. The step-zero wizard has already raised Δt from the
    # constructor value; restoring only the model would continue at a different
    # timestep. This iteration-one fixture resumes with the serialized applied
    # timestep, before the wizard's next scheduled update at iteration ten.
    restored_Δt = restarted.model.clock.last_Δt
    require_contract(isfinite(restored_Δt) && restored_Δt > 0,
                     "GABLS3 checkpoint has no valid applied timestep")
    require_contract(restored_Δt != restarted.simulation.Δt,
                     "GABLS3 restart fixture did not exercise timestep restoration")
    restarted.simulation.Δt = restored_Δt
    run!(restarted.simulation)
    require_contract(time(restarted.simulation) == reference_time,
                     "GABLS3 restarted runner ended at the wrong time")
    require_identical_states(reference_state, host_prognostic_state(restarted.model))
    return Dict(
        "checkpoint_sha256" => bytes2hex(open(sha256, checkpoint_path)),
        "checkpoint_bytes" => filesize(checkpoint_path),
        "continued_iteration" => iteration(restarted.simulation),
        "continued_time_s" => time(restarted.simulation),
        "initial_state_sha256" => string(reference_digest))
end

function full_gpu_runner_contract()
    VALIDATION_MODE == "gpu_full" || return Dict{String, Any}()

    gabls1_directory = joinpath(OUTPUT_ROOT, "gabls1_full_writer")
    ENV["GABLS1_SLD_ARCH"] = "gpu"
    ENV["GABLS1_SLD_NX"] = "32"
    ENV["GABLS1_SLD_CLOSURE"] = "surface_layer"
    ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
    ENV["GABLS1_SLD_SUPPORT"] = "2"
    ENV["GABLS1_SLD_STOP_SECONDS"] = "1"
    ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
    gabls1 = GABLS1ValidationRunner.build_simulation(; run_directory=gabls1_directory)
    run!(gabls1.simulation)
    gabls1_initial = joinpath(gabls1_directory, "$(gabls1.case_id)_diag_initial.jld2")
    audit_full_profile_file(gabls1_initial, 0.0, 32; minimum_variables=46)
    require_contract(gabls1.settings.theta_initial_sha256 ==
        "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b",
        "GABLS1 paired initial array digest changed")
    gabls1_case_id = gabls1.case_id
    gabls1_initial_theta_sha256 = gabls1.settings.theta_initial_sha256
    gabls1 = nothing
    GC.gc(true)
    CUDA.reclaim()

    gabls3_restart = gabls3_serialized_restart_contract(
        joinpath(OUTPUT_ROOT, "gabls3_serialized_restart"))

    gabls3_writer_directory = joinpath(OUTPUT_ROOT, "gabls3_full_writer_clock_jump")
    ENV["GABLS3_ARCH"] = "gpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno9"
    ENV["GABLS3_CLOSURE"] = "surface_layer"
    ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
    ENV["GABLS3_SLD_SUPPORT"] = "2"
    ENV["GABLS3_STOP_SECONDS"] = "301"
    ENV["GABLS3_DIAGNOSTICS"] = "1"
    gabls3_writer = GABLS3ValidationRunner.build_simulation(
        ; run_directory=gabls3_writer_directory)
    delete!(gabls3_writer.simulation.output_writers, :checkpoint)
    gabls3_writer.model.clock.time = 295.0
    skip_past_specified_times!(gabls3_writer.simulation, 295.0)
    run!(gabls3_writer.simulation)
    prefix = joinpath(gabls3_writer_directory, "$(gabls3_writer.case_id)_diag")
    audit_full_profile_file(prefix * "_profiles.jld2", 300.0, 64;
                            minimum_variables=46)
    audit_reduced_file(prefix * "_series.jld2", 300.0)
    audit_reduced_file(prefix * "_points.jld2", 300.0)
    gabls3_case_id = gabls3_writer.case_id
    gabls3_initial_state_sha256 = string(gabls3_writer.settings.initial_state_sha256)
    gabls3_writer = nothing
    GC.gc(true)
    CUDA.reclaim()

    sunrise_directory = joinpath(OUTPUT_ROOT, "gabls3_sunrise_clock_jump")
    ENV["GABLS3_SLD_SUPPORT"] = "1"
    ENV["GABLS3_STOP_SECONDS"] = "21601"
    ENV["GABLS3_DIAGNOSTICS"] = "0"
    sunrise = GABLS3ValidationRunner.build_simulation(; run_directory=sunrise_directory)
    delete!(sunrise.simulation.output_writers, :checkpoint)
    sunrise.model.clock.time = 21599.0
    event_time = Ref(NaN)
    event_surface_q = Ref(NaN)
    function observe_sunrise(model)
        event_time[] = time(model)
        event_surface_q[] = minimum(sunrise.surface_q)
        return nothing
    end
    add_callback!(sunrise.simulation, observe_sunrise, SpecifiedTimes([21600.0]))
    skip_past_specified_times!(sunrise.simulation, 21599.0)
    run!(sunrise.simulation)
    expected_q = GABLS3ValidationRunner.GABLS3ModelForcing.surface_state(
        sunrise.inputs, 21600.0).q
    require_contract(event_time[] == 21600.0, "sunrise callback did not fire exactly at 21600 s")
    require_contract(event_surface_q[] ≈ expected_q,
                     "surface humidity was not refreshed at the sunrise event")
    moisture_activity = host_field(sunrise.model.closure_fields.scalar_active.ρqᵉ[1])
    require_contract(all(value -> value in (0f0, 1f0), moisture_activity),
                     "sunrise moisture guard mask is invalid")
    theta_flux = host_field(sunrise.model.closure_fields.surface_scalar_flux.ρθ)
    theta_activity = host_field(sunrise.model.closure_fields.scalar_active.ρθ[1])
    theta_diffusivity = host_field(
        sunrise.model.closure_fields.tupled_tracer_diffusivities.ρθ)
    theta_guard = sunrise.model.closure.minimum_scalar_fluxes.ρθ
    require_contract(theta_guard === 1f-8, "GABLS3 theta-flux guard changed")
    require_contract(all(isfinite, theta_flux), "GABLS3 sunrise theta flux is not finite")
    require_contract(all(value -> value in (0f0, 1f0), theta_activity),
                     "GABLS3 sunrise theta activity mask is invalid")
    require_contract(all(isfinite, theta_diffusivity) && minimum(theta_diffusivity) >= 0,
                     "GABLS3 sunrise theta diffusivity is invalid")
    below_guard = abs.(theta_flux) .<= theta_guard
    require_contract(all(theta_activity[below_guard] .== 0f0),
                     "GABLS3 theta guard admitted a below-threshold heat flux")

    return Dict(
        "gabls1_case_id" => gabls1_case_id,
        "gabls1_initial_theta_sha256" => gabls1_initial_theta_sha256,
        "gabls3_case_id" => gabls3_case_id,
        "gabls3_initial_state_sha256" => gabls3_initial_state_sha256,
        "gabls3_serialized_restart" => gabls3_restart,
        "sunrise_event_time_s" => event_time[],
        "sunrise_theta_flux_min" => minimum(theta_flux),
        "sunrise_theta_flux_max" => maximum(theta_flux),
        "sunrise_theta_active_fraction" => sum(theta_activity) / length(theta_activity),
        "sunrise_theta_flux_guard" => theta_guard,
        "sunrise_clock_jump_fixture_nonphysical" => true,
        "writer_clock_jump_fixture_nonphysical" => true)
end

function source_hashes()
    sources = (
        @__FILE__,
        joinpath(@__DIR__, "..", "registries", "gabls1_sld_4case.toml"),
        joinpath(@__DIR__, "..", "registries", "gabls3_sld_4case.toml"),
        joinpath(VALIDATION_ROOT, "cases", "surface_layer", "gabls1", "gabls1_case.jl"),
        joinpath(VALIDATION_ROOT, "cases", "gabls3", "runner", "gabls3_case.jl"))
    return Dict(relpath(path, VALIDATION_ROOT) => bytes2hex(open(sha256, path))
                for path in sources)
end

function write_evidence(architecture, restart_evidence, runner_evidence)
    freeze_root = get(ENV, "SLD_FREEZE_ROOT", "")
    if VALIDATION_MODE == "gpu_full"
        require_contract(!isempty(freeze_root),
                         "gpu_full requires the immutable SLD_FREEZE_ROOT")
        require_contract(isfile(joinpath(freeze_root, "source_sha256.txt")),
                         "immutable freeze source_sha256.txt is missing")
    end
    source_manifest = isempty(freeze_root) ? "" : joinpath(freeze_root, "source_sha256.txt")
    evidence = Dict{String, Any}(
        "schema_version" => 1,
        "validation_mode" => VALIDATION_MODE,
        "architecture" => summary(architecture),
        "float_type" => "Float32",
        "passed_checks" => PASS_COUNT[],
        "all_passed" => true,
        "completed_utc" => string(Dates.now(Dates.UTC)),
        "julia_version" => string(VERSION),
        "cuda_functional" => VALIDATION_MODE == "gpu_full",
        "cuda_scalar_indexing_disabled" => VALIDATION_MODE == "gpu_full",
        "freeze_root" => isempty(freeze_root) ? "DEVELOPMENT_NO_FREEZE" : freeze_root,
        "freeze_source_manifest_sha256" => isempty(source_manifest) ?
            "DEVELOPMENT_NO_FREEZE" : bytes2hex(open(sha256, source_manifest)),
        "freeze_source_manifest_entries" => isempty(source_manifest) ? 0 :
            count(line -> !isempty(line), readlines(source_manifest)),
        "nonphysical_clock_jump_outputs_admissible_as_science" => false,
        "restart" => restart_evidence,
        "full_runner" => runner_evidence,
        "source_sha256" => source_hashes())
    path = joinpath(OUTPUT_ROOT, "validation_evidence.toml")
    open(path, "w") do io
        TOML.print(io, evidence; sorted=true)
    end
    return path
end

function main()
    mkpath(OUTPUT_ROOT)
    prefix = VALIDATION_MODE == "gpu_full" ? "GPU" : "CPU"
    done = joinpath(OUTPUT_ROOT, "$(prefix)_VALIDATION_DONE")
    failed = joinpath(OUTPUT_ROOT, "$(prefix)_VALIDATION_FAILED")
    started = joinpath(OUTPUT_ROOT, "$(prefix)_VALIDATION_STARTED")
    ispath(done) && error("refusing to overwrite completed validation at $OUTPUT_ROOT")
    ispath(failed) && error("refusing to overwrite failed validation at $OUTPUT_ROOT")
    open(started, "w") do io
        println(io, "mode=", VALIDATION_MODE)
        println(io, "started_utc=", Dates.now(Dates.UTC))
    end
    try
        architecture = validation_architecture()
        @info "SLD_VALIDATION_PHASE" phase="tiny_model_kernel_writer_restart"
        restart_evidence = tiny_model_contract(architecture)
        @info "SLD_VALIDATION_PHASE" phase="full_case_writer_and_sunrise"
        runner_evidence = full_gpu_runner_contract()
        evidence_path = write_evidence(architecture, restart_evidence, runner_evidence)
        open(done, "w") do io
            println(io, "mode=", VALIDATION_MODE)
            println(io, "passed_checks=", PASS_COUNT[])
            println(io, "evidence_sha256=", bytes2hex(open(sha256, evidence_path)))
            println(io, "completed_utc=", Dates.now(Dates.UTC))
        end
        println("SLD_VALIDATION_PASS mode=", VALIDATION_MODE,
                " checks=", PASS_COUNT[], " output=", OUTPUT_ROOT)
    catch error
        open(failed, "w") do io
            println(io, "mode=", VALIDATION_MODE)
            println(io, "failed_utc=", Dates.now(Dates.UTC))
            showerror(io, error, catch_backtrace())
            println(io)
        end
        rethrow()
    end
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
