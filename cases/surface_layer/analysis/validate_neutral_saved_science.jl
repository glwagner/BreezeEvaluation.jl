#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl"))
using .NeutralSavedScienceAudit

length(ARGS) == 1 || error("usage: validate_neutral_saved_science.jl EVIDENCE_DIRECTORY")
report = validate_saved_evidence(ARGS[1])
println("NEUTRAL_SAVED_SCIENCE_EVIDENCE_VALID pending_root_acceptance=true",
        " original_batch_success=", report["original_batch_success"],
        " cases=", length(report["attempts"]))
