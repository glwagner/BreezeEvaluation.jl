#####
##### Rough-wall Monin-Obukhov transfer coefficients with linear stable functions
#####

"""
$(TYPEDEF)

Rough-wall Monin-Obukhov transfer coefficients using the *linear* Businger-Dyer stability
functions, as specified by the GABLS1 stable boundary layer intercomparison
([Beare et al. (2006)](@cite Beare2006)).

This differs from [`PolynomialCoefficient`](@ref) in two ways: the neutral coefficient comes
from a **roughness length** rather than a wind-speed polynomial, and the stable branch is
**linear** in ``ζ = z/L`` rather than the Hogström form. With

```math
Ψ^D(ζ) = -β^D ζ , \\qquad Ψ^T(ζ) = -β^T ζ , \\qquad ζ > 0 ,
```

and ``a = \\ln(z/z_0^D)``, ``b = \\ln(z/z_0^T)``, the transfer coefficients are

```math
C^D = \\frac{κ²}{(a + β^D ζ)²} , \\qquad
C^T = \\frac{κ²}{(a + β^D ζ)(b + β^T ζ)} .
```

$(TYPEDFIELDS)

# Why ``ζ`` needs no iteration here

Linear stability functions close the Monin-Obukhov balance exactly. With
``u_* = κU/(a + β^D ζ)``, ``θ_* = κ Δθ/(b + β^T ζ)`` and ``ζ = κ g z θ_*/(u_*² θ_r)``, writing
the bulk Richardson number as ``R^b = g z Δθ/(θ_r U²)`` gives

```math
(β^T - R^b (β^D)²) ζ² + (b - 2 R^b a β^D) ζ - R^b a² = 0 ,
```

solved in closed form. Branch-free and exact, which suits a GPU kernel better than a
fixed-iteration solve.

# Guards, stated rather than hidden

- **Supercritical stability.** The leading coefficient vanishes at
  ``R^b = \beta^T/(\beta^D)^2 \approx 0.339``; beyond it the similarity relations admit no root.
  The SAME bound `maximum_stability` applies on both sides of that point: zeta grows smoothly
  toward it as R^b rises (9.4 at 0.30, 20.7 at 0.32, 46.2 at 0.33) and is held there above, so
  the coefficient is continuous across the critical point rather than jumping. Default bound is
  zeta = 10, already extremely stable; a bound of 100 drives C^D to ~7e-7 and effectively
  decouples the surface, which is numerically worse than a bounded residual stress.
- **Unstable side.** GABLS1 is stable throughout. For ``R^b ≤ 0`` the neutral coefficient is
  returned rather than extrapolating a stable formula outside its range — a run depending on
  this branch is doing something unintended, and the surface diagnostics will show it.

Both guards bound the exchange coefficient only; neither modifies the interior state.

# Dry-case simplification

GABLS1 carries no moisture, so the virtual potential temperature equals the potential
temperature and this coefficient reads ``θ`` directly instead of going through Breeze's
`NearWallVirtualPotentialTemperature`. It is therefore **only valid for dry configurations**.

The surface value is taken as a potential temperature. GABLS1's surface pressure is within
0.1% of the 10⁵ Pa reference implied by ``ρ_r = 1.3223`` kg/m³ and ``θ_r = 263.5`` K, so
``θ^s ≈ T^s`` and the same field serves the density calculation in the bulk formula.
"""
struct GABLSRoughWallCoefficient{FT, SP, TC, TT}
    "von Kármán constant ``κ``"
    von_karman_constant :: FT
    "Momentum roughness length ``z_0^D`` (m)"
    momentum_roughness_length :: FT
    "Thermal roughness length ``z_0^T`` (m)"
    thermal_roughness_length :: FT
    "Linear stable coefficient for momentum ``β^D``"
    momentum_stability_parameter :: FT
    "Linear stable coefficient for temperature ``β^T``"
    temperature_stability_parameter :: FT
    "Reference potential temperature ``θ_r`` (K) in the buoyancy parameter"
    reference_temperature :: FT
    "Gravitational acceleration (m s⁻²)"
    gravitational_acceleration :: FT
    "Floor on wind speed (m s⁻¹), preventing a singular ``R^b``"
    minimum_wind_speed :: FT
    "Upper bound on ``ζ`` past the critical Richardson number"
    maximum_stability :: FT
    "Standard pressure for the Exner conversion; `nothing` before materialization"
    standard_pressure :: SP
    "Thermodynamic constants; `nothing` before materialization"
    thermodynamic_constants :: TC
    "`Val(:momentum)` or `Val(:scalar)`; `nothing` before materialization"
    transfer_type :: TT
end

"""
$(TYPEDSIGNATURES)

Return a [`GABLSRoughWallCoefficient`](@ref).

Defaults are the GABLS1 specification: ``κ = 0.4``, ``z_0^D = z_0^T = 0.1`` m,
``β^D = 4.8``, ``β^T = 7.8``, ``θ_r = 263.5`` K.

```jldoctest
using Breeze

coefficient = GABLSRoughWallCoefficient()

# output
GABLSRoughWallCoefficient:
├── κ: 0.4
├── z₀ᴰ: 0.1 m, z₀ᵀ: 0.1 m
├── βᴰ: 4.8, βᵀ: 7.8
└── θᵣ: 263.5 K
```
"""
function GABLSRoughWallCoefficient(FT = Oceananigans.defaults.FloatType;
                                   von_karman_constant = 0.4,
                                   momentum_roughness_length = 0.1,
                                   thermal_roughness_length = 0.1,
                                   momentum_stability_parameter = 4.8,
                                   temperature_stability_parameter = 7.8,
                                   reference_temperature = 263.5,
                                   gravitational_acceleration = 9.81,
                                   minimum_wind_speed = 0.01,
                                   maximum_stability = 10,
                                   standard_pressure = nothing,
                                   thermodynamic_constants = nothing,
                                   transfer_type = nothing)

    return GABLSRoughWallCoefficient(convert(FT, von_karman_constant),
                                     convert(FT, momentum_roughness_length),
                                     convert(FT, thermal_roughness_length),
                                     convert(FT, momentum_stability_parameter),
                                     convert(FT, temperature_stability_parameter),
                                     convert(FT, reference_temperature),
                                     convert(FT, gravitational_acceleration),
                                     convert(FT, minimum_wind_speed),
                                     convert(FT, maximum_stability),
                                     standard_pressure,
                                     thermodynamic_constants,
                                     transfer_type)
end

function Base.show(io::IO, c::GABLSRoughWallCoefficient)
    print(io, "GABLSRoughWallCoefficient:", '\n',
              "├── κ: ", prettysummary(c.von_karman_constant), '\n',
              "├── z₀ᴰ: ", prettysummary(c.momentum_roughness_length), " m, ",
                  "z₀ᵀ: ", prettysummary(c.thermal_roughness_length), " m", '\n',
              "├── βᴰ: ", prettysummary(c.momentum_stability_parameter), ", ",
                  "βᵀ: ", prettysummary(c.temperature_stability_parameter), '\n',
              "└── θᵣ: ", prettysummary(c.reference_temperature), " K")
end

Adapt.adapt_structure(to, c::GABLSRoughWallCoefficient) =
    GABLSRoughWallCoefficient(c.von_karman_constant,
                              c.momentum_roughness_length,
                              c.thermal_roughness_length,
                              c.momentum_stability_parameter,
                              c.temperature_stability_parameter,
                              c.reference_temperature,
                              c.gravitational_acceleration,
                              c.minimum_wind_speed,
                              c.maximum_stability,
                              Adapt.adapt(to, c.standard_pressure),
                              Adapt.adapt(to, c.thermodynamic_constants),
                              Adapt.adapt(to, c.transfer_type))

"""
$(TYPEDSIGNATURES)

Return the stability parameter ``ζ = z/L`` solving the linear-stable Monin-Obukhov balance at
bulk Richardson number `Rᵇ`, with `a = ln(z/z₀ᴰ)`, `b = ln(z/z₀ᵀ)` and stable coefficients
`βᴰ`, `βᵀ`. `ζ` is capped at `ζmax` where the balance has no root.
"""
@inline function gabls_stability_parameter(Rᵇ, a, b, βᴰ, βᵀ, ζmax)
    # (βᵀ - Rᵇ βᴰ²) ζ² + (b - 2 Rᵇ a βᴰ) ζ - Rᵇ a² = 0
    A = βᵀ - Rᵇ * βᴰ^2
    B = b - 2 * Rᵇ * a * βᴰ
    C = - Rᵇ * a^2

    discriminant = B^2 - 4 * A * C

    # `max` keeps the sqrt real; the `solvable` test discards the result where it is meaningless
    root = (-B + sqrt(max(0, discriminant))) / A / 2

    solvable = (A > 0) & (discriminant > 0) & (Rᵇ > 0)
    ζ = ifelse(solvable, min(root, ζmax), ifelse(Rᵇ > 0, ζmax, zero(Rᵇ)))

    return ζ
end

# Evaluate the coefficient next to cell (i, j, k) on `side`, at wind speed U and surface
# temperature Tˢ. Dry: the near-wall potential temperature is read directly.
@inline function (c::GABLSRoughWallCoefficient)(i, j, k, grid, side, U, Tˢ, fields, pˢ)
    h = wall_distance(i, j, k, grid, side)

    a = log(h / c.momentum_roughness_length)
    b = log(h / c.thermal_roughness_length)

    # Convert the wall temperature to a potential temperature exactly as
    # `BulkSensibleHeatFlux` does, so the Richardson number and the heat flux see the *same*
    # Δθ. The Exner factor is ~3e-6 here, but a mismatch between the two paths would be a
    # real inconsistency rather than a small one.
    θ = @inbounds fields.θ[i, j, k]
    θˢ = potential_temperature_from_temperature(Tˢ, pˢ, c.standard_pressure,
                                                c.thermodynamic_constants)
    Δθ = θ - θˢ

    Uₘ = max(U, c.minimum_wind_speed)
    Rᵇ = stability_sign(side) * c.gravitational_acceleration * h * Δθ /
         (c.reference_temperature * Uₘ^2)

    ζ = gabls_stability_parameter(Rᵇ, a, b,
                                  c.momentum_stability_parameter,
                                  c.temperature_stability_parameter,
                                  c.maximum_stability)

    return gabls_transfer_coefficient(c, a, b, ζ, c.transfer_type)
end

@inline function gabls_transfer_coefficient(c, a, b, ζ, ::Val{:momentum})
    ϕᴰ = a + c.momentum_stability_parameter * ζ
    return c.von_karman_constant^2 / ϕᴰ^2
end

@inline function gabls_transfer_coefficient(c, a, b, ζ, ::Val{:scalar})
    ϕᴰ = a + c.momentum_stability_parameter * ζ
    ϕᵀ = b + c.temperature_stability_parameter * ζ
    return c.von_karman_constant^2 / (ϕᴰ * ϕᵀ)
end

# Unmaterialized coefficients default to momentum, matching `PolynomialCoefficient`
@inline gabls_transfer_coefficient(c, a, b, ζ, ::Nothing) =
    gabls_transfer_coefficient(c, a, b, ζ, Val(:momentum))

# Stamp the transfer type so a single coefficient object yields Cᴰ on momentum walls and Cᵀ on
# scalar walls, exactly as `PolynomialCoefficient` does.
materialize_coefficient(c::GABLSRoughWallCoefficient, grid, dynamics, microphysics,
                        constants, transfer_type) =
    GABLSRoughWallCoefficient(c.von_karman_constant,
                              c.momentum_roughness_length,
                              c.thermal_roughness_length,
                              c.momentum_stability_parameter,
                              c.temperature_stability_parameter,
                              c.reference_temperature,
                              c.gravitational_acceleration,
                              c.minimum_wind_speed,
                              c.maximum_stability,
                              standard_pressure(dynamics),
                              constants,
                              transfer_type)

@inline function bulk_coefficient(i, j, k, grid, side, C::GABLSRoughWallCoefficient, fields, Tˢ,
                                  ::Nothing, pˢ)
    U = sqrt(tangential_speed²(i, j, k, grid, side, nothing, fields))
    return C(i, j, k, grid, side, U, Tˢ, fields, pˢ)
end
