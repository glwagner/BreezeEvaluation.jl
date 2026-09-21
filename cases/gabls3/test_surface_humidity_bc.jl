using Test
using Breeze
using Oceananigans
using Oceananigans.BoundaryConditions: Bottom

include(joinpath(@__DIR__, "runner", "gabls3_case.jl"))

ENV["GABLS3_ARCH"] = "cpu"
ENV["GABLS3_NX"] = "64"
ENV["GABLS3_SCHEME"] = "weno9"
ENV["GABLS3_CLOSURE"] = "none"
ENV["GABLS3_DIAGNOSTICS"] = "0"
ENV["GABLS3_STOP_SECONDS"] = "1"

@testset "Actual materialized GABLS3 surface vapor BC" begin
    setup = build_simulation(; run_directory=mktempdir())
    model = setup.model
    grid = model.grid
    constants = model.thermodynamic_constants
    condition = model.moisture_density.boundary_conditions.bottom.condition
    @test condition.surface_relative_humidity isa SurfaceRelativeHumidity
    fields = Breeze.BoundaryConditions.surface_layer_state(model)
    model_fields = Oceananigans.fields(model)
    dynamics_fields = Breeze.AtmosphereModels.dynamics_thermodynamic_fields(model.dynamics)
    side = Bottom()
    surface = condition.surface_relative_humidity

    @test Breeze.AtmosphereModels.moisture_prognostic_name(model.microphysics) == :ρqᵉ
    @test Breeze.AtmosphereModels.moisture_specific_name(model.microphysics) == :qᵉ
    @test model.forcing.ρqᵉ !== nothing

    for t in (0.0, 10800.0, 11100.0, 12600.0, 14400.0,
              21600.0, 25200.0, 32400.0),
        (i, j) in ((1, 1), (32, 32))
        model.clock.time = t
        update_surface_humidity!(setup.surface_q, setup.inputs, t)
        T = Breeze.BoundaryConditions.wall_value(i, j, grid, side,
                                                   condition.surface_temperature, model.clock)
        relative_humidity = Breeze.BoundaryConditions.wall_value(
            i, j, grid, side, surface, model.clock)
        p_wall = Breeze.BoundaryConditions.wall_air_pressure(
            i, j, 1, grid, side, nothing, fields, constants)
        p_from_surface_fields = Breeze.BoundaryConditions.wall_air_pressure(
            i, j, 1, grid, side, nothing,
            (; p=surface.reference_pressure, ρ=surface.reference_density), constants)
        ρ_wall = Breeze.Thermodynamics.surface_density(p_wall, T, constants)
        q_sat = Breeze.Thermodynamics.saturation_specific_humidity(
            T, ρ_wall, constants, condition.surface)
        q_wall = relative_humidity * q_sat
        q_table = setup.inputs.surface_q(t)
        q_air = fields.qᵛ[i, j, 1]
        coefficient = Breeze.BoundaryConditions.bulk_coefficient(
            i, j, 1, grid, side, condition.coefficient, fields, T,
            condition.filtered_velocities, p_wall)
        speed_squared = Breeze.BoundaryConditions.wall_wind_speed²(
            i, j, 1, grid, side, nothing, fields, condition.filtered_velocities)
        speed = sqrt(speed_squared + condition.gustiness^2)
        scale = Breeze.BoundaryConditions.outward_flux_sign(side) * ρ_wall *
                coefficient * speed * condition.moisture_availability
        actual_flux = Oceananigans.BoundaryConditions.getbc(
            condition, i, j, grid, model.clock, model_fields, dynamics_fields)
        expected_flux = scale * (q_air - q_table)
        tolerance_q = 2 * max(abs(nextfloat(q_table) - q_table),
                              abs(q_table - prevfloat(q_table)))
        tolerance_flux = abs(scale) * tolerance_q + 4eps(Float32) * abs(expected_flux)

        @test p_wall === p_from_surface_fields
        @test p_wall > fields.p[i, j, 1]
        @test isfinite(ρ_wall) && isfinite(q_sat) && isfinite(actual_flux)
        @test 0 <= relative_humidity <= 1
        @test abs(q_wall - q_table) <= tolerance_q
        @test abs(actual_flux - expected_flux) <= tolerance_flux
        println((; t, i, j, p_center=fields.p[i, j, 1],
                 rho_center=fields.ρ[i, j, 1], p_wall, rho_wall=ρ_wall,
                 surface_temperature=T, relative_humidity, q_sat,
                 q_before=q_table, q_after=q_wall, q_air, actual_flux,
                 intended_flux=expected_flux, q_error=q_wall - q_table))
    end

    # The published q tendency is specific humidity per second. Breeze routes the
    # qᵗ interface key to prognostic ρqᵉ and supplies the density factor once.
    specific_forcing = model.forcing.ρqᵉ
    @test specific_forcing isa Breeze.Forcings.SpecificForcing
    model.clock.time = 7200.0
    k = 17 # z = 206.25 m, above the 200 m forcing-transition height.
    z = collect(znodes(grid, Center(), Center(), Center()))[k]
    density = specific_forcing.density[1, 1, k]
    actual_density_tendency = specific_forcing(1, 1, k, grid, model.clock, model_fields)
    expected_density_tendency = density * advective_q_tendency(nothing, z, model.clock.time)
    @test z > 200
    @test actual_density_tendency ≈ expected_density_tendency rtol=4eps(Float32)
    @test Breeze.AtmosphereModels.specific_prognostic_moisture(model)[1, 1, k] ≈
          model.moisture_density[1, 1, k] / density rtol=4eps(Float32)
    println((; z, density, specific_q_tendency=advective_q_tendency(nothing, z, model.clock.time),
             actual_density_tendency, expected_density_tendency))
end
