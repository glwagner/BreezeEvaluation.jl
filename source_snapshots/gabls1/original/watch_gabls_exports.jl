#!/usr/bin/env julia

using Dates

const JULIA = "/shared/home/greg/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia"
const ROOT = normpath(get(ARGS, 1,
    "/shared/home/greg/review-coordination/gabls-production-20260919"))
const CASES_PATH = joinpath(ROOT, "cases.json")
const EXPORTER = joinpath(ROOT, "export_gabls_case.jl")
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

function json_string(object, key)
    match_result = match(Regex("\\\"$key\\\"\\s*:\\s*\\\"([^\\\"]*)\\\""), object)
    return isnothing(match_result) ? nothing : only(match_result.captures)
end

function json_integer(object, key)
    match_result = match(Regex("\\\"$key\\\"\\s*:\\s*([0-9]+)"), object)
    return isnothing(match_result) ? nothing : parse(Int, only(match_result.captures))
end

function case_objects(content)
    cases_key = findfirst("\"cases\"", content)
    isnothing(cases_key) && return String[]
    array_start = findnext('[', content, last(cases_key))
    isnothing(array_start) && return String[]

    objects = String[]
    depth = 0
    object_start = nothing
    in_string = false
    escaped = false
    index = nextind(content, array_start)
    while index <= lastindex(content)
        character = content[index]
        if in_string
            if escaped
                escaped = false
            elseif character == '\\'
                escaped = true
            elseif character == '"'
                in_string = false
            end
        elseif character == '"'
            in_string = true
        elseif character == '{'
            depth == 0 && (object_start = index)
            depth += 1
        elseif character == '}'
            depth -= 1
            depth < 0 && error("Malformed cases.json object nesting")
            if depth == 0 && !isnothing(object_start)
                push!(objects, content[object_start:index])
                object_start = nothing
            end
        elseif character == ']' && depth == 0
            break
        end
        index = nextind(content, index)
    end
    depth == 0 || error("Unclosed case object in cases.json")
    return objects
end

function read_registry()
    isfile(CASES_PATH) || return Dict{String, Any}()
    content = read(CASES_PATH, String)
    registry = Dict{String, Any}()
    for object in case_objects(content)
        case_id = json_string(object, "case_id")
        isnothing(case_id) && continue
        # Prefer the parent array ID. Some registries also store a task-qualified
        # `job_id` such as `7088_1`; `ready` appends `array_task_id` itself.
        job_id = json_string(object, "array_job_id")
        if isnothing(job_id)
            integer_job = json_integer(object, "array_job_id")
            job_id = isnothing(integer_job) ? nothing : string(integer_job)
        end
        isnothing(job_id) && (job_id = json_string(object, "job_id"))
        if isnothing(job_id)
            integer_job = json_integer(object, "job_id")
            job_id = isnothing(integer_job) ? nothing : string(integer_job)
        end
        task = json_integer(object, "array_task_id")
        log_path = json_string(object, "log_path")
        isnothing(log_path) && (log_path = json_string(object, "log"))
        run_path = json_string(object, "run_path")
        isnothing(run_path) && (run_path = json_string(object, "root"))
        registry[case_id] = (; job_id, task, log_path, run_path)
    end
    return registry
end

function verified_manifest(case_id)
    path = joinpath(EXPORT_ROOT, case_id, "manifest.json")
    isfile(path) || return false, false
    content = read(path, String)
    verified = occursin(r"\"export_verified\"\s*:\s*true", content)
    hashes = occursin(r"\"source_hashes_checked\"\s*:\s*true", content)
    return verified, hashes
end

function publish_status(registry)
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
        end
        push!(entries, record)
    end
    status = Dict{String, Any}(
        "schema_version" => 1,
        "updated_utc" => string(now(UTC)),
        "production_root" => ROOT,
        "expected_cases" => length(CASE_IDS),
        "verified_cases" => verified_count,
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
    isfile(joinpath(ROOT, "runs", case_id, "$(case_id)_diag_statistics.jld2")) ||
        return false, "statistics absent"
    isfile(joinpath(ROOT, "runs", case_id, "$(case_id)_diag_series.jld2")) ||
        return false, "series absent"
    return true, (log_path, job_spec)
end

if get(ENV, "GABLS_WATCHER_PARSE_ONLY", "0") == "1"
    registry = read_registry()
    println("GABLS_WATCHER_REGISTRY_CASES ", length(registry))
    println("GABLS_WATCHER_EXPECTED_CASES ", length(CASE_IDS))
    first_record = registry[first(CASE_IDS)]
    first_job_spec = isnothing(first_record.task) ? first_record.job_id :
                     "$(first_record.job_id)_$(first_record.task)"
    println("GABLS_WATCHER_FIRST_JOB_SPEC ", first_job_spec)
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
        log_path, job_spec = detail
        project = joinpath(ROOT, "source", "examples")
        command = `$JULIA --project=$project $EXPORTER $ROOT $case_id $log_path $job_spec`
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
