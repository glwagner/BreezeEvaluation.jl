using Test
using Breeze
using Oceananigans
using Oceananigans.Grids: Center, Face
using Oceananigans.Operators: ℑxzᶠᵃᶠ, ℑyzᵃᶠᶠ, ℑzᵃᵃᶠ
using Oceananigans.TimeSteppers: time_discretization
using Oceananigans.TurbulenceClosures: ExplicitTimeDiscretization,
                                        VerticallyImplicitTimeDiscretization,
                                        ivd_diffusivity

include(joinpath(@__DIR__, "gabls1", "gabls1_case.jl"))

@testset "physical implicit-SLD SGS diagnostics" begin
    grid = RectilinearGrid(CPU(), Float32; size=(4, 4, 4),
        x=(0, 40), y=(0, 40), z=(0, 40),
        topology=(Periodic, Periodic, Bounded), halo=(3, 3, 3))
    @test eltype(grid) === Float32
    u = XFaceField(grid)
    v = YFaceField(grid)
    w = ZFaceField(grid)
    θ = CenterField(grid)
    q = CenterField(grid)
    ρ = CenterField(grid)
    Kᵘ = ZFaceField(grid)
    Kθ = ZFaceField(grid)
    Kq = ZFaceField(grid)

    set!(u, (x, y, z) -> Float32(0.1) * z)
    set!(v, (x, y, z) -> Float32(-0.04) * z)
    set!(w, 0)
    set!(θ, (x, y, z) -> Float32(260) + Float32(0.125) * z)
    set!(q, (x, y, z) -> z / Float32(8192))
    set!(ρ, (x, y, z) -> Float32(1.2) - Float32(0.001) * z)
    set!(Kᵘ, (x, y, z) -> 0 < z <= 20 ? Float32(2.5) : 0f0)
    set!(Kθ, (x, y, z) -> 0 < z <= 20 ? Float32(1.25) : 0f0)
    set!(Kq, (x, y, z) -> 0 < z <= 20 ? Float32(0.75) : 0f0)

    closure = Breeze.SurfaceLayerDiffusivity(Float32)
    closure_fields = (; Kᵘ,
        tupled_tracer_diffusivities=(; ρθ=Kθ, ρqᵛ=Kq))
    model_fields = (; u, v, w)
    clock = (; time=0f0)
    i, j, k = 2, 2, 2

    @test time_discretization(closure) isa VerticallyImplicitTimeDiscretization
    @test GABLSDiagnostics.diagnostic_sgs_discretization(closure) isa
          ExplicitTimeDiscretization
    @test ivd_diffusivity(i, j, k, grid, Face(), Center(), Face(),
                         closure, closure_fields, nothing, clock, model_fields) ≈ 2.5f0
    @test ivd_diffusivity(i, j, k, grid, Center(), Face(), Face(),
                         closure, closure_fields, nothing, clock, model_fields) ≈ 2.5f0
    @test ivd_diffusivity(i, j, k, grid, Center(), Center(), Face(),
                         closure, closure_fields, Val(1), clock, model_fields) ≈ 1.25f0
    @test ivd_diffusivity(i, j, k, grid, Center(), Center(), Face(),
                         closure, closure_fields, Val(2), clock, model_fields) ≈ 0.75f0

    u_flux = GABLSDiagnostics.u_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, clock, model_fields)
    v_flux = GABLSDiagnostics.v_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, clock, model_fields)
    θ_flux = GABLSDiagnostics.scalar_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, Val(1), θ,
        clock, model_fields, nothing)
    q_flux = GABLSDiagnostics.scalar_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, Val(2), q,
        clock, model_fields, nothing)

    @test u_flux ≈ -2.5f0 * 0.1f0 atol=2eps(Float32)
    @test v_flux ≈ -2.5f0 * -0.04f0 atol=2eps(Float32)
    @test θ_flux ≈ -1.25f0 * 0.125f0 atol=2eps(Float32)
    @test q_flux ≈ -0.75f0 / 8192f0 atol=2eps(Float32)

    # Breeze's density-weighted wrappers use exactly the same native-face density
    # interpolation in numerator and denominator of the exported kinematic flux.
    explicit = ExplicitTimeDiscretization()
    @test u_flux ≈ Breeze.TurbulenceClosures.𝒯_uz(
        i, j, k, grid, ρ, explicit, closure, closure_fields, clock,
        model_fields, nothing) / ℑxzᶠᵃᶠ(i, j, k, grid, ρ)
    @test v_flux ≈ Breeze.TurbulenceClosures.𝒯_vz(
        i, j, k, grid, ρ, explicit, closure, closure_fields, clock,
        model_fields, nothing) / ℑyzᵃᶠᶠ(i, j, k, grid, ρ)
    @test θ_flux ≈ Breeze.TurbulenceClosures.Jᶜz(
        i, j, k, grid, ρ, explicit, closure, closure_fields, Val(1), θ,
        clock, model_fields, nothing) / ℑzᵃᵃᶠ(i, j, k, grid, ρ)

    # The old diagnostic queried this tendency-only path, which intentionally omits
    # the vertically implicit interior flux. Verify the regression is detectable.
    implicit = time_discretization(closure)
    @test Breeze.TurbulenceClosures.𝒯_uz(
        i, j, k, grid, ρ, implicit, closure, closure_fields, clock,
        model_fields, nothing) == 0
    @test Breeze.TurbulenceClosures.Jᶜz(
        i, j, k, grid, ρ, implicit, closure, closure_fields, Val(1), θ,
        clock, model_fields, nothing) == 0

    # Nonuniform coefficients distinguish native F-C-F / C-F-F momentum
    # interpolation from a mistaken direct C-C-F coefficient lookup.
    set!(Kᵘ, (x, y, z) -> 0 < z <= 20 ?
        Float32(2.5) + Float32(0.01) * x + Float32(0.02) * y : 0f0)
    set!(Kθ, (x, y, z) -> 0 < z <= 20 ?
        Float32(1.25) + Float32(0.01) * x : 0f0)
    set!(Kq, (x, y, z) -> 0 < z <= 20 ?
        Float32(0.75) + Float32(0.01) * y : 0f0)
    νu = ivd_diffusivity(i, j, k, grid, Face(), Center(), Face(),
                        closure, closure_fields, nothing, clock, model_fields)
    νv = ivd_diffusivity(i, j, k, grid, Center(), Face(), Face(),
                        closure, closure_fields, nothing, clock, model_fields)
    κθ = ivd_diffusivity(i, j, k, grid, Center(), Center(), Face(),
                        closure, closure_fields, Val(1), clock, model_fields)
    κq = ivd_diffusivity(i, j, k, grid, Center(), Center(), Face(),
                        closure, closure_fields, Val(2), clock, model_fields)
    @test νu != Kᵘ[i, j, k]
    @test νv != Kᵘ[i, j, k]
    @test GABLSDiagnostics.u_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, clock, model_fields) ≈
        -νu * 0.1f0 atol=2eps(Float32)
    @test GABLSDiagnostics.v_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, clock, model_fields) ≈
        -νv * -0.04f0 atol=2eps(Float32)
    @test GABLSDiagnostics.scalar_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, Val(1), θ,
        clock, model_fields, nothing) ≈ -κθ * 0.125f0 atol=2eps(Float32)
    @test GABLSDiagnostics.scalar_sgs_flux(
        i, j, k, grid, ρ, closure, closure_fields, Val(2), q,
        clock, model_fields, nothing) ≈ -κq / 8192f0 atol=2eps(Float32)

    for face in (2, 3)
        viscosity_u = ivd_diffusivity(i, j, face, grid, Face(), Center(), Face(),
                                     closure, closure_fields, nothing, clock, model_fields)
        viscosity_v = ivd_diffusivity(i, j, face, grid, Center(), Face(), Face(),
                                     closure, closure_fields, nothing, clock, model_fields)
        diffusivity_θ = ivd_diffusivity(i, j, face, grid, Center(), Center(), Face(),
                                       closure, closure_fields, Val(1), clock, model_fields)
        diffusivity_q = ivd_diffusivity(i, j, face, grid, Center(), Center(), Face(),
                                       closure, closure_fields, Val(2), clock, model_fields)
        @test viscosity_u > 0
        @test viscosity_v > 0
        @test diffusivity_θ > 0
        @test diffusivity_q > 0
        @test GABLSDiagnostics.u_sgs_flux(
            i, j, face, grid, ρ, closure, closure_fields, clock, model_fields) ≈
            -viscosity_u * 0.1f0 atol=2eps(Float32)
        @test GABLSDiagnostics.v_sgs_flux(
            i, j, face, grid, ρ, closure, closure_fields, clock, model_fields) ≈
            -viscosity_v * -0.04f0 atol=2eps(Float32)
        @test GABLSDiagnostics.scalar_sgs_flux(
            i, j, face, grid, ρ, closure, closure_fields, Val(1), θ,
            clock, model_fields, nothing) ≈ -diffusivity_θ * 0.125f0 atol=2eps(Float32)
        @test GABLSDiagnostics.scalar_sgs_flux(
            i, j, face, grid, ρ, closure, closure_fields, Val(2), q,
            clock, model_fields, nothing) ≈ -diffusivity_q / 8192f0 atol=2eps(Float32)
    end

    # Face four lies outside the one/two-face SLD support and must have zero SGS flux.
    @test ivd_diffusivity(i, j, 4, grid, Face(), Center(), Face(),
                         closure, closure_fields, nothing, clock, model_fields) == 0
    @test GABLSDiagnostics.u_sgs_flux(
        i, j, 4, grid, ρ, closure, closure_fields, clock, model_fields) == 0
    @test GABLSDiagnostics.v_sgs_flux(
        i, j, 4, grid, ρ, closure, closure_fields, clock, model_fields) == 0
    @test GABLSDiagnostics.scalar_sgs_flux(
        i, j, 4, grid, ρ, closure, closure_fields, Val(1), θ,
        clock, model_fields, nothing) == 0
    @test GABLSDiagnostics.scalar_sgs_flux(
        i, j, 4, grid, ρ, closure, closure_fields, Val(2), q,
        clock, model_fields, nothing) == 0

    # No-closure profiles must remain identically zero independently of density.
    @test GABLSDiagnostics.u_sgs_flux(i, j, k, grid, ρ, nothing, nothing,
                                       clock, model_fields) == 0
    @test GABLSDiagnostics.v_sgs_flux(i, j, k, grid, ρ, nothing, nothing,
                                       clock, model_fields) == 0
    @test GABLSDiagnostics.scalar_sgs_flux(i, j, k, grid, ρ, nothing, nothing,
                                            Val(1), θ, clock, model_fields,
                                            nothing) == 0
end
