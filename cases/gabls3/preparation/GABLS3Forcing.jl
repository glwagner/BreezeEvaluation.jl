module GABLS3Forcing

using TOML
export load_case, surface_state, geostrophic_wind, advection, initial_state,
       linear_value, scalar_flux, stable_psi, forcing_events, preflight

"""Validated, portable input table reader. All units are SI; times are seconds after 2006-07-02T00:00:00Z."""
function load_case(path)
    d = TOML.parsefile(path)
    d["time_origin_utc"] == "2006-07-02T00:00:00Z" || error("Unexpected UTC origin")
    d["humidity_definition"] == "specific_humidity_kg_per_kg_moist_air" || error("Humidity convention must be explicit")
    for (name, axis, columns) in (("surface", "t", ("pressure", "theta", "q")),
                                 ("geostrophic", "t", ("u", "v")),
                                 ("initial_wind", "z", ("u", "v")),
                                 ("initial_thermodynamics", "z", ("pressure", "theta", "q")))
        tab = d[name]; x = tab[axis]
        length(x) >= 2 && all(isfinite, x) && all(diff(x) .> 0) || error("Invalid $name axis")
        for col in columns
            length(tab[col]) == length(x) && all(isfinite, tab[col]) || error("Invalid $name/$col")
        end
    end
    d["surface"]["t"][1] <= 0 && d["surface"]["t"][end] >= 32400 || error("Surface forcing lacks nine-hour coverage")
    d
end

function linear_value(x, y, target)
    isfinite(target) && first(x) <= target <= last(x) || throw(DomainError(target, "Extrapolation is not permitted"))
    target == last(x) && return last(y)
    i = searchsortedlast(x, target)
    f = (target - x[i]) / (x[i+1] - x[i])
    muladd(f, y[i+1] - y[i], y[i])
end

function check_time(t)
    isfinite(t) && 0 <= t <= 32400 || throw(DomainError(t, "Time must be in the nine-hour LES interval"))
end
function check_height(z)
    isfinite(z) && 0 <= z <= 800 || throw(DomainError(z, "Height must lie in the 800m LES domain"))
end

function surface_state(d, t)
    check_time(t); s = d["surface"]
    (; pressure=linear_value(s["t"], s["pressure"], t),
       theta=linear_value(s["t"], s["theta"], t), q=linear_value(s["t"], s["q"], t))
end

function geostrophic_wind(d, z, t)
    check_time(t); check_height(z); g = d["geostrophic"]
    u0 = linear_value(g["t"], g["u"], t)
    v0 = linear_value(g["t"], g["v"], t)
    (; u=muladd(z / g["reference_height"], g["u_at_reference"] - u0, u0),
       v=muladd(z / g["reference_height"], g["v_at_reference"] - v0, v0))
end

"""Tables5–7: signed RHS tendencies, with right-continuous jumps. No artificial millisecond ramp."""
function advection(d, z, t)
    check_time(t); check_height(z)
    f = min(z / 200, 1)
    (; u=f * (t < 10800 ? 5e-4 : 0.0), v=0.0,
       theta=f * (t < 3600 ? -2.5e-5 : t < 21600 ? 7.5e-5 : 0.0),
       q=f * (7200 <= t < 18000 ? -8e-8 : 0.0))
end

forcing_events() = (3600.0, 7200.0, 10800.0, 18000.0, 21600.0)

"""Interpolate published initial profiles only within measured coverage. Below10m needs a reviewed policy."""
function initial_state(d, z)
    check_height(z); w = d["initial_wind"]; s = d["initial_thermodynamics"]
    (; u=linear_value(w["z"], w["u"], z), v=linear_value(w["z"], w["v"], z),
       pressure=linear_value(s["z"], s["pressure"], z),
       theta=linear_value(s["z"], s["theta"], z), q=linear_value(s["z"], s["q"], z))
end

stable_psi(zeta) = zeta >= 0 ? -5zeta : throw(DomainError(zeta, "Unstable branch has not been selected"))

"""Scalar surface flux formula from revised case spec. Inputs use scalar value at0.25m, not at z0m.
The caller supplies an explicitly reviewed stability function and Obukhov length, including morning instability.
This helper does not solve coupled momentum/heat/moisture MOST or select moist buoyancy conventions.
"""
function scalar_flux(ustar, kappa, scalar_at_quarter_m, scalar_at_first_level, z1, L, psi)
    z1 > 0.25 || throw(DomainError(z1, "Model level must exceed scalar reference height"))
    isfinite(ustar) && ustar >= 0 || throw(DomainError(ustar))
    isfinite(kappa) && kappa > 0 || throw(DomainError(kappa))
    !isnan(L) && L != 0 || throw(DomainError(L))
    denominator = log(z1 / 0.25) - psi(z1 / L) + psi(0.25 / L)
    isfinite(denominator) && denominator > 0 || throw(DomainError(denominator))
    ustar * kappa * (scalar_at_quarter_m - scalar_at_first_level) / denominator
end

"""Fail closed until reviewed model integration and external reference audit exist."""
function preflight(d)
    gates = d["readiness"]
    missing = sort([key for (key, value) in gates if value !== true])
    isempty(missing) || error("GABLS3 is preparation-only; unresolved gates: " * join(missing, ", "))
    true
end
end
