# Neutral ABL 7366 saved-output audit and root-only science-pair handoff

Prepared 2026-09-22 UTC. **No GPU rerun or five-hour scientific job was submitted.** No frozen model/diagnostic source or original 7366 parent was changed. WENO reconstructed-flux closure remains on hold.

## Outcome and exact identities

The original parent `/shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614` remains **FAILED**: job **7366**, `child.exit` code **1** (SHA `44334abc939d955e3af82ef5a67efc8c069478b0667e2bacd2a0faf6a378d2d0`), `gate_7366.log` SHA `99a5ff35bb85907ef31b589e0f644d2d218f0fba3b718f4eae5090e8c0be1455`, original v3 auditor SHA `4b5c0bcbbefd7f1d7bd136dd849ae561dadd3a4e686d410e9693dd216e292fbc`, and the old `output/NEUTRAL_SPEED_GATE_FAILED` remains present. The **two 120 s GPU fixture runs themselves completed**, with `output/NEUTRAL_THROUGHPUT_DONE` and `neutral_throughput_evidence.toml` SHA `579d99ee07d361684899f1f837cfbf17d3d4a2e9da0e3a1ecd8a44320b021231`. The old auditor failed only while reading a numeric scalar JLD2 leaf with `vec(::Float64)`; no old success sentinel has been written or inferred.

The versioned, coordination-only replacement `/shared/home/greg/review-coordination/audit_neutral_saved_output_7366-v4.jl` SHA `d4ec5729c91456dcb9bd4aae36fcd5a24dc3bea1c2e9fa10beabc0e024d36a2e` accepts either a numeric `Number` or a singleton numeric array. Its synthetic regression `/shared/home/greg/review-coordination/test_audit_neutral_saved_output_7366-v4.jl` SHA `91d09b1b11fd54ec74ec17c68d6ba38db458b67b18571f8861882706f405673a` passed **14/14** under the frozen Julia 1.12.6 runner environment; it exercises both actual JLD2 storage forms, singleton 3-D arrays, multi-element rejection, and the prior flux/guard negative fixtures.

The **read-only re-audit of existing raw GPU outputs passed** and wrote only to the new sibling directory `/shared/home/greg/review-coordination/neutral-speed-gate-7366-saved-output-audit-v4-20260922`. Its `neutral_saved_output_audit_evidence.toml` SHA is `c3c44a8a6c71a5b8e0166dc26477e18ab823c708d75faabe0b367ba8a13bec7c`, matched by `NEUTRAL_SAVED_OUTPUT_AUDIT_DONE` there. It explicitly records `original_parent_passed=false`, `supplemental_audit_only=true`, `fixture_non_scientific=true`, `scientific_completion=false`, original job/exit/log/auditor hashes, full source/gate identities, and all raw writer hashes. Standalone read-only admission `/shared/home/greg/review-coordination/admit_neutral_saved_output_7366-v4.jl` SHA `f5b57980bb076f4304bc908c15e334d5acceb2e71896fdd698bc8c276bb08b36` also passed; it rechecks the v3 combined gate and the unchanged original failed parent. **This supplemental pass is not a retroactive 7366 job exit-zero claim.** Root must explicitly accept it as a saved-output GPU cost/flux gate before science launch.

Source remains the 761-file read-only `a14c358`/Breeze `02a1647` core at `/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647`, manifest SHA `d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c`; prerequisite v3 combined GPU gate 7241 evidence SHA `55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02`. No GABLS3-only `131ad9b` humidity source or gate is substituted into this dry fixed-stress neutral pair.

## Measured raw physics/record audit

- Both cases have exactly 60/120 s true averaged native profiles, 0:10:120 s reduced series, finite 96-center/97-face writers, matched seed-1994 initial-array digests, and matching raw profile/series/initial/state-bounds SHA-256s. The v4 auditor retained all v3 interior `total=resolved+SGS` checks and the separate prescribed wall-face substitution; it did not relax any flux, guard, or hash threshold.
- Control SGS u/v/θ flux is exactly zero. SLD's maximum first-supported-face momentum SGS flux is **0.1205740571 m² s⁻²**, first-supported viscosity **2.0833334923 m² s⁻¹**. Its SGS θ flux, θ diffusivity, scalar guard activity, actual/prescribed surface heat flux are all **zero**. Direct read-only JLD2 spot check found wall-stress vector magnitudes `(0.25, 0.25000003)` m² s⁻² at 60/120 s in **both** cases, consistent with fixed `u*=0.5 m/s`; this does not test a prognostic drag law.
- The scientific pair remains WENO9/no closure versus WENO9/one-face SLD T=300 s, same 96³/3000×3000×1000 m grid, seed 1994, geostrophic/Coriolis/sponge forcing, initial state and prescribed wall stress, zero heat, no roughness/MOST law. Scientific output requires separate t=0 initial profile, 30 preceding-600 s averages through 18000 s, 301 one-minute series records, hourly checkpoints, and six-bin final/penultimate hours. None of these five-hour requirements are proved by the short fixture.

## Defensible cost reading

Reproducible Julia analysis `/shared/home/greg/review-coordination/analyze_neutral_cost_7366.jl` SHA `fdcb5b2786002f364195f3783541719fccabaf030367dd7ba943ebaf264c0acb` wrote `cost_assessment.toml` SHA `cd94d6b38b23d6ea9c52acb38f05f9092baf9b8a79bd3d5ddfcebea8b678d558` in the new supplemental directory. It binds the exact 7366 log and both evidence hashes. Log initialization durations are rounded to milliseconds/0.001 minutes.

| 120 s fixture | Control | SLD |
|---|---:|---:|
| Reported total `run!` wall time, **including initialization** | 113.804 s | 51.405 s |
| Measured-run initialization from log | ~108.120 s | 42.468 s |
| Measured-run first step from log | ~2.524 s | 4.992 s |
| Remaining post-initialization time | ~5.684 s | 8.937 s |
| After first step, 125-step mean | ~0.02528 s/step | 0.03156 s/step |
| Conditional 5 h solver estimate from that rate and last dt | ~317 s (5.3 min) | ~396 s (6.6 min) |
| Conditional 5 h solver estimate scaling all post-init 120 s time | ~853 s (14.2 min) | ~1341 s (22.3 min) |
| **Invalid** total-elapsed ×150 projection recorded by harness | ~4.74 h | ~2.14 h |

SLD is about **25% slower per post-first-step iteration**, not faster as total fixture time alone suggests. The two corrected projections are *scenarios, not lower/upper bounds*: the final dt may change as turbulence develops, long-run writer/checkpoint load differs, and a fresh process can repeat startup compilation. Root should budget substantial headroom (a two-hour allocation per sequential case is a cautious starting request) and monitor actual step time/remaining walltime; do not claim a measured five-hour runtime or equilibrium from this fixture.

## Exact executed Julia commands

```bash
PROJECT=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647/source/BreezeEvaluation.jl/cases/gabls3/runner
JULIA=/shared/home/greg/.juliaup/bin/julia
$JULIA --startup-file=no --project="$PROJECT" \
  /shared/home/greg/review-coordination/test_audit_neutral_saved_output_7366-v4.jl

SLD_COMBINED_GPU_EVIDENCE=/shared/home/greg/review-coordination/surface-layer-flux-schedule-gpu-validation-v3-20260921-1806 \
$JULIA --startup-file=no --project="$PROJECT" \
  /shared/home/greg/review-coordination/audit_neutral_saved_output_7366-v4.jl \
  /shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614/output \
  /shared/home/greg/review-coordination/neutral-speed-gate-7366-saved-output-audit-v4-20260922

$JULIA --startup-file=no --project="$PROJECT" \
  /shared/home/greg/review-coordination/admit_neutral_saved_output_7366-v4.jl

$JULIA --startup-file=no --project="$PROJECT" \
  /shared/home/greg/review-coordination/analyze_neutral_cost_7366.jl \
  /shared/home/greg/review-coordination/neutral-speed-gate-20260922-0614 \
  /shared/home/greg/review-coordination/neutral-speed-gate-7366-saved-output-audit-v4-20260922/cost_assessment.toml
```

The two writers refuse existing destinations; the above records are complete and must **not** be rerun in place. The reader command is repeatable and read-only.

## Prepared root-only scientific pair; **unsubmitted**

The separately versioned non-login array child wrapper `/shared/home/greg/review-coordination/run_neutral_science_pair_7366-v1.sh` SHA `3bb1dfc34e4288604aaaad1c23cd828964a7e2f5917d88297cc27b99dafbceae` passed `bash -n` and a no-output invalid-root preflight. It pins the 761-file a14c358 source, neutral registry SHA `5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156`, and the strict supplemental admission reader SHA. Before constructing either case it re-admits v3/7241 and the 7366 saved-output supplement; it then enforces the canonical scientific settings, distinct case IDs, fresh run directories, `ATTEMPT_STARTED`, exact `CASE_DONE` case/time, and durable child-exit records. A missing exit record or nonzero child is not admission. **This wrapper has not been executed on GPU and is a root-review candidate**, not scientific validation.

After root explicitly accepts the supplemental gate and reviews the wrapper/resource request, a *fresh* campaign root with `runs/`, `logs/`, and `metadata/` could be created. Archive the exact wrapper/reader/evidence SHA values there before submission. A root-only command template (do not paste `UNIQUE` literally) is:

```bash
CAMPAIGN=/shared/home/greg/review-coordination/neutral-sld-science-UNIQUE
mkdir -p "$CAMPAIGN/runs" "$CAMPAIGN/logs" "$CAMPAIGN/metadata"
SLD_NEUTRAL_SCIENCE_ROOT="$CAMPAIGN" \
sbatch --parsable --job-name=sld-neutral-pair --partition=gpu-prod \
  --nodes=1 --ntasks=1 --gpus=h100:1 --cpus-per-task=8 --mem=32G \
  --time=02:00:00 --array=1-2%1 --export=ALL \
  --output="$CAMPAIGN/logs/neutral_%A_%a.out" \
  --wrap='exec /bin/bash /shared/home/greg/review-coordination/run_neutral_science_pair_7366-v1.sh'
```

Root remains sole scheduler and must preserve the global two-GPU limit and higher-priority work. **Do not scientifically admit or plot** merely because an array task exits zero: post-run finalization must verify both actual 18000 s cases, durable exits, source/initial digests, all exact native profile/series/initial/checkpoint schedules, finite states, raw hashes and wall/interior flux/guard semantics, then use a separately pinned Julia exporter/collector. No such neutral scientific finalizer/export has been executed or is claimed by this handoff. No WENO reconstructed-flux development or test is authorized here.
