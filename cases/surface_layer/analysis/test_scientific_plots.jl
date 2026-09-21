using Test
using CairoMakie
using JSON

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

@testset "NON-SCIENTIFIC full-layout rendering fixture" begin
    case_ids = ("gabls1_n032_weno9_control",
                "gabls1_n032_weno9_surface_layer_t100_s1",
                "gabls1_n032_weno9_surface_layer_t300_s1",
                "gabls1_n032_weno9_surface_layer_t300_s2")
    center_variables = ("u_mean", "theta_mean")
    face_variables = ("total_u_w_flux", "resolved_u_w_flux", "w_variance",
                      "total_w_theta_flux", "resolved_w_theta_flux",
                      "total_v_w_flux", "resolved_v_w_flux",
                      "w_third_central_moment")
    profile_times = (30600.0, 32400.0)
    series_times = [0.0, 60.0, 120.0]
    closure_names = first.(SurfaceLayerScientificPlots.closure_specs("GABLS1"))
    cases = NamedTuple[]
    for (case_index, case_id) in enumerate(case_ids)
        records = NamedTuple[]
        for variable in (center_variables..., face_variables...), time in profile_times
            location = variable in center_variables ? "Center" : "Face"
            heights = location == "Center" ? (6.25, 18.75, 31.25) :
                      (0.0, 12.5, 25.0)
            for (height_index, height) in enumerate(heights)
                value = variable == "w_variance" ? 0.01 * (height_index + case_index) :
                        variable == "w_third_central_moment" ?
                        0.001 * (height_index + case_index) :
                        0.1 * (height_index + case_index)
                push!(records, (; time_s=time, z_m=height, variable, value,
                                 location, units="fixture_units"))
            end
        end
        values = Dict(name => fill(0.1 * case_index, length(series_times)) for name in
                      ("friction_velocity", "surface_theta_kinematic_flux",
                       "boundary_layer_height", "boundary_layer_height_valid",
                       "surface_layer_face1_momentum_active_fraction",
                       closure_names...))
        values["boundary_layer_height_valid"] = [1.0, 0.0, 1.0]
        push!(cases, (; manifest=Dict("case_id" => case_id), profiles=records,
                       series=(; time_s=series_times, values)))
    end
    comparison = (; family="GABLS1", cases)
    reference_data = Dict("curves" => Dict(
        "profile/u_mean" => Dict("coordinates" => [0.0, 12.5],
            "median" => [1.0, 2.0], "member_count" => [2, 2]),
        "series/ustar" => Dict("coordinates" => [0.0, 60.0],
            "median" => [0.2, 0.21], "member_count" => [2, 2]),
        "series/surface_theta_flux" => Dict("coordinates" => [0.0, 60.0],
            "median" => [-0.01, -0.02], "member_count" => [2, 2])))
    @test !isnothing(SurfaceLayerScientificPlots.reference_series(reference_data, "ustar"))
    @test !isnothing(SurfaceLayerScientificPlots.reference_series(
        reference_data, "surface_theta_flux"))
    @test isnothing(SurfaceLayerScientificPlots.reference_curve(
        reference_data, "w_third_central_moment"))
    @test SurfaceLayerScientificPlots.comparison_profile(
        first(cases), :w_skewness_ratio_of_means, [30600.0, 32400.0]).location == "Face"

    mktempdir() do directory
        outputs = (
            ("lead", () -> SurfaceLayerScientificPlots.render_profile_comparison(
                comparison, joinpath(directory, "NON_SCIENTIFIC_lead.pdf");
                reference=reference_data, fixture=true)),
            ("scalars", () -> SurfaceLayerScientificPlots.render_companion_profiles(
                comparison, joinpath(directory, "NON_SCIENTIFIC_scalars.pdf"),
                SurfaceLayerScientificPlots.scalar_specs("GABLS1");
                reference=reference_data, fixture=true)),
            ("moments", () -> SurfaceLayerScientificPlots.render_companion_profiles(
                comparison, joinpath(directory, "NON_SCIENTIFIC_moments.pdf"),
                SurfaceLayerScientificPlots.moment_specs(); reference=reference_data,
                fixture=true)),
            ("timeline", () -> SurfaceLayerScientificPlots.render_surface_timeline(
                comparison, joinpath(directory, "NON_SCIENTIFIC_timeline.pdf");
                reference=reference_data, fixture=true)),
            ("closure", () -> SurfaceLayerScientificPlots.render_closure_diagnostics(
                comparison, joinpath(directory, "NON_SCIENTIFIC_closure.pdf");
                fixture=true)))
        for (name, render) in outputs
            render()
            @test isfile(joinpath(directory, "NON_SCIENTIFIC_$name.pdf"))
            @test isfile(joinpath(directory, "NON_SCIENTIFIC_$name.png"))
        end
    end

    g3_ids = ("n064_weno9_none", "n064_weno9_surface_layer_t100_s1",
              "n064_weno9_surface_layer_t300_s1",
              "n064_weno9_surface_layer_t300_s2")
    g3_times = collect(11100.0:300.0:14400.0)
    g3_closure_names = first.(SurfaceLayerScientificPlots.closure_specs("GABLS3"))
    g3_cases = NamedTuple[]
    for (case, case_id) in zip(cases, g3_ids)
        template = [record for record in case.profiles if record.time_s == 30600.0]
        records = [merge(record, (; time_s=time)) for record in template for time in g3_times]
        for variable in ("q_mean", "total_w_q_flux", "resolved_w_q_flux"), time in g3_times
            location = variable == "q_mean" ? "Center" : "Face"
            heights = location == "Center" ? (6.25, 18.75, 31.25) : (0.0, 12.5, 25.0)
            for height in heights
                push!(records, (; time_s=time, z_m=height, variable,
                                 value=0.001 * (height + 1), location,
                                 units="fixture_units"))
            end
        end
        values = copy(case.series.values)
        values["surface_q_kinematic_flux"] = fill(1e-5, length(series_times))
        for name in g3_closure_names
            values[name] = fill(0.1, length(series_times))
        end
        push!(g3_cases, (; manifest=Dict("case_id" => case_id), profiles=records,
                         series=(; time_s=series_times, values)))
    end
    g3_comparison = (; family="GABLS3", cases=g3_cases)
    mktempdir() do directory
        SurfaceLayerScientificPlots.render_profile_comparison(
            g3_comparison, joinpath(directory, "NON_SCIENTIFIC_g3lead.pdf"); fixture=true)
        SurfaceLayerScientificPlots.render_companion_profiles(
            g3_comparison, joinpath(directory, "NON_SCIENTIFIC_g3scalars.pdf"),
            SurfaceLayerScientificPlots.scalar_specs("GABLS3"); fixture=true)
        SurfaceLayerScientificPlots.render_surface_timeline(
            g3_comparison, joinpath(directory, "NON_SCIENTIFIC_g3timeline.pdf");
            fixture=true)
        SurfaceLayerScientificPlots.render_closure_diagnostics(
            g3_comparison, joinpath(directory, "NON_SCIENTIFIC_g3closure.pdf");
            fixture=true)
        @test all(isfile(joinpath(directory, "NON_SCIENTIFIC_g3$name.pdf")) for name in
                  ("lead", "scalars", "timeline", "closure"))
    end

    fixed_reference_path = normpath(joinpath(@__DIR__, "..", "..", "..",
        "campaigns", "dycoms", "gabls", "reference_data", "fixed_1m_medians.json"))
    fixed_reference = JSON.parsefile(fixed_reference_path)
    @test !isnothing(SurfaceLayerScientificPlots.reference_series(fixed_reference, "ustar"))
    @test !isnothing(SurfaceLayerScientificPlots.reference_series(
        fixed_reference, "surface_theta_flux"))
end
