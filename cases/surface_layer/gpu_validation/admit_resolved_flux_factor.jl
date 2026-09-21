using SHA, TOML
include(joinpath(@__DIR__, "..", "analysis", "SurfaceLayerScientificExport.jl"))
using .SurfaceLayerScientificExport: verify_gpu_evidence, file_sha256

function admit_resolved_flux_factor(directory, root)
    result = verify_gpu_evidence(directory, root, file_sha256(joinpath(root, "source_sha256.txt")))
    result["validation_mode"] == "gpu_resolved_flux_factor" || error("wrong gate scope")
    evidence = TOML.parsefile(joinpath(directory, "validation_evidence.toml"))
    evidence["observers_are_read_only"] === true || error("mutating observers inadmissible")
    length(evidence["runners"]) == 2 || error("both full-runner fixtures required")
    for (run, factor) in zip(evidence["runners"], (1.0, 2.0))
        run["factor"] == factor || error("wrong runner factor")
        run["case_id"] == "gabls1_n032_weno9_surface_layer_t300_s1_rf$(Int(factor))p0" || error("runner identity mismatch")
        run["end_time_s"] == 1800 || error("writer fixture incomplete")
        run["accepted_filter_iterations_observed"] > 2 || error("filter was not observed advancing")
        haskey(evidence["restart"], string(Int(factor))) || error("missing restart factor")
    end
    println("RESOLVED_FLUX_FACTOR_GPU_ADMITTED evidence_sha256=", result["evidence_sha256"])
    return result
end
if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 2 || error("usage: admit_resolved_flux_factor.jl EVIDENCE FREEZE")
    admit_resolved_flux_factor(abspath(ARGS[1]), abspath(ARGS[2]))
end
