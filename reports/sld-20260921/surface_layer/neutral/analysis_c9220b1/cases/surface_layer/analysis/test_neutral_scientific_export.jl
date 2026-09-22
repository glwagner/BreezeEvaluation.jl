using Test

include(joinpath(@__DIR__, "NeutralScientificExport.jl"))
using .NeutralScientificExport
const Neutral = NeutralScientificExport

const FIXTURE_ROOT = "/shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614/output"

@testset "neutral scientific exporter, non-scientific raw fixtures" begin
    @test Neutral.scalar_leaf(1.25, "scalar") == 1.25
    @test Neutral.scalar_leaf(Float32[1.25], "vector singleton") == 1.25
    @test Neutral.scalar_leaf(reshape(Float32[1.25], 1, 1, 1), "3D singleton") == 1.25
    @test_throws ErrorException Neutral.scalar_leaf([1.0, 2.0], "not scalar")

    for closure in ("none", "surface_layer")
        directory = joinpath(FIXTURE_ROOT, closure)
        paths = readdir(directory; join=true)
        initial_path = only(filter(path -> endswith(path, "_diag_initial.jld2"), paths))
        profile_path = only(filter(path -> endswith(path, "_diag_statistics.jld2"), paths))
        series_path = only(filter(path -> endswith(path, "_diag_series.jld2"), paths))
        bounds_path = only(filter(path -> endswith(path, "_state_bounds.jld2"), paths))
        initial = Neutral.read_profiles(initial_path, [0.0], "instantaneous_initial_profile")
        profiles = Neutral.read_profiles(profile_path, [60.0, 120.0],
                                         "true_time_averaged_profiles")
        series = Neutral.read_series(series_path, collect(0.0:10.0:120.0))
        @test Neutral.compare_initial_and_statistics(initial, profiles;
                                                     averaging_window=60.0) === nothing
        @test length(initial.records) == 1
        @test length(profiles.records) == 2
        @test length(series.records) == 13
        @test profiles.information["w_variance"]["location"] == "Face"
        @test profiles.information["w_third_central_moment"]["location"] == "Face"
        @test profiles.native_coordinates == series.native_coordinates
        @test length(profiles.native_coordinates["z_center_m"]) == 96
        @test length(profiles.native_coordinates["z_face_m"]) == 97
        audit = Neutral.check_fluxes(profiles, series, closure;
            profile_times=[60.0, 120.0], series_times=collect(0.0:10.0:120.0))
        @test audit["wall_stress_magnitude_min_m2_s2"] > 0.249
        @test audit["wall_stress_magnitude_max_m2_s2"] < 0.251
        @test audit["maximum_scalar_guard_active_fraction"] == 0.0
        @test closure == "none" ? audit["maximum_first_supported_sgs_stress_m2_s2"] == 0.0 :
                                  audit["maximum_first_supported_sgs_stress_m2_s2"] > 0.0
        @test length(Neutral.check_state_bounds(bounds_path;
              expected_times=collect(0.0:10.0:120.0))) == 5
        checkpoint = only(filter(path -> occursin("_checkpoint_iteration0.jld2", path), paths))
        case_id = replace(basename(checkpoint), "_checkpoint_iteration0.jld2" => "")
        @test length(Neutral.check_checkpoints(directory, case_id;
                                               expected_times=[0.0])) == 1
        @test_throws ErrorException Neutral.read_profiles(profile_path, [60.0],
                                                           "true_time_averaged_profiles")

        mktempdir() do temporary
            output = joinpath(temporary, "profiles.csv")
            Neutral.write_native_profiles(output, initial, profiles)
            lines = readlines(output)
            @test startswith(first(lines), "time_s,z_m,variable,value,location")
            @test any(occursin(",w_variance,", line) &&
                      occursin(",Face,", line) for line in lines)
            @test any(startswith(line, "0,") for line in lines[2:end])
            @test any(startswith(line, "60,") for line in lines[2:end])
            @test any(startswith(line, "120,") for line in lines[2:end])
        end
    end

    started = Dict("case_id" => Neutral.CASE_IDS[1],
        "registry" => Neutral.registry_path(), "registry_index" => "1",
        "array_job_id" => Neutral.ORIGINAL_JOB_ID, "fixture" => "false",
        "source_manifest_sha256" => Neutral.CORE_SHA,
        "gpu_gate_combined_sha256" => Neutral.COMBINED_SHA,
        "supplemental_saved_output_sha256" => Neutral.SUPPLEMENT_SHA,
        "wrapper_sha256" => Neutral.WRAPPER_V1_SHA)
    done = Dict("case_id" => Neutral.CASE_IDS[1], "final_time_s" => "18000.0")
    exited = Dict("schema_version" => "1", "array_job_id" => Neutral.ORIGINAL_JOB_ID,
        "task_id" => "1", "case_id" => Neutral.CASE_IDS[1],
        "child_exit_code" => "0", "record_complete" => "true",
        "wrapper_sha256" => Neutral.WRAPPER_V1_SHA,
        "source_manifest_sha256" => Neutral.CORE_SHA,
        "supplemental_saved_output_sha256" => Neutral.SUPPLEMENT_SHA)
    @test Neutral.verify_completion_identity(started, done, exited,
                                             Neutral.CASE_IDS[1], 1)
    @test_throws ErrorException Neutral.verify_completion_identity(started,
        merge(done, Dict("final_time_s" => "120.0")), exited, Neutral.CASE_IDS[1], 1)
    @test_throws ErrorException Neutral.verify_completion_identity(started, done,
        merge(exited, Dict("child_exit_code" => "1")), Neutral.CASE_IDS[1], 1)
    @test_throws ErrorException Neutral.verify_completion_identity(
        merge(started, Dict("source_manifest_sha256" => "corrupt")), done,
        exited, Neutral.CASE_IDS[1], 1)
    @test_throws ErrorException Neutral.verify_completion_identity(started, done,
        exited, Neutral.CASE_IDS[1], 1;
        job_id="9999", wrapper_sha=Neutral.WRAPPER_V2_SHA)

    original_wrapper = "/shared/home/greg/review-coordination/run_neutral_science_pair_7366-v1.sh"
    @test Neutral.verify_launch_identity(Neutral.ORIGINAL_CAMPAIGN,
        Neutral.ORIGINAL_JOB_ID, original_wrapper, Neutral.WRAPPER_V1_SHA)
    @test_throws ErrorException Neutral.verify_launch_identity(Neutral.ORIGINAL_CAMPAIGN,
        "9999", original_wrapper, Neutral.WRAPPER_V1_SHA)
    replacement = joinpath(@__DIR__, "..", "neutral", "run_neutral_science_pair_v2.sh")
    @test Neutral.sha(replacement) == Neutral.WRAPPER_V2_SHA
    done_path = joinpath(Neutral.ORIGINAL_CAMPAIGN, "runs", Neutral.CASE_IDS[1], "CASE_DONE")
    @test success(`bash $replacement --check-case-done $done_path $(Neutral.CASE_IDS[1])`)
    @test !success(`bash $replacement --check-case-done $done_path wrong_case`)
    @test !success(`bash $replacement --check-case-done $(done_path * ".missing") $(Neutral.CASE_IDS[1])`)

    # Synthetic manifest-only collector contract: never export or admit this fixture.
    mktempdir() do temporary
        names = ("profiles.csv", "series.csv", "profiles_final_hour_long.csv",
                 "profiles_penultimate_hour_long.csv")
        for name in names
            write(joinpath(temporary, name), "synthetic fixture\n")
        end
        attempt = Dict("case_id" => Neutral.CASE_IDS[1], "closure" => "none",
            "registry_index" => 1, "exit_sha256" => "synthetic-exit",
            "run_directory" => temporary, "raw_sha256" => Dict{String, String}(),
            "checkpoint_records" => Dict{String, Any}[])
        manifest = Dict{String, Any}(
            "case_id" => attempt["case_id"], "case_family" => "neutral_fixed_stress_ABL",
            "closure" => "none", "export_verified" => true,
            "fixture_non_scientific" => false,
            "scientific_admission" => "passed_durable_zero_exit",
            "admission_mode" => "durable_zero_exit_v1",
            "original_7367_batch_success" => false, "active_batch_success" => true,
            "final_time_s" => 18000.0,
            "provenance" => Dict("finalized_registry_sha256" => "synthetic-registry",
                "active_attempt_id" => "7367_1", "source_manifest_sha256" => Neutral.CORE_SHA,
                "supplemental_gpu_gate_sha256" => Neutral.SUPPLEMENT_SHA,
                "original_7366_parent_passed" => false,
                "saved_science_evidence_sha256" => "not_applicable",
                "root_acceptance_sha256" => "not_applicable",
                "durable_child_exit_sha256" => "synthetic-exit"),
            "record_audit" => Dict(
                "profiles" => Dict("initial_records" => 1, "averaged_records" => 30,
                    "total_records" => 31, "averaged_times_s" => Neutral.PROFILE_TIMES,
                    "all_finite" => true),
                "series" => Dict("records" => 301, "times_s" => Neutral.SERIES_TIMES,
                    "all_finite" => true),
                "state_bounds" => Dict("records" => 301),
                "checkpoints" => Dict("records" => 6,
                    "times_s" => Neutral.CHECKPOINT_TIMES)),
            "source_files" => Dict{String, Any}(),
            "checkpoint_files" => Dict{String, Any}[],
            "output_sha256" => Dict(name => Neutral.sha(joinpath(temporary, name))
                                    for name in names))
        Neutral.Common.write_manifests(temporary, manifest)
        @test Neutral.verify_export_directory(temporary, attempt,
                                              "synthetic-registry", "7367",
                                              "durable_zero_exit_v1")["case_id"] ==
              Neutral.CASE_IDS[1]
        write(joinpath(temporary, "series.csv"), "corrupted fixture\n")
        @test_throws ErrorException Neutral.verify_export_directory(temporary,
            attempt, "synthetic-registry", "7367", "durable_zero_exit_v1")
        @test_throws ErrorException Neutral.verify_export_directory(temporary,
            attempt, "other-registry", "7367", "durable_zero_exit_v1")
    end
end
