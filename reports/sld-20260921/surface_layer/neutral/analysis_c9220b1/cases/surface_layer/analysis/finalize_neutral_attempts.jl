#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralScientificExport.jl"))
using .NeutralScientificExport

length(ARGS) == 4 || error("usage: finalize_neutral_attempts.jl CAMPAIGN_ROOT ARRAY_JOB_ID PINNED_WRAPPER_PATH NEW_ATTEMPT_REGISTRY.toml")
registry = finalize_neutral_attempts(ARGS[1], ARGS[2], ARGS[3], ARGS[4])
println("NEUTRAL_ATTEMPTS_FINALIZED job=", registry["array_job_id"],
        " cases=", length(registry["attempts"]), " path=", abspath(ARGS[4]))
