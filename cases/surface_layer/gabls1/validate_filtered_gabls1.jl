using Test
using JLD2
using Oceananigans

ENV["GABLS1_SLD_ARCH"] = get(ENV, "GABLS1_SLD_ARCH", "cpu")
ENV["GABLS1_SLD_NX"] = "32"
ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS1_WALL_FILTER_SECONDS"] = "300"
ENV["GABLS1_SLD_SUPPORT"] = "1"
ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = "1.0"
ENV["GABLS1_SLD_SEED"] = "123"
ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
ENV["GABLS1_SLD_STOP_SECONDS"] = "600"

include(joinpath(@__DIR__, "gabls1_case.jl"))

length(ARGS) == 1 || error("usage: validate_filtered_gabls1.jl GATE_ROOT")
gate_root = abspath(ARGS[1])
ispath(gate_root) && !isempty(readdir(gate_root)) &&
    error("refusing to overwrite a nonempty gate directory")
mkpath(gate_root)

for closure_name in ("none", "surface_layer")
    ENV["GABLS1_SLD_CLOSURE"] = closure_name
    ENV["GABLS1_SLD_RESOLVED_TRANSPORT"] =
        closure_name == "none" ? "covariance" : "scheme_native"
    run_directory = joinpath(gate_root, closure_name)
    setup = build_simulation(; run_directory)
    expected_id = closure_name == "none" ?
        "gabls1_n032_weno9_control_wallf300" :
        "gabls1_n032_weno9_surface_layer_t300_s1_rf1p0_native_wallf300"

    @testset "filtered GABLS1 GPU gate: $closure_name" begin
        @test setup.case_id == expected_id
        @test setup.settings.theta_initial_sha256 ==
              "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
        @test setup.settings.wall_filter_seconds == 300
        @test haskey(setup.simulation.output_writers, :wall_filter)
        run!(setup.simulation)
        @test time(setup.simulation) >= 600
        @test all(isfinite, Array(interior(setup.model.velocities.u)))
        @test all(isfinite, Array(interior(setup.model.velocities.v)))
        @test all(isfinite, Array(interior(setup.model.velocities.w)))
        if closure_name == "surface_layer"
            @test setup.model.closure.resolved_transport isa Val{:scheme_native}
            @test all(isfinite, Array(interior(setup.model.closure_fields.Kᵘ)))
        end

        path = joinpath(run_directory, "$(setup.case_id)_wall_filter.jld2")
        @test isfile(path)
        jldopen(path) do file
            for name in ("filtered_u", "filtered_v", "filtered_Δθ")
                group = file["timeseries/$name"]
                record_ids = sort(parse.(Int, filter(x -> x != "serialized", collect(keys(group)))))
                @test length(record_ids) >= 2
                first_state = Array(group[string(first(record_ids))])
                last_state = Array(group[string(last(record_ids))])
                @test all(isfinite, first_state)
                @test all(isfinite, last_state)
                if name == "filtered_Δθ"
                    @test maximum(abs.(last_state .- first_state)) > 0
                end
            end
        end
    end
end
