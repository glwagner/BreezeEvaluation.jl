using SHA
using TOML

include(joinpath(@__DIR__, "admit_gpu_validation.jl"))

const CHECKS = Ref(0)

function check(condition, message)
    condition || error(message)
    CHECKS[] += 1
end

function must_reject(function_to_test, message)
    rejected = try
        function_to_test()
        false
    catch
        true
    end
    check(rejected, message)
end

function make_fixture(root; mode="gpu_full", architecture="CUDAGPU",
                      failed=false, alter_done_hash=false)
    freeze = joinpath(root, "freeze")
    evaluation = joinpath(freeze, "source", "BreezeEvaluation.jl")
    evidence_directory = joinpath(root, "evidence")
    mkpath(evaluation)
    mkpath(evidence_directory)
    source_path = joinpath(evaluation, "source.jl")
    write(source_path, "source fixture\n")
    manifest = joinpath(freeze, "source_sha256.txt")
    open(manifest, "w") do io
        println(io, file_sha256(source_path), "  source/BreezeEvaluation.jl/source.jl")
    end
    evidence = Dict{String, Any}(
        "validation_mode" => mode,
        "all_passed" => true,
        "architecture" => architecture,
        "cuda_functional" => mode == "gpu_full",
        "cuda_scalar_indexing_disabled" => mode == "gpu_full",
        "freeze_root" => freeze,
        "freeze_source_manifest_sha256" => file_sha256(manifest),
        "freeze_source_manifest_entries" => 1,
        "passed_checks" => 12,
        "source_sha256" => Dict("source.jl" => file_sha256(source_path)))
    evidence_path = joinpath(evidence_directory, "validation_evidence.toml")
    open(evidence_path, "w") do io
        TOML.print(io, evidence; sorted=true)
    end
    evidence_hash = alter_done_hash ? repeat("0", 64) : file_sha256(evidence_path)
    open(joinpath(evidence_directory, "GPU_VALIDATION_DONE"), "w") do io
        println(io, "mode=", mode)
        println(io, "evidence_sha256=", evidence_hash)
    end
    failed && write(joinpath(evidence_directory, "GPU_VALIDATION_FAILED"), "failed\n")
    return (; freeze, evidence_directory, source_path, evidence_path)
end

mktempdir() do root
    valid = make_fixture(joinpath(root, "valid"))
    result = admit_gpu_validation(valid.evidence_directory, valid.freeze)
    check(result.source_manifest_entries == 1, "valid GPU evidence was not admitted")

    cpu = make_fixture(joinpath(root, "cpu"); mode="cpu_contract", architecture="CPU")
    must_reject(() -> admit_gpu_validation(cpu.evidence_directory, cpu.freeze),
                "CPU evidence was accepted as GPU evidence")

    altered_evidence = make_fixture(joinpath(root, "altered_evidence"); alter_done_hash=true)
    must_reject(() -> admit_gpu_validation(
                    altered_evidence.evidence_directory, altered_evidence.freeze),
                "altered evidence hash was accepted")

    missing = make_fixture(joinpath(root, "missing"))
    rm(joinpath(missing.evidence_directory, "GPU_VALIDATION_DONE"))
    must_reject(() -> admit_gpu_validation(missing.evidence_directory, missing.freeze),
                "missing GPU sentinel was accepted")

    failed = make_fixture(joinpath(root, "failed"); failed=true)
    must_reject(() -> admit_gpu_validation(failed.evidence_directory, failed.freeze),
                "failure sentinel was ignored")

    altered_source = make_fixture(joinpath(root, "altered_source"))
    write(altered_source.source_path, "altered source\n")
    must_reject(() -> admit_gpu_validation(
                    altered_source.evidence_directory, altered_source.freeze),
                "altered freeze source was accepted")

    wrong_freeze = make_fixture(joinpath(root, "wrong_freeze_a"))
    other = make_fixture(joinpath(root, "wrong_freeze_b"))
    must_reject(() -> admit_gpu_validation(wrong_freeze.evidence_directory, other.freeze),
                "evidence from a different freeze was accepted")
end

println("GPU_ADMISSION_REGRESSION_PASS checks=", CHECKS[])
