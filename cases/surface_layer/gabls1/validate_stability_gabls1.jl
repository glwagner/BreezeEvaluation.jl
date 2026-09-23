using Test
using JLD2
using Oceananigans
using Printf

ENV["GABLS1_SLD_ARCH"] = get(ENV, "GABLS1_SLD_ARCH", "cpu")
ENV["GABLS1_SLD_NX"] = "32"
ENV["GABLS1_SLD_CLOSURE"] = "surface_layer"
ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS1_WALL_FILTER_SECONDS"] = "300"
ENV["GABLS1_SLD_SUPPORT"] = "1"
ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = "1.0"
ENV["GABLS1_SLD_RESOLVED_TRANSPORT"] = "scheme_native"
ENV["GABLS1_SLD_STABILITY_STRENGTH"] = "1.0"
ENV["GABLS1_SLD_SEED"] = "123"
ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
ENV["GABLS1_SLD_STOP_SECONDS"] = get(ENV, "GABLS1_SLD_STOP_SECONDS", "1800")

include(joinpath(@__DIR__, "gabls1_case.jl"))

length(ARGS) == 1 || error("usage: validate_stability_gabls1.jl GATE_ROOT")
gate_root = abspath(ARGS[1])
ispath(gate_root) && !isempty(readdir(gate_root)) &&
    error("refusing to overwrite a nonempty gate directory")
mkpath(gate_root)

run_directory = joinpath(gate_root, "surface_layer_stab1p0")
setup = build_simulation(; run_directory)
expected_id = "gabls1_n032_weno9_surface_layer_t300_s1_rf1p0_native_stab1p0_wallf300"
stop_seconds = parse(Float64, ENV["GABLS1_SLD_STOP_SECONDS"])

@testset "λ=1 stability-corrected SLD GABLS1 gate" begin
    model = setup.model
    closure = model.closure
    @test setup.case_id == expected_id
    @test setup.settings.theta_initial_sha256 ==
          "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
    @test setup.settings.wall_filter_seconds == 300
    @test setup.settings.stability_strength == 1
    @test closure.resolved_transport isa Val{:scheme_native}
    @test closure.stability_strength == 1
    @test closure.momentum_stability_parameter == 4.8f0
    @test closure.scalar_stability_parameter == 7.8f0
    @test closure.resolved_flux_factor == 1
    @test closure.support == 1
    @test haskey(setup.simulation.output_writers, :wall_filter)
    @test haskey(setup.simulation.output_writers, :sld_stability)

    run!(setup.simulation)
    @test time(setup.simulation) >= stop_seconds
    for velocity in model.velocities
        @test all(isfinite, Array(interior(velocity)))
    end
    fields = model.closure_fields
    inverse_length = Array(interior(fields.inverse_obukhov_length))
    state = Array(interior(fields.stability_state))
    φᵐ = Array(interior(fields.momentum_stability_function[1]))
    φʰ = Array(interior(fields.scalar_stability_function[1]))
    viscosity = Array(interior(fields.Kᵘ))
    @test all(isfinite, inverse_length)
    @test all(isfinite, viscosity)
    @test all(>=(1), φᵐ)
    @test all(>=(1), φʰ)
    @test all(in((-1f0, 0f0, 1f0)), state)
    # Face 1 is 12.5 m above the wall on this grid.
    ζ = 12.5f0 .* max.(0, inverse_length)
    @test φᵐ ≈ 1 .+ 4.8f0 .* ζ rtol=1f-5
    @test φʰ ≈ 1 .+ 7.8f0 .* ζ rtol=1f-5
    @test count(==(1), state) > 0
    # Only the first interior face carries SLD coefficients.
    @test all(iszero, viscosity[:, :, [1; 3:end]])

    stable_fraction = count(==(1), state) / length(state)
    upward_fraction = count(==(-1), state) / length(state)
    stable_mean_L = inv(sum(inverse_length[state .== 1]) / max(1, count(==(1), state)))
    @info @sprintf("GATE_STABILITY t=%.0f s stable=%.4f upward=%.4f neutral=%.4f mean(φm)=%.4f mean(φh)=%.4f L(mean 1/L, stable)=%.1f m",
                   time(setup.simulation), stable_fraction, upward_fraction,
                   1 - stable_fraction - upward_fraction,
                   sum(φᵐ) / length(φᵐ), sum(φʰ) / length(φʰ), stable_mean_L)

    for (writer, names) in (("wall_filter", ("filtered_u", "filtered_v", "filtered_Δθ")),
                            ("sld_stability", ("inverse_obukhov_length", "stability_state",
                                               "face1_momentum_stability_function",
                                               "face1_scalar_stability_function",
                                               "filtered_surface_theta_flux")))
        path = joinpath(run_directory, "$(setup.case_id)_$(writer).jld2")
        @test isfile(path)
        jldopen(path) do file
            for name in names
                group = file["timeseries/$name"]
                record_ids = sort(parse.(Int, filter(x -> x != "serialized", collect(keys(group)))))
                @test length(record_ids) >= 2
                @test all(isfinite, Array(group[string(last(record_ids))]))
            end
        end
    end

    series = joinpath(run_directory, "$(setup.case_id)_diag_series.jld2")
    @test isfile(series)
    jldopen(series) do file
        @test file["metadata/surface_layer_stability_strength"] == 1
        for name in ("surface_layer_inverse_obukhov_length",
                     "surface_layer_upward_flux_column_fraction",
                     "surface_layer_face1_momentum_stability_function")
            @test haskey(file, "timeseries/$name")
        end
    end
end
