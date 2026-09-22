# Manufactured input fields validate diagnostic classification, not atmospheric truth.
function zero_fraction_contract(architecture; check, resolved_flux_factor=10)
    model = Helpers.build_contract_model(architecture; moist=false, support=1, resolved_flux_factor)
    f = model.closure_fields
    set!(f.momentum_deficit[1], (x,y) -> x < 10 ? 0f0 : 0.5f0)
    set!(f.Kᵘ, (x,y,z) -> x < 20 ? 0f0 : 1f0)
    set!(f.momentum_active[1], (x,y) -> 10 <= x < 20 ? 0f0 : 1f0)
    set!(f.viscosity_cap_active[1], (x,y) -> x >= 30 ? 1f0 : 0f0)
    set!(f.scalar_deficit.ρθ[1], (x,y) -> x < 20 ? 0f0 : 0.5f0)
    set!(f.tupled_tracer_diffusivities.ρθ, (x,y,z) -> x < 30 ? 0f0 : 1f0)
    set!(f.scalar_active.ρθ[1], (x,y) -> 10 <= x < 30 ? 0f0 : 1f0)
    set!(f.diffusivity_cap_active.ρθ[1], (x,y) -> x >= 30 ? 1f0 : 0f0)
    before = Helpers.host_prognostic_state(model)
    diagnostics = Helpers.GABLS1ValidationRunner.SurfaceLayerDiagnostics.surface_layer_diagnostic_outputs(model)
    expected = Dict(
        :surface_layer_face1_momentum_deficit_zero_fraction => 0.25f0,
        :surface_layer_face1_viscosity_zero_fraction => 0.5f0,
        :surface_layer_face1_momentum_valid_zero_deficit_fraction => 0.25f0,
        :surface_layer_face1_momentum_active_fraction => 0.75f0,
        :surface_layer_face1_viscosity_cap_fraction => 0.25f0,
        :surface_layer_face1_ρθ_deficit_zero_fraction => 0.5f0,
        :surface_layer_face1_ρθ_diffusivity_zero_fraction => 0.75f0,
        :surface_layer_face1_ρθ_valid_zero_deficit_fraction => 0.25f0,
        :surface_layer_face1_ρθ_active_fraction => 0.5f0,
        :surface_layer_face1_ρθ_cap_fraction => 0.25f0)
    for (name, value) in expected
        field = diagnostics.series[name]
        compute!(field)
        actual = only(Array(interior(field)))
        check(actual == value, "manufactured spatial fraction mismatch $name: $actual != $value")
    end
    after = Helpers.host_prognostic_state(model)
    check(isequal(before, after), "diagnostic computation changed model state")
    return Dict(string(k) => v for (k,v) in expected)
end

function audit_zero_fraction_series(prefix; check)
    jldopen(prefix * "_series.jld2", "r") do file
        for key in keys(file["timeseries/t"])
            for scalar in ("momentum", "ρθ")
                coefficient = scalar == "momentum" ? "viscosity" : "ρθ_diffusivity"
                active_name = scalar == "momentum" ? "momentum_active_fraction" : "ρθ_active_fraction"
                values = Dict{String,Float64}()
                for suffix in (scalar * "_deficit_zero_fraction", scalar * "_valid_zero_deficit_fraction", coefficient * "_zero_fraction", active_name)
                    raw = file["timeseries/surface_layer_face1_$suffix/$key"]
                    value = raw isa Number ? Float64(raw) : only(vec(raw))
                    check(isfinite(value) && 0 <= value <= 1, "invalid saved fraction $suffix")
                    values[suffix] = value
                end
                rawzero = values[scalar * "_deficit_zero_fraction"]
                validzero = values[scalar * "_valid_zero_deficit_fraction"]
                active = values[active_name]
                coefficientzero = values[coefficient * "_zero_fraction"]
                check(validzero <= rawzero && validzero <= active, "invalid zero/valid intersection")
                check(validzero <= coefficientzero + 1e-6, "target met but coefficient nonzero")
                check(1-active <= coefficientzero + 1e-6, "inactive guard but coefficient nonzero")
            end
        end
    end
end
