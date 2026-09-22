using Test
using JLD2
using Oceananigans

ENV["GABLS1_SLD_ARCH"] = get(ENV, "GABLS1_SLD_ARCH", "cpu")
ENV["GABLS1_SLD_CLOSURE"] = "surface_layer"
ENV["GABLS1_SLD_NX"] = "32"
ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS1_SLD_SUPPORT"] = "1"
ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = "1.0"
ENV["GABLS1_SLD_RESOLVED_TRANSPORT"] = "scheme_native"
ENV["GABLS1_SLD_SEED"] = "123"
ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
ENV["GABLS1_SLD_STOP_SECONDS"] = get(ENV, "GABLS1_SLD_STOP_SECONDS", "120")

include(joinpath(@__DIR__, "..", "gabls1", "gabls1_case.jl"))

run_directory = abspath(ARGS[1])
ispath(run_directory) && !isempty(readdir(run_directory)) &&
    error("refusing to overwrite a nonempty gate directory")
setup = build_simulation(; run_directory)
@testset "matched GABLS1 native-flux gate" begin
    @test setup.case_id == "gabls1_n032_weno9_surface_layer_t300_s1_rf1p0_native"
    @test setup.settings.theta_initial_sha256 ==
          "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
    @test setup.model.closure.resolved_transport isa Val{:scheme_native}
    @test setup.model.closure.resolved_flux_factor == 1
    @test setup.model.closure.support == 1
    @test setup.model.closure.filter_timescale == 300

    diagnostics = setup.simulation.output_writers[:gabls1_surface_layer_series]
    @test diagnostics !== nothing
    run!(setup.simulation)
    @test time(setup.simulation) >= parse(Float64, ENV["GABLS1_SLD_STOP_SECONDS"])
    fields = setup.model.closure_fields
    @test all(isfinite, Array(interior(fields.Kᵘ)))
    @test all(isfinite, Array(interior(fields.numerical_u_correction[1])))
    @test all(isfinite, Array(interior(fields.numerical_scalar_correction.ρθ[1])))
    series_path = joinpath(run_directory, "$(setup.case_id)_diag_series.jld2")
    @test isfile(series_path)
    jldopen(series_path) do file
        @test file["metadata/resolved_transport"] == "scheme_native"
        series_names = keys(file["timeseries"])
        for name in ("surface_layer_face1_scheme_u_flux",
                     "surface_layer_face1_numerical_u_correction",
                     "surface_layer_face1_reconstructed_u_flux",
                     "surface_layer_face1_ρθ_scheme_flux",
                     "surface_layer_face1_ρθ_numerical_correction",
                     "surface_layer_face1_ρθ_reconstructed_flux")
            @test name in series_names
        end
    end
    if parse(Float64, ENV["GABLS1_SLD_STOP_SECONDS"]) >= 1800
        @test isfile(joinpath(run_directory, "$(setup.case_id)_diag_statistics.jld2"))
    end
end
