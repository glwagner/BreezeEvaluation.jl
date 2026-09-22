using SHA, TOML
include(joinpath(@__DIR__, "..", "analysis", "SurfaceLayerScientificExport.jl"))
using .SurfaceLayerScientificExport: verify_gpu_evidence, file_sha256

function admit_single_factor(directory, root; factor=10)
    factor in (3, 10) || error("unsupported single-factor scope")
    result = verify_gpu_evidence(directory, root, file_sha256(joinpath(root, "source_sha256.txt")))
    result["validation_mode"] == "gpu_factor$factor" || error("wrong gate scope")
    evidence = TOML.parsefile(joinpath(directory, "validation_evidence.toml"))
    evidence["observers_are_read_only"] === true || error("mutating observers inadmissible")
    length(evidence["runners"]) == 1 || error("one full-runner fixture required")
    for run in evidence["runners"]
        run["factor"] == factor || error("wrong runner factor")
        run["case_id"] == "gabls1_n032_weno9_surface_layer_t300_s1_rf$(Int(factor))p0" || error("runner identity mismatch")
        run["end_time_s"] == 1800 || error("writer fixture incomplete")
        run["accepted_filter_iterations_observed"] > 2 || error("filter was not observed advancing")
        haskey(evidence["restart"], string(Int(factor))) || error("missing restart factor")
    end
    println("FACTOR", factor, "_GPU_ADMITTED evidence_sha256=", result["evidence_sha256"])
    return result
end
admit_factor10(directory, root) = admit_single_factor(directory, root; factor=10)
if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 2 || error("usage: admit_factor10.jl EVIDENCE FREEZE")
    admit_factor10(abspath(ARGS[1]), abspath(ARGS[2]))
end
