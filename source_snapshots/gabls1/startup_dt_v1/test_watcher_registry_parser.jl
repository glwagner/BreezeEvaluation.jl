#!/usr/bin/env julia

using JSON
using SHA
using Test

const ROOT = "/shared/home/greg/review-coordination/gabls-production-v2-20260919"
const REVISION_ROOT = joinpath(ROOT, "revisions", "startup_dt_v1")
const WATCHER = joinpath(REVISION_ROOT, "watch_gabls_exports_revision.jl")
const JULIA = "/shared/home/greg/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia"
const PROJECT = joinpath(REVISION_ROOT, "source", "benchmarking")

function inspect_fixture(fixture, case_id)
    environment = copy(ENV)
    environment["GABLS_WATCHER_PARSE_ONLY"] = "1"
    environment["GABLS_WATCHER_REGISTRY_PATH"] = fixture
    environment["GABLS_WATCHER_INSPECT_CASE"] = case_id
    command = setenv(`$JULIA --startup-file=no --project=$PROJECT $WATCHER $ROOT`, environment)
    output = read(command, String)
    prefix = "GABLS_WATCHER_INSPECT "
    lines = filter(line -> startswith(line, prefix), split(output, '\n'))
    length(lines) == 1 || error("Expected one inspection line, got $(length(lines))")
    return JSON.parse(replace(only(lines), prefix => ""; count=1))
end

function file_sha256(path)
    return bytes2hex(open(sha256, path))
end

registry = JSON.parsefile(joinpath(ROOT, "cases.json"))
replacement_cases = Dict(
    "n400_weno9_none" => Dict(
        "job_spec" => "7120_1",
        "log_path" => joinpath(REVISION_ROOT, "logs", "replacement-7120_1.log"),
        "run_path" => joinpath(REVISION_ROOT, "runs", "n400_weno9_none")),
    "n400_weno9_smagorinsky" => Dict(
        "job_spec" => "7120_2",
        "log_path" => joinpath(REVISION_ROOT, "logs", "replacement-7120_2.log"),
        "run_path" => joinpath(REVISION_ROOT, "runs", "n400_weno9_smagorinsky")))

source_paths = Dict(
    "root_Manifest.toml" => joinpath(REVISION_ROOT, "source", "Manifest.toml"),
    "gabls_diagnostics.jl" => joinpath(REVISION_ROOT, "source", "examples", "gabls_diagnostics.jl"),
    "gabls_case.jl" => joinpath(REVISION_ROOT, "source", "validation_output", "gabls", "gabls_case.jl"),
    "gabls_rough_wall_coefficient.jl" => joinpath(REVISION_ROOT, "source", "src", "BoundaryConditions", "gabls_rough_wall_coefficient.jl"))

@testset "watcher selects only top-level active attempt" begin
    mktempdir() do temporary_directory
        for (case_id, expected) in replacement_cases
            fixture_document = deepcopy(registry)
            case_index = findfirst(case -> case["case_id"] == case_id, fixture_document["cases"])
            @test !isnothing(case_index)
            case_object = fixture_document["cases"][case_index]
            case_object["attempt_history"] = [Dict(
                "array_job_id" => 999001,
                "job_id" => "999001_9",
                "array_task_id" => 9,
                "log" => "/wrong/nested/current-name.log",
                "log_path" => "/wrong/nested/history.log",
                "root" => "/wrong/nested/current-name-root",
                "run_path" => "/wrong/nested/history-root",
                "source_revision" => "wrong_nested_revision",
                "source_hashes" => Dict(key => repeat("0", 64) for key in keys(source_paths)))]

            fixture = joinpath(temporary_directory, "$case_id.json")
            open(fixture, "w") do io
                JSON.print(io, fixture_document, 2)
            end
            inspected = inspect_fixture(fixture, case_id)

            @test inspected["job_spec"] == expected["job_spec"]
            @test inspected["log_path"] == expected["log_path"]
            @test inspected["run_path"] == expected["run_path"]
            @test inspected["source_revision"] == "startup_dt_v1"
            for (role, path) in source_paths
                @test inspected["source_hashes"][role] == file_sha256(path)
                @test inspected["source_hashes"][role] != repeat("0", 64)
            end
        end
    end
end
