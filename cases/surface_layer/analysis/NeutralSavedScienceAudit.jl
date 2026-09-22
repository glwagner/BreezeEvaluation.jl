module NeutralSavedScienceAudit

export audit_saved_science, validate_saved_evidence, validate_root_acceptance,
       finalize_root_accepted_saved_science, verify_postprocessing_failure,
       verify_saved_attempt

using Dates
using SHA
using TOML

include("NeutralScientificExport.jl")
using .NeutralScientificExport
const Neutral = NeutralScientificExport

const CAMPAIGN = Neutral.ORIGINAL_CAMPAIGN
const JOB_ID = Neutral.ORIGINAL_JOB_ID
const WRAPPER = "/shared/home/greg/review-coordination/run_neutral_science_pair_7366-v1.sh"
const WRAPPER_SHA = Neutral.WRAPPER_V1_SHA
const ORIGINAL_7366_GATE_SHA = Neutral.SUPPLEMENT_SHA
const EVALUATION_REPOSITORY = normpath(joinpath(@__DIR__, "..", "..", ".."))
const ANALYSIS_FILES = (
    "cases/surface_layer/analysis/NeutralScientificExport.jl",
    "cases/surface_layer/analysis/NeutralSavedScienceAudit.jl",
    "cases/surface_layer/analysis/audit_neutral_saved_science.jl",
    "cases/surface_layer/analysis/validate_neutral_saved_science.jl",
    "cases/surface_layer/analysis/admit_neutral_saved_science.jl",
    "cases/surface_layer/analysis/finalize_neutral_saved_science.jl",
    "cases/surface_layer/analysis/finalize_neutral_attempts.jl",
    "cases/surface_layer/analysis/export_neutral_case.jl",
    "cases/surface_layer/analysis/collect_neutral_exports.jl",
    "cases/surface_layer/neutral/run_neutral_science_pair_v2.sh")

check(condition, message) = condition || error(message)
sha(path) = Neutral.sha(path)

function pinned_analysis_revision(; expected_commit=nothing)
    commit = expected_commit === nothing ?
             chomp(read(`git -C $EVALUATION_REPOSITORY rev-parse HEAD`, String)) :
             expected_commit
    hashes = Dict{String, String}()
    for relative in ANALYSIS_FILES
        path = joinpath(EVALUATION_REPOSITORY, relative)
        committed = read(`git -C $EVALUATION_REPOSITORY show $commit:$relative`)
        check(sha(path) == bytes2hex(SHA.sha256(committed)),
              "analysis file differs from committed revision: $relative")
        hashes[relative] = sha(path)
    end
    return (; commit, hashes)
end

function failure_paths(index)
    case_id = Neutral.CASE_IDS[index]
    run_directory = joinpath(CAMPAIGN, "runs", case_id)
    log_path = joinpath(CAMPAIGN, "logs", "neutral_$(JOB_ID)_$index.out")
    exit_path = joinpath(CAMPAIGN, "logs", "neutral_$(JOB_ID)_$index.exit")
    return (; case_id, run_directory, log_path, exit_path,
            started_path=joinpath(run_directory, "ATTEMPT_STARTED"),
            done_path=joinpath(run_directory, "CASE_DONE"),
            failed_path=joinpath(run_directory, "CASE_FAILED"))
end

function verify_postprocessing_failure(log, index, case_id, exit_path)
    started = findfirst("NEUTRAL_ABL_RUN_START", log)
    finished = findfirst("NEUTRAL_ABL_RUN_DONE", log)
    missing_rg = findfirst("$WRAPPER: line 75: rg: command not found", log)
    recorded = findfirst("NEUTRAL_RECORDED_CHILD_EXIT job=$JOB_ID task=$index case=$case_id code=3 record=$exit_path", log)
    check(started !== nothing && finished !== nothing && missing_rg !== nothing &&
          recorded !== nothing && first(started) < first(finished) <
          first(missing_rg) < first(recorded),
          "solver-completion/postprocessing log sequence differs")
    check(length(collect(eachmatch(r"rg: command not found", log))) == 1,
          "missing-rg failure is not unique")
    check(length(collect(eachmatch(r"NEUTRAL_ABL_RUN_DONE", log))) == 1 &&
          length(collect(eachmatch(r"NEUTRAL_RECORDED_CHILD_EXIT", log))) == 1,
          "solver or exit record repeated")
    check(occursin("Simulation time 5 hours equals or exceeds stop time 5 hours.", log) &&
          occursin("final_time = 18000.0", log) &&
          occursin("case_id = \"$case_id\"", log),
          "solver stop/case/time log differs")
    # An iteration-zero progress rate is deliberately NaN (zero elapsed steps),
    # so only actual error/exception records are excluded here. Raw fields are
    # audited independently for non-finite data.
    check(!occursin("ERROR:", log) && !occursin("Stacktrace:", log) &&
          !occursin("Exception", log) && !occursin("GPU_VALIDATION_FAILED", log),
          "solver log contains an error unrelated to missing rg")
    return Dict("solver_returned_zero_inferred_from_wrapper_branch" => true,
                "proof" => "pinned v1 wrapper only executes line-75 rg after Julia child_exit_code == 0; unique rg failure follows RUN_DONE and precedes durable code-3 record",
                "missing_rg_occurrences" => 1,
                "original_batch_exit_code" => 3)
end

function verify_saved_attempt(index, canonical)
    paths = failure_paths(index)
    for path in (paths.started_path, paths.done_path, paths.failed_path,
                 paths.log_path, paths.exit_path)
        check(isfile(path), "saved attempt missing $path")
    end
    case = canonical["cases"][index]
    check(case["case_id"] == paths.case_id, "canonical case/index differs")
    started = Neutral.parse_fields(paths.started_path)
    done = Neutral.parse_fields(paths.done_path)
    failed = Neutral.parse_fields(paths.failed_path)
    exited = Neutral.parse_fields(paths.exit_path)
    check(started["case_id"] == paths.case_id &&
          started["registry"] == Neutral.registry_path() &&
          started["registry_index"] == string(index) &&
          started["array_job_id"] == JOB_ID &&
          started["source_manifest_sha256"] == Neutral.CORE_SHA &&
          started["wrapper_sha256"] == WRAPPER_SHA &&
          started["gpu_gate_combined_sha256"] == Neutral.COMBINED_SHA &&
          started["supplemental_saved_output_sha256"] == ORIGINAL_7366_GATE_SHA &&
          started["fixture"] == "false", "saved ATTEMPT_STARTED identity differs")
    check(done["case_id"] == paths.case_id &&
          parse(Float64, done["final_time_s"]) == 18000.0,
          "solver CASE_DONE case/final time differs")
    check(failed == Dict("case_id" => paths.case_id, "child_exit_code" => "3"),
          "original CASE_FAILED is not the expected wrapper-only code 3")
    check(exited["schema_version"] == "1" && exited["array_job_id"] == JOB_ID &&
          exited["task_id"] == string(index) && exited["case_id"] == paths.case_id &&
          exited["child_exit_code"] == "3" && exited["record_complete"] == "true" &&
          exited["wrapper_sha256"] == WRAPPER_SHA &&
          exited["source_manifest_sha256"] == Neutral.CORE_SHA &&
          exited["supplemental_saved_output_sha256"] == ORIGINAL_7366_GATE_SHA &&
          all(isdigit, exited["slurm_job_id"]),
          "original durable code-3 child-exit identity differs")
    log = read(paths.log_path, String)
    proof = verify_postprocessing_failure(log, index, paths.case_id, paths.exit_path)
    captured = Neutral.verify_provenance(paths.run_directory, paths.case_id, canonical)
    raw = Neutral.audit_neutral_raw(paths.run_directory, paths.case_id, case["closure"])
    return Dict{String, Any}(
        "case_id" => paths.case_id, "registry_index" => index,
        "closure" => case["closure"], "run_directory" => paths.run_directory,
        "original_log_path" => paths.log_path, "original_exit_path" => paths.exit_path,
        "original_started_sha256" => sha(paths.started_path),
        "original_case_done_sha256" => sha(paths.done_path),
        "original_case_failed_sha256" => sha(paths.failed_path),
        "original_log_sha256" => sha(paths.log_path),
        "original_exit_sha256" => sha(paths.exit_path),
        "original_batch_success" => false,
        "solver_control_flow_proof" => proof,
        "raw_sha256" => raw.raw_sha256,
        "checkpoint_records" => raw.checkpoints,
        "physics_audit" => raw.physics,
        "record_audit" => Dict("initial_records" => length(raw.initial.records),
            "averaged_profile_records" => length(raw.profiles.records),
            "series_records" => length(raw.series.records),
            "checkpoint_records" => length(raw.checkpoints),
            "profile_variables" => length(raw.profiles.data),
            "series_variables" => length(raw.series.values),
            "native_w_face_moments" => true, "all_finite" => true),
        "captured_source_sha256" => captured)
end

function audit_saved_science(destination)
    destination = abspath(destination)
    check(!ispath(destination), "refusing to overwrite saved-science evidence")
    check(!startswith(destination, CAMPAIGN * Base.Filesystem.path_separator),
          "supplemental evidence must be outside original campaign")
    check(sha(WRAPPER) == WRAPPER_SHA, "original v1 wrapper differs")
    analysis = pinned_analysis_revision()
    canonical = Neutral.verify_frozen_inputs()
    attempts = [verify_saved_attempt(index, canonical) for index in 1:2]
    report = Dict{String, Any}(
        "schema_version" => 1,
        "mode" => "neutral_7367_saved_scientific_raw_audit_pending_root_acceptance",
        "all_raw_checks_passed" => true,
        "scientific_admission" => false,
        "root_acceptance_required" => true,
        "original_batch_success" => false,
        "original_array_job_id" => JOB_ID,
        "original_campaign" => CAMPAIGN,
        "original_wrapper_path" => WRAPPER,
        "original_wrapper_sha256" => WRAPPER_SHA,
        "source_root" => Neutral.CORE,
        "source_manifest_sha256" => Neutral.CORE_SHA,
        "canonical_registry_sha256" => Neutral.REGISTRY_SHA,
        "combined_gpu_evidence_sha256" => Neutral.COMBINED_SHA,
        "saved_7366_gpu_gate_sha256" => ORIGINAL_7366_GATE_SHA,
        "audit_script_sha256" => sha(@__FILE__),
        "analysis_module_sha256" => sha(joinpath(@__DIR__, "NeutralScientificExport.jl")),
        "analysis_git_commit" => analysis.commit,
        "analysis_source_sha256" => analysis.hashes,
        "created_utc" => string(now(UTC)),
        "attempts" => attempts)
    mkpath(destination)
    evidence_path = joinpath(destination, "neutral_saved_science_audit.toml")
    open(evidence_path, "w") do io
        TOML.print(io, report; sorted=true)
    end
    open(joinpath(destination, "NEUTRAL_SAVED_SCIENCE_AUDIT_DONE"), "w") do io
        println(io, "mode=neutral_7367_saved_scientific_raw_audit_pending_root_acceptance")
        println(io, "original_batch_success=false")
        println(io, "scientific_admission=false")
        println(io, "evidence_sha256=", sha(evidence_path))
    end
    return report
end

function validate_saved_evidence(directory)
    evidence_path = joinpath(directory, "neutral_saved_science_audit.toml")
    done_path = joinpath(directory, "NEUTRAL_SAVED_SCIENCE_AUDIT_DONE")
    check(isfile(evidence_path) && isfile(done_path) &&
          !ispath(joinpath(directory, "NEUTRAL_SAVED_SCIENCE_AUDIT_FAILED")),
          "saved-science evidence missing or failed")
    evidence = TOML.parsefile(evidence_path)
    done = Neutral.parse_fields(done_path)
    check(done["evidence_sha256"] == sha(evidence_path) &&
          done["scientific_admission"] == "false" &&
          evidence["mode"] == "neutral_7367_saved_scientific_raw_audit_pending_root_acceptance" &&
          evidence["all_raw_checks_passed"] === true &&
          evidence["scientific_admission"] === false &&
          evidence["root_acceptance_required"] === true &&
          evidence["original_batch_success"] === false &&
          evidence["original_array_job_id"] == JOB_ID &&
          evidence["source_manifest_sha256"] == Neutral.CORE_SHA &&
          evidence["original_wrapper_sha256"] == WRAPPER_SHA &&
          evidence["audit_script_sha256"] == sha(@__FILE__) &&
          evidence["analysis_module_sha256"] == sha(joinpath(@__DIR__, "NeutralScientificExport.jl")),
          "saved-science evidence identity differs")
    check(sha(WRAPPER) == WRAPPER_SHA, "original wrapper changed")
    analysis = pinned_analysis_revision(expected_commit=evidence["analysis_git_commit"])
    check(analysis.hashes == evidence["analysis_source_sha256"],
          "committed analysis source hashes differ")
    canonical = Neutral.verify_frozen_inputs()
    check(length(evidence["attempts"]) == 2, "saved-science pair count differs")
    for index in 1:2
        fresh = verify_saved_attempt(index, canonical)
        check(fresh == evidence["attempts"][index],
              "saved-science raw/source/exit audit changed for case $index")
    end
    return evidence
end

function validate_root_acceptance(directory)
    evidence = validate_saved_evidence(directory)
    evidence_path = joinpath(directory, "neutral_saved_science_audit.toml")
    acceptance_path = joinpath(directory, "ROOT_ACCEPTANCE.toml")
    check(isfile(acceptance_path), "root has not accepted saved 7367 scientific output")
    acceptance = TOML.parsefile(acceptance_path)
    check(acceptance["schema_version"] == 1 &&
          acceptance["mode"] == "accept_neutral_7367_saved_scientific_output" &&
          acceptance["decision"] ==
              "accept_completed_science_despite_wrapper_postprocessing_failure" &&
          acceptance["accepted_by"] == "Greg" &&
          !isempty(acceptance["accepted_utc"]) &&
          acceptance["original_array_job_id"] == JOB_ID &&
          acceptance["original_batch_success"] === false &&
          acceptance["audit_evidence_sha256"] == sha(evidence_path) &&
          acceptance["source_manifest_sha256"] == Neutral.CORE_SHA &&
          acceptance["original_wrapper_sha256"] == WRAPPER_SHA,
          "root acceptance file is missing a required source/evidence decision binding")
    return (; evidence, acceptance_path, acceptance_sha256=sha(acceptance_path),
            evidence_sha256=sha(evidence_path))
end

function finalize_root_accepted_saved_science(directory, destination)
    check(!ispath(destination), "refusing to overwrite saved-science attempt registry")
    accepted = validate_root_acceptance(directory)
    attempts = Dict{String, Any}[]
    for audit in accepted.evidence["attempts"]
        push!(attempts, Dict{String, Any}(
            "case_id" => audit["case_id"],
            "registry_index" => audit["registry_index"],
            "closure" => audit["closure"],
            "run_directory" => audit["run_directory"],
            "log_path" => audit["original_log_path"],
            "exit_path" => audit["original_exit_path"],
            "log_sha256" => audit["original_log_sha256"],
            "exit_sha256" => audit["original_exit_sha256"],
            "attempt_started_sha256" => audit["original_started_sha256"],
            "case_done_sha256" => audit["original_case_done_sha256"],
            "case_failed_sha256" => audit["original_case_failed_sha256"],
            "original_batch_success" => false,
            "solver_returned_zero_inferred_from_wrapper_branch" => true,
            "raw_sha256" => audit["raw_sha256"],
            "checkpoint_records" => audit["checkpoint_records"],
            "physics_audit" => audit["physics_audit"],
            "captured_source_sha256" => audit["captured_source_sha256"]))
    end
    registry = Dict{String, Any}(
        "schema_version" => 1, "mode" => "neutral_five_hour_scientific_pair",
        "admission_mode" => "root_accepted_saved_scientific_output_v1",
        "array_job_id" => JOB_ID, "campaign_root" => CAMPAIGN,
        "generated_utc" => string(now(UTC)), "expected_cases" => 2,
        "source_root" => Neutral.CORE, "source_manifest_sha256" => Neutral.CORE_SHA,
        "canonical_registry_path" => Neutral.registry_path(),
        "canonical_registry_sha256" => Neutral.REGISTRY_SHA,
        "wrapper_path" => WRAPPER, "wrapper_sha256" => WRAPPER_SHA,
        "supplemental_gate_reader_sha256" => Neutral.GATE_READER_SHA,
        "supplemental_gate_evidence_sha256" => Neutral.SUPPLEMENT_SHA,
        "combined_gpu_evidence_sha256" => Neutral.COMBINED_SHA,
        "original_7366_parent_passed" => false,
        "original_7367_batch_success" => false,
        "saved_science_evidence_directory" => abspath(directory),
        "saved_science_evidence_sha256" => accepted.evidence_sha256,
        "root_acceptance_path" => accepted.acceptance_path,
        "root_acceptance_sha256" => accepted.acceptance_sha256,
        "saved_science_auditor_sha256" => sha(@__FILE__),
        "profiles_expected_times_s" => Neutral.PROFILE_TIMES,
        "series_expected_times_s" => Neutral.SERIES_TIMES,
        "checkpoint_expected_times_s" => Neutral.CHECKPOINT_TIMES,
        "attempts" => attempts)
    mkpath(dirname(destination))
    open(destination, "w") do io
        TOML.print(io, registry; sorted=true)
    end
    return registry
end

end
