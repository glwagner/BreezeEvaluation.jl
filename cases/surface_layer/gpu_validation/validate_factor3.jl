# Factor3 scope using the already-validated runner, raw schedule, and fraction helpers.
# No factor10 main or simulation is executed by including these helper definitions.
using Breeze, Oceananigans, CUDA, SHA, TOML
import Dates
module SharedFactorGate
    include("validate_factor10.jl")
end
const G = SharedFactorGate

function main()
    G.MODE in ("cpu", "gpu") || error("SLD_FACTOR_MODE must be cpu or gpu")
    ispath(G.OUTPUT) && !isempty(readdir(G.OUTPUT)) && error("refusing existing output")
    mkpath(G.OUTPUT)
    gpu = G.MODE == "gpu"
    prefix = gpu ? "GPU" : "CPU"
    mode = gpu ? "gpu_factor3" : "cpu_factor3"
    try
        gpu && (CUDA.functional() || error("CUDA unavailable"))
        gpu && CUDA.allowscalar(false)
        architecture = gpu ? GPU() : CPU()
        closure = SurfaceLayerDiffusivity(Float32; resolved_flux_factor=3)
        props = Breeze.TurbulenceClosures.momentum_surface_layer_properties
        scalar = Breeze.TurbulenceClosures.scalar_surface_layer_properties
        # At half the target, factor3 credits1.5×target and clips the deficit.
        aligned = props(-0.02f0,0f0,-0.04f0,0f0,12.5f0,1f0,closure)
        G.check(aligned.deficit == 0 && aligned.viscosity == 0 && aligned.valid,
                "factor3 aligned target switch-off")
        quarter = props(-0.01f0,0f0,-0.04f0,0f0,12.5f0,1f0,closure)
        G.check(quarter.deficit == 0.25f0 && quarter.viscosity > 0,
                "factor3 quarter-target positive deficit")
        opposed = props(0.01f0,0f0,-0.04f0,0f0,12.5f0,1f0,closure)
        G.check(opposed.deficit == 1.75f0 && opposed.viscosity > quarter.viscosity,
                "opposing signed flux incorrectly switches off")
        G.check(scalar(-0.005f0,-0.01f0,0.2f0,12.5f0,1f0,1f-8,closure).diffusivity == 0,
                "factor3 heat target switch-off")
        G.check(scalar(-0.0025f0,-0.01f0,0.2f0,12.5f0,1f0,1f-8,closure).deficit == 0.25f0,
                "factor3 heat positive deficit")
        G.check(!scalar(0f0,0f0,0.2f0,12.5f0,1f0,1f-8,closure).valid,
                "zero heat target must remain guarded")
        fractions = G.zero_fraction_contract(architecture; check=G.check, resolved_flux_factor=3)
        restart = G.Helpers.serialized_restart_check(architecture; moist=false,
            support=1, resolved_flux_factor=3, directory=joinpath(G.OUTPUT, "restart3"))
        runners = gpu ? [G.runner_check(3, "gpu")] : Any[]
        sources = ("cases/surface_layer/gpu_validation/validate_factor3.jl",
                   "cases/surface_layer/gpu_validation/validate_factor10.jl",
                   "cases/surface_layer/gpu_validation/validate_surface_layer.jl",
                   "cases/surface_layer/gpu_validation/factor10_zero_fraction_contract.jl",
                   "cases/surface_layer/gpu_validation/audit_resolved_factor_outputs.jl",
                   "cases/surface_layer/diagnostics/SurfaceLayerDiagnostics.jl",
                   "cases/surface_layer/gabls1/gabls1_case.jl",
                   "cases/surface_layer/registries/gabls1_sld_factor3.toml")
        evidence = Dict("validation_mode"=>mode, "case_family"=>"GABLS1",
            "all_passed"=>true, "factors"=>[3.0], "changed_path_checks_passed"=>true,
            "zero_fraction_contract_passed"=>true, "zero_fraction_contract"=>fractions,
            "passed_checks"=>G.checks[] + G.Helpers.PASS_COUNT[], "architecture"=>summary(architecture),
            "cuda_functional"=>gpu, "cuda_scalar_indexing_disabled"=>gpu,
            "freeze_root"=>G.ROOT, "freeze_source_manifest_sha256"=>G.hashfile(joinpath(G.ROOT,"source_sha256.txt")),
            "freeze_source_manifest_entries"=>length(readlines(joinpath(G.ROOT,"source_sha256.txt"))),
            "source_sha256"=>Dict(p=>G.hashfile(joinpath(G.EVAL,p)) for p in sources),
            "restart"=>Dict("3"=>restart), "runners"=>runners,
            "observers_are_read_only"=>true, "scientific_output"=>false,
            "completed_utc"=>string(Dates.now(Dates.UTC)))
        path = joinpath(G.OUTPUT,"validation_evidence.toml")
        open(io->TOML.print(io,evidence;sorted=true),path,"w")
        write(joinpath(G.OUTPUT,"$(prefix)_VALIDATION_DONE"),"mode=$mode\nevidence_sha256=$(G.hashfile(path))\n")
        println("FACTOR3_GATE_PASS mode=$mode checks=$(evidence["passed_checks"])")
    catch err
        open(io->showerror(io,err,catch_backtrace()),joinpath(G.OUTPUT,"$(prefix)_VALIDATION_FAILED"),"w")
        rethrow()
    end
end
abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
