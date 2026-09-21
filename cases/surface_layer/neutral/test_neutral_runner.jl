using Breeze
using JLD2
using Logging
using Oceananigans
using Test
using TOML

using Breeze.AtmosphereModels: liquid_ice_potential_temperature,
                               thermodynamic_density
using Oceananigans.Fields: AbstractField, Field, interior
using Oceananigans.Models: BoundaryConditionOperation

module NeutralRunner
    include(joinpath(@__DIR__, "neutral_abl_case.jl"))
end

function configure_fixture!(; closure="surface_layer", diagnostics=false,
                            stop_time="1", profile_interval="0.2",
                            series_interval="0.1")
    ENV["NEUTRAL_ABL_FIXTURE"] = "1"
    ENV["NEUTRAL_ABL_ARCH"] = "cpu"
    ENV["NEUTRAL_ABL_NX"] = "8"
    ENV["NEUTRAL_ABL_NY"] = "8"
    ENV["NEUTRAL_ABL_NZ"] = "12"
    ENV["NEUTRAL_ABL_CLOSURE"] = closure
    ENV["NEUTRAL_ABL_FILTER_SECONDS"] = "300"
    ENV["NEUTRAL_ABL_SUPPORT"] = "1"
    ENV["NEUTRAL_ABL_STOP_SECONDS"] = stop_time
    ENV["NEUTRAL_ABL_SEED"] = "1994"
    ENV["NEUTRAL_ABL_DIAGNOSTICS"] = diagnostics ? "1" : "0"
    ENV["NEUTRAL_ABL_PROFILE_INTERVAL"] = profile_interval
    ENV["NEUTRAL_ABL_SERIES_INTERVAL"] = series_interval
    ENV["NEUTRAL_ABL_CHECKPOINT_INTERVAL"] = "100"
    ENV["NEUTRAL_ABL_PROGRESS_INTERVAL"] = "10000"
    return nothing
end

host(field) = Array(interior(field))

function boundary_fluxes(model)
    u = Field(BoundaryConditionOperation(model.momentum.ρu, :bottom, model))
    v = Field(BoundaryConditionOperation(model.momentum.ρv, :bottom, model))
    theta_density = thermodynamic_density(model.formulation)
    theta = Field(BoundaryConditionOperation(theta_density, :bottom, model))
    compute!(u); compute!(v); compute!(theta)
    return (; u=host(u), v=host(v), theta=host(theta))
end

function flatten_state!(flat, prefix, state)
    if state isa Nothing
        return flat
    elseif state isa Oceananigans.TimeSteppers.Clock
        for name in propertynames(state)
            flatten_state!(flat, "$prefix.$name", getproperty(state, name))
        end
    elseif state isa AbstractField
        flat[prefix] = host(state)
    elseif state isa AbstractArray
        flat[prefix] = Array(state)
    elseif state isa NamedTuple
        for name in keys(state)
            nested = isempty(prefix) ? string(name) : "$prefix.$name"
            flatten_state!(flat, nested, getproperty(state, name))
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
        error("unsupported checkpoint state $(typeof(state)) at $prefix")
    end
    return flat
end

model_state(model) = flatten_state!(
    Dict{String, Any}(), "", Oceananigans.prognostic_state(model))

function raw_times(path)
    return jldopen(path, "r") do file
        group = file["timeseries/t"]
        sort([Float64(group[key]) for key in keys(group)])
    end
end

function raw_records(path, name)
    return jldopen(path, "r") do file
        group = file["timeseries/$name"]
        record_keys = filter(!=("serialized"), String.(keys(group)))
        sort([(time=Float64(file["timeseries/t/$key"]),
               value=Array(group[key])) for key in record_keys]; by=first)
    end
end

@testset "Neutral registry and canonical contract" begin
    registry = TOML.parsefile(joinpath(@__DIR__, "neutral_sld_2case.toml"))
    @test registry["expected_case_count"] == 2
    @test registry["grid"] == [96, 96, 96]
    @test registry["domain_m"] == [3000.0, 3000.0, 1000.0]
    @test registry["duration_s"] == 18000.0
    @test registry["profile_record_count"] == 30
    @test registry["final_hour_source_times_s"] ==
          collect(15000.0:600.0:18000.0)
    @test registry["penultimate_hour_source_times_s"] ==
          collect(11400.0:600.0:14400.0)
    @test registry["prescribed_friction_velocity_m_s"] == 0.5
    @test registry["prescribed_surface_heat_flux_K_m_s"] == 0.0
    z = Float32.(((1:96) .- 0.5) .* (1000 / 96))
    initial = NeutralRunner.neutral_initial_arrays(Float32, 96, 96, 96, z, 1994)
    digests = NeutralRunner.initial_state_digests(initial)
    for (name, expected) in registry["paired_initial_state_sha256"]
        @test getproperty(digests, Symbol(name)) == expected
    end
    @test NeutralRunner.neutral_reference_theta(468f0) == 300f0
    @test NeutralRunner.neutral_reference_theta(530.5f0) == 308f0

    ENV["NEUTRAL_ABL_FIXTURE"] = "0"
    ENV["NEUTRAL_ABL_ARCH"] = "cpu"
    ENV["NEUTRAL_ABL_NX"] = "96"
    ENV["NEUTRAL_ABL_NY"] = "96"
    ENV["NEUTRAL_ABL_NZ"] = "96"
    ENV["NEUTRAL_ABL_CLOSURE"] = "surface_layer"
    ENV["NEUTRAL_ABL_FILTER_SECONDS"] = "200"
    ENV["NEUTRAL_ABL_SUPPORT"] = "1"
    ENV["NEUTRAL_ABL_STOP_SECONDS"] = "18000"
    ENV["NEUTRAL_ABL_SEED"] = "1994"
    ENV["NEUTRAL_ABL_DIAGNOSTICS"] = "1"
    ENV["NEUTRAL_ABL_PROFILE_INTERVAL"] = "600"
    ENV["NEUTRAL_ABL_SERIES_INTERVAL"] = "60"
    ENV["NEUTRAL_ABL_CHECKPOINT_INTERVAL"] = "3600"
    @test_throws ErrorException NeutralRunner.build_simulation(run_directory=mktempdir())
end

@testset "Fixed stress, zero heat flux, support, and conservation" begin
    configure_fixture!(closure="none")
    control = NeutralRunner.build_simulation(run_directory=mktempdir())
    configure_fixture!(closure="surface_layer")
    surface_layer = NeutralRunner.build_simulation(run_directory=mktempdir())
    @test control.settings.initial_state_sha256 == surface_layer.settings.initial_state_sha256
    @test control.settings.fixed_stress_no_roughness === true
    @test surface_layer.settings.surface_heat_flux == 0.0
    @test startswith(surface_layer.case_id,
        "neutral_fixture_n008_weno9_surface_layer_t300_s1_cfg")
    @test surface_layer.case_id != control.case_id

    for setup in (control, surface_layer)
        flux = boundary_fluxes(setup.model)
        dynamic_stress = sqrt.(flux.u .^ 2 .+ flux.v .^ 2)
        expected = setup.settings.surface_density * 0.5f0^2
        @test all(isapprox.(dynamic_stress, expected; rtol=2f-5, atol=2f-6))
        @test all(iszero, flux.theta)
    end

    Oceananigans.time_step!(control.model, 0.1f0)
    Oceananigans.time_step!(surface_layer.model, 0.1f0)
    closure_fields = surface_layer.model.closure_fields
    viscosity = host(closure_fields.Kᵘ)
    diffusivity = host(closure_fields.tupled_tracer_diffusivities.ρθ)
    @test all(isfinite, viscosity)
    @test maximum(viscosity[:, :, 2]) > 0
    @test all(iszero, viscosity[:, :, 3:end])
    @test all(iszero, diffusivity)
    @test all(iszero, host(closure_fields.scalar_active.ρθ[1]))

    control_fields = Breeze.AtmosphereModels.prognostic_fields(control.model)
    surface_fields = Breeze.AtmosphereModels.prognostic_fields(surface_layer.model)
    for name in (:ρu, :ρv, :ρθ)
        control_values = host(control_fields[name])
        surface_values = host(surface_fields[name])
        difference = surface_values .- control_values
        # The full runner includes periodic horizontal transport and a stress vector whose
        # direction follows the evolving local wind, so compare global mass-weighted content.
        # The feature-level operator suite separately checks isolated per-column conservation.
        conservation_error = abs(sum(difference))
        scale = max(sum(abs, control_values), sum(abs, surface_values))
        tolerance = 128f0 * eps(Float32) * scale
        @test conservation_error <= tolerance
        deliberately_nonconservative = copy(difference)
        deliberately_nonconservative[1] += max(10f0 * tolerance, eps(Float32))
        @test abs(sum(deliberately_nonconservative)) > tolerance
    end
end

@testset "Native diagnostics and six-record hour windows" begin
    configure_fixture!(closure="surface_layer", diagnostics=true,
                       stop_time="0.4", profile_interval="0.2",
                       series_interval="0.1")
    directory = mktempdir()
    setup = NeutralRunner.build_simulation(run_directory=directory)
    with_logger(NullLogger()) do
        run!(setup.simulation)
    end
    prefix = joinpath(directory, "$(setup.case_id)_diag")
    initial_path = prefix * "_initial.jld2"
    profiles_path = prefix * "_statistics.jld2"
    series_path = prefix * "_series.jld2"
    @test raw_times(initial_path) == [0.0]
    @test all(isapprox.(raw_times(profiles_path), [0.2, 0.4]; atol=2e-7, rtol=0))
    @test all(isapprox.(raw_times(series_path), collect(0.0:0.1:0.4);
                        atol=2e-7, rtol=0))
    midpoint_records = raw_records(
        profiles_path, "averaging_interval_midpoint_time_seconds")
    @test length(midpoint_records) == 2
    @test isapprox(only(midpoint_records[1].value), 0.1; atol=2e-6, rtol=0)
    @test isapprox(only(midpoint_records[2].value), 0.3; atol=2e-6, rtol=0)
    jldopen(profiles_path, "r") do file
        @test file["metadata/authorized_final_hour_source_times_seconds"] ==
              (15000, 15600, 16200, 16800, 17400, 18000)
        @test file["metadata/authorized_penultimate_hour_source_times_seconds"] ==
              (11400, 12000, 12600, 13200, 13800, 14400)
        @test all(isapprox.(file["metadata/expected_profile_times_seconds"],
                            [0.2, 0.4]; atol=2e-7, rtol=0))
        @test file["metadata/expected_profile_record_count"] == 2
        @test length(file["coordinates/z_center_m"]) == 12
        @test length(file["coordinates/z_face_m"]) == 13
        @test file["coordinates/native_w_moment_location"] == "Face"
        for name in ("w_mean", "w_variance", "w_third_central_moment",
                     "resolved_u_w_flux", "sgs_u_w_flux", "total_u_w_flux",
                     "u_vertical_gradient", "surface_layer_viscosity",
                     "surface_layer_diffusivity_ρθ")
            keys_for_variable = filter(!=("serialized"),
                String.(keys(file["timeseries/$name"])))
            @test length(keys_for_variable) == 2
            for key in keys_for_variable
                values = file["timeseries/$name/$key"]
                @test size(values, ndims(values)) == 13
                @test all(isfinite, values)
            end
        end
    end
end

@testset "Serialized closure restart continuation" begin
    configure_fixture!(closure="surface_layer", diagnostics=false, stop_time="10")
    reference_setup = NeutralRunner.build_simulation(run_directory=mktempdir())
    reference = Simulation(reference_setup.model; Δt=0.1f0, stop_iteration=4)
    run!(reference)

    configure_fixture!(closure="surface_layer", diagnostics=false, stop_time="10")
    split_setup = NeutralRunner.build_simulation(run_directory=mktempdir())
    checkpoint_directory = mktempdir()
    split = Simulation(split_setup.model; Δt=0.1f0, stop_iteration=2)
    split.output_writers[:checkpoint] = Checkpointer(split_setup.model;
        prefix="neutral_restart", dir=checkpoint_directory,
        schedule=IterationInterval(2), overwrite_files=true)
    run!(split)
    checkpoint = joinpath(checkpoint_directory, "neutral_restart_iteration2.jld2")
    @test isfile(checkpoint) && filesize(checkpoint) > 0

    configure_fixture!(closure="surface_layer", diagnostics=false, stop_time="10")
    restarted_setup = NeutralRunner.build_simulation(run_directory=mktempdir())
    restarted = Simulation(restarted_setup.model; Δt=0.1f0, stop_iteration=4)
    set!(restarted; checkpoint)
    @test iteration(restarted) == 2
    @test time(restarted) == 0.2f0
    run!(restarted)

    reference_state = model_state(reference.model)
    restarted_state = model_state(restarted.model)
    @test Set(keys(reference_state)) == Set(keys(restarted_state))
    for key in keys(reference_state)
        @test reference_state[key] == restarted_state[key]
    end
end
