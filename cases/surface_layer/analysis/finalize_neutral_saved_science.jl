#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl"))
using .NeutralSavedScienceAudit

length(ARGS) == 2 || error("usage: finalize_neutral_saved_science.jl SAVED_EVIDENCE_DIRECTORY NEW_ATTEMPT_REGISTRY.toml")
registry = finalize_root_accepted_saved_science(ARGS[1], ARGS[2])
println("NEUTRAL_SAVED_SCIENCE_FINALIZED original_batch_success=false",
        " cases=", length(registry["attempts"]), " path=", abspath(ARGS[2]))
