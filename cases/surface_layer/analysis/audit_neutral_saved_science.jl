#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl"))
using .NeutralSavedScienceAudit

length(ARGS) == 1 || error("usage: audit_neutral_saved_science.jl NEW_EVIDENCE_DIRECTORY")
report = audit_saved_science(ARGS[1])
println("NEUTRAL_SAVED_SCIENCE_RAW_AUDIT_PASS pending_root_acceptance=true",
        " original_batch_success=", report["original_batch_success"],
        " cases=", length(report["attempts"]))
