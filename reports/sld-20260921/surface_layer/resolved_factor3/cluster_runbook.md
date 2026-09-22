# GABLS1 resolved-flux factor3: completed campaign

The single factor3 case completed nine simulated hours and passed the frozen scientific reader: **admitted 1, rejected 0**. Root submitted GPU gate **7347** after GABLS3 task7343_1, then science **7348** after successful gate completion. The gate passed4424 checks; science recorded `CASE_DONE` and durable child exit0. Integration wall time was10.824 minutes (this excludes compilation/startup). Root has released the temporary holds on GABLS3 tasks7343_2–4. Do not resubmit these jobs.

## Source and scope

- Campaign: `/shared/home/greg/review-coordination/gabls1-sld-factor3-20260922-v1`
- Immutable freeze: `/shared/home/greg/review-coordination/sld-factor3-freeze-20260922-v1`
- Public evaluation branch: `glw/sld-factor3-evaluation`
- Evaluation commit: `b9c31029929650c61040a5a20f9699de9a457978` (remote branch head verified)
- Breeze physics commit: `1df78f2bb94db159e3a296f7439e1a5e90286014`, unchanged from factors1/2/10
- Frozen source manifest: `818b06d6ed93968232d8ea3049e2098b3fbbbd2c2b1764f1cdc8f3103769709b`,786 files
- Registry SHA256: `e6afbb08e7af4995df8611578121d3304d81986c0b809ffe9938c2bb958f154a`
- Case: `gabls1_n032_weno9_surface_layer_t300_s1_rf3p0`

The case uses32³ cells in400m ×400m ×400m,12.5m spacing, WENO9, one supported interior face,300s covariance filter, seed123, and32400s duration. Both momentum and heat deficits credit3 times the signed local filtered resolved covariance. This assumes a missing numerical contribution of2 times resolved; it does not measure numerical flux. All reported actual resolved/SGS/total fluxes remain unscaled. The scientific runner and diagnostic implementation are byte-identical to factor10. No new control was run: the earlier factor1 output matched corrected7293 oneface300 bitwise. No scheme-native reconstruction work is included.

The six read-only face1 fractions distinguish raw nonpositive deficit, guard-valid nonpositive deficit, and actual zero coefficient, separately for momentum and heat. Their denominator is all horizontal points. Existing active fractions mean valid target/guard/support, not positive mixing. These newer fractions are unavailable for factors1/2; they must not be fabricated from mean coefficients.

## Validation and admission

Focused CPU gate passed88 checks, including factor3 aligned, quarter-target, opposing-sign, guard/cap, exact synthetic fractions, observer state invariance, and serialized restart with zero mismatches. Exporter regressions passed71/71. CPU evidence SHA256: `c92ef8bd5f37e4900ea1fe872d5d5ea58ff463a3d3496e2a54691793945e454f`.

GPU gate7347 passed4424 checks including1800s factor3 integration, exact writer schedules, finite coefficients, unscaled physical flux partition, fractions, accepted-step filters and restart. GPU evidence SHA256: `e2023069d0527ad7efa2a490a6765e18392ff29fdfd263923c8e7b240bfc0c98`.

Both wrappers are non-login bash, use explicit Julia/project paths and verify every frozen file hash before execution. Science re-admits the GPU evidence before running. Admission relies on complete source-bound output and durable exit evidence, not solely scheduler labels.

Final attempts SHA256: `4b8627478204afcaf50360a90aac27ac36268f8c3bb9404c57897a468204a3ca`.

## Completed finalization commands

These are a record of the commands already run successfully. The finalizer creates a new attempts registry; do not overwrite it or rerun science.

```bash
freeze=/shared/home/greg/review-coordination/sld-factor3-freeze-20260922-v1
campaign=/shared/home/greg/review-coordination/gabls1-sld-factor3-20260922-v1
evaluation="$freeze/source/BreezeEvaluation.jl"
project="$evaluation/cases/gabls3/runner"
analysis="$evaluation/cases/surface_layer/analysis"
julia=/shared/home/greg/.juliaup/bin/julia
"$julia" --startup-file=no --project="$project" "$evaluation/cases/surface_layer/gpu_validation/admit_factor3.jl" "$campaign/gpu_gate" "$freeze"
"$julia" --startup-file=no --project="$project" "$analysis/finalize_factor3_attempt.jl" "$freeze" "$campaign/gpu_gate" 7348 "$campaign/runs" "$campaign/logs" "$campaign/attempts.toml"
"$julia" --startup-file=no --project="$project" "$analysis/export_case.jl" "$campaign/attempts.toml" gabls1_n032_weno9_surface_layer_t300_s1_rf3p0 "$campaign/analysis_export"
"$julia" --startup-file=no --project="$project" "$analysis/collect_admitted_exports.jl" "$campaign/attempts.toml" "$campaign/analysis_export" "$campaign/collection"
```

## Local compact collection

- `exports_v1/`: admitted profile/series CSVs and case manifest
- `collection_v1/`: strict admission collection manifest
- `analysis_v1/`: exact frozen analysis modules, source manifest, attempts registry and local Julia transfer audit
- `evidence_v1/{cpu,gpu}/`: source-bound evidence and completion sentinels
- `logs_v1/`: GPU gate, science stdout/durable exit, CPU/exporter tests

`analysis_v1/audit_transfer.jl` independently checks compact output/module/evidence/log hashes, factor identity, full19 profile times and541 series times, native32/33 levels, finite fractions within[0,1] and guard/zero relationships, and actual resolved+SGS=total flux at interior faces. Unsupported higher-face SGS must be zero. See `analysis_v1/audit_transfer.toml` for the completed local audit.
