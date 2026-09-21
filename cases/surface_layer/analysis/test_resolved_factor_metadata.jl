using Test, JLD2
include("SurfaceLayerScientificExport.jl")
using .SurfaceLayerScientificExport: verify_raw_factor_metadata
@testset "factor identity in physical raw outputs" begin
    mktempdir() do directory
        id = "factor_fixture"
        for kind in ("initial", "statistics", "series")
            jldopen(joinpath(directory, "$(id)_diag_$(kind).jld2"), "w") do file
                file["metadata/resolved_flux_factor"] = 2f0
            end
        end
        @test isnothing(verify_raw_factor_metadata(directory, id, 2.0))
        @test_throws ErrorException verify_raw_factor_metadata(directory, id, 1.0)
        jldopen(joinpath(directory, "$(id)_diag_statistics.jld2"), "w") do file
            file["metadata/unrelated"] = true
        end
        @test_throws ErrorException verify_raw_factor_metadata(directory, id, 2.0)
    end
end
