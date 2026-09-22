#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralScientificExport.jl"))
using .NeutralScientificExport

length(ARGS) == 3 || error("usage: export_neutral_case.jl FINALIZED_REGISTRY.toml CASE_ID NEW_EXPORT_ROOT")
manifest = export_neutral_case(ARGS[1], ARGS[2], ARGS[3])
println("NEUTRAL_SCIENTIFIC_EXPORT_VERIFIED case_id=", manifest["case_id"],
        " directory=", joinpath(abspath(ARGS[3]), manifest["case_id"]))
