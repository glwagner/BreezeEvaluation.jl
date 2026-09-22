LATEST: factor10 completed nine hours and was strictly admitted1/rejected0. GPU7338 passed4462checks; science7339 childexit0. Local audit analysis_v2/audit_transfer.toml verifies19profile/541series records and all compact transfer hashes. Evaluation branch glw/sld-factor10-evaluation is public at cbe90cee275866f742275127de95b6148d2a4653. Earlier submission status below is historical.

CURRENT: root has submitted corrected V2. GPU gate7338 is running on node1; single nine-hour science job7339 is pending afterok:7338. DO NOT resubmit the example below. Campaign `/shared/home/greg/review-coordination/gabls1-sld-factor10-20260921-v2`; gate log `logs/gate_7338.out`, science log `logs/gabls1_factor10_7339.out`, durable science exit record in the same logs directory. Set `science_job=7339` for finalization.

CPU admission: V2 focused gate PASSED88 checks, including exact manufactured zero/guard/cap fractions, unchanged complete prognostic/closure/filter state, and serialized factor10 restart with zero mismatches. Exporter regression PASSED71/71. Both exited0. CPU evidence `/shared/home/greg/review-coordination/sld-factor10-cpu-20260921-v2/validation_evidence.toml`, SHA`5262822d0358d2deb473cadfbe545b9db6cf0c98e4f2b23fb80ee76565083f28`. GPU admission still requires7338 to finish and its source-specific reader to pass.

# Factor10 preparation and root-only scheduling

No production or GPU job has been submitted by the preparation agent. Root canceled first candidateGPU7337 after the manufactured reduced-field callback arity defect was identified. V1CPU failure, candidate and job output remain preserved. Use only the corrected V2 candidate below.

- Freeze: `/shared/home/greg/review-coordination/sld-factor10-freeze-20260921-v2`
- Evaluation: `cbe90cee275866f742275127de95b6148d2a4653`, branch `glw/sld-factor10-evaluation`
- Breeze unchanged: `1df78f2bb94db159e3a296f7439e1a5e90286014`
- Manifest: `32ebced6c54266ce5f9d7300759635e51d599bc1b090ced070eaa6111e540b0f`,779 files
- Registry: `cases/surface_layer/registries/gabls1_sld_factor10.toml`, SHA`d1f4e56ed705ce035207d9900e8da441cb8f4d3a06a283acaa4958e08f314519`
- Gate wrapper: `cases/surface_layer/gpu_validation/factor10_gpu_gate.slurm`, SHA`be4aa36cf904f89bd00af75fa2938484e32a347201a5dedc2f4359a7480aecac`
- Admission reader: `cases/surface_layer/gpu_validation/admit_factor10.jl`, SHA`2fc5bc06c12b33da6bc3fba2095dd33649fd8503e8205b6cfed79e6178a0e169`
- Single-case wrapper: `cases/surface_layer/registries/run_factor10.slurm`, SHA`6e479e83a6e20859704944add7eda50a64a71c79dfc45c3d136d2c80688e00ec`

Before root submission: require focusedCPU completion `/shared/home/greg/review-coordination/sld-factor10-cpu-20260921-v2/CPU_VALIDATION_DONE`, no failed sentinel, and successful exporter regression log `/shared/home/greg/review-coordination/sld-factor10-export-20260921-v2.log`. CPU log is `sld-factor10-cpu-20260921-v2.log`. V1CPU146/source364/QA40 tests do not replace these new diagnostic checks or the factor10GPU gate.

One case only: GABLS1WENO9,32³,400m×400m×400m,12.5m spacing,one interior face,300s averaging,seed123,32400s. Factor10 applies to signed local temporally filtered momentum and heat covariance in the deficit; physical reported covariance and resolved/SGS/total flux remain unscaled. Crediting10× resolved corresponds to assuming missing9× resolved, not measuring numerical flux. No repeated control is needed: factor1's every profile and time-series datum already reproduces7293 oneface300 exactly.

Six new read-only face1 spatial fractions separately describe raw clipped deficit<=0, guard-valid AND deficit<=0, and actual coefficient<=0 for momentum/heat. Every denominator is all horizontal points. Existing active fractions are target/guard/support validity; caps are separate. These fractions were not saved for factors1/2 and must remain marked unavailable there. Deficit/fraction units are dimensionless in the new exporter; old artifacts are preserved.

Both launchers use non-login `/bin/bash` and explicit Julia/project paths, preserving inherited Slurm/CUDA environment without sourcing `.bash_logout`. Both check every frozen source hash before executing. The gate tests signs, guards/caps, manufactured exact fractions and unchanged full prognostic/closure/filter state, factor10 restart, and1800s GPU integration with native raw[0,1800] statistics, initial[0], series0:60:1800, exact initial duplicate and unscaled flux partition. A factor10 coefficient may legitimately become zero, so positivity is not imposed as a false scientific requirement.

Root conditional launch example; choose a NEW campaign, confirm original7120_2 is the only other evaluation GPU allocation:

```bash
set -euo pipefail
freeze=/shared/home/greg/review-coordination/sld-factor10-freeze-20260921-v2
campaign=/shared/home/greg/review-coordination/gabls1-sld-factor10-20260921-v2
evaluation="$freeze/source/BreezeEvaluation.jl"
test ! -e "$campaign"
mkdir -p "$campaign"/{runs,logs,metadata}
cp "$freeze/source_sha256.txt" "$freeze/README.md" "$campaign/metadata/"
cp "$evaluation/cases/surface_layer/registries/gabls1_sld_factor10.toml" "$campaign/metadata/"
gate_job=$(/opt/slurm/bin/sbatch --parsable --partition=gpu-prod --gpus=1 --mem=32G \
  --output="$campaign/logs/gate_%j.out" \
  --export="ALL,SLD_FREEZE_ROOT=$freeze,SLD_VALIDATION_OUTPUT=$campaign/gpu_gate" \
  "$evaluation/cases/surface_layer/gpu_validation/factor10_gpu_gate.slurm")
[[ "$gate_job" =~ ^[0-9]+$ ]]
science_job=$(/opt/slurm/bin/sbatch --parsable --partition=gpu-prod --gpus=1 --mem=32G \
  --dependency="afterok:$gate_job" \
  --output="$campaign/logs/gabls1_factor10_%j.out" \
  --export="ALL,SLD_FREEZE_ROOT=$freeze,SLD_VALIDATION_EVIDENCE=$campaign/gpu_gate,SLD_RUN_ROOT=$campaign/runs,SLD_EXIT_RECORD_ROOT=$campaign/logs" \
  "$evaluation/cases/surface_layer/registries/run_factor10.slurm")
[[ "$science_job" =~ ^[0-9]+$ ]]
printf 'gate_job_id=%s\nscience_job_id=%s\nsubmitted_utc=%s\n' "$gate_job" "$science_job" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$campaign/submission.txt"
```

No array, no duplicate baseline. The production wrapper re-admits the source-specific gate itself before running. Require matching gate evidence independently after GPU completion; scientific completion must have durable childexit0,32400s CASE_DONE and all scheduled output records, not merely successful Slurm status.

Finalization and export after science completion:

```bash
julia=/shared/home/greg/.juliaup/bin/julia
project="$evaluation/cases/gabls3/runner"
analysis="$evaluation/cases/surface_layer/analysis"
"$julia" --startup-file=no --project="$project" \
  "$evaluation/cases/surface_layer/gpu_validation/admit_factor10.jl" "$campaign/gpu_gate" "$freeze"
"$julia" --startup-file=no --project="$project" \
  "$analysis/finalize_factor10_attempt.jl" "$freeze" "$campaign/gpu_gate" "$science_job" \
  "$campaign/runs" "$campaign/logs" "$campaign/attempts.toml"
"$julia" --startup-file=no --project="$project" "$analysis/export_case.jl" \
  "$campaign/attempts.toml" gabls1_n032_weno9_surface_layer_t300_s1_rf10p0 "$campaign/analysis_export"
"$julia" --startup-file=no --project="$project" "$analysis/collect_admitted_exports.jl" \
  "$campaign/attempts.toml" "$campaign/analysis_export" "$campaign/collection"
```

Require admitted1/rejected0 and factor10 metadata; retain19 exported profile records and541 series records. Compare both7–8h and8–9h with admitted1/2 using native profiles and unscaled actual fluxes. Separate new guard-valid switch-off fractions from actual zero coefficients, and mark these spatial fractions unavailable in old1/2 output. Numerical transport remains unmeasured regardless of apparent improvement.
