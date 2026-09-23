##### GABLS1 dry rough-wall coefficient adapter for Breeze's shared filtered wall state.
##### Included into Breeze.BoundaryConditions by the isolated evaluation case.

@inline function surface_layer_Δθᵥ(i, j, k, grid, c::GABLSRoughWallCoefficient,
                                   Tˢ, fields, pˢ)
    θˢ = potential_temperature_from_temperature(Tˢ, pˢ, c.standard_pressure,
                                                c.thermodynamic_constants)
    return @inbounds(fields.θ[i, j, k]) - θˢ
end

function initialize_filtered_Δθᵥ!(fv::FilteredSurfaceVelocities,
                                  c::GABLSRoughWallCoefficient, Tˢ, model)
    initialize_Δθᵥ!(fv, c, Tˢ, model.grid, model.clock, surface_layer_state(model))
    return nothing
end

function update_filtered_Δθᵥ!(fv::FilteredSurfaceVelocities,
                              c::GABLSRoughWallCoefficient, Tˢ, model)
    key = (model.clock.iteration, model.clock.stage)
    fv.last_Δθᵥ_update[] == key && return nothing
    Δt = model.clock.last_Δt
    isinf(Δt) && return nothing
    update_Δθᵥ!(fv, c, Tˢ, model.grid, model.clock, Δt, surface_layer_state(model))
    fv.last_Δθᵥ_update[] = key
    return nothing
end

@inline function bulk_coefficient(i, j, k, grid, side::Bottom,
                                  c::GABLSRoughWallCoefficient, fields, Tˢ,
                                  fv::FilteredSurfaceVelocities, pˢ)
    h = wall_distance(i, j, k, grid, side)
    a = log(h / c.momentum_roughness_length)
    b = log(h / c.thermal_roughness_length)
    U = sqrt(wind_speed²ᶜᶜᶜ(i, j, grid, fields, fv))
    Uₘ = max(U, c.minimum_wind_speed)
    Δθ = @inbounds fv.Δθᵥ[i, j, 1]
    Rᵇ = stability_sign(side) * c.gravitational_acceleration * h * Δθ /
         (c.reference_temperature * Uₘ^2)
    ζ = gabls_stability_parameter(Rᵇ, a, b,
                                  c.momentum_stability_parameter,
                                  c.temperature_stability_parameter,
                                  c.maximum_stability)
    return gabls_transfer_coefficient(c, a, b, ζ, c.transfer_type)
end

# GABLS1 cools the surface throughout the run. The generic filtered heat path
# filters θ and subtracts the *current* θˢ; its Δθ would differ from the filtered
# θ - θˢ used by the stability coefficient by the surface-cooling lag. Use the
# same filtered difference for both the coefficient and heat flux in this dry case.
@inline function bulk_sensible_heat_difference(i, j, k, grid, side::Bottom,
                                                ::PotentialTemperatureFlux,
                                                bf::BulkSensibleHeatFluxFunction{<:Any,<:GABLSRoughWallCoefficient},
                                                Tˢ, fields, pˢ,
                                                fs::FilteredSurfaceScalar)
    return @inbounds bf.filtered_velocities.Δθᵥ[i, j, 1]
end
