#!/usr/bin/env julia

# Read-only admission of the versioned supplemental audit of failed parent 7366.
# This admits the saved 120 s fixture evidence, NOT the failed parent or LES science.
using SHA
using TOML

const SUPPLEMENTAL_ROOT = "/shared/home/greg/review-coordination/neutral-speed-gate-7366-saved-output-audit-v4-20260922"
const SUPPLEMENTAL_SHA = "c3c44a8a6c71a5b8e0166dc26477e18ab823c708d75faabe0b367ba8a13bec7c"
const AUDITOR_PATH = "/shared/home/greg/review-coordination/audit_neutral_saved_output_7366-v4.jl"
const AUDITOR_SHA = "d4ec5729c91456dcb9bd4aae36fcd5a24dc3bea1c2e9fa10beabc0e024d36a2e"
const ORIGINAL_PARENT = "/shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614"
const CORE_ROOT = "/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647"
const CORE_SHA = "d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
const COMBINED_PARENT = "/shared/home/greg/review-coordination/surface-layer-flux-schedule-gpu-validation-v3-20260921-1806"
const COMBINED_SHA = "55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02"
const THROUGHPUT_SHA = "579d99ee07d361684899f1f837cfbf17d3d4a2e9da0e3a1ecd8a44320b021231"
const ORIGINAL_LOG_SHA = "99a5ff35bb85907ef31b589e0f644d2d218f0fba3b718f4eae5090e8c0be1455"
const ORIGINAL_EXIT_SHA = "44334abc939d955e3af82ef5a67efc8c069478b0667e2bacd2a0faf6a378d2d0"

module CombinedGateReader
include("/shared/home/greg/review-coordination/admit_sld_flux_schedule_gpu_gate_a14c358-v3.jl")
end

digest(path) = bytes2hex(open(sha256, path))
require_saved(condition, message) = condition || error(message)

function fields(path)
    result = Dict{String, String}()
    for line in eachline(path)
        key, value = split(line, '='; limit=2)
        result[key] = value
    end
    return result
end

function only_suffix(directory, suffix)
    matching = filter(path -> endswith(path, suffix), readdir(directory; join=true))
    require_saved(length(matching) == 1, "expected one $suffix in $directory")
    return only(matching)
end

function admit_neutral_saved_output()
    require_saved(digest(AUDITOR_PATH) == AUDITOR_SHA,
                  "supplemental auditor source changed")
    evidence_path = joinpath(SUPPLEMENTAL_ROOT, "neutral_saved_output_audit_evidence.toml")
    done_path = joinpath(SUPPLEMENTAL_ROOT, "NEUTRAL_SAVED_OUTPUT_AUDIT_DONE")
    require_saved(isfile(evidence_path) && isfile(done_path) &&
                  !ispath(joinpath(SUPPLEMENTAL_ROOT, "NEUTRAL_SAVED_OUTPUT_AUDIT_FAILED")),
                  "supplemental audit evidence is incomplete")
    require_saved(digest(evidence_path) == SUPPLEMENTAL_SHA,
                  "supplemental evidence SHA changed")
    done = fields(done_path)
    require_saved(done["mode"] == "supplemental_gpu_neutral_saved_output_audit" &&
                  done["original_job_id"] == "7366" &&
                  done["original_parent_passed"] == "false" &&
                  done["fixture_non_scientific"] == "true" &&
                  done["evidence_sha256"] == SUPPLEMENTAL_SHA,
                  "supplemental DONE identity differs")
    report = TOML.parsefile(evidence_path)
    require_saved(report["all_passed"] === true &&
                  report["fixture_non_scientific"] === true &&
                  report["scientific_completion"] === false &&
                  report["original_parent_passed"] === false &&
                  report["supplemental_audit_only"] === true &&
                  report["supplemental_auditor_sha256"] == AUDITOR_SHA &&
                  report["source_root"] == CORE_ROOT &&
                  report["source_manifest_sha256"] == CORE_SHA &&
                  report["combined_gpu_gate_directory"] == COMBINED_PARENT &&
                  report["combined_gpu_evidence_sha256"] == COMBINED_SHA &&
                  report["frozen_throughput_evidence_sha256"] == THROUGHPUT_SHA,
                  "supplemental evidence contract differs")
    require_saved(digest(joinpath(CORE_ROOT, "source_sha256.txt")) == CORE_SHA,
                  "frozen core manifest changed")
    combined = CombinedGateReader.admit_semantic_gate(COMBINED_PARENT)
    require_saved(combined.combined_sha == COMBINED_SHA,
                  "prerequisite GPU gate changed")
    require_saved(digest(joinpath(ORIGINAL_PARENT, "gate_7366.log")) == ORIGINAL_LOG_SHA &&
                  digest(joinpath(ORIGINAL_PARENT, "child.exit")) == ORIGINAL_EXIT_SHA &&
                  fields(joinpath(ORIGINAL_PARENT, "child.exit"))["child_exit_code"] == "1" &&
                  isfile(joinpath(ORIGINAL_PARENT, "output", "NEUTRAL_SPEED_GATE_FAILED")) &&
                  !ispath(joinpath(ORIGINAL_PARENT, "output", "NEUTRAL_SPEED_GATE_DONE")),
                  "original failed parent identity changed")
    original_evidence_path = joinpath(ORIGINAL_PARENT, "output", "neutral_throughput_evidence.toml")
    require_saved(digest(original_evidence_path) == THROUGHPUT_SHA,
                  "saved throughput evidence changed")
    original = TOML.parsefile(original_evidence_path)
    for closure in ("none", "surface_layer")
        directory = joinpath(ORIGINAL_PARENT, "output", closure)
        source = original["results"][closure]
        audited = report["cases"][closure]
        for (suffix, source_key, audited_key) in (
            ("_statistics.jld2", "statistics_sha256", "profile_sha256"),
            ("_series.jld2", "series_sha256", "series_sha256"),
            ("_initial.jld2", "initial_sha256", nothing),
            ("_state_bounds.jld2", "state_bounds_sha256", nothing))
            actual = digest(only_suffix(directory, suffix))
            require_saved(actual == source[source_key],
                          "$closure $suffix saved writer hash differs")
            isnothing(audited_key) || require_saved(actual == audited[audited_key],
                                                   "$closure $suffix supplemental hash differs")
        end
        require_saved(audited["case_id"] == source["case_id"] &&
                      audited["iterations"] == source["iterations"] &&
                      audited["elapsed_seconds"] == source["elapsed_seconds"],
                      "$closure identity/timing differs")
    end
    require_saved(report["cases"]["none"]["max_abs_sgs_momentum_flux_m2_s2"] == 0 &&
                  report["cases"]["surface_layer"]["max_abs_sgs_first_supported_face_m2_s2"] > 0 &&
                  report["cases"]["surface_layer"]["max_first_supported_viscosity_m2_s"] > 0 &&
                  report["cases"]["surface_layer"]["max_abs_theta_diffusivity_m2_s"] == 0 &&
                  report["cases"]["surface_layer"]["max_scalar_guard_active_fraction"] == 0,
                  "saved flux/guard audit conclusions differ")
    println("NEUTRAL_SAVED_OUTPUT_ADMITTED original_job_id=7366 original_child_exit=1",
            " supplemental_sha256=", SUPPLEMENTAL_SHA,
            " fixture_non_scientific=true")
    return report
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && admit_neutral_saved_output()
