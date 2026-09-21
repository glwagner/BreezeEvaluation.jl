module GABLS3Diagnostics

export build_gabls3_diagnostics, install_gabls3_diagnostics!

using Breeze
using Oceananigans

using Breeze.AtmosphereModels: closure_scalar_index,
                               moisture_prognostic_name,
                               specific_prognostic_moisture
using Breeze.BoundaryConditions: surface_layer_state,
                                 wall_air_pressure,
                                 wall_value
using Oceananigans.AbstractOperations: Average, KernelFunctionOperation
using Oceananigans.BoundaryConditions: Bottom
using Oceananigans.Fields: Field, Reduction
using Oceananigans.Grids: Center, Face
using Oceananigans.Models: BoundaryConditionOperation
using Oceananigans.Units: minute

# The historical GABLS1 diagnostic snapshot imported this helper from an uncommitted campaign
# surface-law overlay. Preserve the frozen file and supply its exact closed-form relation only in
# the loaded evaluation process when the Breeze revision does not contain that overlay.
if !isdefined(Breeze.BoundaryConditions, :gabls_stability_parameter)
    @eval Breeze.BoundaryConditions begin
        @inline function gabls_stability_parameter(Rᵇ, a, b, βᴰ, βᵀ, ζmax)
            A = βᵀ - Rᵇ * βᴰ^2
            B = b - 2 * Rᵇ * a * βᴰ
            C = -Rᵇ * a^2
            discriminant = B^2 - 4 * A * C
            root = (-B + sqrt(max(0, discriminant))) / A / 2
            solvable = (A > 0) & (discriminant > 0) & (Rᵇ > 0)
            return ifelse(solvable, min(root, ζmax),
                          ifelse(Rᵇ > 0, ζmax, zero(Rᵇ)))
        end
    end
end

include(joinpath(@__DIR__, "..", "..", "surface_layer", "diagnostics",
                 "LegacyGABLSDiagnosticsAdaptation.jl"))
const FROZEN_GABLS_DIAGNOSTICS = joinpath(
    @__DIR__, "..", "..", "..", "source_snapshots", "gabls1", "original",
    "source", "examples", "gabls_diagnostics.jl")
LegacyGABLSDiagnosticsAdaptation.load_adapted_gabls_diagnostics!(
    @__MODULE__, FROZEN_GABLS_DIAGNOSTICS)
using .GABLSDiagnostics

include(joinpath(@__DIR__, "..", "..", "surface_layer", "diagnostics",
                 "SurfaceLayerDiagnostics.jl"))

using ..GABLS3ModelForcing: most_diagnostics, surface_state

const C = Center
const F = Face

@inline moist_obukhov_denominator_valid(denominator) =
    isfinite(denominator) & (abs(denominator) > eps(one(denominator)))

@inline function surface_moist_obukhov_value(ustar, wtheta, wq, inputs, time,
                                             kappa, gravity)
    state = surface_state(inputs, time)
    theta_s = state.theta
    q_s = state.q
    delta = oftype(theta_s, 0.6078)
    virtual_theta_flux = (1 + delta * q_s) * wtheta + delta * theta_s * wq
    denominator = kappa * gravity * virtual_theta_flux
    valid = moist_obukhov_denominator_valid(denominator)
    safe_denominator = ifelse(valid, denominator, one(denominator))
    length = -ustar^3 * theta_s * (1 + delta * q_s) / safe_denominator
    return ifelse(valid, length, zero(length))
end

@inline function surface_moist_obukhov_valid_value(wtheta, wq, inputs, time,
                                                   kappa, gravity)
    state = surface_state(inputs, time)
    delta = oftype(state.theta, 0.6078)
    virtual_theta_flux = (1 + delta * state.q) * wtheta + delta * state.theta * wq
    denominator = kappa * gravity * virtual_theta_flux
    valid = moist_obukhov_denominator_valid(denominator)
    return ifelse(valid, one(denominator), zero(denominator))
end

@inline function surface_moist_obukhov(i, j, k, grid, friction_velocity,
                                       theta_flux, q_flux, inputs, clock,
                                       kappa, gravity)
    ustar = @inbounds friction_velocity[i, j, k]
    wtheta = @inbounds theta_flux[i, j, k]
    wq = @inbounds q_flux[i, j, k]
    return surface_moist_obukhov_value(ustar, wtheta, wq, inputs, clock.time,
                                       kappa, gravity)
end


@inline function surface_moist_obukhov_valid(i, j, k, grid, theta_flux,
                                             q_flux, inputs, clock,
                                             kappa, gravity)
    wtheta = @inbounds theta_flux[i, j, k]
    wq = @inbounds q_flux[i, j, k]
    return surface_moist_obukhov_valid_value(wtheta, wq, inputs, clock.time,
                                             kappa, gravity)
end

@inline function most_richardson(i, j, k, grid, coefficient, model_fields,
                                 dynamics_fields, surface_temperature, clock)
    fields = surface_layer_state(model_fields, dynamics_fields)
    side = Bottom()
    T_s = wall_value(i, j, grid, side, surface_temperature, clock)
    p_s = wall_air_pressure(i, j, 1, grid, side, nothing, fields,
                            coefficient.thermodynamic_constants)
    state = most_diagnostics(i, j, 1, grid, side, coefficient, fields, T_s, p_s)
    return state.richardson
end

@inline function most_zeta(i, j, k, grid, coefficient, model_fields,
                           dynamics_fields, surface_temperature, clock)
    fields = surface_layer_state(model_fields, dynamics_fields)
    side = Bottom()
    T_s = wall_value(i, j, grid, side, surface_temperature, clock)
    p_s = wall_air_pressure(i, j, 1, grid, side, nothing, fields,
                            coefficient.thermodynamic_constants)
    state = most_diagnostics(i, j, 1, grid, side, coefficient, fields, T_s, p_s)
    return state.zeta
end

@inline cap_mask(i, j, k, grid, zeta, maximum) =
    ifelse(@inbounds(zeta[i, j, 1]) >= maximum - 8eps(maximum), one(grid), zero(grid))
@inline unstable_mask(i, j, k, grid, richardson) =
    ifelse(@inbounds(richardson[i, j, 1]) < 0, one(grid), zero(grid))

function without_keys(tuple, keys_to_remove)
    kept = Tuple(key for key in keys(tuple) if !(key in keys_to_remove))
    return NamedTuple{kept}(Tuple(tuple[key] for key in kept))
end

function build_gabls3_diagnostics(model, coefficient, surface_temperature, inputs)
    reference_temperature = inputs.initial_theta_table(first(inputs.initial_theta_table.x))
    base = GABLSDiagnostics.build_gabls_diagnostics(model;
        reference_temperature,
        surface_temperature_initial=inputs.surface_theta(0),
        surface_cooling_rate=0,
        momentum_roughness_length=inputs.momentum_roughness,
        heat_roughness_length=inputs.scalar_reference_height,
        minimum_surface_wind_speed=coefficient.minimum_wind_speed,
        maximum_surface_stability=coefficient.maximum_stable_zeta)

    grid = model.grid
    q = specific_prognostic_moisture(model)
    q_mean, _, q_variance, _ = GABLSDiagnostics.plane_central_moments(q)
    w = model.velocities.w
    q_faces = Field(@at (C, C, F) q)
    resolved_w_q_flux = GABLSDiagnostics.plane_central_flux(w, q_faces)
    moisture_id = closure_scalar_index(model, moisture_prognostic_name(model.microphysics))
    sgs_q_flux_3d = GABLSDiagnostics.scalar_sgs_flux_field(model, q, moisture_id)
    sgs_w_q_flux = GABLSDiagnostics.plane_mean(sgs_q_flux_3d)

    density = total_density(model.dynamics)
    dynamic_q_flux = Field(BoundaryConditionOperation(model.moisture_density, :bottom, model))
    dynamic_q_flux_mean = GABLSDiagnostics.plane_mean(dynamic_q_flux)
    density_faces = Field(@at (C, C, F) density)
    surface_density = GABLSDiagnostics.plane_mean(view(density_faces, :, :, 1))
    kinematic_q_flux = Field(dynamic_q_flux_mean / surface_density)
    total_w_q_flux = GABLSDiagnostics.corrected_flux_field(
        grid, resolved_w_q_flux, sgs_w_q_flux, kinematic_q_flux)

    surface_theta_output = model -> inputs.surface_theta(model.clock.time)
    surface_q_output = model -> inputs.surface_q(model.clock.time)
    surface_pressure_output = model -> inputs.surface_pressure(model.clock.time)

    friction_velocity = base.series_outputs.friction_velocity
    theta_flux = base.series_outputs.surface_theta_kinematic_flux
    gravity = eltype(grid)(model.thermodynamic_constants.gravitational_acceleration)
    kappa = eltype(grid)(coefficient.von_karman_constant)
    obukhov_length_moist = Field(KernelFunctionOperation{Nothing, Nothing, Face}(
        surface_moist_obukhov, grid, friction_velocity, theta_flux, kinematic_q_flux,
        inputs, model.clock, kappa, gravity))
    obukhov_length_moist_valid = Field(KernelFunctionOperation{Nothing, Nothing, Face}(
        surface_moist_obukhov_valid, grid, theta_flux, kinematic_q_flux,
        inputs, model.clock, kappa, gravity))

    model_fields = fields(model)
    dynamics_fields = Breeze.AtmosphereModels.dynamics_thermodynamic_fields(model.dynamics)
    richardson_field = Field(KernelFunctionOperation{Center, Center, Nothing}(
        most_richardson, grid, coefficient, model_fields, dynamics_fields,
        surface_temperature, model.clock))
    zeta_field = Field(KernelFunctionOperation{Center, Center, Nothing}(
        most_zeta, grid, coefficient, model_fields, dynamics_fields,
        surface_temperature, model.clock))
    cap_field = Field(KernelFunctionOperation{Center, Center, Nothing}(
        cap_mask, grid, zeta_field, coefficient.maximum_stable_zeta))
    unstable_field = Field(KernelFunctionOperation{Center, Center, Nothing}(
        unstable_mask, grid, richardson_field))

    surface_bulk_richardson_mean = GABLSDiagnostics.plane_mean(richardson_field)
    surface_bulk_richardson_maximum = Field(Reduction(maximum!, richardson_field; dims=(1, 2)))
    surface_bulk_richardson_minimum = Field(Reduction(minimum!, richardson_field; dims=(1, 2)))
    surface_zeta_mean = GABLSDiagnostics.plane_mean(zeta_field)
    surface_zeta_maximum = Field(Reduction(maximum!, zeta_field; dims=(1, 2)))
    surface_zeta_minimum = Field(Reduction(minimum!, zeta_field; dims=(1, 2)))
    surface_zeta_cap_fraction = GABLSDiagnostics.plane_mean(cap_field)
    surface_unstable_fraction = GABLSDiagnostics.plane_mean(unstable_field)
    q_minimum = Field(Reduction(minimum!, q; dims=(1, 2, 3)))
    q_maximum = Field(Reduction(maximum!, q; dims=(1, 2, 3)))

    legacy_surface_keys = (:obukhov_length,
        :obukhov_length_valid,
        :surface_bulk_richardson_mean,
        :surface_bulk_richardson_maximum,
        :surface_stability_parameter_mean,
        :surface_stability_parameter_maximum,
        :surface_stability_cap_fraction,
        :surface_neutral_fallback_fraction,
        :surface_temperature)
    base_series = without_keys(base.series_outputs, legacy_surface_keys)

    surface_layer = SurfaceLayerDiagnostics.surface_layer_diagnostic_outputs(model)

    profile_outputs = merge(base.profile_outputs, (;
        q_mean,
        q_variance,
        resolved_w_q_flux,
        sgs_w_q_flux,
        total_w_q_flux), surface_layer.profiles)

    series_outputs = merge(base_series, (;
        surface_q_dynamic_flux=dynamic_q_flux_mean,
        surface_q_kinematic_flux=kinematic_q_flux,
        obukhov_length_moist,
        obukhov_length_moist_valid,
        surface_bulk_richardson_mean,
        surface_bulk_richardson_minimum,
        surface_bulk_richardson_maximum,
        surface_zeta_mean,
        surface_zeta_minimum,
        surface_zeta_maximum,
        surface_zeta_cap_fraction,
        surface_unstable_fraction,
        prescribed_surface_pressure=surface_pressure_output,
        prescribed_surface_theta=surface_theta_output,
        prescribed_surface_q=surface_q_output,
        q_minimum,
        q_maximum), surface_layer.series)

    diagnostic_fields = merge(base.diagnostic_fields, (;
        surface_bulk_richardson=richardson_field,
        surface_zeta=zeta_field,
        surface_zeta_cap_mask=cap_field,
        surface_unstable_mask=unstable_field))

    metadata = merge(base.metadata, (;
        diagnostic_case="GABLS3 revised nine-hour LES",
        sgs_flux_diagnostic_definition="For SurfaceLayerDiffusivity, evaluate the full constitutive vertical flux with explicit-discretization operators for output only; the model retains vertically implicit diffusion",
        averaging_definition="instantaneous horizontal reductions; no temporal averaging",
        surface_law="coupled moist bulk-Richardson MOST; stable psi_m=psi_h=-5 zeta; unstable Businger-Dyer gamma=16",
        scalar_reference_height_m=inputs.scalar_reference_height,
        momentum_roughness_m=inputs.momentum_roughness,
        surface_pressure_convention="anelastic reference pressure remains fixed; observed pressure converts prescribed theta to temperature and is exported",
        moisture_definition="specific humidity per mass moist air; Breeze total-water prognostic",
        surface_obukhov_definition="moist virtual-potential-temperature flux approximation including heat and moisture surface fluxes; zero fallback is invalid unless obukhov_length_moist_valid=1",
        surface_cap_definition="fraction at zeta=10 stable cap; unstable fraction is RiB<0",
        required_paper_window="instantaneous records 11100:300:14400 seconds (12 records)"),
        surface_layer.metadata)

    return (; profile_outputs, series_outputs, diagnostic_fields, metadata)
end

function initialize_file!(file, metadata, kind, interval)
    file["metadata/diagnostic_kind"] = kind
    file["metadata/output_interval_seconds"] = interval
    file["metadata/averaging_window_seconds"] = 0
    for (name, value) in pairs(metadata)
        file["metadata/$(name)"] = value
    end
    return nothing
end

function point_outputs(model, heights)
    grid = model.grid
    i = max(1, grid.Nx ÷ 2)
    j = max(1, grid.Ny ÷ 2)
    z_center = collect(znodes(grid, Center(), Center(), Center()))
    z_face = collect(znodes(grid, Center(), Center(), Face()))
    center_indices = map(height -> argmin(abs.(z_center .- height)), heights)
    face_indices = map(height -> argmin(abs.(z_face .- height)), heights)
    q = specific_prognostic_moisture(model)
    theta = liquid_ice_potential_temperature(model)
    u, v, w = model.velocities
    outputs = Dict{Symbol, Any}()
    for (height, center_k, face_k) in zip(heights, center_indices, face_indices)
        suffix = Symbol("z", replace(string(height), "." => "p"), "m")
        outputs[Symbol("u_", suffix)] = view(u, i, j, center_k)
        outputs[Symbol("v_", suffix)] = view(v, i, j, center_k)
        outputs[Symbol("w_", suffix)] = view(w, i, j, face_k)
        outputs[Symbol("theta_", suffix)] = view(theta, i, j, center_k)
        outputs[Symbol("q_", suffix)] = view(q, i, j, center_k)
    end
    center_heights = map(index -> z_center[index], center_indices)
    face_heights = map(index -> z_face[index], face_indices)
    return NamedTuple(outputs), center_heights, face_heights
end

function install_gabls3_diagnostics!(simulation, coefficient, surface_temperature, inputs;
                                     dir=".", prefix="gabls3", overwrite_files=true)
    diagnostics = build_gabls3_diagnostics(simulation.model, coefficient,
                                            surface_temperature, inputs)
    profile_times = collect(0.0:300.0:32400.0)
    series_times = collect(10.0:10.0:32400.0)
    profile_init = (file, model) -> initialize_file!(
        file, diagnostics.metadata, "instantaneous_horizontal_profile", 300.0)
    series_init = (file, model) -> initialize_file!(
        file, diagnostics.metadata, "instantaneous_reduced_series", 10.0)

    simulation.output_writers[:gabls3_profiles] = JLD2Writer(
        simulation.model, diagnostics.profile_outputs;
        filename="$(prefix)_profiles.jld2", dir,
        schedule=SpecifiedTimes(profile_times), with_halos=false,
        overwrite_files, init=profile_init)

    simulation.output_writers[:gabls3_series] = JLD2Writer(
        simulation.model, diagnostics.series_outputs;
        filename="$(prefix)_series.jld2", dir,
        schedule=SpecifiedTimes(series_times), with_halos=false,
        overwrite_files, init=series_init)

    heights = (10.0, 25.0, 50.0, 100.0, 180.0, 200.0)
    points, actual_center_heights, actual_w_face_heights =
        point_outputs(simulation.model, heights)
    point_metadata = merge(diagnostics.metadata, (;
        requested_point_heights_m=join(heights, ","),
        actual_scalar_and_horizontal_velocity_heights_m=join(actual_center_heights, ","),
        actual_native_w_face_heights_m=join(actual_w_face_heights, ","),
        point_vertical_location_definition="u, v, theta, q use nearest native z center; w uses nearest native z face"))
    point_init = (file, model) -> initialize_file!(
        file, point_metadata, "instantaneous_center_column_points", 10.0)
    simulation.output_writers[:gabls3_points] = JLD2Writer(
        simulation.model, points;
        filename="$(prefix)_points.jld2", dir,
        schedule=SpecifiedTimes(series_times), with_halos=false,
        overwrite_files, init=point_init)

    return diagnostics
end

end
