# Source-bound analysis finalizer; never submits or runs simulations.
using TOML, SHA
include(joinpath(@__DIR__, "..", "gpu_validation", "admit_factor10.jl"))
using .SurfaceLayerScientificExport: verify_completion, parse_fields

function finalize(root, evidence, job, runs, logs, destination)
    ispath(destination) && error("refusing existing attempt registry")
    all(isdigit, job) || error("invalid array job")
    admit_factor10(evidence, root)
    evaluation = joinpath(root, "source", "BreezeEvaluation.jl")
    registry_relative = "cases/surface_layer/registries/gabls1_sld_factor10.toml"
    scientific_path = joinpath(evaluation, registry_relative)
    scientific = TOML.parsefile(scientific_path)
    wrapper = joinpath(evaluation, "cases/surface_layer/registries/run_factor10.slurm")
    manifest = joinpath(root, "source_sha256.txt")
    readme = read(joinpath(root, "README.md"), String)
    evaluation_commit = match(r"BreezeEvaluation.jl commit: `([0-9a-f]{40})`", readme)[1]
    breeze_commit = match(r"Breeze.jl feature commit: `([0-9a-f]{40})`", readme)[1]
    entries = length(readlines(manifest))
    registry = Dict{String, Any}(
        "schema_version" => 1, "study" => scientific["campaign"], "case_family" => "GABLS1",
        "expected_case_count" => 1, "scientific_registry_relative" => registry_relative,
        "scientific_registry_sha256" => file_sha256(scientific_path),
        "source_freeze_root" => root, "source_freeze_manifest_sha256" => file_sha256(manifest),
        "source_freeze_manifest_entries" => entries, "source_evaluation_commit" => evaluation_commit,
        "source_breeze_commit" => breeze_commit, "gpu_validation_evidence_directory" => evidence,
        "analysis_freeze_root" => root, "analysis_freeze_manifest_sha256" => file_sha256(manifest))
    attempts = Dict{String, Any}[]
    for (index, case) in enumerate(scientific["cases"])
        id = case["case_id"]
        directory = joinpath(runs, id)
        completed = verify_completion(directory, id)
        completed["started"]["registry"] == scientific_path || error("wrong scientific registry")
        completed["started"]["registry_index"] == string(index) || error("wrong registry index")
        log = joinpath(logs, "gabls1_factor10_$(job).out")
        exit_path = joinpath(logs, "gabls1_factor10_$(job).exit")
        exit_record = parse_fields(exit_path)
        length(readlines(exit_path)) == 10 || error("wrong exit record size")
        exit_record["batch_job_id"] == job && exit_record["case_index"] == string(index) || error("wrong exit identity")
        exit_record["child_exit_code"] == "0" && exit_record["record_complete"] == "true" || error("batch failed or incomplete")
        exit_record["source_manifest_sha256"] == file_sha256(manifest) || error("wrong exit source")
        exit_record["wrapper_sha256"] == file_sha256(wrapper) || error("wrong exit wrapper")
        exit_record["gpu_evidence_directory"] == evidence || error("wrong exit GPU evidence")
        text = read(log, String)
        occursin("SLD_REGISTERED_CASE_DONE case_id=$id", text) || error("missing case completion log")
        occursin("SLD_FACTOR10_BATCH_EXIT job=$job case=$index child_exit_code=0 record=$exit_path", text) || error("missing durable-exit log")
        occursin("CASE_FAILED", text) && error("failure in log")
        push!(attempts, Dict{String, Any}(
            "case_id" => id, "registry_index" => index, "resolved_flux_factor" => case["resolved_flux_factor"],
            "active_attempt_id" => "slurm-$job-$index", "active" => true,
            "attempt_state" => "completed_candidate", "scientific_candidate" => true, "fixture_kind" => "none",
            "run_directory" => directory, "log_path" => log, "job_spec" => job,
            "log_sha256" => file_sha256(log), "attempt_started_sha256" => file_sha256(joinpath(directory, "ATTEMPT_STARTED")),
            "case_done_sha256" => file_sha256(joinpath(directory, "CASE_DONE")),
            "batch_exit_record_path" => exit_path, "batch_exit_record_sha256" => file_sha256(exit_path),
            "batch_child_exit_code" => 0, "batch_slurm_job_id" => exit_record["slurm_job_id"],
            "launch_wrapper_path" => wrapper, "launch_wrapper_sha256" => file_sha256(wrapper)))
    end
    registry["attempts"] = attempts
    open(io -> TOML.print(io, registry; sorted=true), destination, "w")
    println("FACTOR_ATTEMPTS_FINALIZED sha256=", file_sha256(destination))
end
if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 6 || error("usage: finalize_resolved_factor_attempts.jl FREEZE EVIDENCE ARRAY_JOB RUNS LOGS NEW_ATTEMPTS.toml")
    finalize(abspath(ARGS[1]), abspath(ARGS[2]), ARGS[3], abspath.(ARGS[4:6])...)
end
