module SurfaceLayerDiagnostics

export surface_layer_diagnostic_outputs

using Oceananigans
using Oceananigans.AbstractOperations: Average, KernelFunctionOperation
using Oceananigans.Fields: Field
using Oceananigans.Grids: Center, Face

plane_mean(field) = Field(Average(field; dims=(1, 2)))

@inline nonpositive_indicator(i, j, k, grid, field, source_k) =
    ifelse(field[i, j, source_k] <= 0, one(eltype(grid)), zero(eltype(grid)))

@inline valid_nonpositive_indicator(i, j, k, grid, deficit, active) =
    ifelse((deficit[i, j, 1] <= 0) & (active[i, j, 1] > 0), one(eltype(grid)), zero(eltype(grid)))

function valid_nonpositive_fraction(deficit, active)
    operation = KernelFunctionOperation{Center, Center, Nothing}(
        valid_nonpositive_indicator, deficit.grid, deficit, active)
    return plane_mean(Field(operation))
end

# Diagnostic-only kernel: retain spatial information before the horizontal mean.
# A zero mean coefficient cannot be used to reconstruct this fraction.
function nonpositive_fraction(field, source_k)
    operation = KernelFunctionOperation{Center, Center, Nothing}(
        nonpositive_indicator, field.grid, field, source_k)
    return plane_mean(Field(operation))
end

function surface_layer_diagnostic_outputs(model)
    closure_fields = model.closure_fields
    hasproperty(closure_fields, :momentum_deficit) ||
        return (; profiles=NamedTuple(), series=NamedTuple(), metadata=(;
            surface_layer_diffusivity_available=false))

    closure = model.closure

    profiles = (; surface_layer_viscosity=plane_mean(closure_fields.Kᵘ))
    series = (;
        surface_layer_filtered_surface_u_flux=
            plane_mean(closure_fields.surface_u_flux),
        surface_layer_filtered_surface_v_flux=
            plane_mean(closure_fields.surface_v_flux))

    filtered_friction_velocity = Field(sqrt(sqrt(closure_fields.surface_u_flux^2 +
                                                   closure_fields.surface_v_flux^2)))
    series = merge(series, (;
        surface_layer_filtered_friction_velocity=plane_mean(filtered_friction_velocity)))

    for (slot, face) in enumerate((2, 3))
        prefix = "surface_layer_face$(slot)_"
        filtered_u_mean = closure_fields.u_mean[slot]
        filtered_v_mean = closure_fields.v_mean[slot]
        filtered_w_mean = closure_fields.w_mean[slot]
        filtered_u_mean_transport = Field(filtered_u_mean * filtered_w_mean)
        filtered_v_mean_transport = Field(filtered_v_mean * filtered_w_mean)
        series = merge(series, (;
              Symbol(prefix, "viscosity") =>
                  plane_mean(view(closure_fields.Kᵘ, :, :, face)),
              Symbol(prefix, "filtered_u_mean") => plane_mean(filtered_u_mean),
              Symbol(prefix, "filtered_v_mean") => plane_mean(filtered_v_mean),
              Symbol(prefix, "filtered_w_mean") => plane_mean(filtered_w_mean),
              Symbol(prefix, "filtered_uw_product") =>
                  plane_mean(closure_fields.uw_product_mean[slot]),
              Symbol(prefix, "filtered_vw_product") =>
                  plane_mean(closure_fields.vw_product_mean[slot]),
              Symbol(prefix, "filtered_u_mean_w_mean_transport") =>
                  plane_mean(filtered_u_mean_transport),
              Symbol(prefix, "filtered_v_mean_w_mean_transport") =>
                  plane_mean(filtered_v_mean_transport),
              Symbol(prefix, "momentum_deficit") =>
                  plane_mean(closure_fields.momentum_deficit[slot]),
              Symbol(prefix, "transverse_resolved_stress") =>
                  plane_mean(closure_fields.transverse_stress[slot]),
              Symbol(prefix, "resolved_u_flux") =>
                  plane_mean(closure_fields.resolved_u_flux[slot]),
              Symbol(prefix, "resolved_v_flux") =>
                  plane_mean(closure_fields.resolved_v_flux[slot]),
              Symbol(prefix, "momentum_active_fraction") =>
                  plane_mean(closure_fields.momentum_active[slot]),
              Symbol(prefix, "viscosity_cap_fraction") =>
                  plane_mean(closure_fields.viscosity_cap_active[slot])))
        if closure.resolved_transport isa Val{:scheme_native}
            series = merge(series, (;
                Symbol(prefix, "scheme_u_flux") =>
                    plane_mean(closure_fields.scheme_u_flux[slot]),
                Symbol(prefix, "scheme_v_flux") =>
                    plane_mean(closure_fields.scheme_v_flux[slot]),
                Symbol(prefix, "numerical_u_correction") =>
                    plane_mean(closure_fields.numerical_u_correction[slot]),
                Symbol(prefix, "numerical_v_correction") =>
                    plane_mean(closure_fields.numerical_v_correction[slot]),
                Symbol(prefix, "reconstructed_u_flux") =>
                    plane_mean(Field(closure_fields.resolved_u_flux[slot] +
                                     closure_fields.numerical_u_correction[slot])),
                Symbol(prefix, "reconstructed_v_flux") =>
                    plane_mean(Field(closure_fields.resolved_v_flux[slot] +
                                     closure_fields.numerical_v_correction[slot]))))
        end
        if slot == 1
            series = merge(series, (;
                surface_layer_face1_momentum_deficit_zero_fraction=
                    nonpositive_fraction(closure_fields.momentum_deficit[slot], 1),
                surface_layer_face1_viscosity_zero_fraction=
                    nonpositive_fraction(closure_fields.Kᵘ, face),
                surface_layer_face1_momentum_valid_zero_deficit_fraction=
                    valid_nonpositive_fraction(closure_fields.momentum_deficit[slot], closure_fields.momentum_active[slot])))
        end
    end

    for name in keys(closure_fields.tupled_tracer_diffusivities)
        suffix = string(name)
        diffusivity = closure_fields.tupled_tracer_diffusivities[name]
        profiles = merge(profiles, (;
            Symbol("surface_layer_diffusivity_", suffix) => plane_mean(diffusivity)))
        series = merge(series, (;
            Symbol("surface_layer_filtered_surface_flux_", suffix) =>
                plane_mean(closure_fields.surface_scalar_flux[name])))
        for (slot, face) in enumerate((2, 3))
            prefix = "surface_layer_face$(slot)_$(suffix)_"
            filtered_scalar_mean = closure_fields.scalar_mean[name][slot]
            filtered_w_mean = closure_fields.w_mean[slot]
            filtered_mean_transport = Field(filtered_scalar_mean * filtered_w_mean)
            series = merge(series, (;
                  Symbol(prefix, "diffusivity") =>
                      plane_mean(view(diffusivity, :, :, face)),
                  Symbol(prefix, "filtered_scalar_mean") =>
                      plane_mean(filtered_scalar_mean),
                  Symbol(prefix, "filtered_scalar_w_product") =>
                      plane_mean(closure_fields.scalar_w_product_mean[name][slot]),
                  Symbol(prefix, "filtered_scalar_mean_w_mean_transport") =>
                      plane_mean(filtered_mean_transport),
                  Symbol(prefix, "resolved_flux") =>
                      plane_mean(closure_fields.resolved_scalar_flux[name][slot]),
                  Symbol(prefix, "deficit") =>
                      plane_mean(closure_fields.scalar_deficit[name][slot]),
                  Symbol(prefix, "active_fraction") =>
                      plane_mean(closure_fields.scalar_active[name][slot]),
                  Symbol(prefix, "cap_fraction") =>
                      plane_mean(closure_fields.diffusivity_cap_active[name][slot])))
            if closure.resolved_transport isa Val{:scheme_native}
                series = merge(series, (;
                    Symbol(prefix, "scheme_flux") =>
                        plane_mean(closure_fields.scheme_scalar_flux[name][slot]),
                    Symbol(prefix, "numerical_correction") =>
                        plane_mean(closure_fields.numerical_scalar_correction[name][slot]),
                    Symbol(prefix, "reconstructed_flux") =>
                        plane_mean(Field(closure_fields.resolved_scalar_flux[name][slot] +
                                         closure_fields.numerical_scalar_correction[name][slot]))))
            end
            if slot == 1 && name == :ρθ
                series = merge(series, (;
                    surface_layer_face1_ρθ_deficit_zero_fraction=
                        nonpositive_fraction(closure_fields.scalar_deficit[name][slot], 1),
                    surface_layer_face1_ρθ_diffusivity_zero_fraction=
                        nonpositive_fraction(diffusivity, face),
                    surface_layer_face1_ρθ_valid_zero_deficit_fraction=
                        valid_nonpositive_fraction(closure_fields.scalar_deficit[name][slot], closure_fields.scalar_active[name][slot])))
            end
        end
    end

    z_faces = collect(znodes(model.grid, Center(), Center(), Face()))
    FT = eltype(model.grid)
    support_weights = (one(FT), closure.support == 2 ? FT(0.5) : zero(FT))
    metadata = (;
        surface_layer_diffusivity_available=true,
        surface_layer_zero_fraction_definition="all fractions use all horizontal points as denominator: deficit_zero is clipped deficit<=0; valid_zero_deficit is active>0 AND deficit<=0 (off because signed resolved target met); coefficient_zero is actual coefficient<=0; active_fraction reports target/guard/support validity, not positive mixing; cap_fraction is separate",
        surface_layer_filter_timescale_seconds=closure.filter_timescale,
        surface_layer_support_faces=closure.support,
        surface_layer_interior_face_indices=(2, 3),
        surface_layer_interior_face_heights_m=(z_faces[2], z_faces[3]),
        surface_layer_interior_face_weights=support_weights,
        surface_layer_von_karman_constant=closure.von_karman_constant,
        surface_layer_turbulent_prandtl_number=closure.turbulent_prandtl_number,
        surface_layer_minimum_friction_velocity=closure.minimum_friction_velocity,
        surface_layer_maximum_viscosity=closure.maximum_viscosity,
        surface_layer_maximum_diffusivity=closure.maximum_diffusivity,
        surface_layer_filter_timing="updated once per accepted step from completed-step state and contemporaneous wall operands; coefficients have a one-completed-step lag",
        surface_layer_covariance_definition="stable exponentially weighted centered recurrence; raw product means do not drive the closure",
        surface_layer_resolved_transport=closure.resolved_transport isa Val{:scheme_native} ?
            "scheme_native" : "covariance",
        surface_layer_scheme_native_definition="stable filtered covariance plus filtered instantaneous operator-flux-minus-centered-product correction; sampled at accepted steps, not RK-stage-integrated",
        surface_layer_mean_transport_definition="horizontal mean of each local filtered mean product, for example <ubar_T wbar_T>_xy; never product of horizontal averages",
        surface_layer_friction_velocity_definition="compute local ustar from the filtered local wall-stress vector, then horizontally average local ustar",
        surface_layer_momentum_flux_units="m2 s-2",
        surface_layer_viscosity_units="m2 s-1")
    for (name, guard) in pairs(closure.minimum_scalar_fluxes)
        units = name === :ρθ ? "K m s-1" :
                startswith(string(name), "ρq") ? "m s-1" : "specific-scalar m s-1"
        metadata = merge(metadata, (;
            Symbol("surface_layer_flux_guard_", name) => guard,
            Symbol("surface_layer_flux_guard_", name, "_units") => units,
            Symbol("surface_layer_diffusivity_", name, "_units") => "m2 s-1"))
    end
    return (; profiles, series, metadata)
end

end
