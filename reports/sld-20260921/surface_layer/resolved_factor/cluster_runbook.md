CURRENT: already submitted 2026-09-21 22:17:45 UTC. Gate7330, array7331. DO NOT resubmit the example below. Set array_job=7331 for finalization. Campaign metadata is readonly; write attempts.toml in the campaign root.

# Factor GPU fixture retry v2

Root submits; preparation agent has submitted nothing.

Use the same conditional gate → array1-2%1 machinery from `sld-factor-runbook-20260921-v1.md`, with new paths:

- Freeze `/shared/home/greg/review-coordination/sld-factor-freeze-20260921-v2`.
- NEW campaign `/shared/home/greg/review-coordination/gabls1-sld-factor-20260921-v2` (must not exist).
- Evaluation `ec714e57615d888a9976f501c87f02fc5bb4e77f`.
- Breeze unchanged `1df78f2bb94db159e3a296f7439e1a5e90286014`.
- Source manifest `395f7a42b5cdc7dfd688d1e0b0d0d2767f11d4cb186748070d517f507b74c1c4`, 771 files.
- Admission reader SHA `c14c5659785f7c968a5c2d83ac227b8b6f8f3efa7f59cc4d56fb0cb985a0c320` (unchanged).
- GPU gate Julia SHA `1a8281f7406ea6565c86fcd5a1b3ce010cbd1eb33b6e3817fff3856bccaf3ab0`.
- Raw output auditor SHA `2c8b304fc75bdb5cd1fd2e59eba96c89e49a2106658b22f2d13ebd4e64ef5d7c`.

Preserve failedGPU7326, canceleddependent7327, v1source/evidence/raw. No science ran. Do not admit the failed v1 gate retroactively.

The old fixture incorrectly expected statistics `[1800]`. Established GABLS1 raw statistics contain `[0, 1800]`: Oceananigans initializes every writer at zero. The production exporter already checks that statistics zero is an exact duplicate of the separate initial writer before omitting it from the averaged profiles. This is a fixture expectation correction, not a model or writer change.

V2 audits exact `[0,1800]`, exact all-variable duplicate equality, exact series0:60:1800, factors in all three output files, all 33 native flux faces, finite data, and unscaled total=resolved+SGS at every interior face. Nonzero first-face momentum SGS flux is required at1800 only; uniform initial wind has zero initial shear. All remaining assertions pass on the preserved real factor1 output (81 checks). Changed timestamps, changed initial data, and wrong factors are rejected in copies (4 tests; 178 total audit checks).

Regression log `/shared/home/greg/review-coordination/sld-factor-raw-regression-v2b-20260921.log`; exact frozen rerun log `sld-factor-raw-regression-v2-frozen-20260921.log`. Reader recheck `sld-factor-v2-admission-rejection-20260921.log` correctly rejects missingGPU_VALIDATION_DONE from failedv1. SourceCPU364/QA40/doctests and v1tinyCPU146 restart/formula checks still apply to their unchanged source paths; they do not constitute new GPU admission. Root must launch and verify a freshv2GPUgate before production. Scientific runner, registry, source, launch wrappers, exporter and admission reader remain byte-identical to v1.


# Matched GABLS1 resolved-flux factor: root-only launch runbook

No jobs have been submitted by the preparation agent.

Frozen candidate: `/shared/home/greg/review-coordination/sld-factor-freeze-20260921-v2`

- Evaluation: `ec714e57615d888a9976f501c87f02fc5bb4e77f` (public branch `glw/sld-resolved-flux-factor-evaluation`).
- Breeze: `1df78f2bb94db159e3a296f7439e1a5e90286014`.
- Manifest: `395f7a42b5cdc7dfd688d1e0b0d0d2767f11d4cb186748070d517f507b74c1c4`, 771 files, readonly.
- CPU analysis: 68 existing export checks + 3 factor-identity rejection checks passed.
- Focused freeze CPU gate: `/shared/home/greg/review-coordination/sld-factor-cpu-20260921-v1`; PASSED146 checks, both factor restarts exact, `CPU_VALIDATION_DONE`, no failed sentinel. Source sibling CPU364/364, QA40 and doctests passed. GPU is still untested until the new gate runs.

Exactly two nine-hour 32³/400m WENO9 cases: one interior face, 300s filter, seed123, factors1 and2. Both momentum and heat deficits use the factor. Raw local filtered covariances and physical diagnostic fluxes stay unscaled. Local exponentially filtered covariance used by the closure is distinct from instantaneous horizontally averaged Reynolds flux in profile diagnostics. Old7293 no-closure results are historical context. No factor1.2/support/filter matrix, no u/v-only variant.

Gate and production scripts verify every source-file hash before execution. The focused new-source GPU gate tests constitutive identities, two-factor serialized continuation, materialized GPU factors/coefficient formulas, finite one-face coefficients, nonzero native implicit SGS momentum flux, unscaled physical flux partition, and actual initial/60s/1800s writer schedules. Its observer only reads filter state. It is explicitly `gpu_resolved_flux_factor`, not `gpu_full` or old7241 reuse. Gate fixtures are not scientific results.

Root: first confirm queue capacity (at most two evaluation GPUs; original7120_2 may occupy one), exact hashes, clean reviewed sources, and CPU passes. Choose a NEW absolute campaign directory. For example:

```bash
set -euo pipefail
freeze=/shared/home/greg/review-coordination/sld-factor-freeze-20260921-v2
campaign=/shared/home/greg/review-coordination/gabls1-sld-factor-20260921-v2
evaluation="$freeze/source/BreezeEvaluation.jl"
test ! -e "$campaign"
mkdir -p "$campaign"/{runs,logs,metadata}
cp "$freeze/source_sha256.txt" "$freeze/README.md" "$campaign/metadata/"
cp "$evaluation/cases/surface_layer/registries/gabls1_sld_resolved_factor.toml" "$campaign/metadata/"
gate_job=$(/opt/slurm/bin/sbatch --parsable --partition=gpu-prod --gpus=1 --mem=32G \
  --output="$campaign/logs/factor_gate_%j.out" \
  --export="ALL,SLD_FREEZE_ROOT=$freeze,SLD_VALIDATION_OUTPUT=$campaign/gpu_gate" \
  "$evaluation/cases/surface_layer/gpu_validation/resolved_factor_gpu_gate.slurm")
[[ "$gate_job" =~ ^[0-9]+$ ]]
array_job=$(/opt/slurm/bin/sbatch --parsable --partition=gpu-prod --gpus=1 --mem=32G \
  --array=1-2%1 --dependency="afterok:$gate_job" \
  --output="$campaign/logs/gabls1_factor_%A_%a.out" \
  --export="ALL,SLD_FREEZE_ROOT=$freeze,SLD_VALIDATION_EVIDENCE=$campaign/gpu_gate,SLD_RUN_ROOT=$campaign/runs,SLD_EXIT_RECORD_ROOT=$campaign/logs" \
  "$evaluation/cases/surface_layer/registries/run_resolved_factor_array.slurm")
[[ "$array_job" =~ ^[0-9]+$ ]]
printf 'gate_job_id=%s\narray_job_id=%s\nsubmitted_utc=%s\n' "$gate_job" "$array_job" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$campaign/submission.txt"
```

If the gate fails, no production runs start. Preserve the candidate and failed evidence; review before making another immutable candidate. Do not relabel old GPU evidence or patch a freeze.

After successful gate, independently run its admission reader from the same freeze; after both production jobs finish, verify exit0 records/logs and finalize/export:

```bash
julia=/shared/home/greg/.juliaup/bin/julia
project="$evaluation/cases/gabls3/runner"
analysis="$evaluation/cases/surface_layer/analysis"
"$julia" --startup-file=no --project="$project" \
  "$evaluation/cases/surface_layer/gpu_validation/admit_resolved_flux_factor.jl" "$campaign/gpu_gate" "$freeze"
"$julia" --startup-file=no --project="$project" \
  "$analysis/finalize_resolved_factor_attempts.jl" "$freeze" "$campaign/gpu_gate" "$array_job" \
  "$campaign/runs" "$campaign/logs" "$campaign/attempts.toml"
for id in gabls1_n032_weno9_surface_layer_t300_s1_rf1p0 gabls1_n032_weno9_surface_layer_t300_s1_rf2p0; do
  "$julia" --startup-file=no --project="$project" "$analysis/export_case.jl" \
    "$campaign/attempts.toml" "$id" "$campaign/analysis_export"
done
"$julia" --startup-file=no --project="$project" "$analysis/collect_admitted_exports.jl" \
  "$campaign/attempts.toml" "$campaign/analysis_export" "$campaign/collection"
```

Require admitted=2/rejected=0, exact19 profiletimes0:1800:32400 and541 series0:60:32400, both unique IDs/factor metadata, same source/registry/analysis, and paired initial digest before comparing. The existing four-variant plotting convenience loader is deliberately unchanged: factor plotting should load the two exports individually, verify matching provenance and factor identity, then use native-coordinate final-hour profile helpers. Keep reference1m median and historical no-closure/Smag clearly identified as context.
