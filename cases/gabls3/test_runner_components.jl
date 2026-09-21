using Test
using Breeze
using Oceananigans

include(joinpath(@__DIR__, "preparation", "GABLS3Forcing.jl"))
include(joinpath(@__DIR__, "forcing", "GABLS3ModelForcing.jl"))
include(joinpath(@__DIR__, "diagnostics", "GABLS3Diagnostics.jl"))

using .GABLS3Forcing
using .GABLS3ModelForcing
using .GABLS3Diagnostics

data = GABLS3Forcing.load_case(joinpath(@__DIR__, "preparation", "inputs.toml"))
inputs = GABLS3InputTables(data, Float32)

@testset "GABLS3 runner inputs" begin
    @test GABLS3ModelForcing.surface_state(inputs, 0f0) ==
          (pressure=102210f0, theta=291.28f0, q=0.01f0)
    @test initial_u(inputs, 10f0) ≈ -3.35f0
    @test initial_v(inputs, 10f0) ≈ -0.04f0
    @test initial_u(inputs, inputs.momentum_roughness) == 0
    @test initial_theta(inputs, 0.25f0) ≈ inputs.surface_theta(0)
    @test initial_q(inputs, 0.25f0) ≈ inputs.surface_q(0)
    @test initial_pressure(inputs, 0.25f0) ≈ inputs.surface_pressure(0)
    @test initial_theta(inputs, 10f0) ≈ 292.72f0
    @test initial_q(inputs, 10f0) ≈ 0.0098f0
    @test initial_pressure(inputs, 10f0) ≈ 102091f0
    @test initial_theta(inputs, 6.25f0) isa Float32
end

@testset "Time-varying moist Obukhov formula" begin
    ustar = 0.3f0
    wtheta = -0.02f0
    wq = 1f-5
    kappa = 0.4f0
    gravity = 9.81f0
    for time in (0f0, 21600f0, 28800f0)
        state = GABLS3ModelForcing.surface_state(inputs, time)
        delta = 0.6078f0
        virtual_flux = (1 + delta * state.q) * wtheta + delta * state.theta * wq
        expected = -ustar^3 * state.theta * (1 + delta * state.q) /
                   (kappa * gravity * virtual_flux)
        actual = GABLS3Diagnostics.surface_moist_obukhov_value(
            ustar, wtheta, wq, inputs, time, kappa, gravity)
        @test actual ≈ expected rtol=2f-6
    end
    night = GABLS3Diagnostics.surface_moist_obukhov_value(
        ustar, wtheta, wq, inputs, 0f0, kappa, gravity)
    morning = GABLS3Diagnostics.surface_moist_obukhov_value(
        ustar, wtheta, wq, inputs, 28800f0, kappa, gravity)
    @test night != morning
    @test GABLS3Diagnostics.surface_moist_obukhov_value(
        ustar, 0f0, 0f0, inputs, 0f0, kappa, gravity) == 0
    @test GABLS3Diagnostics.surface_moist_obukhov_valid_value(
        0f0, 0f0, inputs, 0f0, kappa, gravity) == 0
    @test GABLS3Diagnostics.surface_moist_obukhov_valid_value(
        nextfloat(0f0), 0f0, inputs, 0f0, kappa, gravity) == 0
    @test GABLS3Diagnostics.surface_moist_obukhov_valid_value(
        wtheta, wq, inputs, 0f0, kappa, gravity) == 1
end

@testset "Stage-time forcing events" begin
    z = 200f0
    @test advective_theta_tendency(inputs, z, prevfloat(3600f0)) < 0
    @test advective_theta_tendency(inputs, z, 3600f0) > 0
    @test advective_q_tendency(inputs, z, prevfloat(7200f0)) == 0
    @test advective_q_tendency(inputs, z, 7200f0) < 0
    @test advective_u_tendency(inputs, z, prevfloat(10800f0)) > 0
    @test advective_u_tendency(inputs, z, 10800f0) == 0
    @test advective_q_tendency(inputs, z, 18000f0) == 0
    @test advective_theta_tendency(inputs, z, 21600f0) == 0
end

@testset "Table-free advective forcing preserves values and units" begin
    event_times = (3600f0, 7200f0, 10800f0, 18000f0, 21600f0)
    times = (0f0, 32400f0,
             (time for event in event_times for time in
              (prevfloat(event), event, nextfloat(event)))...)
    heights = (0f0, 5f0, 100f0, 200f0, 800f0)
    tendencies = (advective_u_tendency, advective_v_tendency,
                  advective_theta_tendency, advective_q_tendency)
    for tendency in tendencies, z in heights, time in times
        @test tendency(inputs, z, time) === tendency(nothing, z, time)
    end

    # u/v: m s⁻²; θ: K s⁻¹; qᵗ: kg kg⁻¹ s⁻¹. The event-side checks above
    # guard the discontinuities independently of these dimensional values.
    @test advective_u_tendency(nothing, 200f0, 0f0) ≈ 5e-4 atol=1e-12
    @test advective_v_tendency(nothing, 200f0, 0f0) == 0
    @test advective_theta_tendency(nothing, 200f0, 0f0) ≈ -2.5e-5 atol=1e-12
    @test advective_theta_tendency(nothing, 200f0, 3600f0) ≈ 7.5e-5 atol=1e-12
    @test advective_q_tendency(nothing, 200f0, 7200f0) ≈ -8e-8 atol=1e-12
    @test advective_u_tendency(nothing, 100f0, 0f0) ≈
          0.5 * advective_u_tendency(nothing, 200f0, 0f0) atol=1e-12
end

@testset "MOST branches and caps" begin
    grid = RectilinearGrid(CPU(); size=(2, 2, 2), x=(0, 20), y=(0, 20), z=(0, 20))
    surface_q = Field{Center, Center, Nothing}(grid)
    coefficient = GABLS3MOSTCoefficient(surface_q)
    height = 5f0
    @test GABLS3ModelForcing.solve_zeta(coefficient, height, 0f0) ≈ 0 atol=1f-5
    @test GABLS3ModelForcing.solve_zeta(coefficient, height, 0.05f0) > 0
    @test GABLS3ModelForcing.solve_zeta(coefficient, height, -0.05f0) < 0
    @test GABLS3ModelForcing.solve_zeta(coefficient, height, 100f0) ≈
          coefficient.maximum_stable_zeta rtol=1f-4
    @test GABLS3ModelForcing.momentum_psi(0.2f0) ≈ -1f0
    @test GABLS3ModelForcing.scalar_psi(-0.2f0) > 0
end
