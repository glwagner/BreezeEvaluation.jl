using Test

include(joinpath(@__DIR__, "validate_surface_layer.jl"))

length(ARGS) == 2 || error("usage: test_saved_writer_audit.jl SAVED_GPU_OUTPUT NEW_FIXTURE_DIRECTORY")
saved_root = abspath(ARGS[1])
fixture_root = abspath(ARGS[2])
isdir(saved_root) || error("missing saved GPU output directory $saved_root")
ispath(fixture_root) && error("refusing to overwrite $fixture_root")

ENV["GABLS1_SLD_ARCH"] = "cpu"
ENV["GABLS1_SLD_NX"] = "32"
ENV["GABLS1_SLD_CLOSURE"] = "surface_layer"
ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS1_SLD_SUPPORT"] = "2"
ENV["GABLS1_SLD_STOP_SECONDS"] = "1"
ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"

@testset "Read-only saved GABLS1 native initial writer" begin
    setup = GABLS1ValidationRunner.build_simulation(
        ; run_directory=joinpath(fixture_root, "gabls1"))
    initial_path = joinpath(saved_root, "gabls1_full_writer",
        "$(setup.case_id)_diag_initial.jld2")
    @test isfile(initial_path)
    @test audit_full_profile_file(initial_path, (0.0,), setup.model.grid,
        setup.simulation.output_writers[:gabls1_surface_layer_initial];
        minimum_variables=46) == ["0"]
end

ENV["GABLS3_ARCH"] = "cpu"
ENV["GABLS3_NX"] = "64"
ENV["GABLS3_SCHEME"] = "weno9"
ENV["GABLS3_CLOSURE"] = "surface_layer"
ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS3_SLD_SUPPORT"] = "2"
ENV["GABLS3_STOP_SECONDS"] = "301"
ENV["GABLS3_DIAGNOSTICS"] = "1"

@testset "Read-only saved GABLS3 initial and scheduled writers" begin
    setup = GABLS3ValidationRunner.build_simulation(
        ; run_directory=joinpath(fixture_root, "gabls3"))
    prefix = joinpath(saved_root, "gabls3_full_writer_clock_jump",
        "$(setup.case_id)_diag")
    profile_path = prefix * "_profiles.jld2"
    series_path = prefix * "_series.jld2"
    point_path = prefix * "_points.jld2"
    @test all(isfile, (profile_path, series_path, point_path))
    times = (295.0, 300.0)
    profile_records = audit_full_profile_file(profile_path, times, setup.model.grid,
        setup.simulation.output_writers[:gabls3_profiles]; minimum_variables=46)
    series_records = audit_reduced_file(series_path, times,
        setup.simulation.output_writers[:gabls3_series])
    point_records = audit_reduced_file(point_path, times,
        setup.simulation.output_writers[:gabls3_points])
    @test profile_records == series_records == point_records == ["0", "11"]
    audit_point_coordinates(point_path, setup.model.grid)
end

println("NON_SCIENTIFIC_SAVED_WRITER_AUDIT_PASS source=", saved_root)
