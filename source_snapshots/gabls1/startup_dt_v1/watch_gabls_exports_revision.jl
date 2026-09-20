#!/usr/bin/env julia

using Dates
using JSON

const JULIA = "/shared/home/greg/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia"
const ROOT = normpath(get(ARGS, 1,
    "/shared/home/greg/review-coordination/gabls-production-20260919"))
const CASES_PATH = get(ENV, "GABLS_WATCHER_REGISTRY_PATH", joinpath(ROOT, "cases.json"))
const REVISION_ROOT = joinpath(ROOT, "revisions", "startup_dt_v1")
const EXPORTER = joinpath(REVISION_ROOT, "export_gabls_case_revision.jl")
const EXPORT_ROOT = joinpath(ROOT, "analysis_export")
const STATUS_PATH = "/shared/home/greg/review-coordination/gabls-export-status.json"
const LOG_PATH = joinpath(ROOT, "export_watcher.log")
const POLL_SECONDS = 60
const HEARTBEAT_SECONDS = 600

const CASE_IDS = [
    "n$(lpad(nx, 3, '0'))_$(suffix)"
    for nx in (32, 64, 128, 200, 400)
    for suffix in ("weno9_none", "weno5_none", "weno9_smagorinsky")
]

json_escape(value) = replace(string(value), '\\' => "\\\\", '"' => "\\\"",
                             '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")

function write_json(io, value; indent=0)
    if value === nothing
        print(io, "null")
    elseif value isa Bool
        print(io, value ? "true" : "false")
    elseif value isa Integer || value isa AbstractFloat
        print(io, value)
    elseif value isa AbstractString || value isa Symbol
        print(io, '"', json_escape(value), '"')
    elseif value isa AbstractDict
        entries = sort!(collect(pairs(value)); by=p -> string(first(p)))
        println(io, "{")
        for (n, (key, item)) in enumerate(entries)
            print(io, " "^(indent + 2), '"', json_escape(key), "\": ")
            write_json(io, item; indent=indent + 2)
            print(io, n == length(entries) ? "\n" : ",\n")
        end
        print(io, repeat(" ", indent), "}")
    elseif value isa AbstractVector || value isa Tuple
        print(io, "[")
        for (n, item) in enumerate(value)
            n > 1 && print(io, ", ")
            write_json(io, item; indent)
        end
        print(io, "]")
    else
        error("Cannot JSON-encode $(typeof(value))")
    end
end

function log_message(message)
    line = "$(now(UTC)) $message"
    println(line)
    open(LOG_PATH, "a") do io
        println(io, line)
    end
end

string_or_nothing(value) = isnothing(value) ? nothing : string(value)

function integer_or_nothing(value)
    isnothing(value) && return nothing
    value isa Integer && return Int(value)
    return parse(Int, string(value))
end

function source_hashes_from_mapping(object)
    object isa AbstractDict || return Dict{String, Any}()
    hashes = Dict{String, Any}()
    for key in ("root_Manifest.toml", "gabls_diagnostics.jl", "gabls_case.jl",
                "gabls_rough_wall_coefficient.jl")
        value = get(object, key, nothing)
        isnothing(value) || (hashes[key] = string(value))
    end
    return hashes
end

function read_registry()
    isfile(CASES_PATH) || return Dict{String, Any}()
    document = JSON.parsefile(CASES_PATH)
    cases = get(document, "cases", nothing)
    cases isa AbstractVector || error("cases.json must contain a top-level cases array")
    registry = Dict{String, Any}()
    for object in cases
        object isa AbstractDict || error("Each cases entry must be an object")
        case_id = string_or_nothing(get(object, "case_id", nothing))
        isnothing(case_id) && continue
        # Every active value below is obtained by a direct lookup on the case object.
        # Nested attempt_history entries therefore cannot satisfy current-run checks.
        job_id = string_or_nothing(get(object, "array_job_id", get(object, "job_id", nothing)))
        task = integer_or_nothing(get(object, "array_task_id", nothing))
        log_path = string_or_nothing(get(object, "log", get(object, "log_path", nothing)))
        run_path = string_or_nothing(get(object, "root", get(object, "run_path", nothing)))
        source_revision = string_or_nothing(get(object, "source_revision", nothing))
        source_hashes = source_hashes_from_mapping(get(object, "source_hashes", nothing))
        attempt_history = get(object, "attempt_history", Any[])
        attempt_history isa AbstractVector || error("attempt_history for $case_id must be an array")
        registry[case_id] = (; job_id, task, log_path, run_path, source_revision,
                              source_hashes, attempt_history)
    end
    return registry
end

function verified_manifest(case_id)
    path = joinpath(EXPORT_ROOT, case_id, "manifest.json")
    isfile(path) || return false, false
    manifest = JSON.parsefile(path)
    verified = get(manifest, "export_verified", false) === true
    hashes = get(manifest, "source_hashes_checked", false) === true
    return verified, hashes
end

function publish_status(registry)
    registry_document = JSON.parsefile(CASES_PATH)
    global_source_hashes = source_hashes_from_mapping(get(registry_document, "source_hashes", nothing))
    entries = Any[]
    verified_count = 0
    for case_id in CASE_IDS
        verified, hashes = verified_manifest(case_id)
        verified_count += verified
        record = Dict{String, Any}(
            "case_id" => case_id,
            "export_verified" => verified,
            "source_hashes_checked" => hashes)
        if haskey(registry, case_id)
            case_record = registry[case_id]
            record["job_id"] = case_record.job_id
            record["array_task_id"] = case_record.task
            record["log_path"] = case_record.log_path
            record["run_path"] = case_record.run_path
            if !isnothing(case_record.source_revision)
                record["source_revision"] = case_record.source_revision
                record["source_hashes"] = case_record.source_hashes
                record["attempt_history"] = case_record.attempt_history
            end
        end
        push!(entries, record)
    end
    status = Dict{String, Any}(
        "schema_version" => 2,
        "updated_utc" => string(now(UTC)),
        "production_root" => ROOT,
        "expected_cases" => length(CASE_IDS),
        "verified_cases" => verified_count,
        "global_source_hashes" => global_source_hashes,
        "profile_record_semantics" => Dict(
            "record_times_s" => "0:1800:32400; t=0 instantaneous, subsequent records true preceding-1800-s means",
            "final_hour_source_times_s" => [30600, 32400],
            "penultimate_hour_source_times_s" => [27000, 28800]),
        "cases" => entries,
        "admission_rule" => "export_verified=true only after both sentinels, queue absence, full record/finite/coordinate audit, and matching frozen source hashes")
    temporary = STATUS_PATH * ".tmp"
    open(temporary, "w") do io
        write_json(io, status); println(io)
    end
    mv(temporary, STATUS_PATH; force=true)
    return verified_count
end

function scheduler_absent(job_spec)
    state = strip(read(pipeline(ignorestatus(`squeue -h -j $job_spec -o %T`),
                                stderr=devnull), String))
    return isempty(state)
end

function ready(case_id, record)
    isnothing(record.job_id) && return false, "job_id absent"
    isnothing(record.log_path) && return false, "log path absent"
    log_path = isabspath(record.log_path) ? record.log_path : joinpath(ROOT, record.log_path)
    isfile(log_path) || return false, "log absent"
    log = read(log_path, String)
    occursin("CASE_DONE $case_id ", log) || return false, "CASE_DONE absent"
    occursin("GABLS_CASE_EXIT_SUCCESS", log) || return false, "success sentinel absent"
    job_spec = isnothing(record.task) ? record.job_id : "$(record.job_id)_$(record.task)"
    scheduler_absent(job_spec) || return false, "still queued/running"
    isnothing(record.run_path) && return false, "run path absent"
    run_path = isabspath(record.run_path) ? record.run_path : joinpath(ROOT, record.run_path)
    isfile(joinpath(run_path, "$(case_id)_diag_statistics.jld2")) ||
        return false, "statistics absent"
    isfile(joinpath(run_path, "$(case_id)_diag_series.jld2")) ||
        return false, "series absent"
    return true, (log_path, job_spec, run_path)
end

if get(ENV, "GABLS_WATCHER_PARSE_ONLY", "0") == "1"
    registry = read_registry()
    println("GABLS_WATCHER_REGISTRY_CASES ", length(registry))
    println("GABLS_WATCHER_EXPECTED_CASES ", length(CASE_IDS))
    first_record = registry[first(CASE_IDS)]
    first_job_spec = isnothing(first_record.task) ? first_record.job_id :
                     "$(first_record.job_id)_$(first_record.task)"
    println("GABLS_WATCHER_FIRST_JOB_SPEC ", first_job_spec)
    inspect_case = get(ENV, "GABLS_WATCHER_INSPECT_CASE", "")
    if !isempty(inspect_case)
        haskey(registry, inspect_case) || error("Requested inspection case $inspect_case is absent")
        record = registry[inspect_case]
        job_spec = isnothing(record.task) ? record.job_id : "$(record.job_id)_$(record.task)"
        inspection = Dict{String, Any}(
            "case_id" => inspect_case,
            "job_spec" => job_spec,
            "log_path" => record.log_path,
            "run_path" => record.run_path,
            "source_revision" => record.source_revision,
            "source_hashes" => record.source_hashes,
            "attempt_history" => record.attempt_history)
        print("GABLS_WATCHER_INSPECT ")
        JSON.print(stdout, inspection)
        println()
    end
    println(join(sort!(collect(keys(registry))), '\n'))
    missing = setdiff(CASE_IDS, collect(keys(registry)))
    isempty(missing) || println("GABLS_WATCHER_MISSING_CASES ", join(missing, ','))
    exit(isempty(missing) ? 0 : 1)
end

mkpath(EXPORT_ROOT)
isfile(EXPORTER) || error("Missing exporter $EXPORTER")
last_heartbeat = Ref(0.0)
log_message("GABLS export watcher started; polling every $(POLL_SECONDS)s")

while true
    registry = read_registry()
    for case_id in CASE_IDS
        verified, _ = verified_manifest(case_id)
        verified && continue
        haskey(registry, case_id) || continue
        admitted, detail = ready(case_id, registry[case_id])
        admitted || continue
        log_path, job_spec, run_path = detail
        source_revision = isnothing(registry[case_id].source_revision) ?
                          "v2_original" : registry[case_id].source_revision
        source_dir = source_revision == "v2_original" ? joinpath(ROOT, "source") :
                     joinpath(ROOT, "revisions", source_revision, "source")
        registry_document = JSON.parsefile(CASES_PATH)
        global_hashes = source_hashes_from_mapping(get(registry_document, "source_hashes", nothing))
        declared_hashes = isempty(registry[case_id].source_hashes) ?
                          global_hashes : registry[case_id].source_hashes
        required_hash_keys = ("root_Manifest.toml", "gabls_diagnostics.jl", "gabls_case.jl",
                              "gabls_rough_wall_coefficient.jl")
        all(haskey(declared_hashes, key) for key in required_hash_keys) ||
            error("Missing declared source hashes for $case_id")
        manifest_sha = declared_hashes["root_Manifest.toml"]
        diagnostics_sha = declared_hashes["gabls_diagnostics.jl"]
        runner_sha = declared_hashes["gabls_case.jl"]
        surface_sha = declared_hashes["gabls_rough_wall_coefficient.jl"]
        project = joinpath(source_dir, "examples")
        command = `$JULIA --project=$project $EXPORTER $ROOT $case_id $log_path $job_spec $run_path $source_dir $source_revision $manifest_sha $diagnostics_sha $runner_sha $surface_sha`
        log_message("exporting $case_id")
        process = open(LOG_PATH, "a") do io
            run(pipeline(ignorestatus(command), stdout=io, stderr=io); wait=true)
        end
        if success(process)
            log_message("export verified $case_id")
        else
            log_message("export failed $case_id; will retry after next poll")
        end
    end

    verified_count = publish_status(registry)
    verified_count == length(CASE_IDS) && begin
        log_message("all $(length(CASE_IDS)) GABLS exports verified; watcher exiting")
        break
    end
    current_time = time()
    if current_time - last_heartbeat[] >= HEARTBEAT_SECONDS
        log_message("heartbeat verified=$verified_count/$(length(CASE_IDS)) registry=$(length(registry))")
        last_heartbeat[] = current_time
    end
    sleep(POLL_SECONDS)
end
