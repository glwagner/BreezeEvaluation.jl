using Test
using JLD2
using Oceananigans
using Printf

length(ARGS) == 2 || error("usage: validate_stability_gamma2_n128.jl none|s1|s2 GATE_ROOT")
kind, gate_root = ARGS
kind in ("none", "s1", "s2") || error("unsupported gate case $kind")
is_sld = kind != "none"
support = kind == "s2" ? 2 : 1
ENV["GABLS1_SLD_ARCH"] = get(ENV, "GABLS1_SLD_ARCH", "gpu")
ENV["GABLS1_SLD_NX"] = "128"
ENV["GABLS1_SLD_CLOSURE"] = is_sld ? "surface_layer" : "none"
ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS1_WALL_FILTER_SECONDS"] = "300"
ENV["GABLS1_SLD_SUPPORT"] = string(support)
ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = "1.0"
ENV["GABLS1_SLD_RESOLVED_TRANSPORT"] = is_sld ? "scheme_native" : "covariance"
is_sld ? (ENV["GABLS1_SLD_STABILITY_STRENGTH"] = "2.0") :
         pop!(ENV, "GABLS1_SLD_STABILITY_STRENGTH", nothing)
ENV["GABLS1_SLD_SEED"] = "123"
ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
ENV["GABLS1_SLD_STOP_SECONDS"] = get(ENV, "GABLS1_SLD_STOP_SECONDS", "600")

include(joinpath(@__DIR__, "gabls1_case.jl"))

gate_root = abspath(gate_root)
ispath(gate_root) && !isempty(readdir(gate_root)) &&
    error("refusing to overwrite a nonempty gate directory")
mkpath(gate_root)
setup = build_simulation(; run_directory=gate_root)
expected_id = kind == "none" ? "gabls1_n128_weno9_control_wallf300" :
    "gabls1_n128_weno9_surface_layer_t300_s$(support)_rf1p0_native_stab2p0_wallf300"
stop_seconds = parse(Float64, ENV["GABLS1_SLD_STOP_SECONDS"])

@testset "n128 GABLS1 gamma2 $kind gate" begin
    @test setup.case_id == expected_id
    @test setup.settings.nx == 128
    @test setup.settings.spacing == 3.125
    @test setup.settings.theta_initial_sha256 ==
        "177e9b12560bf668690ecb0eb9aa57488c385d48f54fd2084218188d98bbc3c5"
    @test setup.settings.paired_coarse_theta_sha256 ==
        "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
    @test setup.settings.wall_filter_seconds == 300
    @test haskey(setup.simulation.output_writers, :wall_filter)
    if is_sld
        closure = setup.model.closure
        @test setup.settings.stability_strength == 2
        @test closure.stability_strength == 2
        @test closure.support == support
        @test closure.resolved_transport isa Val{:scheme_native}
        @test closure.resolved_flux_factor == 1
        @test haskey(setup.simulation.output_writers, :sld_stability)
    else
        @test isnothing(setup.model.closure)
        @test !haskey(setup.simulation.output_writers, :sld_stability)
    end

    run!(setup.simulation)
    @test time(setup.simulation) >= stop_seconds
    for velocity in setup.model.velocities
        @test all(isfinite, Array(interior(velocity)))
    end

    if is_sld
        fields = setup.model.closure_fields
        inverse_length = Array(interior(fields.inverse_obukhov_length))
        state = Array(interior(fields.stability_state))
        viscosity = Array(interior(fields.Kᵘ))
        @test all(isfinite, inverse_length)
        @test all(isfinite, viscosity)
        @test all(in((-1f0, 0f0, 1f0)), state)
        for slot in 1:support
            zface = 3.125f0 * slot
            φᵐ = Array(interior(fields.momentum_stability_function[slot]))
            φʰ = Array(interior(fields.scalar_stability_function[slot]))
            @test all(>=(1), φᵐ)
            @test all(>=(1), φʰ)
            ζ = zface .* max.(0, inverse_length)
            @test φᵐ ≈ 1 .+ 2f0 * 4.8f0 .* ζ rtol=1f-5
            @test φʰ ≈ 1 .+ 2f0 * 7.8f0 .* ζ rtol=1f-5
        end
        @test all(iszero, viscosity[:, :, [1; (support+2):size(viscosity, 3)]])
        @info @sprintf("N128_GATE_STABILITY kind=%s t=%.0f stable=%.4f mean(φm1)=%.4f", kind,
                       time(setup.simulation), count(==(1), state) / length(state),
                       sum(Array(interior(fields.momentum_stability_function[1]))) / length(state))
        stability_file = joinpath(gate_root, "$(expected_id)_sld_stability.jld2")
        @test isfile(stability_file)
        jldopen(stability_file) do file
            for name in ("inverse_obukhov_length", "stability_state",
                         "face1_momentum_stability_function", "face1_scalar_stability_function")
                @test haskey(file, "timeseries/$name")
            end
            if support == 2
                @test haskey(file, "timeseries/face2_momentum_stability_function")
                @test haskey(file, "timeseries/face2_scalar_stability_function")
            end
        end
    end
    wall_file = joinpath(gate_root, "$(expected_id)_wall_filter.jld2")
    @test isfile(wall_file)
    @test isfile(joinpath(gate_root, "$(expected_id)_diag_series.jld2"))
end
