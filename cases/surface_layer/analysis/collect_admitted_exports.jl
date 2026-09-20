#!/usr/bin/env julia

include(joinpath(@__DIR__, "SurfaceLayerScientificExport.jl"))
using .SurfaceLayerScientificExport

length(ARGS) == 3 || error(
    "usage: collect_admitted_exports.jl ATTEMPT_REGISTRY.toml EXPORT_ROOT COLLECTION_DIR")

collection = collect_admitted_exports(ARGS[1], ARGS[2], ARGS[3])
println("SLD_EXPORT_COLLECTION admitted=", collection["admitted_count"],
        " rejected=", collection["rejected_count"],
        " directory=", abspath(ARGS[3]))
