#!/usr/bin/env julia

using JSON
using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CAMPAIGN = joinpath(ROOT, "campaigns", "dycoms")

file_sha256(path) = bytes2hex(open(sha256, path))

function csv_header_and_times(path)
    open(path, "r") do io
        header = split(readline(io), ',')
        time_index = findfirst(==("time_s"), header)
        isnothing(time_index) && error("Missing time_s in $path")
        times = Float64[]
        for line in eachline(io)
            isempty(line) && continue
            push!(times, parse(Float64, split(line, ',')[time_index]))
        end
        return header, times
    end
end

function profile_inventory(path)
    open(path, "r") do io
        header = split(readline(io), ',')
        time_index = something(findfirst(==("time_s"), header))
        variable_index = something(findfirst(==("variable"), header))
        times = Set{Float64}()
        variables = Set{String}()
        rows = 0
        for line in eachline(io)
            isempty(line) && continue
            fields = split(line, ',')
            push!(times, parse(Float64, fields[time_index]))
            push!(variables, fields[variable_index])
            rows += 1
        end
        return sort!(collect(times)), variables, rows
    end
end

function verify_cases(root, expected_case_count, expected_series_times,
                      expected_profile_times, expected_profile_variables)
    directories = sort!(filter(directory ->
        isdir(directory) && isfile(joinpath(directory, "manifest.json")),
        readdir(root; join=true)))
    length(directories) == expected_case_count ||
        error("Expected $expected_case_count cases under $root, found $(length(directories))")
    total_profile_rows = 0
    for directory in directories
        manifest = JSON.parsefile(joinpath(directory, "manifest.json"))
        manifest["record_audit"]["series"]["all_finite"] === true ||
            error("Non-finite series audit in $directory")
        manifest["record_audit"]["profiles"]["all_finite"] === true ||
            error("Non-finite profile audit in $directory")
        manifest["artifact_kind"] == "derived_compact_comparison_subset" ||
            error("Missing derived-subset label in $directory")
        manifest["export_verified"] === false ||
            error("Compact subset must not pass full-export admission in $directory")
        manifest["full_campaign_admission"] === false ||
            error("Compact subset marked admissible in $directory")
        isfile(joinpath(directory, "source_manifest.json")) ||
            error("Missing original source manifest in $directory")
        _, series_times = csv_header_and_times(joinpath(directory, "series.csv"))
        series_times == expected_series_times || error("Unexpected series times in $directory")
        profile_times, variables, rows = profile_inventory(joinpath(directory, "profiles.csv"))
        profile_times == expected_profile_times || error("Unexpected profile times in $directory")
        length(variables) == expected_profile_variables ||
            error("Unexpected profile-variable count in $directory")
        manifest["compact_migration"]["retained_profile_times_s"] == expected_profile_times ||
            error("Compact-migration metadata mismatch in $directory")
        for (name, expected) in manifest["output_sha256"]
            path = joinpath(directory, name)
            isfile(path) || error("Missing hashed output $path")
            file_sha256(path) == expected || error("Output hash mismatch for $path")
        end
        total_profile_rows += rows
    end
    return length(directories), total_profile_rows
end

dycoms_cases, dycoms_rows = verify_cases(
    joinpath(CAMPAIGN, "simulation_data"), 15, collect(0.:60.:14400.),
    [9000., 10800., 12600., 14400.], 46)
gabls_cases, gabls_rows = verify_cases(
    joinpath(CAMPAIGN, "gabls", "simulation_data"), 13, collect(0.:60.:32400.),
    [27000., 28800., 30600., 32400.], 44)

migration = JSON.parsefile(joinpath(ROOT, "provenance", "legacy_migration.json"))
for entry in migration["destination_tree"]
    path = joinpath(CAMPAIGN, entry["relative_path"])
    isfile(path) || error("Missing migrated file $path")
    filesize(path) == entry["bytes"] || error("Size mismatch for $path")
    file_sha256(path) == entry["sha256"] || error("Hash mismatch for $path")
end

for relative_path in (
    "breeze_les_master.pdf",
    "dycoms_section.pdf",
    "gabls/gabls_section.pdf",
    "gabls3/gabls3_section.pdf",
    "gabls3/reference.md",
    "gabls3/workflow.md",
)
    isfile(joinpath(CAMPAIGN, relative_path)) || error("Missing report artifact $relative_path")
end
for prohibited in ("mwre-mwr2930.1.pdf", "pressel2017/pressel2017.pdf", "gabls/beare2006.pdf")
    !isfile(joinpath(CAMPAIGN, prohibited)) || error("Third-party PDF was versioned: $prohibited")
end

source_manifest = JSON.parsefile(joinpath(ROOT, "source_snapshots", "manifest.json"))
source_manifest["base_commit"] == "548e6fb7b6aecc62b7e05ddcf3e422b8dadd9504" ||
    error("Unexpected Breeze base revision")
snapshot_hashes = Dict{Tuple{String, String}, String}()
for snapshot in source_manifest["snapshots"], entry in snapshot["files"]
    path = joinpath(ROOT, "source_snapshots", snapshot["name"],
                    entry["snapshot_relative_path"])
    isfile(path) || error("Missing source snapshot file $path")
    filesize(path) == entry["bytes"] || error("Source snapshot size mismatch for $path")
    file_sha256(path) == entry["sha256"] || error("Source snapshot hash mismatch for $path")
    snapshot_hashes[(snapshot["name"], entry["snapshot_relative_path"])] = entry["sha256"]
end
snapshot_hashes[("gabls1/original", "source/validation_output/gabls/gabls_case.jl")] ==
    "66f4c3351ecfdcfe19164ce2146ade842824d7c95b700c668e7a25e9c791be01" ||
    error("Unexpected original GABLS1 runner")
snapshot_hashes[("gabls1/startup_dt_v1", "source/validation_output/gabls/gabls_case.jl")] ==
    "8d408477905868429fcd3a7defba2428984cb2efcf461450ace5bbb2b2f4140a" ||
    error("Unexpected startup_dt_v1 GABLS1 runner")
for snapshot in ("gabls1/original", "gabls1/startup_dt_v1")
    snapshot_hashes[(snapshot, "source/examples/gabls_diagnostics.jl")] ==
        "6486c8ccd94f45df1c204fc57d1f3c0a79b8c4f3c27b3412c1b2bb81573e0c24" ||
        error("Unexpected GABLS1 diagnostics in $snapshot")
    snapshot_hashes[(snapshot, "source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl")] ==
        "5af7df039cf665817cd5ca0a9d48dca6d28bbae3bc300f3c5e79bd982aee20c3" ||
        error("Unexpected GABLS1 surface law in $snapshot")
    snapshot_hashes[(snapshot, "source/Manifest.toml")] ==
        "9a410126b4340c4e2c17838e4c920df94d376e3852815b9db09033c01cd8a9fc" ||
        error("Unexpected GABLS1 Manifest in $snapshot")
end

tree_file_count = length(migration["destination_tree"])
source_file_count = sum(length(snapshot["files"]) for snapshot in source_manifest["snapshots"])
println("MIGRATED_CAMPAIGNS_VERIFIED ",
        "dycoms_cases=$dycoms_cases dycoms_profile_rows=$dycoms_rows ",
        "gabls1_cases=$gabls_cases gabls1_profile_rows=$gabls_rows ",
        "tree_files=$tree_file_count source_files=$source_file_count")
