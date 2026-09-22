#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl"))
using .NeutralSavedScienceAudit

length(ARGS) == 1 || error("usage: admit_neutral_saved_science.jl SAVED_EVIDENCE_DIRECTORY")
accepted = validate_root_acceptance(ARGS[1])
println("NEUTRAL_SAVED_SCIENCE_ROOT_ACCEPTED original_batch_success=false",
        " evidence_sha256=", accepted.evidence_sha256,
        " root_acceptance_sha256=", accepted.acceptance_sha256)
