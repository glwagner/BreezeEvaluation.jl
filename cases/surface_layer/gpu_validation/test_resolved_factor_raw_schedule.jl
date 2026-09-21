# Read-only audit of real failed-gate output, plus corrupted-copy rejection.
# Passing this regression never admits the failed GPU attempt as a valid gate.
using Test, JLD2
include("audit_resolved_factor_outputs.jl")
length(ARGS) == 1 || error("usage: test_resolved_factor_raw_schedule.jl REAL_FACTOR1_DIAGNOSTIC_PREFIX")
const audit_checks = Ref(0)
require_check(ok, message) = (ok || error(message); audit_checks[] += 1; nothing)
@testset "exact native initialization and evolved profile contract" begin
    prefix = abspath(ARGS[1])
    @test isnothing(audit_resolved_factor_outputs(prefix, 1; check=require_check))
    mktempdir() do temporary
        copy_prefix = joinpath(temporary, "fixture")
        for suffix in ("_initial.jld2", "_statistics.jld2", "_series.jld2")
            cp(prefix * suffix, copy_prefix * suffix)
        end
        statistics = copy_prefix * "_statistics.jld2"
        first_key = jldopen(statistics, "r") do file
            only([String(key) for key in keys(file["timeseries/t"]) if file["timeseries/t/$key"] == 0])
        end
        jldopen(statistics, "a+") do file
            delete!(file, "timeseries/t/$first_key")
            file["timeseries/t/$first_key"] = 1.0
        end
        @test_throws ErrorException audit_resolved_factor_outputs(copy_prefix, 1; check=require_check)
        cp(prefix * "_statistics.jld2", statistics; force=true)
        jldopen(statistics, "a+") do file
            key = "timeseries/u_mean/$first_key"
            values = copy(file[key]); values[1] += 1
            delete!(file, key); file[key] = values
        end
        @test_throws ErrorException audit_resolved_factor_outputs(copy_prefix, 1; check=require_check)
        cp(prefix * "_statistics.jld2", statistics; force=true)
        @test_throws ErrorException audit_resolved_factor_outputs(copy_prefix, 2; check=require_check)
    end
end
println("RAW_FACTOR_FIXTURE_AUDIT_PASS checks=", audit_checks[])
