#!/usr/bin/env julia
using JSON, SHA, Dates

filehash(path) = bytes2hex(open(sha256, path))
shellquote(s) = "'" * replace(s, "'" => "'\\''") * "'"

function fetch_file(source, target, host)
    mkpath(dirname(target))
    if host === nothing
        cp(source, target)
    else
        command = Cmd(["ssh", "-o", "ConnectTimeout=15", "-o", "ServerAliveInterval=15",
                       "-o", "ServerAliveCountMax=2", host, "cat -- " * shellquote(source)])
        open(target, "w") do output
            run(pipeline(command, stdout=output))
        end
    end
end

function checked_relative(path)
    path isa AbstractString || error("Expected a relative path")
    isabspath(path) && error("Absolute path in migration metadata: $path")
    any(==(".."), splitpath(path)) && error("Parent traversal in migration metadata: $path")
    isempty(path) && error("Empty relative path")
    normpath(path)
end

function options(args)
    opts = Dict("repository" => normpath(joinpath(@__DIR__, "..")), "case" => "all")
    isempty(args) && error("Usage: restore_full_profiles.jl --destination NEW_DIRECTORY [--repository REPO] [--source-root SOURCE] [--host SSH_ALIAS] [--case CASE_ID|all]")
    iseven(length(args)) || error("Options require values")
    for i in 1:2:length(args)
        key = args[i]
        key in ("--destination", "--repository", "--source-root", "--host", "--case") || error("Unknown option $key")
        opts[key[3:end]] = args[i+1]
    end
    haskey(opts, "destination") || error("--destination is required")
    opts
end

function restore(opts)
    repo = abspath(opts["repository"])
    destination = abspath(opts["destination"])
    ispath(destination) && error("Destination already exists; refusing to overwrite $destination")
    migration_path = joinpath(repo, "provenance", "legacy_migration.json")
    migration = JSON.parsefile(migration_path)
    campaign = joinpath(repo, checked_relative(migration["destination"]))
    source_root = get(opts, "source-root", migration["source_root_at_migration"])
    host = get(opts, "host", nothing)
    if host !== nothing
        occursin(r"^[A-Za-z0-9][A-Za-z0-9_.@:-]*$", host) || error("Invalid SSH host/alias")
    end
    profile_entries = filter(migration["source_copy_and_transform_records"]) do entry
        get(entry, "transformation", "") == "CSV row subset by exact time_s; header unchanged"
    end
    wanted = opts["case"]
    selected = filter(profile_entries) do entry
        relative = checked_relative(entry["destination_relative_path"])
        wanted == "all" || basename(dirname(relative)) == wanted
    end
    isempty(selected) && error("No migrated profiles match case $wanted")
    wanted != "all" && length(selected) != 1 && error("Ambiguous case $wanted")

    # Verify committed source artifacts before staging a separate analysis tree.
    for entry in migration["destination_tree"]
        path = joinpath(campaign, checked_relative(entry["relative_path"]))
        isfile(path) && !islink(path) || error("Missing or symlinked artifact $path")
        filesize(path) == entry["bytes"] && filehash(path) == entry["sha256"] || error("Archived artifact mismatch: $path")
    end
    mkpath(dirname(destination))
    staging = mktempdir(dirname(destination); prefix=".restore-profiles-")
    try
        tree = joinpath(staging, "analysis")
        cp(campaign, tree)
        restored = Any[]
        for entry in selected
            relative = checked_relative(entry["destination_relative_path"])
            source_relative = checked_relative(entry["source_relative_path"])
            source = joinpath(source_root, source_relative)
            target = joinpath(tree, relative)
            partial = target * ".download"
            fetch_file(source, partial, host)
            actual = filehash(partial)
            actual == entry["source_sha256"] || error("Full profile hash mismatch: $source_relative")
            source_manifest_path = joinpath(dirname(target), "source_manifest.json")
            source_manifest = JSON.parsefile(source_manifest_path)
            # For manifests with their own output hashes, require both authorities to agree.
            hashes = get(source_manifest, "output_sha256", Dict())
            haskey(hashes, "profiles.csv") && hashes["profiles.csv"] != actual && error("Original manifest profile hash mismatch")
            for (name, expected) in hashes
                name == "profiles.csv" && continue
                existing = joinpath(dirname(target), checked_relative(name))
                if !isfile(existing) || filehash(existing) != expected
                    companion_partial = existing * ".download"
                    fetch_file(joinpath(dirname(source), name), companion_partial, host)
                    filehash(companion_partial) == expected || error("Original manifest companion hash mismatch: $name")
                    mv(companion_partial, existing; force=true)
                end
            end
            mv(partial, target; force=true)
            cp(source_manifest_path, joinpath(dirname(target), "manifest.json"); force=true)
            push!(restored, Dict("relative_path" => relative, "sha256" => actual,
                                "original_manifest_sha256" => filehash(source_manifest_path)))
        end
        open(joinpath(tree, "restored_profiles.json"), "w") do io
            JSON.print(io, Dict("created_utc" => string(now(UTC)), "migration_sha256" => filehash(migration_path),
                "source_root" => source_root, "host" => host, "restored" => restored,
                "all_migrated_cases_restored" => length(selected) == length(profile_entries),
                "note" => "Original manifests restored only for hash-verified full histories. Run the original scientific admission checks before analysis. Unselected cases remain derived compact subsets."), 2)
        end
        ispath(destination) && error("Destination appeared during restoration; refusing to replace it")
        mv(tree, destination)
        println("FULL_PROFILES_RESTORED cases=$(length(restored)) destination=$destination")
    finally
        rm(staging; recursive=true, force=true)
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && restore(options(ARGS))
