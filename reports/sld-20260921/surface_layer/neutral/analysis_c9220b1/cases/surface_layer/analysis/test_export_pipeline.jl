using JLD2
using Test
using TOML

include(joinpath(@__DIR__, "SurfaceLayerScientificExport.jl"))
include(joinpath(@__DIR__, "SurfaceLayerAnalysisData.jl"))
using .SurfaceLayerScientificExport
using .SurfaceLayerAnalysisData

function write_profiles(path, times, nz; metadata_available=false, bad_shape=false,
                        nonfinite=false, initial_offset=0f0)
    jldopen(path, "w") do file
        file["metadata/surface_layer_diffusivity_available"] = metadata_available
        file["metadata/test_fixture"] = true
        for (index, time) in enumerate(times)
            key = string(index)
            file["timeseries/t/$key"] = time
            center = fill(Float32(time) + (index == 1 ? initial_offset : 0f0),
                          1, 1, bad_shape ? nz - 1 : nz)
            face = fill(Float32(time + 1), 1, 1, nz + 1)
            nonfinite && index == length(times) && (center[1] = Float32(NaN))
            file["timeseries/u_mean/$key"] = center
            file["timeseries/w_variance/$key"] = face
        end
    end
end

function write_series(path, times; gabls3=false, nonfinite=false,
                      mixed_final_prescribed=false, mixed_middle_prescribed=false,
                      mixed_final_unlisted=false)
    jldopen(path, "w") do file
        file["metadata/surface_layer_diffusivity_available"] = false
        file["metadata/test_fixture"] = true
        for (index, time) in enumerate(times)
            key = string(index)
            file["timeseries/t/$key"] = time
            value = nonfinite && index == length(times) ? Float32(Inf) : Float32(time)
            mixed_final_unlisted && index == length(times) && (value = Float64(value))
            file["timeseries/surface_temperature/$key"] = value
            file["timeseries/surface_theta_kinematic_flux/$key"] = Float32(-0.01)
            if gabls3
                prescribed_type = mixed_final_prescribed || mixed_middle_prescribed ?
                    (index == length(times) && mixed_final_prescribed ||
                     index == 2 && mixed_middle_prescribed ? Float32 : Float64) : Float32
                file["timeseries/prescribed_surface_pressure/$key"] = prescribed_type(102210)
                file["timeseries/prescribed_surface_theta/$key"] = prescribed_type(270)
                file["timeseries/prescribed_surface_q/$key"] = prescribed_type(0.002)
            end
        end
    end
end

function write_points(path, times)
    jldopen(path, "w") do file
        file["metadata/actual_scalar_and_horizontal_velocity_heights_m"] = "6.25"
        file["metadata/actual_native_w_face_heights_m"] = "12.5"
        for (index, time) in enumerate(times)
            key = string(index)
            file["timeseries/t/$key"] = time
            file["timeseries/theta_z10p0m/$key"] = Float32(270 + time / 32400)
            file["timeseries/w_z10p0m/$key"] = Float32(time / 32400)
        end
    end
end

function make_gabls1_fixture(root, case_id; profile_times=GABLS1_STATISTICS_TIMES,
                             bad_shape=false, nonfinite=false,
                             mismatched_statistics_initial=false)
    mkpath(root)
    prefix = joinpath(root, "$(case_id)_diag")
    write_profiles(prefix * "_initial.jld2", GABLS1_INITIAL_TIMES, 2)
    write_profiles(prefix * "_statistics.jld2", profile_times, 2;
                   bad_shape, nonfinite,
                   initial_offset=mismatched_statistics_initial ? 99f0 : 0f0)
    write_series(prefix * "_series.jld2", GABLS1_SERIES_TIMES)
end

function make_gabls3_fixture(root, case_id)
    mkpath(root)
    prefix = joinpath(root, "$(case_id)_diag")
    write_profiles(prefix * "_profiles.jld2", GABLS3_PROFILE_TIMES, 2)
    write_series(prefix * "_series.jld2", GABLS3_SERIES_TIMES; gabls3=true)
    write_points(prefix * "_points.jld2", GABLS3_SERIES_TIMES)
end

@testset "GABLS3 final prescribed-scalar precision exception" begin
    mktempdir() do root
        case_id = "fixture_gabls3_final_precision"
        run = joinpath(root, "run")
        make_gabls3_fixture(run, case_id)
        series_path = joinpath(run, "$(case_id)_diag_series.jld2")
        write_series(series_path, GABLS3_SERIES_TIMES;
                     gabls3=true, mixed_final_prescribed=true)
        manifest = export_fixture("GABLS3", run, case_id,
            joinpath(root, "export"), 2, 800.0, "none")
        for name in ("prescribed_surface_pressure", "prescribed_surface_theta",
                     "prescribed_surface_q")
            info = manifest["series_variables"][name]
            @test info["raw_element_type_counts"] ==
                Dict("Float64" => 3240, "Float32" => 1)
            @test info["final_record_float32_exception"] === true
        end
        @test manifest["export_verified"] === false
    end
    for (label, options) in (
        ("middle_precision", (; mixed_middle_prescribed=true)),
        ("unlisted_precision", (; mixed_final_unlisted=true)))
        mktempdir() do root
            case_id = "fixture_gabls3_$label"
            run = joinpath(root, "run")
            make_gabls3_fixture(run, case_id)
            series_path = joinpath(run, "$(case_id)_diag_series.jld2")
            write_series(series_path, GABLS3_SERIES_TIMES; gabls3=true, options...)
            @test_throws ErrorException export_fixture("GABLS3", run, case_id,
                joinpath(root, "export"), 2, 800.0, "none")
        end
    end
end

@testset "Surface-layer scientific export plumbing" begin
    mktempdir() do root
        run = joinpath(root, "g1-run")
        destination = joinpath(root, "g1-export")
        case_id = "fixture_gabls1"
        make_gabls1_fixture(run, case_id)
        manifest = export_fixture("GABLS1", run, case_id, destination, 2, 400.0, "none")
        @test manifest["export_verified"] === false
        @test manifest["fixture_non_scientific"] === true
        @test manifest["record_audit"]["profiles"]["total_records"] == 19
        @test manifest["record_audit"]["profiles"]["statistics_writer_records"] == 19
        @test manifest["record_audit"]["profiles"]["statistics_writer_initial_exact_duplicate"] === true
        @test length(readlines(joinpath(destination, "profiles.csv"))) == 1 + 19 * 5
        @test length(readlines(joinpath(destination, "series.csv"))) == 1 + 541
        final_lines = readlines(joinpath(destination, "profiles_final_hour_long.csv"))
        @test any(occursin("31500", line) for line in final_lines)
        loaded_series = read_wide_series(joinpath(destination, "series.csv"))
        loaded_profiles = read_long_profiles(joinpath(destination, "profiles.csv"))
        @test length(loaded_series.time_s) == 541
        @test Set(record.location for record in loaded_profiles) == Set(("Center", "Face"))
        @test_throws ErrorException load_case_export(destination)
    end

    mktempdir() do root
        run = joinpath(root, "g3-run")
        destination = joinpath(root, "g3-export")
        case_id = "fixture_gabls3"
        make_gabls3_fixture(run, case_id)
        manifest = export_fixture("GABLS3", run, case_id, destination, 2, 800.0, "none")
        @test manifest["record_audit"]["profiles"]["records"] == 109
        @test manifest["record_audit"]["series"]["records"] == 3241
        @test manifest["record_audit"]["points"]["records"] == 3241
        @test first(manifest["record_audit"]["series"]["times_s"]) == 0.0
        @test first(manifest["record_audit"]["points"]["times_s"]) == 0.0
        @test length(readlines(joinpath(destination, "series.csv"))) == 3242
        @test length(readlines(joinpath(destination, "points.csv"))) == 3242
        mean_lines = readlines(joinpath(destination, "profiles_03_04utc_mean.csv"))
        @test any(occursin("12750", line) for line in mean_lines)
        @test manifest["raw_metadata"]["points"][
            "actual_native_w_face_heights_m"] == "12.5"
    end
end

@testset "Strict schedule, finite, shape, and completion rejection" begin
    for missing_initial in ("series", "points")
        mktempdir() do root
            case_id = "fixture_gabls3_missing_initial_$(missing_initial)"
            run = joinpath(root, "run")
            make_gabls3_fixture(run, case_id)
            path = joinpath(run, "$(case_id)_diag_$(missing_initial).jld2")
            scheduled_only = collect(10.0:10.0:32400.0)
            if missing_initial == "series"
                write_series(path, scheduled_only; gabls3=true)
            else
                write_points(path, scheduled_only)
            end
            @test_throws ErrorException export_fixture(
                "GABLS3", run, case_id, joinpath(root, "export"), 2, 800.0, "none")
        end
    end
    mktempdir() do root
        case_id = "fixture_incomplete"
        run = joinpath(root, "run")
        make_gabls1_fixture(run, case_id; profile_times=GABLS1_STATISTICS_TIMES[1:end-1])
        destination = joinpath(root, "export")
        @test_throws ErrorException export_fixture(
            "GABLS1", run, case_id, destination, 2, 400.0, "none")
        @test !ispath(destination)
    end
    mktempdir() do root
        case_id = "fixture_statistics_initial_mismatch"
        run = joinpath(root, "run")
        make_gabls1_fixture(run, case_id; mismatched_statistics_initial=true)
        @test_throws ErrorException export_fixture(
            "GABLS1", run, case_id, joinpath(root, "export"), 2, 400.0, "none")
    end
    mktempdir() do root
        case_id = "fixture_nonfinite"
        run = joinpath(root, "run")
        make_gabls1_fixture(run, case_id; nonfinite=true)
        @test_throws ErrorException export_fixture(
            "GABLS1", run, case_id, joinpath(root, "export"), 2, 400.0, "none")
    end
    mktempdir() do root
        case_id = "fixture_shape"
        run = joinpath(root, "run")
        make_gabls1_fixture(run, case_id; bad_shape=true)
        @test_throws ErrorException export_fixture(
            "GABLS1", run, case_id, joinpath(root, "export"), 2, 400.0, "none")
    end
    mktempdir() do root
        write(joinpath(root, "ATTEMPT_STARTED"), "case_id=x\n")
        write(joinpath(root, "CASE_DONE"), "case_id=x\nfinal_time_s=32399\n")
        @test_throws ErrorException verify_completion(root, "x")
        write(joinpath(root, "CASE_DONE"), "case_id=x\nfinal_time_s=32400\n")
        @test verify_completion(root, "x")["final_time_s"] == 32400
        write(joinpath(root, "CASE_FAILED"), "failed\n")
        @test_throws ErrorException verify_completion(root, "x")
    end
end

@testset "Hash and registry admission rejection" begin
    mktempdir() do root
        mkpath(joinpath(root, "source"))
        write(joinpath(root, "source", "x.txt"), "reviewed\n")
        digest = file_sha256(joinpath(root, "source", "x.txt"))
        manifest = joinpath(root, "source_sha256.txt")
        write(manifest, "$digest  source/x.txt\n")
        @test verify_hash_manifest(root, manifest) == 1
        write(joinpath(root, "source", "x.txt"), "corrupt\n")
        @test_throws ErrorException verify_hash_manifest(root, manifest)
    end
    registry = joinpath(@__DIR__, "registries", "gabls1_analysis_attempts.toml")
    parsed = load_attempt_registry(registry)
    @test parsed["source_freeze_manifest_entries"] == 761
    @test parsed["source_freeze_manifest_sha256"] ==
          "d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
    gabls3_registry = joinpath(@__DIR__, "registries", "gabls3_analysis_attempts.toml")
    gabls3_parsed = load_attempt_registry(gabls3_registry)
    @test gabls3_parsed["source_freeze_manifest_entries"] == 762
    @test gabls3_parsed["source_freeze_manifest_sha256"] ==
          "1cc45c554fe4675a5ffde2dc6bfe70953d9c5294f9df4e6fe76b6f1f033886ac"
    changed_path = copy(gabls3_parsed)
    changed_path["gpu_validation_mode"] = "gabls3_surface_q_read_only_v2"
    changed_path["case_family"] = "GABLS1"
    @test_throws ErrorException SurfaceLayerScientificExport.verify_gpu_evidence_for_registry(
        changed_path, changed_path["source_freeze_root"])
    changed_path["case_family"] = "GABLS3"
    @test_throws ErrorException SurfaceLayerScientificExport.verify_gpu_evidence_for_registry(
        changed_path, "/wrong/source")
    @test_throws KeyError SurfaceLayerScientificExport.verify_gpu_evidence_for_registry(
        changed_path, changed_path["source_freeze_root"])
    @test_throws ErrorException SurfaceLayerScientificExport.active_attempt(
        parsed, "gabls1_n032_weno9_control")
    mktempdir() do root
        collection = collect_admitted_exports(registry, joinpath(root, "exports"),
                                              joinpath(root, "collection"))
        @test collection["admitted_count"] == 0
        @test collection["rejected_count"] == 4
    end
    mktempdir() do root
        freeze = joinpath(root, "freeze")
        evidence_directory = joinpath(root, "evidence")
        source = joinpath(freeze, "source", "BreezeEvaluation.jl", "x.txt")
        mkpath(dirname(source)); mkpath(evidence_directory)
        write(source, "reviewed\n")
        source_sha = file_sha256(source)
        source_manifest = joinpath(freeze, "source_sha256.txt")
        write(source_manifest, "$source_sha  source/BreezeEvaluation.jl/x.txt\n")
        evidence = Dict{String, Any}(
            "validation_mode" => "gpu_full", "all_passed" => true,
            "architecture" => "CUDAGPU", "cuda_functional" => true,
            "cuda_scalar_indexing_disabled" => true, "freeze_root" => freeze,
            "freeze_source_manifest_sha256" => file_sha256(source_manifest),
            "freeze_source_manifest_entries" => 1, "passed_checks" => 99,
            "source_sha256" => Dict("x.txt" => source_sha))
        evidence_path = joinpath(evidence_directory, "validation_evidence.toml")
        open(evidence_path, "w") do io
            TOML.print(io, evidence; sorted=true)
        end
        write(joinpath(evidence_directory, "GPU_VALIDATION_DONE"),
              "mode=gpu_full\nevidence_sha256=$(file_sha256(evidence_path))\n")
        audit = SurfaceLayerScientificExport.verify_gpu_evidence(
            evidence_directory, freeze, file_sha256(source_manifest))
        @test audit["passed_checks"] == 99
        write(source, "corrupt\n")
        @test_throws ErrorException SurfaceLayerScientificExport.verify_gpu_evidence(
            evidence_directory, freeze, file_sha256(source_manifest))
        write(source, "reviewed\n")
        evidence["validation_mode"] = "cpu_contract"
        open(evidence_path, "w") do io
            TOML.print(io, evidence; sorted=true)
        end
        write(joinpath(evidence_directory, "GPU_VALIDATION_DONE"),
              "mode=gpu_full\nevidence_sha256=$(file_sha256(evidence_path))\n")
        @test_throws ErrorException SurfaceLayerScientificExport.verify_gpu_evidence(
            evidence_directory, freeze, file_sha256(source_manifest))
    end
    top = Dict{String, Any}(
        "case_id" => "x", "active_attempt_id" => "new", "active" => true,
        "attempt_state" => "completed_candidate", "scientific_candidate" => true,
        "fixture_kind" => "none", "run_directory" => "/new/run",
        "log_path" => "/new/log", "job_spec" => "new_job",
        "log_sha256" => "new_log_hash", "attempt_started_sha256" => "new_start_hash",
        "case_done_sha256" => "new_done_hash",
        "attempt_history" => [Dict("active_attempt_id" => "old",
            "run_directory" => "/old/run", "log_path" => "/old/log",
            "job_spec" => "old_job")])
    selected = SurfaceLayerScientificExport.active_attempt(
        Dict{String, Any}("attempts" => [top]), "x")
    @test selected["active_attempt_id"] == "new"
    @test selected["job_spec"] == "new_job"
end

@testset "Corrected GABLS3 durable child-exit binding" begin
    mktempdir() do root
        scientific_path = joinpath(root, "registry.toml")
        run_directory = joinpath(root, "run")
        mkpath(run_directory)
        started = joinpath(run_directory, "ATTEMPT_STARTED")
        done = joinpath(run_directory, "CASE_DONE")
        exit_path = joinpath(root, "case.exit")
        log_path = joinpath(root, "case.log")
        write(started, "case_id=x\nregistry=$scientific_path\nregistry_index=1\n")
        write(done, "case_id=x\nfinal_time_s=32400\n")
        write(exit_path,
              "schema_version=2\narray_job_id=9000\ntask_id=1\nchild_exit_code=0\n" *
              "record_complete=true\nwrapper_sha256=wrapper\nsource_manifest_sha256=source\n" *
              "gpu_validation_job_id=8000\ngpu_validation_log_sha256=gpu_log\n" *
              "gpu_evidence_directory=$root\n")
        write(log_path, "SLD_RECORDED_BATCH_EXIT job=9000 task=1 child_exit_code=0 record=$exit_path\n")
        attempt = Dict{String, Any}(
            "registry_index" => 1, "run_directory" => run_directory,
            "log_path" => log_path, "log_sha256" => file_sha256(log_path),
            "attempt_started_sha256" => file_sha256(started),
            "case_done_sha256" => file_sha256(done), "job_spec" => "9000_1",
            "batch_exit_record_path" => exit_path,
            "batch_exit_record_sha256" => file_sha256(exit_path),
            "launch_wrapper_sha256" => "wrapper")
        registry = Dict{String, Any}(
            "gpu_validation_mode" => "gabls3_surface_q_read_only_v2",
            "source_freeze_manifest_sha256" => "source",
            "gpu_validation_job_id" => "8000",
            "gpu_validation_log_sha256" => "gpu_log",
            "gpu_validation_evidence_directory" => root)
        completion = Dict("started" => SurfaceLayerScientificExport.parse_fields(started))
        @test SurfaceLayerScientificExport.verify_attempt_identity(
            attempt, completion, scientific_path, registry)
        bad = copy(registry)
        bad["gpu_validation_job_id"] = "old_job"
        @test_throws ErrorException SurfaceLayerScientificExport.verify_attempt_identity(
            attempt, completion, scientific_path, bad)
        write(exit_path, read(exit_path, String) * "extra=tampered\n")
        @test_throws ErrorException SurfaceLayerScientificExport.verify_attempt_identity(
            attempt, completion, scientific_path, registry)
    end
end

@testset "SLD variable/unit contract" begin
    for family in ("GABLS1", "GABLS3")
        required = SurfaceLayerScientificExport.required_surface_layer_variables(family)
        @test !isempty(required.profiles)
        @test !isempty(required.series)
        @test all(name -> SurfaceLayerScientificExport.profile_unit(name) == "m^2 s^-1",
                  required.profiles)
        @test all(name -> !isempty(SurfaceLayerScientificExport.series_unit(name)),
                  required.series)
    end
    @test SurfaceLayerScientificExport.series_unit(
        "surface_layer_face1_ρθ_deficit") == "K m s^-1"
    @test SurfaceLayerScientificExport.series_unit(
        "surface_layer_face2_ρqᵉ_deficit") == "m s^-1"
    @test SurfaceLayerScientificExport.series_unit(
        "surface_layer_filtered_surface_flux_ρqᵛ") == "m s^-1"
    @test SurfaceLayerScientificExport.series_unit(
        "surface_layer_face2_ρqᵛ_filtered_scalar_mean_w_mean_transport") == "m s^-1"
    expected_units = Dict(
        "surface_layer_face1_filtered_u_mean" => "m s^-1",
        "surface_layer_face1_filtered_v_mean" => "m s^-1",
        "surface_layer_face1_filtered_uw_product" => "m^2 s^-2",
        "surface_layer_face1_filtered_vw_product" => "m^2 s^-2",
        "surface_layer_face1_filtered_u_mean_w_mean_transport" => "m^2 s^-2",
        "surface_layer_face1_filtered_v_mean_w_mean_transport" => "m^2 s^-2",
        "surface_layer_face1_ρθ_filtered_scalar_mean" => "K",
        "surface_layer_face1_ρθ_filtered_scalar_w_product" => "K m s^-1",
        "surface_layer_face1_ρθ_filtered_scalar_mean_w_mean_transport" => "K m s^-1",
        "surface_layer_face2_ρqᵉ_filtered_scalar_mean" => "1",
        "surface_layer_face2_ρqᵉ_filtered_scalar_w_product" => "m s^-1",
        "surface_layer_face2_ρqᵉ_filtered_scalar_mean_w_mean_transport" => "m s^-1")
    for (name, expected) in expected_units
        @test SurfaceLayerScientificExport.series_unit(name) == expected
    end
end
