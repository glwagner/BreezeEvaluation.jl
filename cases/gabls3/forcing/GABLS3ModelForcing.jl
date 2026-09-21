module GABLS3ModelForcing

export GABLS3InputTables,
       GABLS3MOSTCoefficient,
       SurfaceTemperature,
       SurfaceRelativeHumidity,
       geostrophic_u,
       geostrophic_v,
       advective_u_tendency,
       advective_v_tendency,
       advective_theta_tendency,
       advective_q_tendency,
       initial_u,
       initial_v,
       initial_theta,
       initial_q,
       initial_pressure,
       initial_temperature,
       update_surface_humidity!,
       surface_state,
       most_diagnostics

using Breeze
using Oceananigans

using Breeze.AtmosphereModels: moisture_specific_name, standard_pressure
using Breeze.AtmosphereModels.Diagnostics: virtual_potential_temperature
using Breeze.BoundaryConditions: NearWallVirtualPotentialTemperature,
                                 tangential_speed²,
                                 wall_distance
using Breeze.Thermodynamics: MoistureMassFractions,
                             PlanarLiquidSurface,
                             saturation_specific_humidity,
                             surface_density
using Oceananigans.BoundaryConditions: Bottom
using Oceananigans.Fields: Field
using Oceananigans.Grids: Center

const BCS = Breeze.BoundaryConditions
const Adapt = Breeze.BoundaryConditions.Adapt

"""An isbits table used directly by CPU and GPU forcing kernels."""
struct LinearTable{N, T}
    x :: NTuple{N, T}
    y :: NTuple{N, T}
end

function LinearTable(x, y, ::Type{T}) where T
    length(x) == length(y) || throw(ArgumentError("table axes have different lengths"))
    return LinearTable(Tuple(T.(x)), Tuple(T.(y)))
end

@inline function (table::LinearTable{N})(target) where N
    # Clamp only outside the forcing interval. All production stage times lie in it.
    value = first(table.y)
    @inbounds for n in 1:N-1
        fraction = clamp((target - table.x[n]) / (table.x[n+1] - table.x[n]), 0, 1)
        segment_value = muladd(fraction, table.y[n+1] - table.y[n], table.y[n])
        value = ifelse(target >= table.x[n], segment_value, value)
    end
    return ifelse(target >= last(table.x), last(table.y), value)
end

struct GABLS3InputTables{S, G, W, T, FT}
    surface_pressure :: S
    surface_theta :: S
    surface_q :: S
    geostrophic_u_ground :: G
    geostrophic_v_ground :: G
    initial_u_table :: W
    initial_v_table :: W
    initial_pressure_table :: T
    initial_theta_table :: T
    initial_q_table :: T
    geostrophic_reference_height :: FT
    geostrophic_u_reference :: FT
    geostrophic_v_reference :: FT
    momentum_roughness :: FT
    scalar_reference_height :: FT
    standard_pressure :: FT
end

function GABLS3InputTables(data, ::Type{FT}=Float64) where FT
    surface = data["surface"]
    geostrophic = data["geostrophic"]
    wind = data["initial_wind"]
    thermodynamics = data["initial_thermodynamics"]
    surface_axis = surface["t"]
    geostrophic_axis = geostrophic["t"]
    wind_axis = wind["z"]
    thermo_axis = thermodynamics["z"]
    return GABLS3InputTables(
        LinearTable(surface_axis, surface["pressure"], FT),
        LinearTable(surface_axis, surface["theta"], FT),
        LinearTable(surface_axis, surface["q"], FT),
        LinearTable(geostrophic_axis, geostrophic["u"], FT),
        LinearTable(geostrophic_axis, geostrophic["v"], FT),
        LinearTable(wind_axis, wind["u"], FT),
        LinearTable(wind_axis, wind["v"], FT),
        LinearTable(thermo_axis, thermodynamics["pressure"], FT),
        LinearTable(thermo_axis, thermodynamics["theta"], FT),
        LinearTable(thermo_axis, thermodynamics["q"], FT),
        FT(geostrophic["reference_height"]),
        FT(geostrophic["u_at_reference"]),
        FT(geostrophic["v_at_reference"]),
        FT(surface["momentum_roughness"]),
        FT(surface["scalar_reference_height"]),
        FT(1e5))
end

Adapt.adapt_structure(to, tables::GABLS3InputTables) =
    GABLS3InputTables(Adapt.adapt(to, tables.surface_pressure),
                      Adapt.adapt(to, tables.surface_theta),
                      Adapt.adapt(to, tables.surface_q),
                      Adapt.adapt(to, tables.geostrophic_u_ground),
                      Adapt.adapt(to, tables.geostrophic_v_ground),
                      Adapt.adapt(to, tables.initial_u_table),
                      Adapt.adapt(to, tables.initial_v_table),
                      Adapt.adapt(to, tables.initial_pressure_table),
                      Adapt.adapt(to, tables.initial_theta_table),
                      Adapt.adapt(to, tables.initial_q_table),
                      Adapt.adapt(to, tables.geostrophic_reference_height),
                      Adapt.adapt(to, tables.geostrophic_u_reference),
                      Adapt.adapt(to, tables.geostrophic_v_reference),
                      Adapt.adapt(to, tables.momentum_roughness),
                      Adapt.adapt(to, tables.scalar_reference_height),
                      Adapt.adapt(to, tables.standard_pressure))

@inline surface_state(tables, time) = (; pressure=tables.surface_pressure(time),
                                        theta=tables.surface_theta(time),
                                        q=tables.surface_q(time))

@inline function geostrophic_u(tables, z, time)
    u₀ = tables.geostrophic_u_ground(time)
    return muladd(z / tables.geostrophic_reference_height,
                  tables.geostrophic_u_reference - u₀, u₀)
end

@inline function geostrophic_v(tables, z, time)
    v₀ = tables.geostrophic_v_ground(time)
    return muladd(z / tables.geostrophic_reference_height,
                  tables.geostrophic_v_reference - v₀, v₀)
end

@inline height_factor(z) = min(z / 200, 1)
@inline advective_u_tendency(tables, z, time) =
    height_factor(z) * ifelse(time < 10800, oftype(z, 5e-4), zero(z))
@inline advective_v_tendency(tables, z, time) = zero(z + time)
@inline advective_theta_tendency(tables, z, time) =
    height_factor(z) * ifelse(time < 3600, oftype(z, -2.5e-5),
                             ifelse(time < 21600, oftype(z, 7.5e-5), zero(z)))
@inline advective_q_tendency(tables, z, time) =
    height_factor(z) * ifelse((time >= 7200) & (time < 18000),
                             oftype(z, -8e-8), zero(z))

# Below 10 m, scalars connect the prescribed 0.25 m surface values to the first sounding value.
# Wind connects the no-slip aerodynamic origin at z₀ₘ to the 10 m observation logarithmically.
@inline function initial_wind_component(table, tables, z)
    z₀ = tables.momentum_roughness
    value₁₀ = first(table.y)
    logarithmic = value₁₀ * log(max(z, z₀) / z₀) / log(10 / z₀)
    return ifelse(z < 10, ifelse(z <= z₀, zero(z), logarithmic), table(z))
end

@inline initial_u(tables, z) = initial_wind_component(
    tables.initial_u_table, tables, oftype(tables.momentum_roughness, z))
@inline initial_v(tables, z) = initial_wind_component(
    tables.initial_v_table, tables, oftype(tables.momentum_roughness, z))

@inline function near_surface_scalar(table, surface_value, z)
    reference_height = oftype(z, 0.25)
    first_observation_height = oftype(z, 10)
    fraction = clamp((z - reference_height) /
                     (first_observation_height - reference_height), 0, 1)
    return muladd(fraction, first(table.y) - surface_value, surface_value)
end

@inline function initial_theta(tables, z)
    z = oftype(tables.momentum_roughness, z)
    return ifelse(z < 10,
        near_surface_scalar(tables.initial_theta_table, tables.surface_theta(0), z),
        tables.initial_theta_table(z))
end
@inline function initial_q(tables, z)
    z = oftype(tables.momentum_roughness, z)
    return ifelse(z < 10,
        near_surface_scalar(tables.initial_q_table, tables.surface_q(0), z),
        tables.initial_q_table(z))
end
@inline function initial_pressure(tables, z)
    z = oftype(tables.momentum_roughness, z)
    return ifelse(z < 10,
        near_surface_scalar(tables.initial_pressure_table, tables.surface_pressure(0), z),
        tables.initial_pressure_table(z))
end

@inline function initial_temperature(tables, constants, z)
    Rᵈ = Breeze.Thermodynamics.dry_air_gas_constant(constants)
    cᵖᵈ = constants.dry_air.heat_capacity
    return initial_theta(tables, z) * (initial_pressure(tables, z) / tables.standard_pressure)^(Rᵈ / cᵖᵈ)
end

struct SurfaceTemperature{I, TC}
    inputs :: I
    thermodynamic_constants :: TC
end

Adapt.adapt_structure(to, surface::SurfaceTemperature) =
    SurfaceTemperature(Adapt.adapt(to, surface.inputs), Adapt.adapt(to, surface.thermodynamic_constants))

@inline function (surface::SurfaceTemperature)(x, y, time)
    state = surface_state(surface.inputs, time)
    Rᵈ = Breeze.Thermodynamics.dry_air_gas_constant(surface.thermodynamic_constants)
    cᵖᵈ = surface.thermodynamic_constants.dry_air.heat_capacity
    return state.theta * (state.pressure / surface.inputs.standard_pressure)^(Rᵈ / cᵖᵈ)
end

struct SurfaceRelativeHumidity{I, TC, P, R}
    inputs :: I
    thermodynamic_constants :: TC
    reference_pressure :: P
    reference_density :: R
end

BCS.materialize_surface_field(surface::SurfaceTemperature, grid, side) = surface
BCS.materialize_surface_field(surface::SurfaceRelativeHumidity, grid, side) = surface

@inline function BCS.wall_value(i, j, grid, ::Bottom,
                                surface::SurfaceTemperature, clock)
    x, y = Oceananigans.Grids.node(i, j, 1, grid, Center(), Center(), nothing)
    return surface(x, y, clock.time)
end

@inline function BCS.wall_value(i, j, grid, ::Bottom,
                                surface::SurfaceRelativeHumidity, clock)
    x, y = Oceananigans.Grids.node(i, j, 1, grid, Center(), Center(), nothing)
    temperature = SurfaceTemperature(surface.inputs, surface.thermodynamic_constants)(x, y, clock.time)
    qˢ = surface.inputs.surface_q(clock.time)
    # Use the same bottom-wall pressure, dry surface density, and saturation function as
    # BulkVaporFluxFunction.getbc. For anelastic dynamics, both reference fields are fixed.
    fields = (; p=surface.reference_pressure, ρ=surface.reference_density)
    pˢ = BCS.wall_air_pressure(i, j, 1, grid, Bottom(), nothing, fields,
                              surface.thermodynamic_constants)
    ρˢ = surface_density(pˢ, temperature, surface.thermodynamic_constants)
    qˢᵃᵗ = saturation_specific_humidity(temperature, ρˢ,
                                       surface.thermodynamic_constants, PlanarLiquidSurface())
    return clamp(qˢ / qˢᵃᵗ, 0, 1)
end

Adapt.adapt_structure(to, surface::SurfaceRelativeHumidity) =
    SurfaceRelativeHumidity(Adapt.adapt(to, surface.inputs),
                            Adapt.adapt(to, surface.thermodynamic_constants),
                            Adapt.adapt(to, surface.reference_pressure),
                            Adapt.adapt(to, surface.reference_density))

"""GABLS3 MOST coefficient shared by momentum, heat, and moisture boundary conditions."""
struct GABLS3MOSTCoefficient{FT, Q, θV, SP, TC, TT}
    von_karman_constant :: FT
    momentum_roughness :: FT
    scalar_reference_height :: FT
    minimum_wind_speed :: FT
    maximum_stable_zeta :: FT
    minimum_unstable_zeta :: FT
    surface_q :: Q
    virtual_potential_temperature :: θV
    standard_pressure :: SP
    thermodynamic_constants :: TC
    transfer_type :: TT
end

function GABLS3MOSTCoefficient(surface_q;
                               von_karman_constant=0.4,
                               momentum_roughness=0.15,
                               scalar_reference_height=0.25,
                               minimum_wind_speed=0.1,
                               maximum_stable_zeta=10,
                               minimum_unstable_zeta=-100)
    FT = eltype(surface_q)
    return GABLS3MOSTCoefficient(FT(von_karman_constant), FT(momentum_roughness),
        FT(scalar_reference_height), FT(minimum_wind_speed), FT(maximum_stable_zeta),
        FT(minimum_unstable_zeta), surface_q, nothing, nothing, nothing, nothing)
end

Adapt.adapt_structure(to, coefficient::GABLS3MOSTCoefficient) =
    GABLS3MOSTCoefficient(Adapt.adapt(to, coefficient.von_karman_constant),
        Adapt.adapt(to, coefficient.momentum_roughness),
        Adapt.adapt(to, coefficient.scalar_reference_height),
        Adapt.adapt(to, coefficient.minimum_wind_speed),
        Adapt.adapt(to, coefficient.maximum_stable_zeta),
        Adapt.adapt(to, coefficient.minimum_unstable_zeta),
        Adapt.adapt(to, coefficient.surface_q),
        Adapt.adapt(to, coefficient.virtual_potential_temperature),
        Adapt.adapt(to, coefficient.standard_pressure),
        Adapt.adapt(to, coefficient.thermodynamic_constants),
        coefficient.transfer_type)

@inline function unstable_momentum_psi(zeta)
    x = sqrt(sqrt(max(1 - 16zeta, eps(zeta))))
    return 2log((1 + x) / 2) + log((1 + x^2) / 2) - 2atan(x) + oftype(zeta, π / 2)
end

@inline unstable_scalar_psi(zeta) = 2log((1 + sqrt(max(1 - 16zeta, eps(zeta)))) / 2)
@inline momentum_psi(zeta) = ifelse(zeta >= 0, -5zeta, unstable_momentum_psi(zeta))
@inline scalar_psi(zeta) = ifelse(zeta >= 0, -5zeta, unstable_scalar_psi(zeta))

@inline function most_denominators(coefficient, height, zeta)
    z₀ₘ = coefficient.momentum_roughness
    zₛ = coefficient.scalar_reference_height
    Dₘ = log(height / z₀ₘ) - momentum_psi(zeta) + momentum_psi(zeta * z₀ₘ / height)
    Dₛ = log(height / zₛ) - scalar_psi(zeta) + scalar_psi(zeta * zₛ / height)
    return Dₘ, Dₛ
end

@inline function richardson_residual(coefficient, height, zeta, richardson)
    Dₘ, Dₛ = most_denominators(coefficient, height, zeta)
    return zeta * Dₛ / Dₘ^2 - richardson
end

@inline function solve_zeta(coefficient, height, richardson)
    stable = richardson >= 0
    lower = ifelse(stable, zero(richardson), coefficient.minimum_unstable_zeta)
    upper = ifelse(stable, coefficient.maximum_stable_zeta, zero(richardson))
    @inbounds for iteration in 1:28
        middle = (lower + upper) / 2
        residual = richardson_residual(coefficient, height, middle, richardson)
        move_lower = residual < 0
        lower = ifelse(move_lower, middle, lower)
        upper = ifelse(move_lower, upper, middle)
    end
    return (lower + upper) / 2
end

@inline function most_state(i, j, k, grid, side, coefficient, fields, Tˢ, pˢ)
    height = wall_distance(i, j, k, grid, side)
    speed² = tangential_speed²(i, j, k, grid, side, nothing, fields)
    speed = sqrt(max(speed², coefficient.minimum_wind_speed^2))
    θᵛ = coefficient.virtual_potential_temperature(i, j, k, grid, fields)
    qˢ = @inbounds coefficient.surface_q[i, j, 1]
    θᵛˢ = virtual_potential_temperature(Tˢ, pˢ, coefficient.standard_pressure,
        MoistureMassFractions(qˢ), coefficient.thermodynamic_constants)
    gravity = coefficient.thermodynamic_constants.gravitational_acceleration
    θᵛ_mean = (θᵛ + θᵛˢ) / 2
    richardson = gravity * height * (θᵛ - θᵛˢ) / (θᵛ_mean * speed^2)
    zeta = solve_zeta(coefficient, height, richardson)
    Dₘ, Dₛ = most_denominators(coefficient, height, zeta)
    return (; richardson, zeta, Dₘ, Dₛ, speed)
end

@inline function (coefficient::GABLS3MOSTCoefficient)(i, j, k, grid, side, U, Tˢ, fields, pˢ)
    state = most_state(i, j, k, grid, side, coefficient, fields, Tˢ, pˢ)
    κ² = coefficient.von_karman_constant^2
    momentum = κ² / state.Dₘ^2
    scalar = κ² / (state.Dₘ * state.Dₛ)
    return ifelse(coefficient.transfer_type === Val(:scalar), scalar, momentum)
end

function BCS.materialize_coefficient(coefficient::GABLS3MOSTCoefficient, grid, dynamics,
                                     microphysics, constants, transfer_type)
    pressure = standard_pressure(dynamics)
    moisture_name = Val(moisture_specific_name(microphysics))
    θᵛ = NearWallVirtualPotentialTemperature(microphysics, moisture_name, pressure, constants)
    return GABLS3MOSTCoefficient(coefficient.von_karman_constant,
        coefficient.momentum_roughness, coefficient.scalar_reference_height,
        coefficient.minimum_wind_speed, coefficient.maximum_stable_zeta,
        coefficient.minimum_unstable_zeta, coefficient.surface_q, θᵛ,
        pressure, constants, transfer_type)
end

@inline function BCS.bulk_coefficient(i, j, k, grid, side,
                                      coefficient::GABLS3MOSTCoefficient,
                                      fields, Tˢ, ::Nothing, pˢ)
    U = sqrt(tangential_speed²(i, j, k, grid, side, nothing, fields))
    return coefficient(i, j, k, grid, side, U, Tˢ, fields, pˢ)
end

BCS.coefficient_surface(::GABLS3MOSTCoefficient) = PlanarLiquidSurface()
BCS.coefficient_moisture_availability(::GABLS3MOSTCoefficient) = 1
BCS.resolve_moisture_availability(::Nothing, ::GABLS3MOSTCoefficient) = 1
BCS.resolve_moisture_availability(beta::Number, ::GABLS3MOSTCoefficient) = beta

function update_surface_humidity!(surface_q::Field, tables, time)
    set!(surface_q, tables.surface_q(time))
    return nothing
end

@inline most_diagnostics(i, j, k, grid, side, coefficient, fields, Tˢ, pˢ) =
    most_state(i, j, k, grid, side, coefficient, fields, Tˢ, pˢ)

end
