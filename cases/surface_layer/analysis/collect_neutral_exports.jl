#!/usr/bin/env julia

include(joinpath(@__DIR__, "NeutralScientificExport.jl"))
using .NeutralScientificExport

length(ARGS) == 3 || error("usage: collect_neutral_exports.jl FINALIZED_REGISTRY.toml EXPORT_ROOT NEW_COLLECTION_ROOT")
collection = collect_neutral_exports(ARGS[1], ARGS[2], ARGS[3])
println("NEUTRAL_COLLECTION admitted=", collection["admitted_count"],
        " rejected=", collection["rejected_count"],
        " directory=", abspath(ARGS[3]))
