#!/usr/bin/env julia

using Dates
using JSON
using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DESTINATION = joinpath(ROOT, "source_snapshots")
const DYCOMS_ROOT = normpath(get(
    ENV, "BREEZE_EVALUATION_DYCOMS_PRODUCTION",
    "/shared/home/greg/review-coordination/dycoms-production-20260919"))
const GABLS1_ROOT = normpath(get(
    ENV, "BREEZE_EVALUATION_GABLS1_PRODUCTION",
    "/shared/home/greg/review-coordination/gabls-production-v2-20260919"))
const BASE_REPOSITORY = "https://github.com/NumericalEarth/Breeze.jl.git"
const BASE_COMMIT = "548e6fb7b6aecc62b7e05ddcf3e422b8dadd9504"

file_sha256(path) = bytes2hex(open(sha256, path))

function capture_file(source_root, source_relative_path, destination_root;
                      destination_relative_path=source_relative_path)
    source = joinpath(source_root, source_relative_path)
    isfile(source) || error("Missing frozen source file $source")
    destination = joinpath(destination_root, destination_relative_path)
    mkpath(dirname(destination))
    cp(source, destination; force=true)
    source_hash = file_sha256(source)
    source_hash == file_sha256(destination) || error("Snapshot copy hash mismatch for $source")
    return Dict(
        "source_relative_path" => source_relative_path,
        "snapshot_relative_path" => destination_relative_path,
        "bytes" => filesize(source),
        "sha256" => source_hash)
end

function capture_snapshot(name, source_root, paths; source_revision)
    destination = joinpath(DESTINATION, name)
    records = Dict{String, Any}[]
    for path in paths
        push!(records, capture_file(source_root, path, destination))
    end
    return Dict(
        "name" => name,
        "source_revision" => source_revision,
        "frozen_source_root_at_capture" => source_root,
        "files" => records)
end

dycoms_paths = [
    "source/SOURCE_ORIGIN.json",
    "source/Project.toml",
    "source/Manifest.toml",
    "source/examples/Project.toml",
    "source/examples/dycoms.jl",
    "source/examples/dycoms_diagnostics.jl",
    "source/src/AtmosphereModels/dycoms_radiation.jl",
    "source/validation_output/dycoms/factorial/dycoms_case.jl",
    "production_cases.json",
    "production.batch",
    "analysis_export/export_completed_cases.jl",
    "analysis_export/verify_export.jl",
    "source_provenance.json",
    "submission.json",
]

gabls1_paths = [
    "source/SOURCE_ORIGIN.json",
    "source/Project.toml",
    "source/Manifest.toml",
    "source/examples/Project.toml",
    "source/examples/gabls_diagnostics.jl",
    "source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl",
    "source/validation_output/gabls/gabls_case.jl",
    "cases.json",
    "gabls-production.batch",
    "submit_gabls_production_v2.sh",
    "export_gabls_case.jl",
    "watch_gabls_exports.jl",
]

gabls1_revision_root = joinpath(GABLS1_ROOT, "revisions", "startup_dt_v1")
gabls1_revision_paths = [
    "source/SOURCE_ORIGIN.json",
    "source/Project.toml",
    "source/Manifest.toml",
    "source/examples/Project.toml",
    "source/examples/gabls_diagnostics.jl",
    "source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl",
    "source/validation_output/gabls/gabls_case.jl",
    "source_revision.json",
    "cases.before-startup_dt_v1.json",
    "replacement_production.batch",
    "activate_replacement_registry.sh",
    "export_gabls_case_revision.jl",
    "watch_gabls_exports_revision.jl",
    "test_watcher_registry_parser.jl",
]

snapshots = [
    capture_snapshot("dycoms", DYCOMS_ROOT, dycoms_paths; source_revision="original"),
    capture_snapshot("gabls1/original", GABLS1_ROOT, gabls1_paths;
                     source_revision="v2_original"),
    capture_snapshot("gabls1/startup_dt_v1", gabls1_revision_root, gabls1_revision_paths;
                     source_revision="startup_dt_v1"),
]

manifest = Dict(
    "schema_version" => 1,
    "generated_utc" => string(now(UTC)),
    "base_repository" => BASE_REPOSITORY,
    "base_commit" => BASE_COMMIT,
    "contract" => "Clone base_commit, then overlay the selected source/ paths from the applicable snapshot. Project and Manifest files pin the resolved Julia environment; scheduler/export files preserve the exact campaign execution contract.",
    "scope_note" => "These snapshots preserve executable case definitions and every known campaign-specific source delta. They do not include raw JLD2 output, checkpoints, logs, or the complete unchanged Breeze tree.",
    "snapshots" => snapshots)
open(joinpath(DESTINATION, "manifest.json"), "w") do io
    JSON.print(io, manifest, 2)
    println(io)
end

snapshot_file_count = sum(length(snapshot["files"]) for snapshot in snapshots)
println("SOURCE_SNAPSHOTS_CAPTURED snapshots=$(length(snapshots)) ",
        "files=$snapshot_file_count")
