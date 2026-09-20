using Test, JSON, SHA
include("restore_full_profiles.jl")

@testset "Verified restoration is transactional" begin
    mktempdir() do tmp
        repo = joinpath(tmp, "repo")
        source = joinpath(tmp, "source with apostrophe '")
        relative = "simulation_data/test_case/profiles.csv"
        campaign = joinpath(repo, "campaigns", "dycoms")
        case = joinpath(campaign, dirname(relative))
        mkpath(case); mkpath(joinpath(repo, "provenance")); mkpath(dirname(joinpath(source, relative)))
        write(joinpath(source, relative), "time_s,value\n0,1\n60,2\n120,3\n")
        write(joinpath(case, "profiles.csv"), "time_s,value\n120,3\n")
        write(joinpath(case, "series.csv"), "time_s,value\n0,4\n60,5\n120,6\n")
        fullhash = filehash(joinpath(source, relative))
        extra = joinpath(source,dirname(relative),"comparison.csv")
        write(extra,"statistic,value\nmean,2\n")
        original = Dict("export_verified" => true, "output_sha256" => Dict(
            "profiles.csv" => fullhash, "series.csv" => filehash(joinpath(case, "series.csv")),
            "comparison.csv" => filehash(extra)))
        write(joinpath(case, "source_manifest.json"), JSON.json(original))
        write(joinpath(case, "manifest.json"), JSON.json(Dict("export_verified" => false)))
        tree = [Dict("relative_path" => relpath(joinpath(case,f), campaign),
                     "bytes" => filesize(joinpath(case,f)), "sha256" => filehash(joinpath(case,f))) for f in readdir(case)]
        migration = Dict("destination" => "campaigns/dycoms", "source_root_at_migration" => source,
            "destination_tree" => tree, "source_copy_and_transform_records" => [Dict("source_relative_path" => relative,
            "destination_relative_path" => relative, "source_sha256" => fullhash,
            "transformation" => "CSV row subset by exact time_s; header unchanged")])
        write(joinpath(repo,"provenance","legacy_migration.json"), JSON.json(migration))
        destination = joinpath(tmp,"restored")
        opts = Dict("repository" => repo, "destination" => destination, "case" => "all")
        restore(opts)
        @test filehash(joinpath(destination,relative)) == fullhash
        @test filehash(joinpath(destination,dirname(relative),"comparison.csv")) == filehash(extra)
        @test JSON.parsefile(joinpath(destination,dirname(relative),"manifest.json"))["export_verified"] === true
        @test JSON.parsefile(joinpath(case,"manifest.json"))["export_verified"] === false
        @test JSON.parsefile(joinpath(destination,"restored_profiles.json"))["all_migrated_cases_restored"] === true
        @test_throws ErrorException restore(opts)
        @test filehash(joinpath(destination,relative)) == fullhash

        # Corrupt original data must not publish a destination or mutate committed subsets.
        write(joinpath(source,relative), "corrupt")
        failed = joinpath(tmp,"failed")
        opts["destination"] = failed
        @test_throws ErrorException restore(opts)
        @test !ispath(failed)
        @test !any(startswith(".restore-profiles-"), readdir(tmp))
        @test read(joinpath(case,"profiles.csv"),String) == "time_s,value\n120,3\n"

        @test_throws ErrorException checked_relative("../outside")
        @test_throws ErrorException checked_relative("/outside")
        @test_throws ErrorException restore(merge(opts, Dict("host" => "-oProxyCommand=bad")))
        @test_throws ErrorException restore(merge(opts, Dict("case" => "unknown")))
    end
end
