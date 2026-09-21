using Test

include(joinpath(@__DIR__, "validate_surface_layer.jl"))

length(ARGS) == 1 || error("usage: test_gabls3_clock_jump_writer.jl NEW_OUTPUT_DIRECTORY")
directory = abspath(only(ARGS))
ispath(directory) && error("refusing to overwrite $directory")

ENV["GABLS3_ARCH"] = "cpu"
ENV["GABLS3_NX"] = "64"
ENV["GABLS3_SCHEME"] = "weno9"
ENV["GABLS3_CLOSURE"] = "surface_layer"
ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS3_SLD_SUPPORT"] = "2"
ENV["GABLS3_STOP_SECONDS"] = "301"
ENV["GABLS3_DIAGNOSTICS"] = "1"

@testset "Non-scientific GABLS3 clock-jump writer records" begin
    setup = GABLS3ValidationRunner.build_simulation(; run_directory=directory)
    delete!(setup.simulation.output_writers, :checkpoint)
    for name in (:gabls3_profiles, :gabls3_series, :gabls3_points)
        schedule_times = setup.simulation.output_writers[name].schedule.times
        @test 300.0 in schedule_times
        @test !(295.0 in schedule_times)
    end
    setup.model.clock.time = 295.0
    skip_past_specified_times!(setup.simulation, 295.0)
    run!(setup.simulation)

    prefix = joinpath(directory, "$(setup.case_id)_diag")
    profile_path = prefix * "_profiles.jld2"
    series_path = prefix * "_series.jld2"
    point_path = prefix * "_points.jld2"
    @test all(isfile, (profile_path, series_path, point_path))
    @test raw_times(profile_path) == [295.0, 300.0]
    @test raw_times(series_path) == [295.0, 300.0]
    @test raw_times(point_path) == [295.0, 300.0]
    profile_records = audit_full_profile_file(
        profile_path, (295.0, 300.0), setup.model.grid,
        setup.simulation.output_writers[:gabls3_profiles]; minimum_variables=46)
    series_records = audit_reduced_file(
        series_path, (295.0, 300.0), setup.simulation.output_writers[:gabls3_series])
    point_records = audit_reduced_file(
        point_path, (295.0, 300.0), setup.simulation.output_writers[:gabls3_points])
    @test profile_records == series_records == point_records
    @test first(profile_records) == "0"
    @test parse(Int, last(profile_records)) > 0
    audit_point_coordinates(point_path, setup.model.grid)

    # Reject a missing scheduled record or a dropped initialization record.
    @test_throws ErrorException audit_full_profile_file(
        profile_path, (300.0,), setup.model.grid,
        setup.simulation.output_writers[:gabls3_profiles]; minimum_variables=46)
    @test_throws ErrorException audit_reduced_file(
        series_path, (295.0,), setup.simulation.output_writers[:gabls3_series])
    @test_throws ErrorException audit_reduced_file(
        point_path, (294.0, 300.0), setup.simulation.output_writers[:gabls3_points])
end

println("NON_SCIENTIFIC_GABLS3_CLOCK_JUMP_WRITER_PASS directory=", directory)
