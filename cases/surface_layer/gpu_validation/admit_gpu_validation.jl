using SHA
using TOML

file_sha256(path) = bytes2hex(open(sha256, path))

function require_admission(condition, message)
    condition || error(message)
    return nothing
end

function sentinel_fields(path)
    fields = Dict{String, String}()
    for line in readlines(path)
        occursin('=', line) || continue
        key, value = split(line, '='; limit=2)
        fields[strip(key)] = strip(value)
    end
    return fields
end

function audit_source_manifest(freeze_root, manifest_path)
    entries = 0
    for line in readlines(manifest_path)
        isempty(strip(line)) && continue
        parts = split(line; limit=2)
        require_admission(length(parts) == 2, "malformed source manifest line")
        expected = parts[1]
        relative = strip(parts[2])
        startswith(relative, "*") && (relative = relative[2:end])
        path = normpath(joinpath(freeze_root, relative))
        require_admission(startswith(path, normpath(freeze_root) * Base.Filesystem.path_separator),
                          "source manifest path escapes freeze root")
        require_admission(isfile(path), "source manifest file is missing: $relative")
        require_admission(file_sha256(path) == expected,
                          "source manifest hash mismatch: $relative")
        entries += 1
    end
    return entries
end

function admit_gpu_validation(evidence_directory, freeze_root)
    evidence_directory = abspath(evidence_directory)
    freeze_root = abspath(freeze_root)
    done_path = joinpath(evidence_directory, "GPU_VALIDATION_DONE")
    failed_path = joinpath(evidence_directory, "GPU_VALIDATION_FAILED")
    evidence_path = joinpath(evidence_directory, "validation_evidence.toml")
    manifest_path = joinpath(freeze_root, "source_sha256.txt")

    require_admission(isfile(done_path), "GPU_VALIDATION_DONE is missing")
    require_admission(!ispath(failed_path), "GPU_VALIDATION_FAILED is present")
    require_admission(isfile(evidence_path), "validation_evidence.toml is missing")
    require_admission(isfile(manifest_path), "freeze source_sha256.txt is missing")

    done = sentinel_fields(done_path)
    evidence = TOML.parsefile(evidence_path)
    evidence_hash = file_sha256(evidence_path)
    manifest_hash = file_sha256(manifest_path)
    require_admission(get(done, "mode", "") == "gpu_full",
                      "DONE sentinel is not gpu_full")
    require_admission(get(done, "evidence_sha256", "") == evidence_hash,
                      "DONE sentinel evidence hash mismatch")
    require_admission(evidence["validation_mode"] == "gpu_full",
                      "CPU evidence cannot admit a GPU run")
    require_admission(evidence["all_passed"] === true,
                      "GPU evidence does not report all_passed")
    require_admission(evidence["architecture"] == "CUDAGPU",
                      "GPU evidence architecture is not CUDAGPU")
    require_admission(evidence["cuda_functional"] === true,
                      "CUDA functional flag is false")
    require_admission(evidence["cuda_scalar_indexing_disabled"] === true,
                      "CUDA scalar-indexing guard is false")
    require_admission(abspath(evidence["freeze_root"]) == freeze_root,
                      "GPU evidence points to a different freeze root")
    require_admission(evidence["freeze_source_manifest_sha256"] == manifest_hash,
                      "GPU evidence source-manifest hash does not match this freeze")

    entries = audit_source_manifest(freeze_root, manifest_path)
    require_admission(evidence["freeze_source_manifest_entries"] == entries,
                      "GPU evidence source-manifest entry count mismatch")
    evaluation_root = joinpath(freeze_root, "source", "BreezeEvaluation.jl")
    for (relative, expected) in evidence["source_sha256"]
        path = normpath(joinpath(evaluation_root, relative))
        require_admission(isfile(path), "evidence source is missing: $relative")
        require_admission(file_sha256(path) == expected,
                          "evidence source hash mismatch: $relative")
    end
    return (;
        evidence_sha256=evidence_hash,
        source_manifest_sha256=manifest_hash,
        source_manifest_entries=entries,
        passed_checks=evidence["passed_checks"])
end

function main()
    length(ARGS) == 2 || error(
        "usage: admit_gpu_validation.jl VALIDATION_EVIDENCE_DIRECTORY FREEZE_ROOT")
    result = admit_gpu_validation(ARGS[1], ARGS[2])
    println("GPU_VALIDATION_ADMITTED evidence_sha256=", result.evidence_sha256,
            " source_manifest_sha256=", result.source_manifest_sha256,
            " source_manifest_entries=", result.source_manifest_entries,
            " passed_checks=", result.passed_checks)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
