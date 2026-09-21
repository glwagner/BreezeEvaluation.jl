using Test
using CairoMakie

include(joinpath(@__DIR__, "SurfaceLayerScientificPlots.jl"))
using .SurfaceLayerScientificPlots

@testset "native comparison windows and admission-only loading" begin
    times = [30600.0, 32400.0]
    profiles = [
        (time_s=time, z_m=height, variable="w_variance", value=value,
         location="Face", units="m^2 s^-2")
        for (time, values) in ((30600.0, (1.0, 2.0, 3.0)),
                               (32400.0, (3.0, 4.0, 5.0)))
        for (height, value) in zip((0.0, 12.5, 25.0), values)]
    fixture = (; manifest=Dict("case_id" => "synthetic_fixture"), profiles)
    mean_profile = comparison_profile(fixture, "w_variance", times)
    @test mean_profile.z_m == [0.0, 12.5, 25.0]
    @test mean_profile.value == [2.0, 3.0, 4.0]
    @test mean_profile.location == "Face"
    @test mean_profile.source_times_s == times
    @test_throws ErrorException comparison_profile(fixture, "w_variance", [32400.0, 34200.0])
    @test SurfaceLayerScientificPlots.comparison_times("GABLS1", :penultimate_hour) ==
        [27000.0, 28800.0]
    @test SurfaceLayerScientificPlots.comparison_times("GABLS3", :paper_03_04utc) ==
        collect(11100.0:300.0:14400.0)
    @test_throws ErrorException load_comparison_cases(String[])
    mktempdir() do directory
        @test_throws ErrorException load_comparison_cases([directory])
        write(joinpath(directory, "manifest.toml"),
              "export_verified = false\nfixture_non_scientific = true\n")
        @test_throws ErrorException load_comparison_cases([directory])
        figure = Figure(size=(300, 300))
        axis = Axis(figure[1, 1])
        drawable = (; manifest=Dict("case_id" =>
            "gabls1_n032_weno9_surface_layer_t100_s1"), profiles)
        SurfaceLayerScientificPlots.add_profile!(axis, drawable, "w_variance", times)
        image_path = joinpath(directory, "NON_SCIENTIFIC_PLOT_FIXTURE.png")
        save(image_path, figure)
        @test isfile(image_path)
    end
end
