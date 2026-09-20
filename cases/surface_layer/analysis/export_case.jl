#!/usr/bin/env julia

include(joinpath(@__DIR__, "SurfaceLayerScientificExport.jl"))
using .SurfaceLayerScientificExport

length(ARGS) == 3 || error(
    "usage: export_case.jl ATTEMPT_REGISTRY.toml CASE_ID EXPORT_ROOT")

manifest = export_scientific_case(ARGS[1], ARGS[2], ARGS[3])
println("SLD_SCIENTIFIC_EXPORT_VERIFIED case_id=", manifest["case_id"],
        " directory=", joinpath(abspath(ARGS[3]), manifest["case_id"]))
