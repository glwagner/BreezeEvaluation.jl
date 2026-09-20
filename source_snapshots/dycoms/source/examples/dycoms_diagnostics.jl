module DYCOMSDiagnostics

export build_dycoms_diagnostics,
       install_dycoms_diagnostics!,
       finite_difference,
       entrainment_velocity,
       dycoms_entrainment_velocities,
       radiative_efficiency,
       convective_velocity_scale,
       tke_storage,
       tke_budget_residual

using Breeze
using Oceananigans

using Breeze.AtmosphereModels: AtmosphereModelBuoyancy,
                               buoyancy_forceᶜᶜᶜ,
                               closure_scalar_index,
                               liquid_mass_fraction,
                               moisture_prognostic_name,
                               pressure_anomaly,
                               thermodynamic_density_name
using Breeze.TurbulenceClosures: Jᶜz, 𝒯_uz, 𝒯_vz
using Oceananigans.AbstractOperations: Average, Integral, KernelFunctionOperation
using Oceananigans.Fields: Field, Reduction, location
using Oceananigans.Grids: Center, Face, znode
using Oceananigans.Models: BoundaryConditionOperation
using Oceananigans.Operators: ℑzᵃᵃᶠ, ℑxzᶠᵃᶠ, ℑyzᵃᶠᶠ
using Oceananigans.TimeSteppers: time_discretization
using Oceananigans.TurbulenceClosures.Smagorinskys: ΣᵢⱼΣᵢⱼᶜᶜᶜ
using Oceananigans.Units: minute, minutes

const C = Center
const F = Face

# All custom point functions below are used by KernelFunctionOperation and therefore
# have to remain allocation-free and GPU-safe.

@inline function buoyancy_per_mass(i, j, k, grid, dynamics, temperature,
                                   prognostic_moisture, microphysics,
                                   microphysical_fields, constants, density)
    ρb = buoyancy_forceᶜᶜᶜ(i, j, k, grid, dynamics, temperature,
                          prognostic_moisture, microphysics,
                          microphysical_fields, constants)
    return @inbounds ρb / density[i, j, k]
end

@inline function threshold_mask(i, j, k, grid, field, threshold)
    value = @inbounds field[i, j, k]
    return ifelse(value > threshold, one(grid), zero(grid))
end

@inline function safe_ratio(i, j, k, grid, numerator, denominator)
    n = @inbounds numerator[i, j, k]
    d = @inbounds denominator[i, j, k]
    ratio = n / max(d, eps(d))
    return ifelse(d > 0, ratio, zero(grid))
end

@inline function nonnegative_variance(i, j, k, grid, first_moment, second_moment)
    m₁ = @inbounds first_moment[i, j, k]
    m₂ = @inbounds second_moment[i, j, k]
    return max(0, m₂ - m₁^2)
end

@inline function convective_velocity(i, j, k, grid, inversion_height, surface_buoyancy_flux)
    height = @inbounds inversion_height[i, j, k]
    return cbrt(height * surface_buoyancy_flux)
end

@inline function cloud_base_height(i, j, k, grid, liquid, threshold)
    base = zero(grid)
    found = false

    for k′ in 1:grid.Nz
        cloudy = @inbounds liquid[i, j, k′] > threshold
        first_cloudy = cloudy & !found
        z = znode(i, j, k′, grid, Center(), Center(), Center())
        base = ifelse(first_cloudy, z, base)
        found = found | cloudy
    end

    return base
end

@inline function contour_height(i, j, k, grid, field, target, increasing)
    nearest_height = znode(i, j, 1, grid, Center(), Center(), Center())
    nearest_distance = abs(@inbounds field[i, j, 1] - target)
    crossing_height = nearest_height
    crossed = false

    for k′ in 1:grid.Nz
        value = @inbounds field[i, j, k′]
        distance = abs(value - target)
        closer_or_higher_tie = distance <= nearest_distance
        height = znode(i, j, k′, grid, Center(), Center(), Center())
        nearest_height = ifelse(closer_or_higher_tie, height, nearest_height)
        nearest_distance = ifelse(closer_or_higher_tie, distance, nearest_distance)
    end

    for k′ in 1:grid.Nz-1
        lower_value = @inbounds field[i, j, k′]
        upper_value = @inbounds field[i, j, k′+1]
        upward_crossing = (lower_value <= target) & (upper_value > target)
        downward_crossing = (lower_value >= target) & (upper_value < target)
        crossing = ifelse(increasing, upward_crossing, downward_crossing)
        first_crossing = crossing & !crossed
        lower_height = znode(i, j, k′,   grid, Center(), Center(), Center())
        upper_height = znode(i, j, k′+1, grid, Center(), Center(), Center())
        difference = upper_value - lower_value
        safe_difference = ifelse(abs(difference) > eps(difference), difference, one(grid))
        fraction = (target - lower_value) / safe_difference
        interpolated_height = lower_height + fraction * (upper_height - lower_height)
        crossing_height = ifelse(first_crossing, interpolated_height, crossing_height)
        crossed = crossed | crossing
    end

    return ifelse(crossed, crossing_height, nearest_height)
end

@inline function contour_valid(i, j, k, grid, field, target, increasing)
    crossed = false
    for k′ in 1:grid.Nz-1
        lower_value = @inbounds field[i, j, k′]
        upper_value = @inbounds field[i, j, k′+1]
        upward_crossing = (lower_value <= target) & (upper_value > target)
        downward_crossing = (lower_value >= target) & (upper_value < target)
        crossed = crossed | ifelse(increasing, upward_crossing, downward_crossing)
    end
    return ifelse(crossed, one(grid), zero(grid))
end

@inline function layer_overlap_fraction(i, j, k, grid, lower, upper)
    z⁻ = znode(i, j, k,   grid, Center(), Center(), Face())
    z⁺ = znode(i, j, k+1, grid, Center(), Center(), Face())
    overlap = max(0, min(z⁺, upper) - max(z⁻, lower))
    return overlap / (z⁺ - z⁻)
end

@inline function scalar_sgs_flux(i, j, k, grid, density, ::Nothing, args...)
    return zero(grid)
end

@inline function scalar_sgs_flux(i, j, k, grid, density, closure, closure_fields,
                                 id, scalar, clock, model_fields, buoyancy)
    discretization = time_discretization(closure)
    dynamic_flux = Jᶜz(i, j, k, grid, density, discretization, closure,
                       closure_fields, id, scalar, clock, model_fields, buoyancy)
    density_at_face = ℑzᵃᵃᶠ(i, j, k, grid, density)
    return dynamic_flux / density_at_face
end

@inline function u_sgs_flux(i, j, k, grid, density, ::Nothing, args...)
    return zero(grid)
end

@inline function u_sgs_flux(i, j, k, grid, density, closure, closure_fields,
                            clock, model_fields)
    discretization = time_discretization(closure)
    dynamic_flux = 𝒯_uz(i, j, k, grid, density, discretization, closure,
                        closure_fields, clock, model_fields, nothing)
    density_at_face = ℑxzᶠᵃᶠ(i, j, k, grid, density)
    return dynamic_flux / density_at_face
end

@inline function v_sgs_flux(i, j, k, grid, density, ::Nothing, args...)
    return zero(grid)
end

@inline function v_sgs_flux(i, j, k, grid, density, closure, closure_fields,
                            clock, model_fields)
    discretization = time_discretization(closure)
    dynamic_flux = 𝒯_vz(i, j, k, grid, density, discretization, closure,
                        closure_fields, clock, model_fields, nothing)
    density_at_face = ℑyzᵃᶠᶠ(i, j, k, grid, density)
    return dynamic_flux / density_at_face
end

@inline function eddy_viscosity_dissipation(i, j, k, grid, viscosity, u, v, w)
    strain_squared = ΣᵢⱼΣᵢⱼᶜᶜᶜ(i, j, k, grid, u, v, w)
    return @inbounds 2 * viscosity[i, j, k] * strain_squared
end

function plane_mean(field)
    horizontal_dimensions = Tuple(d for d in (1, 2) if location(field)[d] !== Nothing)
    isempty(horizontal_dimensions) && return field
    return Field(Average(field, dims=horizontal_dimensions))
end

function plane_central_moments(field)
    mean_field = plane_mean(field)
    perturbation = field - mean_field
    variance = Field(Average(perturbation^2, dims=(1, 2)))
    third_moment = Field(Average(perturbation^3, dims=(1, 2)))
    return mean_field, perturbation, variance, third_moment
end

function plane_central_flux(vertical_velocity, scalar)
    w_mean = plane_mean(vertical_velocity)
    scalar_mean = plane_mean(scalar)
    w_perturbation = vertical_velocity - w_mean
    scalar_perturbation = scalar - scalar_mean
    return Field(Average(w_perturbation * scalar_perturbation, dims=(1, 2)))
end

function horizontal_statistics(field)
    first_moment = plane_mean(field)
    second_moment = plane_mean(field^2)
    variance = Field(KernelFunctionOperation{Nothing, Nothing, Nothing}(
        nonnegative_variance, field.grid, first_moment, second_moment))
    return first_moment, variance
end

function conditional_horizontal_statistics(field, mask)
    fraction = plane_mean(mask)
    weighted_first = plane_mean(field * mask)
    weighted_second = plane_mean(field^2 * mask)

    first_moment = Field(KernelFunctionOperation{Nothing, Nothing, Nothing}(
        safe_ratio, field.grid, weighted_first, fraction))
    second_moment = Field(KernelFunctionOperation{Nothing, Nothing, Nothing}(
        safe_ratio, field.grid, weighted_second, fraction))
    variance = Field(KernelFunctionOperation{Nothing, Nothing, Nothing}(
        nonnegative_variance, field.grid, first_moment, second_moment))

    return fraction, first_moment, variance
end

function exact_layer_mean(field, lower, upper)
    upper > lower || throw(ArgumentError("layer upper bound must exceed its lower bound"))
    grid = field.grid
    FT = eltype(grid)
    lower = FT(lower)
    upper = FT(upper)
    weights = Field(KernelFunctionOperation{C, C, C}(
        layer_overlap_fraction, grid, lower, upper))
    column_integral = Field(Integral(field * weights, dims=3))
    column_mean = Field(column_integral / (upper - lower))
    return plane_mean(column_mean)
end

function scalar_sgs_flux_field(model, scalar, id)
    grid = model.grid
    density = total_density(model.dynamics)
    model_fields = fields(model)
    buoyancy = AtmosphereModelBuoyancy(model.dynamics, model.formulation,
                                       model.thermodynamic_constants)
    operation = KernelFunctionOperation{C, C, F}(
        scalar_sgs_flux, grid, density, model.closure, model.closure_fields,
        id, scalar, model.clock, model_fields, buoyancy)
    return Field(operation)
end

function momentum_sgs_flux_fields(model)
    grid = model.grid
    density = total_density(model.dynamics)
    model_fields = fields(model)

    u_operation = KernelFunctionOperation{F, C, F}(
        u_sgs_flux, grid, density, model.closure, model.closure_fields,
        model.clock, model_fields)
    v_operation = KernelFunctionOperation{C, F, F}(
        v_sgs_flux, grid, density, model.closure, model.closure_fields,
        model.clock, model_fields)

    return Field(u_operation), Field(v_operation)
end

function surface_drag_diagnostics(model, density)
    dynamic_u_flux = Field(BoundaryConditionOperation(model.momentum.ρu, :bottom, model))
    dynamic_v_flux = Field(BoundaryConditionOperation(model.momentum.ρv, :bottom, model))
    dynamic_u_flux_mean = plane_mean(dynamic_u_flux)
    dynamic_v_flux_mean = plane_mean(dynamic_v_flux)

    density_at_z_faces = Field(@at (C, C, F) density)
    surface_density_mean = plane_mean(view(density_at_z_faces, :, :, 1))
    kinematic_u_flux = Field(dynamic_u_flux_mean / surface_density_mean)
    kinematic_v_flux = Field(dynamic_v_flux_mean / surface_density_mean)
    friction_velocity = Field(sqrt(sqrt(kinematic_u_flux^2 + kinematic_v_flux^2)))

    return (; dynamic_u_flux_mean,
              dynamic_v_flux_mean,
              kinematic_u_flux,
              kinematic_v_flux,
              surface_density_mean,
              friction_velocity)
end

function optional_sgs_dissipation(model)
    if isnothing(model.closure)
        zero_dissipation = plane_mean(0 * Field(@at (C, C, C) model.velocities.w))
        return (; sgs_resolved_kinetic_energy_dissipation=zero_dissipation)
    end

    hasproperty(model.closure_fields, :νₑ) || return NamedTuple()
    u, v, w = model.velocities
    operation = KernelFunctionOperation{C, C, C}(
        eddy_viscosity_dissipation, model.grid, model.closure_fields.νₑ, u, v, w)
    dissipation = plane_mean(Field(operation))
    return (; sgs_resolved_kinetic_energy_dissipation=dissipation)
end

function optional_sgs_tke(model)
    haskey(model.tracers, :e) || return (; profiles=NamedTuple(), series=NamedTuple(), available=false)
    sgs_tke = plane_mean(model.tracers.e)
    sgs_tke_integral = Field(Integral(sgs_tke, dims=3))
    return (; profiles=(; sgs_tke),
              series=(; sgs_tke_vertical_integral=sgs_tke_integral),
              available=true)
end

function build_dycoms_diagnostics(model;
                                  cloud_liquid_threshold=1e-6,
                                  theta_li_inversion_contour=295,
                                  q_t_inversion_contour=8e-3,
                                  lower_mixed_layer=(100, 200),
                                  upper_mixed_layer=(700, 800),
                                  divergence=3.75e-6,
                                  surface_sensible_heat_flux=15,
                                  surface_latent_heat_flux=115,
                                  surface_reference_density=1.22,
                                  surface_reference_temperature=292.5,
                                  latent_heat_of_vaporization=2.47e6)
    radiation = model.radiation
    hasproperty(radiation, :inversion_height) ||
        throw(ArgumentError("DYCOMS diagnostics require radiation.inversion_height"))
    hasproperty(radiation, :net_upward_flux) ||
        throw(ArgumentError("DYCOMS diagnostics require radiation.net_upward_flux"))

    grid = model.grid
    FT = eltype(grid)
    threshold = FT(cloud_liquid_threshold)
    theta_li_contour = FT(theta_li_inversion_contour)
    q_t_contour = FT(q_t_inversion_contour)
    divergence = FT(divergence)
    sensible_heat_flux = FT(surface_sensible_heat_flux)
    latent_heat_flux = FT(surface_latent_heat_flux)
    surface_density = FT(surface_reference_density)
    surface_temperature = FT(surface_reference_temperature)
    latent_heat = FT(latent_heat_of_vaporization)

    u, v, w = model.velocities
    uᶜ = Field(@at (C, C, C) u)
    vᶜ = Field(@at (C, C, C) v)
    wᶜ = Field(@at (C, C, C) w)

    θ = liquid_ice_potential_temperature(model)
    qᵗ = specific_prognostic_moisture(model)
    qˡ = liquid_mass_fraction(model)
    isnothing(qˡ) && throw(ArgumentError("DYCOMS diagnostics require liquid water"))
    ρ = total_density(model.dynamics)

    b_operation = KernelFunctionOperation{C, C, C}(
        buoyancy_per_mass, grid, model.dynamics, model.temperature, qᵗ,
        model.microphysics, model.microphysical_fields,
        model.thermodynamic_constants, ρ)
    b = Field(b_operation)

    u_mean, _, u_variance, _ = plane_central_moments(u)
    v_mean, _, v_variance, _ = plane_central_moments(v)
    w_mean, _, w_variance, w_third_central_moment = plane_central_moments(w)
    _, u′, _, _ = plane_central_moments(uᶜ)
    _, v′, _, _ = plane_central_moments(vᶜ)
    w_center_mean, w′, w_center_variance, w_center_third_central_moment =
        plane_central_moments(wᶜ)
    theta_li_mean, θ′, theta_li_variance, _ = plane_central_moments(θ)
    q_t_mean, qᵗ′, q_t_variance, _ = plane_central_moments(qᵗ)
    q_l_mean, qˡ′, q_l_variance, _ = plane_central_moments(qˡ)
    density_mean = plane_mean(ρ)
    buoyancy_mean, b′, _, _ = plane_central_moments(b)

    wᶠ = w
    uᶠ = Field(@at (C, C, F) u)
    vᶠ = Field(@at (C, C, F) v)
    θᶠ = Field(@at (C, C, F) θ)
    qᵗᶠ = Field(@at (C, C, F) qᵗ)
    qˡᶠ = Field(@at (C, C, F) qˡ)
    bᶠ = Field(@at (C, C, F) b)

    resolved_u_w_flux = plane_central_flux(wᶠ, uᶠ)
    resolved_v_w_flux = plane_central_flux(wᶠ, vᶠ)
    resolved_w_theta_li_flux = plane_central_flux(wᶠ, θᶠ)
    resolved_w_q_t_flux = plane_central_flux(wᶠ, qᵗᶠ)
    resolved_w_q_l_flux = plane_central_flux(wᶠ, qˡᶠ)
    resolved_buoyancy_flux = plane_central_flux(wᶠ, bᶠ)

    thermodynamic_id = closure_scalar_index(model, thermodynamic_density_name(model.formulation))
    moisture_id = closure_scalar_index(model, moisture_prognostic_name(model.microphysics))
    sgs_theta_li_flux_3d = scalar_sgs_flux_field(model, θ, thermodynamic_id)
    sgs_q_t_flux_3d = scalar_sgs_flux_field(model, qᵗ, moisture_id)
    sgs_u_w_flux_3d, sgs_v_w_flux_3d = momentum_sgs_flux_fields(model)

    sgs_theta_li_flux = plane_mean(sgs_theta_li_flux_3d)
    sgs_q_t_flux = plane_mean(sgs_q_t_flux_3d)
    sgs_u_w_flux = plane_mean(Field(@at (C, C, F) sgs_u_w_flux_3d))
    sgs_v_w_flux = plane_mean(Field(@at (C, C, F) sgs_v_w_flux_3d))

    resolved_tke_3d = Field((u′^2 + v′^2 + w′^2) / 2)
    resolved_tke = plane_mean(resolved_tke_3d)

    shear_production_face = -resolved_u_w_flux * ∂z(u_mean) -
                             resolved_v_w_flux * ∂z(v_mean)
    sgs_shear_production_face = -sgs_u_w_flux * ∂z(u_mean) -
                                 sgs_v_w_flux * ∂z(v_mean)
    total_shear_production_face = -(resolved_u_w_flux + sgs_u_w_flux) * ∂z(u_mean) -
                                   (resolved_v_w_flux + sgs_v_w_flux) * ∂z(v_mean)
    resolved_tke_shear_production = Field(@at (C, C, C) shear_production_face)
    sgs_tke_shear_production = Field(@at (C, C, C) sgs_shear_production_face)
    total_tke_shear_production = Field(@at (C, C, C) total_shear_production_face)
    resolved_tke_buoyancy_production = Field(@at (C, C, C) resolved_buoyancy_flux)

    density_at_w_faces = plane_mean(Field(@at (C, C, F) ρ))
    turbulent_tke_flux = plane_central_flux(wᶠ, Field(@at (C, C, F) resolved_tke_3d))
    kinematic_pressure = Field(pressure_anomaly(model.dynamics) / ρ)
    pressure_tke_flux = plane_central_flux(wᶠ, Field(@at (C, C, F) kinematic_pressure))
    density_weighted_turbulent_tke_flux = Field(density_at_w_faces * turbulent_tke_flux)
    density_weighted_pressure_tke_flux = Field(density_at_w_faces * pressure_tke_flux)
    resolved_tke_turbulent_transport =
        Field(-∂z(density_weighted_turbulent_tke_flux) / density_mean)
    resolved_tke_pressure_transport =
        Field(-∂z(density_weighted_pressure_tke_flux) / density_mean)
    resolved_tke_transport = Field(resolved_tke_turbulent_transport +
                                   resolved_tke_pressure_transport)

    liquid_water_path = Field(Integral(ρ * qˡ, dims=3))
    lwp_mean, lwp_variance = horizontal_statistics(liquid_water_path)

    maximum_liquid = Field(Reduction(maximum!, qˡ; dims=3))
    column_cloud_mask = Field(KernelFunctionOperation{C, C, Nothing}(
        threshold_mask, grid, maximum_liquid, threshold))
    cloud_base = Field(KernelFunctionOperation{C, C, Nothing}(
        cloud_base_height, grid, qˡ, threshold))
    cloud_fraction, cloud_base_mean, cloud_base_variance =
        conditional_horizontal_statistics(cloud_base, column_cloud_mask)

    cloud_mask_3d = Field(KernelFunctionOperation{C, C, C}(
        threshold_mask, grid, qˡ, threshold))
    cloud_fraction_profile = plane_mean(cloud_mask_3d)

    theta_li_295_inversion_height = Field(KernelFunctionOperation{C, C, Nothing}(
        contour_height, grid, θ, theta_li_contour, true))
    theta_li_295_inversion_valid_mask = Field(KernelFunctionOperation{C, C, Nothing}(
        contour_valid, grid, θ, theta_li_contour, true))
    theta_li_295_inversion_valid_fraction,
    theta_li_295_inversion_height_mean,
    theta_li_295_inversion_height_variance = conditional_horizontal_statistics(
        theta_li_295_inversion_height, theta_li_295_inversion_valid_mask)

    q_t_8gkg_inversion_height = Field(KernelFunctionOperation{C, C, Nothing}(
        contour_height, grid, qᵗ, q_t_contour, false))
    q_t_8gkg_inversion_valid_mask = Field(KernelFunctionOperation{C, C, Nothing}(
        contour_valid, grid, qᵗ, q_t_contour, false))
    q_t_8gkg_inversion_valid_fraction,
    q_t_8gkg_inversion_height_mean,
    q_t_8gkg_inversion_height_variance = conditional_horizontal_statistics(
        q_t_8gkg_inversion_height, q_t_8gkg_inversion_valid_mask)

    radiation_nearest_q_t_inversion_height = radiation.inversion_height
    radiation_nearest_q_t_inversion_height_mean, radiation_nearest_q_t_inversion_height_variance =
        horizontal_statistics(radiation_nearest_q_t_inversion_height)

    lower_q_t = exact_layer_mean(qᵗ, lower_mixed_layer...)
    upper_q_t = exact_layer_mean(qᵗ, upper_mixed_layer...)
    decoupling_delta_q_t = Field(lower_q_t - upper_q_t)

    resolved_tke_vertical_integral = Field(Integral(resolved_tke, dims=3))
    domain_height = znode(1, 1, grid.Nz+1, grid, Center(), Center(), Face()) -
                    znode(1, 1, 1, grid, Center(), Center(), Face())
    resolved_tke_depth_mean = Field(resolved_tke_vertical_integral / domain_height)
    w_variance_max = Field(Reduction(maximum!, w_variance; dims=3))

    bottom_sgs_u_w_flux = view(sgs_u_w_flux, :, :, 1)
    bottom_sgs_v_w_flux = view(sgs_v_w_flux, :, :, 1)
    drag = surface_drag_diagnostics(model, ρ)

    constants = model.thermodynamic_constants
    gravity = constants.gravitational_acceleration
    heat_capacity = constants.dry_air.heat_capacity
    surface_buoyancy_flux = gravity * (sensible_heat_flux / (surface_density * heat_capacity * surface_temperature) +
                                       FT(0.61) * latent_heat_flux / (surface_density * latent_heat))
    w_star = Field(KernelFunctionOperation{Nothing, Nothing, Nothing}(
        convective_velocity, grid, q_t_8gkg_inversion_height_mean, surface_buoyancy_flux))

    radiative_flux = plane_mean(radiation.net_upward_flux)
    radiative_flux_divergence = plane_mean(radiation.flux_divergence)

    sgs_kinetic_energy_dissipation = optional_sgs_dissipation(model)
    sgs_dissipation = if haskey(sgs_kinetic_energy_dissipation,
                                :sgs_resolved_kinetic_energy_dissipation)
        total_dissipation = sgs_kinetic_energy_dissipation.sgs_resolved_kinetic_energy_dissipation
        tke_dissipation = Field(total_dissipation - sgs_tke_shear_production)
        (; sgs_tke_dissipation=tke_dissipation,
           sgs_kinetic_energy_dissipation...)
    else
        NamedTuple()
    end
    sgs_tke = optional_sgs_tke(model)

    profile_outputs = (;
        u_mean,
        v_mean,
        w_mean,
        theta_li_mean,
        q_t_mean,
        q_l_mean,
        density_mean,
        buoyancy_mean,
        u_variance,
        v_variance,
        w_variance,
        w_third_central_moment,
        w_center_mean,
        w_center_variance,
        w_center_third_central_moment,
        theta_li_variance,
        q_t_variance,
        q_l_variance,
        cloud_fraction_profile,
        resolved_u_w_flux,
        resolved_v_w_flux,
        resolved_w_theta_li_flux,
        resolved_w_q_t_flux,
        resolved_w_q_l_flux,
        resolved_buoyancy_flux,
        sgs_u_w_flux,
        sgs_v_w_flux,
        sgs_theta_li_flux,
        sgs_q_t_flux,
        net_upward_radiative_flux=radiative_flux,
        radiative_flux_divergence,
        resolved_tke,
        resolved_tke_shear_production,
        sgs_tke_shear_production,
        total_tke_shear_production,
        resolved_tke_buoyancy_production,
        turbulent_tke_flux,
        pressure_tke_flux,
        density_at_w_faces,
        density_weighted_turbulent_tke_flux,
        density_weighted_pressure_tke_flux,
        resolved_tke_turbulent_transport,
        resolved_tke_pressure_transport,
        resolved_tke_transport,
        sgs_dissipation...,
        sgs_tke.profiles...)

    surface_sensible_heat_flux_output = model -> sensible_heat_flux
    surface_latent_heat_flux_output = model -> latent_heat_flux
    surface_buoyancy_flux_output = model -> surface_buoyancy_flux

    series_outputs = (;
        lwp_mean,
        lwp_variance,
        cloud_fraction,
        cloud_base_valid_fraction=cloud_fraction,
        cloud_base_mean,
        cloud_base_variance,
        q_t_8gkg_inversion_valid_fraction,
        q_t_8gkg_inversion_height_mean,
        q_t_8gkg_inversion_height_variance,
        theta_li_295_inversion_valid_fraction,
        theta_li_295_inversion_height_mean,
        theta_li_295_inversion_height_variance,
        radiation_nearest_q_t_inversion_height_mean,
        radiation_nearest_q_t_inversion_height_variance,
        decoupling_delta_q_t,
        resolved_tke_vertical_integral,
        resolved_tke_depth_mean,
        w_variance_max,
        friction_velocity=drag.friction_velocity,
        convective_velocity_scale=w_star,
        surface_drag_u_dynamic_flux=drag.dynamic_u_flux_mean,
        surface_drag_v_dynamic_flux=drag.dynamic_v_flux_mean,
        surface_drag_u_kinematic_flux=drag.kinematic_u_flux,
        surface_drag_v_kinematic_flux=drag.kinematic_v_flux,
        surface_density_for_drag=drag.surface_density_mean,
        surface_sgs_u_w_flux=bottom_sgs_u_w_flux,
        surface_sgs_v_w_flux=bottom_sgs_v_w_flux,
        surface_sgs_theta_li_flux=view(sgs_theta_li_flux, :, :, 1),
        surface_sgs_q_t_flux=view(sgs_q_t_flux, :, :, 1),
        surface_sensible_heat_flux=surface_sensible_heat_flux_output,
        surface_latent_heat_flux=surface_latent_heat_flux_output,
        surface_buoyancy_flux=surface_buoyancy_flux_output,
        sgs_tke.series...)

    diagnostic_fields = (;
        liquid_water_path,
        cloud_base,
        column_cloud_mask,
        q_t_8gkg_inversion_height,
        q_t_8gkg_inversion_valid_mask,
        theta_li_295_inversion_height,
        theta_li_295_inversion_valid_mask,
        radiation_nearest_q_t_inversion_height,
        resolved_tke_3d,
        buoyancy=b)

    metadata = (;
        cloud_liquid_threshold=threshold,
        theta_li_inversion_contour=theta_li_contour,
        q_t_inversion_contour=q_t_contour,
        lower_mixed_layer=tuple(FT.(lower_mixed_layer)...),
        upper_mixed_layer=tuple(FT.(upper_mixed_layer)...),
        divergence,
        surface_sensible_heat_flux=sensible_heat_flux,
        surface_latent_heat_flux=latent_heat_flux,
        surface_reference_density=surface_density,
        surface_reference_temperature=surface_temperature,
        latent_heat_of_vaporization=latent_heat,
        surface_buoyancy_flux,
        sgs_tke_available=sgs_tke.available,
        sgs_liquid_water_flux_available=false,
        averaging_definition="time average of instantaneous horizontally reduced diagnostics",
        published_inversion_height_definition="first downward q_t = 8 g/kg crossing, linearly interpolated and conditioned on a crossing; Stevens et al. (2005) Appendix B Table B1",
        draft_inversion_height_definition="first upward theta_li = 295 K crossing, linearly interpolated and conditioned on a crossing; retained for older GCSS-draft comparisons",
        radiation_inversion_height_definition="DYCOMSRadiation nearest-q_t internal; not a linearly interpolated diagnostic contour",
        entrainment_definition="E = d<zi>/dt + D<zi>, computed separately for q_t=8 g/kg and theta_li=295 K contours",
        convective_velocity_scale_definition="w_star = cbrt(<q_t=8g/kg zi> B0), with B0 from fixed SHF/LHF and recorded reference constants",
        missing_contour_handling="per-column fallback field holds nearest contour value, but reported means/variances exclude missing crossings and valid fractions are output; all-missing moments are zero",
        cloud_free_column_handling="cloud-base moments exclude cloud-free columns, cloud_base_valid_fraction is output, and all-clear mean and variance are zero",
        profile_flux_units="kinematic: theta K m/s, moisture kg/kg m/s, momentum m2/s2, buoyancy m2/s3",
        sgs_tke_dissipation_definition="2 nu_e S:S minus SGS mean-shear production; total resolved-KE sink is also output",
        tke_turbulent_transport_definition="-1/rho_r d/dz [rho_r <w' e'>], where e is per-mass resolved TKE; both raw and density-weighted face fluxes are output",
        tke_pressure_transport_definition="-1/rho_r d/dz [rho_r <w' (p'/rho_r)'>], matching the anelastic pressure-gradient acceleration -grad(p'/rho_r); both raw and density-weighted face fluxes are output",
        tke_residual_definition="storage - shear - buoyancy - transport + dissipation; a budget-closure residual only, not an estimate of numerical dissipation")

    return (; profile_outputs, series_outputs, diagnostic_fields, metadata)
end

function initialize_diagnostics_file!(file, model, metadata, kind, interval, window)
    file["metadata/diagnostic_kind"] = kind
    file["metadata/output_interval_seconds"] = interval
    file["metadata/averaging_window_seconds"] = window
    for (name, value) in pairs(metadata)
        file["metadata/$(name)"] = value
    end
    return nothing
end

function install_dycoms_diagnostics!(simulation;
                                     dir=".",
                                     prefix="dycoms",
                                     profile_interval=30minutes,
                                     series_interval=1minute,
                                     overwrite_files=true,
                                     kwargs...)
    diagnostics = build_dycoms_diagnostics(simulation.model; kwargs...)

    profile_init = (file, model) -> initialize_diagnostics_file!(
        file, model, diagnostics.metadata, "true_time_averaged_profiles",
        profile_interval, profile_interval)
    series_init = (file, model) -> initialize_diagnostics_file!(
        file, model, diagnostics.metadata, "instantaneous_reduced_series",
        series_interval, zero(series_interval))

    simulation.output_writers[:dycoms_statistics] = JLD2Writer(
        simulation.model, diagnostics.profile_outputs;
        filename="$(prefix)_statistics.jld2",
        dir,
        schedule=AveragedTimeInterval(profile_interval; window=profile_interval, stride=1),
        with_halos=false,
        overwrite_files,
        init=profile_init)

    simulation.output_writers[:dycoms_series] = JLD2Writer(
        simulation.model, diagnostics.series_outputs;
        filename="$(prefix)_series.jld2",
        dir,
        schedule=TimeInterval(series_interval),
        with_halos=false,
        overwrite_files,
        init=series_init)

    return diagnostics
end

function finite_difference(times, values)
    length(times) == length(values) || throw(DimensionMismatch("times and values must have equal length"))
    length(times) ≥ 2 || throw(ArgumentError("at least two samples are required"))
    all(diff(times) .> 0) || throw(ArgumentError("times must be strictly increasing"))

    derivative = similar(values, promote_type(eltype(times), eltype(values)))
    derivative[1] = (values[2] - values[1]) / (times[2] - times[1])

    for n in 2:length(times)-1
        Δt⁻ = times[n] - times[n-1]
        Δt⁺ = times[n+1] - times[n]
        backward = (values[n] - values[n-1]) / Δt⁻
        forward = (values[n+1] - values[n]) / Δt⁺
        derivative[n] = (Δt⁺ * backward + Δt⁻ * forward) / (Δt⁻ + Δt⁺)
    end

    derivative[end] = (values[end] - values[end-1]) / (times[end] - times[end-1])
    return derivative
end

function entrainment_velocity(times, inversion_height; divergence=3.75e-6)
    return finite_difference(times, inversion_height) .+ divergence .* inversion_height
end

function dycoms_entrainment_velocities(times, q_t_8gkg_inversion_height,
                                       theta_li_295_inversion_height;
                                       divergence=3.75e-6)
    q_t_8gkg = entrainment_velocity(times, q_t_8gkg_inversion_height; divergence)
    theta_li_295 = entrainment_velocity(times, theta_li_295_inversion_height; divergence)
    return (; q_t_8gkg, theta_li_295)
end

function radiative_efficiency(entrainment, inversion_jump, radiative_flux_jump;
                              density=1.13, heat_capacity=1015)
    kinematic_radiative_flux_jump = radiative_flux_jump ./ (density * heat_capacity)
    return entrainment .* inversion_jump ./ kinematic_radiative_flux_jump
end

convective_velocity_scale(inversion_height, surface_buoyancy_flux) =
    cbrt(inversion_height * surface_buoyancy_flux)

function tke_storage(times, tke_profiles)
    size(tke_profiles, 2) == length(times) ||
        throw(DimensionMismatch("the second profile dimension must match times"))
    length(times) ≥ 2 || throw(ArgumentError("at least two samples are required"))
    all(diff(times) .> 0) || throw(ArgumentError("times must be strictly increasing"))
    storage = similar(tke_profiles, promote_type(eltype(times), eltype(tke_profiles)))

    storage[:, 1] .= (tke_profiles[:, 2] .- tke_profiles[:, 1]) ./ (times[2] - times[1])
    for n in 2:length(times)-1
        Δt⁻ = times[n] - times[n-1]
        Δt⁺ = times[n+1] - times[n]
        backward = (tke_profiles[:, n] .- tke_profiles[:, n-1]) ./ Δt⁻
        forward = (tke_profiles[:, n+1] .- tke_profiles[:, n]) ./ Δt⁺
        storage[:, n] .= (Δt⁺ .* backward .+ Δt⁻ .* forward) ./ (Δt⁻ + Δt⁺)
    end
    storage[:, end] .= (tke_profiles[:, end] .- tke_profiles[:, end-1]) ./
                       (times[end] - times[end-1])
    return storage
end

function tke_budget_residual(storage, shear_production, buoyancy_production,
                             transport, dissipation)
    return storage .- shear_production .- buoyancy_production .-
           transport .+ dissipation
end

end # module DYCOMSDiagnostics
