#!/usr/bin/env julia

using Dates
using JSON
using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOURCE = normpath(get(ENV, "BREEZE_EVALUATION_LEGACY_REFERENCE",
                            "/shared/home/greg/review-coordination/dycoms-reference"))
const DESTINATION = joinpath(ROOT, "campaigns", "dycoms")
const MIGRATION_RECORDS = Dict{String, Any}[]

file_sha256(path) = bytes2hex(open(sha256, path))

function copy_audited(relative_path; destination_relative_path=relative_path)
    source = joinpath(SOURCE, relative_path)
    destination = joinpath(DESTINATION, destination_relative_path)
    isfile(source) || error("Missing migration source $source")
    mkpath(dirname(destination))
    cp(source, destination; force=true)
    push!(MIGRATION_RECORDS, Dict(
        "source_relative_path" => relative_path,
        "destination_relative_path" => destination_relative_path,
        "bytes" => filesize(source),
        "source_sha256" => file_sha256(source),
        "destination_sha256" => file_sha256(destination),
        "transformation" => "byte copy"))
    return destination
end

function profile_time_index(header)
    fields = split(header, ',')
    index = findfirst(==("time_s"), fields)
    isnothing(index) && error("profiles.csv has no time_s column")
    return index
end

function compact_profiles(source, destination, retained_times)
    mkpath(dirname(destination))
    source_hash = file_sha256(source)
    source_records = 0
    retained_records = 0
    open(source, "r") do input
        header = readline(input)
        time_index = profile_time_index(header)
        open(destination, "w") do output
            println(output, header)
            for line in eachline(input)
                source_records += 1
                fields = split(line, ',')
                time_s = parse(Float64, fields[time_index])
                if time_s in retained_times
                    println(output, line)
                    retained_records += 1
                end
            end
        end
    end
    push!(MIGRATION_RECORDS, Dict(
        "source_relative_path" => relpath(source, SOURCE),
        "destination_relative_path" => relpath(destination, DESTINATION),
        "bytes" => filesize(destination),
        "source_sha256" => source_hash,
        "destination_sha256" => file_sha256(destination),
        "source_data_rows" => source_records,
        "retained_data_rows" => retained_records,
        "retained_profile_times_s" => sort!(collect(retained_times)),
        "transformation" => "CSV row subset by exact time_s; header unchanged"))
end

function compact_case(source_directory, destination_directory, retained_times;
                      copy_names=String[])
    mkpath(destination_directory)
    source_manifest_path = joinpath(source_directory, "manifest.json")
    source_manifest = JSON.parsefile(source_manifest_path)
    cp(source_manifest_path, joinpath(destination_directory, "source_manifest.json"); force=true)
    for name in copy_names
        source = joinpath(source_directory, name)
        isfile(source) || continue
        cp(source, joinpath(destination_directory, name); force=true)
    end
    compact_profiles(joinpath(source_directory, "profiles.csv"),
                     joinpath(destination_directory, "profiles.csv"), retained_times)

    manifest = deepcopy(source_manifest)
    manifest["artifact_kind"] = "derived_compact_comparison_subset"
    manifest["source_export_verified"] = get(source_manifest, "export_verified", nothing)
    manifest["export_verified"] = false
    manifest["full_campaign_admission"] = false
    manifest["source_record_audit"] = deepcopy(source_manifest["record_audit"])
    manifest["record_audit"]["profiles"]["records"] = length(retained_times)
    manifest["record_audit"]["profiles"]["times_s"] = sort!(collect(retained_times))
    manifest["compact_migration"] = Dict(
        "generated_utc" => string(now(UTC)),
        "source_profiles_sha256" => file_sha256(joinpath(source_directory, "profiles.csv")),
        "retained_profile_times_s" => sort!(collect(retained_times)),
        "full_profile_history_versioned" => false,
        "admission_note" => "Derived subset for fixed comparison windows; retrieve the full profiles.csv and use source_manifest.json for campaign admission and complete plot regeneration.",
        "source_manifest" => "source_manifest.json")
    output_names = filter(name -> isfile(joinpath(destination_directory, name)),
                          unique(vcat(copy_names, ["profiles.csv"])))
    manifest["output_sha256"] = Dict(
        name => file_sha256(joinpath(destination_directory, name)) for name in output_names)
    open(joinpath(destination_directory, "manifest.json"), "w") do io
        JSON.print(io, manifest, 2)
        println(io)
    end
end

for path in (
    "README.md", "experiment_matrix.json", "report_methods.md", "report_workflow.md",
    "simulation_status.md", "breeze_les_master.md", "breeze_les_master.html",
    "breeze_les_master.pdf", "dycoms_report.md", "dycoms_report.html", "dycoms_report.pdf",
    "dycoms_section.md", "dycoms_section.html", "dycoms_section.pdf",
    "paper_reference.md", "figure_data.md", "gpu_model_probe.json",
    "cluster/production_cases.json", "cluster/run_status.json",
    "cluster/source_provenance.json", "cluster/submission.json")
    isfile(joinpath(SOURCE, path)) && copy_audited(path)
end

for directory in ("data", "pressel2017/data")
    source_directory = joinpath(SOURCE, directory)
    for (path, _, names) in walkdir(source_directory), name in names
        startswith(name, "._") && continue
        extension = lowercase(splitext(name)[2])
        extension in (".csv", ".json") || continue
        copy_audited(relpath(joinpath(path, name), SOURCE))
    end
end

for path in ("pressel2017/reference.md", "pressel2017/reference.html")
    copy_audited(path)
end

for (path, _, names) in walkdir(joinpath(SOURCE, "report_figures")), name in names
    startswith(name, "._") && continue
    lowercase(splitext(name)[2]) in (".png", ".svg", ".pdf", ".json") || continue
    copy_audited(relpath(joinpath(path, name), SOURCE))
end

dycoms_source = joinpath(SOURCE, "simulation_data")
dycoms_destination = joinpath(DESTINATION, "simulation_data")
for source_directory in filter(isdir, readdir(dycoms_source; join=true))
    isfile(joinpath(source_directory, "manifest.json")) || continue
    destination_directory = joinpath(dycoms_destination, basename(source_directory))
    compact_case(source_directory, destination_directory,
                 Set([9000.0, 10800.0, 12600.0, 14400.0]);
                 copy_names=["series.csv", "entrainment.csv", "moisture_extrema.csv"])
end
for name in ("fourth_hour_metrics.csv", "paired_effects.csv", "solver_costs.csv")
    isfile(joinpath(dycoms_source, name)) &&
        copy_audited(joinpath("simulation_data", name))
end

gabls_source = joinpath(SOURCE, "gabls")
for name in ("experiment_matrix.json", "campaign_incidents.json", "local_audit.json",
             "results_summary.json", "reference.md", "scope_update.md",
             "table4_boundary_layer_heights.csv", "workflow.md")
    isfile(joinpath(gabls_source, name)) && copy_audited(joinpath("gabls", name))
end
for name in ("cases.json", "completion_metrics.json", "export_status.json",
             "heartbeat_status.json", "last_collection.json")
    isfile(joinpath(gabls_source, "cluster", name)) &&
        copy_audited(joinpath("gabls", "cluster", name))
end
for name in ("final_hour_profiles.json", "series.json", "fixed_1m_medians.json",
             "import_audit.csv", "provenance.json")
    isfile(joinpath(gabls_source, "reference_data", name)) &&
        copy_audited(joinpath("gabls", "reference_data", name))
end
for (path, _, names) in walkdir(joinpath(gabls_source, "figures")), name in names
    startswith(name, "._") && continue
    lowercase(splitext(name)[2]) in (".png", ".svg", ".pdf") || continue
    copy_audited(relpath(joinpath(path, name), SOURCE))
end
isfile(joinpath(gabls_source, "gabls_section.pdf")) &&
    copy_audited(joinpath("gabls", "gabls_section.pdf"))

for name in ("reference.md", "workflow.md", "gabls3_section.pdf")
    isfile(joinpath(SOURCE, "gabls3", name)) && copy_audited(joinpath("gabls3", name))
end

gabls_simulation_source = joinpath(gabls_source, "simulation_data")
gabls_simulation_destination = joinpath(DESTINATION, "gabls", "simulation_data")
for source_directory in filter(isdir, readdir(gabls_simulation_source; join=true))
    isfile(joinpath(source_directory, "manifest.json")) || continue
    destination_directory = joinpath(gabls_simulation_destination, basename(source_directory))
    compact_case(source_directory, destination_directory,
                 Set([27000.0, 28800.0, 30600.0, 32400.0]);
                 copy_names=["series.csv", "profiles_final_hour_long.csv",
                             "profiles_penultimate_hour_long.csv", "moisture_extrema.csv"])
end
isfile(joinpath(gabls_simulation_source, "final_hour_metrics.csv")) &&
    copy_audited(joinpath("gabls", "simulation_data", "final_hour_metrics.csv"))

destination_files = Dict{String, Any}[]
for (path, _, names) in walkdir(DESTINATION), name in names
    destination = joinpath(path, name)
    push!(destination_files, Dict(
        "relative_path" => relpath(destination, DESTINATION),
        "bytes" => filesize(destination),
        "sha256" => file_sha256(destination)))
end
sort!(destination_files; by=entry -> entry["relative_path"])

manifest = Dict(
    "schema_version" => 1,
    "generated_utc" => string(now(UTC)),
    "source_root_at_migration" => SOURCE,
    "destination" => "campaigns/dycoms",
    "policy" => "Julia workflows, compact comparison-window profiles, complete reduced series, and generated report artifacts are versioned; full profile histories, JLD2 fields, archives, and third-party PDFs remain external.",
    "source_copy_and_transform_records" => MIGRATION_RECORDS,
    "destination_tree" => destination_files)
open(joinpath(ROOT, "provenance", "legacy_migration.json"), "w") do io
    JSON.print(io, manifest, 2)
    println(io)
end

println("LEGACY_MIGRATION_COMPLETE records=$(length(MIGRATION_RECORDS))")
