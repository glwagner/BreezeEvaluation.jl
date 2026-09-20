using Test
include("GABLS3Forcing.jl")
using .GABLS3Forcing

@testset "GABLS3 published forcing and contract" begin
    d = load_case(joinpath(@__DIR__, "inputs.toml"))
    @test surface_state(d, 0) == (; pressure=102210, theta=291.28, q=0.0100)
    @test surface_state(d, 32400) == (; pressure=102220, theta=298.45, q=0.0129)
    @test surface_state(d, 1800).theta ≈ 290.81
    @test surface_state(d, 1800).pressure ≈ 102205
    @test geostrophic_wind(d, 0, 0) == (; u=-6.125, v=4.5)
    @test geostrophic_wind(d, 800, 10800) == (; u=-3.8, v=3.5)
    @test geostrophic_wind(d, 0, 32400) == (; u=-5.75, v=3.5)
    @test advection(d, 0, 0) == (; u=0.0, v=0.0, theta=-0.0, q=0.0)
    @test advection(d, 100, 0).u == 2.5e-4
    @test advection(d, 800, 0).u == 5e-4
    for z in (200, 800)
        @test advection(d, z, prevfloat(10800.0)).u == 5e-4
        @test advection(d, z, 10800).u == 0
        @test advection(d, z, prevfloat(3600.0)).theta == -2.5e-5
        @test advection(d, z, 3600).theta == 7.5e-5
        @test advection(d, z, prevfloat(21600.0)).theta == 7.5e-5
        @test advection(d, z, 21600).theta == 0
        @test advection(d, z, prevfloat(7200.0)).q == 0
        @test advection(d, z, 7200).q == -8e-8
        @test advection(d, z, prevfloat(18000.0)).q == -8e-8
        @test advection(d, z, 18000).q == 0
    end
    @test initial_state(d, 140).u == -11.48
    @test initial_state(d, 140).q == 0.0092
    @test initial_state(d, 15).theta ≈ (292.72 + 293.02) / 2
    @test_throws DomainError initial_state(d, 6.25)
    @test_throws DomainError surface_state(d, -1)
    @test_throws DomainError surface_state(d, 32401)
    @test_throws DomainError geostrophic_wind(d, 801, 0)
    @test_throws DomainError linear_value([0,1], [0,1], NaN)
    @test_throws ErrorException preflight(d)
    @test scalar_flux(0.2, 0.4, 291., 292., 3.125, Inf, stable_psi) ≈ -0.08 / log(12.5)
    @test scalar_flux(0.2, 0.4, 291., 292., 3.125, 10., stable_psi) > -0.08 / log(12.5)
    @test_throws DomainError scalar_flux(0.2, 0.4, 291., 292., 3.125, -10., stable_psi)
    @test_throws DomainError scalar_flux(0.2, 0.4, 291., 292., 0.15, 10., stable_psi)
    @test forcing_events() == (3600, 7200, 10800, 18000, 21600)
    # Full production-domain coverage; catches accidental extrapolation and absentforcing.
    for t in 0:300:32400, z in 0:12.5:800
        @test all(isfinite, values(geostrophic_wind(d, z, t)))
        @test all(isfinite, values(advection(d, z, t)))
    end
end
