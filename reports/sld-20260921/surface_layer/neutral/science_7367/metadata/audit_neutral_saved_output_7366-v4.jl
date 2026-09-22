# Read-only re-audit of the completed NON-SCIENTIFIC 7366 neutral GPU fixture.
# Original failed parent, raw output, source snapshot, and v3 auditor are untouched.

using Dates
using JLD2
using SHA
using TOML

const CORE_ROOT = "/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647"
const CORE_MANIFEST_SHA = "d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
const HARNESS = joinpath(CORE_ROOT, "source", "BreezeEvaluation.jl", "cases",
                         "surface_layer", "neutral", "run_neutral_gpu_throughput.jl")
const HARNESS_SHA = "15acf1ea5f24c390dcf7319b1a429b7076caa3d353192bcb688173ee656c0a91"
const REGISTRY = joinpath(CORE_ROOT, "source", "BreezeEvaluation.jl", "cases",
                          "surface_layer", "neutral", "neutral_sld_2case.toml")
const REGISTRY_SHA = "5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156"
const ADAPTATION = joinpath(CORE_ROOT, "source", "BreezeEvaluation.jl", "cases",
                            "surface_layer", "diagnostics", "LegacyGABLSDiagnosticsAdaptation.jl")
const ADAPTATION_SHA = "a8d029d23d9765c76895337c6d537008c5d322f401756fc9d1eae714c9052257"
const COMBINED_ADMISSION = "/shared/home/greg/review-coordination/admit_sld_flux_schedule_gpu_gate_a14c358-v3.jl"
const COMBINED_ADMISSION_SHA = "9b8782a1fd29d95841a9af2ed382c57751662052dcef877f3797ad224c0aec10"
const ORIGINAL_PARENT = "/shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614"
const ORIGINAL_OUTPUT = joinpath(ORIGINAL_PARENT, "output")
const ORIGINAL_JOB_ID = 7366
const ORIGINAL_LOG_SHA = "99a5ff35bb85907ef31b589e0f644d2d218f0fba3b718f4eae5090e8c0be1455"
const ORIGINAL_CHILD_EXIT_SHA = "44334abc939d955e3af82ef5a67efc8c069478b0667e2bacd2a0faf6a378d2d0"
const ORIGINAL_AUDITOR_SHA = "4b5c0bcbbefd7f1d7bd136dd849ae561dadd3a4e686d410e9693dd216e292fbc"
const ORIGINAL_THROUGHPUT_SHA = "579d99ee07d361684899f1f837cfbf17d3d4a2e9da0e3a1ecd8a44320b021231"
const GATE_DIRECTORY = let directory = get(ENV, "SLD_COMBINED_GPU_EVIDENCE", "")
    isempty(directory) && error("SLD_COMBINED_GPU_EVIDENCE must name the admitted v2 parent")
    abspath(directory)
end

module NeutralCombinedGpuAdmission
include("/shared/home/greg/review-coordination/admit_sld_flux_schedule_gpu_gate_a14c358-v3.jl")
end

file_sha(path) = bytes2hex(open(sha256, path))
require_neutral(condition, message) = condition || error(message)

function check_sources()
    for (path, expected) in ((joinpath(CORE_ROOT, "source_sha256.txt"), CORE_MANIFEST_SHA),
                             (HARNESS, HARNESS_SHA),
                             (REGISTRY, REGISTRY_SHA),
                             (ADAPTATION, ADAPTATION_SHA),
                             (COMBINED_ADMISSION, COMBINED_ADMISSION_SHA))
        require_neutral(isfile(path), "missing source: $path")
        require_neutral(file_sha(path) == expected, "source hash mismatch: $path")
    end
end

function record_keys(file)
    keys_and_times = [(parse(Int, String(key)), Float64(file["timeseries/t/$key"]))
                      for key in keys(file["timeseries/t"]) if String(key) != "serialized"]
    return sort(keys_and_times; by=first)
end

profile(file, name, key) = vec(Float64.(file["timeseries/$name/$key"]))

function scalar_leaf(raw, name)
    raw isa Number && return Float64(raw)
    raw isa AbstractArray && length(raw) == 1 && return Float64(only(raw))
    error("$name is neither a numeric scalar nor a singleton numeric array")
end

scalar(file, name, key) = scalar_leaf(file["timeseries/$name/$key"], name)

function parse_fields(path)
    fields = Dict{String, String}()
    for line in eachline(path)
        key, value = split(line, '='; limit=2)
        fields[key] = value
    end
    return fields
end

function check_original_attempt(output_directory, supplemental_directory)
    require_neutral(output_directory == ORIGINAL_OUTPUT,
                    "re-audit must use the exact saved 7366 output")
    require_neutral(!ispath(supplemental_directory),
                    "supplemental evidence destination already exists")
    require_neutral(!startswith(supplemental_directory, ORIGINAL_PARENT * Base.Filesystem.path_separator),
                    "supplemental evidence must be outside the failed parent")
    log_path = joinpath(ORIGINAL_PARENT, "gate_7366.log")
    exit_path = joinpath(ORIGINAL_PARENT, "child.exit")
    auditor_path = joinpath(ORIGINAL_PARENT, "metadata", "audit_neutral_speed_gate_a14c358-v3.jl")
    require_neutral(file_sha(log_path) == ORIGINAL_LOG_SHA &&
                    file_sha(exit_path) == ORIGINAL_CHILD_EXIT_SHA &&
                    file_sha(auditor_path) == ORIGINAL_AUDITOR_SHA,
                    "original 7366 log, exit record, or v3 auditor SHA differs")
    exit_record = parse_fields(exit_path)
    require_neutral(exit_record["job_id"] == string(ORIGINAL_JOB_ID) &&
                    exit_record["child_exit_code"] == "1",
                    "original 7366 failed child identity differs")
    require_neutral(isfile(joinpath(output_directory, "NEUTRAL_SPEED_GATE_FAILED")) &&
                    !ispath(joinpath(output_directory, "NEUTRAL_SPEED_GATE_DONE")),
                    "original failed auditor state differs")
    failure = parse_fields(joinpath(output_directory, "NEUTRAL_SPEED_GATE_FAILED"))
    require_neutral(failure["exit_code"] == "1", "original failure exit code differs")
    evidence_path = joinpath(output_directory, "neutral_throughput_evidence.toml")
    done = parse_fields(joinpath(output_directory, "NEUTRAL_THROUGHPUT_DONE"))
    require_neutral(file_sha(evidence_path) == ORIGINAL_THROUGHPUT_SHA &&
                    done["evidence_sha256"] == ORIGINAL_THROUGHPUT_SHA &&
                    done["mode"] == "gpu_neutral_throughput_fixture" &&
                    done["fixture_non_scientific"] == "true",
                    "completed throughput evidence/sentinel differs")
    return Dict("original_job_id" => ORIGINAL_JOB_ID,
                "original_child_exit_code" => 1,
                "original_log_sha256" => ORIGINAL_LOG_SHA,
                "original_child_exit_sha256" => ORIGINAL_CHILD_EXIT_SHA,
                "original_v3_auditor_sha256" => ORIGINAL_AUDITOR_SHA,
                "original_throughput_evidence_sha256" => ORIGINAL_THROUGHPUT_SHA)
end

function check_profile_semantics(path, closure)
    isfile(path) || error("missing neutral profile file: $path")
    jldopen(path, "r") do file
        records = record_keys(file)
        require_neutral(last.(records) == [60.0, 120.0],
                        "$closure profile records are not exact 60, 120 s")
        require_neutral(file["coordinates/native_w_moment_location"] == "Face",
                        "$closure native vertical-coordinate metadata is wrong")
        require_neutral(length(file["coordinates/z_face_m"]) == 97,
                        "$closure face coordinate count is not 97")
        require_neutral(length(file["coordinates/z_center_m"]) == 96,
                        "$closure center coordinate count is not 96")
        max_momentum_flux = 0.0
        max_scalar_flux = 0.0
        max_implicit_sgs = 0.0
        max_viscosity = 0.0
        max_diffusivity = 0.0
        for (key, _) in records
            wall_flux_squared = 0.0
            for component in ("u", "v")
                resolved = profile(file, "resolved_$(component)_w_flux", key)
                sgs = profile(file, "sgs_$(component)_w_flux", key)
                total = profile(file, "total_$(component)_w_flux", key)
                require_neutral(length(resolved) == length(sgs) == length(total) == 97,
                                "$closure $component flux is not on native faces")
                require_neutral(all(isfinite, resolved) && all(isfinite, sgs) && all(isfinite, total),
                                "$closure $component flux has nonfinite values")
                # Face 1 is the prescribed wall flux, not resolved plus SGS.
                residual = maximum(abs.(total[2:end] .- resolved[2:end] .- sgs[2:end]))
                scale = max(1.0, maximum(abs.(total)), maximum(abs.(resolved)),
                            maximum(abs.(sgs)))
                require_neutral(residual <= 5e-6 * scale,
                                "$closure $component total is not resolved plus SGS above wall: $residual")
                max_momentum_flux = max(max_momentum_flux, maximum(abs.(sgs[2:end])))
                max_implicit_sgs = max(max_implicit_sgs, abs(sgs[2]))
                wall = abs(total[1])
                wall_flux_squared += wall^2
                require_neutral(wall <= 0.3,
                                "$closure $component wall stress exceeds prescribed 0.25 scale")
            end
            require_neutral(0.2 <= sqrt(wall_flux_squared) <= 0.3,
                            "$closure vector wall stress is inconsistent with fixed ustar=0.5")
            resolved_theta = profile(file, "resolved_w_theta_flux", key)
            sgs_theta = profile(file, "sgs_w_theta_flux", key)
            total_theta = profile(file, "total_w_theta_flux", key)
            require_neutral(length(resolved_theta) == length(sgs_theta) == length(total_theta) == 97,
                            "$closure theta flux is not on native faces")
            require_neutral(all(isfinite, resolved_theta) && all(isfinite, sgs_theta) &&
                            all(isfinite, total_theta), "$closure theta flux is nonfinite")
            max_scalar_flux = max(max_scalar_flux, maximum(abs.(sgs_theta)))
            require_neutral(abs(total_theta[1]) <= 1e-7,
                            "$closure violates prescribed zero bottom heat flux")
            residual = maximum(abs.(total_theta[2:end] .- resolved_theta[2:end] .- sgs_theta[2:end]))
            require_neutral(residual <= 5e-6 * max(1.0, maximum(abs.(total_theta))),
                            "$closure theta total is not resolved plus SGS")
            if closure == "surface_layer"
                viscosity = profile(file, "surface_layer_viscosity", key)
                diffusivity = profile(file, "surface_layer_diffusivity_ρθ", key)
                require_neutral(length(viscosity) == length(diffusivity) == 97,
                                "SLD coefficients are not on native faces")
                require_neutral(all(isfinite, viscosity) && all(isfinite, diffusivity),
                                "SLD coefficients are nonfinite")
                max_viscosity = max(max_viscosity, viscosity[2])
                max_diffusivity = max(max_diffusivity, maximum(abs.(diffusivity)))
            end
        end
        if closure == "none"
            require_neutral(max_momentum_flux == 0 && max_scalar_flux == 0,
                            "no-closure SGS flux must be exactly zero")
        else
            require_neutral(max_implicit_sgs > 1e-10 && max_viscosity > 0,
                            "implicit SLD first-supported-face stress is missing")
            require_neutral(max_scalar_flux <= 1e-7 && max_diffusivity <= 1e-7,
                            "neutral zero-heat guard produced a scalar SGS flux/coefficient")
        end
        return Dict(
            "max_abs_sgs_momentum_flux_m2_s2" => max_momentum_flux,
            "max_abs_sgs_first_supported_face_m2_s2" => max_implicit_sgs,
            "max_abs_sgs_theta_flux_K_m_s" => max_scalar_flux,
            "max_first_supported_viscosity_m2_s" => max_viscosity,
            "max_abs_theta_diffusivity_m2_s" => max_diffusivity,
            "profile_sha256" => file_sha(path))
    end
end

function check_series_semantics(path, closure)
    jldopen(path, "r") do file
        records = record_keys(file)
        require_neutral(last.(records) == collect(0.0:10.0:120.0),
                        "$closure series records are not exact 0:10:120 s")
        max_actual_heat = 0.0
        max_prescribed_heat = 0.0
        max_active = 0.0
        for (key, _) in records
            actual = scalar(file, "surface_theta_kinematic_flux", key)
            prescribed = scalar(file, "prescribed_surface_heat_flux", key)
            max_actual_heat = max(max_actual_heat, abs(actual))
            max_prescribed_heat = max(max_prescribed_heat, abs(prescribed))
            if closure == "surface_layer"
                active = scalar(file, "surface_layer_face1_ρθ_active_fraction", key)
                max_active = max(max_active, abs(active))
            end
        end
        require_neutral(max_actual_heat <= 1e-7 && max_prescribed_heat == 0,
                        "$closure has nonzero surface heat flux")
        closure == "surface_layer" && require_neutral(max_active == 0,
            "neutral SLD scalar guard activated at the first supported face")
        return Dict("max_abs_actual_heat_flux_K_m_s" => max_actual_heat,
                    "max_abs_prescribed_heat_flux_K_m_s" => max_prescribed_heat,
                    "max_scalar_guard_active_fraction" => max_active,
                    "series_sha256" => file_sha(path))
    end
end

function audit_neutral_saved_output(output_directory, supplemental_directory)
    check_sources()
    output_directory = abspath(output_directory)
    supplemental_directory = abspath(supplemental_directory)
    attempt_identity = check_original_attempt(output_directory, supplemental_directory)
    require_neutral(isfile(joinpath(output_directory, "NEUTRAL_THROUGHPUT_DONE")),
                    "frozen neutral throughput did not complete")
    require_neutral(!ispath(joinpath(output_directory, "NEUTRAL_THROUGHPUT_FAILED")),
                    "frozen neutral throughput recorded failure")
    evidence_path = joinpath(output_directory, "neutral_throughput_evidence.toml")
    frozen_evidence = TOML.parsefile(evidence_path)
    require_neutral(frozen_evidence["all_passed"] === true &&
                    frozen_evidence["mode"] == "gpu_neutral_throughput_fixture" &&
                    frozen_evidence["fixture_non_scientific"] === true &&
                    frozen_evidence["architecture"] == "CUDAGPU" &&
                    frozen_evidence["grid"] == [96, 96, 96] &&
                    frozen_evidence["domain_m"] == [3000.0, 3000.0, 1000.0] &&
                    frozen_evidence["measured_fixture_duration_s"] == 120.0 &&
                    frozen_evidence["authorized_scientific_duration_s"] == 18000.0,
                    "frozen neutral fixture evidence is not the authorized matched pair")
    registry = TOML.parsefile(REGISTRY)
    require_neutral(frozen_evidence["paired_initial_state_sha256"] ==
                    registry["paired_initial_state_sha256"],
                    "paired initial-array digest differs from sealed registry")
    gpu_admission = NeutralCombinedGpuAdmission.admit_semantic_gate(GATE_DIRECTORY)
    cases = Dict{String, Any}()
    for closure in ("none", "surface_layer")
        result = frozen_evidence["results"][closure]
        expected_prefix = closure == "none" ?
            "neutral_fixture_n096_weno9_control_cfg" :
            "neutral_fixture_n096_weno9_surface_layer_t300_s1_cfg"
        require_neutral(result["fixture_non_scientific"] === true &&
                        startswith(result["case_id"], expected_prefix) &&
                        result["initial_state_sha256"] ==
                            registry["paired_initial_state_sha256"] &&
                        result["final_time_seconds"] == 120.0 &&
                        result["iterations"] > 0 &&
                        result["elapsed_seconds"] > 0,
                        "$closure run is not a complete paired 120 s fixture")
        directory = joinpath(output_directory, closure)
        require_neutral(isfile(joinpath(directory, "FIXTURE_CASE_DONE")),
                        "$closure fixture completion sentinel missing")
        profiles = only(filter(path -> endswith(path, "_statistics.jld2"),
                               readdir(directory; join=true)))
        series = only(filter(path -> endswith(path, "_series.jld2"),
                             readdir(directory; join=true)))
        profile_audit = check_profile_semantics(profiles, closure)
        series_audit = check_series_semantics(series, closure)
        require_neutral(profile_audit["profile_sha256"] == result["statistics_sha256"] &&
                        series_audit["series_sha256"] == result["series_sha256"],
                        "$closure raw writer hash differs from frozen throughput evidence")
        for (suffix, name) in (("_initial.jld2", "initial_sha256"),
                               ("_state_bounds.jld2", "state_bounds_sha256"))
            matching = filter(path -> endswith(path, suffix), readdir(directory; join=true))
            require_neutral(length(matching) == 1 &&
                            file_sha(only(matching)) == result[name],
                            "$closure $name raw writer hash differs")
        end
        completed = parse_fields(joinpath(directory, "FIXTURE_CASE_DONE"))
        require_neutral(completed["case_id"] == result["case_id"] &&
                        completed["fixture_non_scientific"] == "true" &&
                        parse(Float64, completed["final_time_s"]) == 120.0,
                        "$closure fixture completion record differs")
        cases[closure] = merge(profile_audit, series_audit, Dict(
            "case_id" => result["case_id"],
            "iterations" => result["iterations"],
            "elapsed_seconds" => result["elapsed_seconds"],
            "simulated_seconds_per_wall_second" => result["simulated_seconds_per_wall_second"],
            "naive_five_hour_wall_seconds" => result["projected_five_hour_wall_seconds"]))
    end
    report = Dict{String, Any}(
        "schema_version" => 1,
        "mode" => "supplemental_gpu_neutral_saved_output_audit",
        "all_passed" => true,
        "fixture_non_scientific" => true,
        "scientific_completion" => false,
        "original_parent_passed" => false,
        "supplemental_audit_only" => true,
        "created_utc" => string(Dates.now(Dates.UTC)),
        "original_attempt" => attempt_identity,
        "original_output_root" => ORIGINAL_OUTPUT,
        "supplemental_auditor_sha256" => file_sha(@__FILE__),
        "source_root" => CORE_ROOT,
        "source_manifest_sha256" => CORE_MANIFEST_SHA,
        "throughput_harness_sha256" => HARNESS_SHA,
        "corrected_diagnostic_adaptation_sha256" => ADAPTATION_SHA,
        "combined_gpu_gate_directory" => GATE_DIRECTORY,
        "combined_gpu_evidence_sha256" => gpu_admission.combined_sha,
        "semantic_gpu_evidence_sha256" => gpu_admission.semantic_sha,
        "frozen_throughput_evidence_sha256" => file_sha(evidence_path),
        "cases" => cases)
    mkpath(supplemental_directory)
    report_path = joinpath(supplemental_directory, "neutral_saved_output_audit_evidence.toml")
    open(report_path, "w") do io
        TOML.print(io, report; sorted=true)
    end
    open(joinpath(supplemental_directory, "NEUTRAL_SAVED_OUTPUT_AUDIT_DONE"), "w") do io
        println(io, "mode=supplemental_gpu_neutral_saved_output_audit")
        println(io, "original_job_id=7366")
        println(io, "original_parent_passed=false")
        println(io, "fixture_non_scientific=true")
        println(io, "evidence_sha256=", file_sha(report_path))
    end
    println("NEUTRAL_SAVED_OUTPUT_AUDIT_PASSED evidence_sha256=", file_sha(report_path))
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) &&
    (length(ARGS) == 2 || error("usage: audit_neutral_saved_output_7366-v4.jl OLD_OUTPUT NEW_EVIDENCE_DIR");
     audit_neutral_saved_output(ARGS[1], ARGS[2]))
