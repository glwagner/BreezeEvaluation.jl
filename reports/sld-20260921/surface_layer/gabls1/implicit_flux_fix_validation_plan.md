# Diagnostic-only SLD SGS-flux fix: validation and handoff

Prepared by pane 48 on 2026-09-21. This is a **new evaluation diagnostic revision only** in `/shared/home/greg/Projects/BreezeEvaluation-surface-layer`; Breeze feature source, immutable GPU-admitted core, all existing runs/exports, and scheduler state remain unchanged. Root owns any GPU scheduling, replacement-run decision, collection, and report.

## Fix contract

The shared GABLS1/GABLS3 frozen diagnostic helper is hash-checked and adapted in memory. For `SurfaceLayerDiffusivity` *output evaluation only*, its momentum, heat, and moisture SGS flux calls use Oceananigans' full constitutive vertical-flux operators via `ExplicitTimeDiscretization()`. The actual model closure remains `VerticallyImplicitTimeDiscretization` and continues through the same implicit solver. No-closure stays exactly zero; other closures retain their original discretization. Native F-C-F/C-F-F/C-C-F coefficient locations, Breeze density-weighted wrappers, and the actual bottom wall BoundaryConditionOperation are retained.

The detailed affected-variable list and checkpoint recovery limit are recorded in `/shared/home/greg/review-coordination/surface-layer-sgs-flux-diagnostic-audit.md` and `cases/surface_layer/diagnostics/README.md`. Old exports must not be overwritten or re-admitted as corrected flux/depth evidence.

## Completed CPU gate and exact command

The analytic direct-operator test passed **46/46** in the GPU-admitted frozen runner environment. It uses an explicitly Float32 grid, checks both active faces and a zero-coefficient face, signed nonzero u/v/θ/q fluxes, varying density, nonuniform native-staggered coefficients against `ivd_diffusivity`, the explicit tendency's old zero behavior, and no-closure zero. It does not claim a full model result. An initial Float32 fixture with a non-binary θ slope exposed representational sampling error; the final fixture uses exactly representable analytic slopes rather than relaxed tolerances.

```sh
JULIA=/shared/home/greg/.juliaup/bin/julia
PROJECT=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-9fb39dc-02a1647/source/BreezeEvaluation.jl/cases/gabls3/runner
cd /shared/home/greg/Projects/BreezeEvaluation-surface-layer
"$JULIA" --startup-file=no --project="$PROJECT" \
  cases/surface_layer/test_implicit_sgs_flux_diagnostics.jl
```

The existing short GABLS3 three-variant CPU writer fixture passed **345/345** with the same frozen runner environment (fixture root `/tmp/jl_6lFJ9e`, not scientific data). Read-only JLD2 audit of its native-face t=0 profile found, at the supported first interior face, SLD SGS u/v/θ/q fluxes `+0.13620266`, `-0.011510815`, `-0.094073825`, and `+1.8873692e-5` in their respective kinematic units, with viscosity `1.4348497 m²/s`. The no-closure writer had exact zero for each corresponding 65-face SGS profile. All t=0 profiles were finite and full-height. The fixture did not evolve for nine hours and does not establish physical fidelity.

```sh
"$JULIA" --startup-file=no --project="$PROJECT" \
  cases/surface_layer/test_diagnostic_adaptation.jl
```

## Next gate for root (prepare/decide; no job submitted here)

1. Inspect the scoped evaluation commit and `git diff --check`. Build a **new** immutable core snapshot with the new Evaluation revision, the unchanged Breeze `02a1647` feature source and exact runner Manifest; hash every source file and bind the validation evidence to that new manifest. Keep `9fb39dc/02a1647` and all prior evidence immutable.
2. On one free GPU, run a bounded native-writer smoke for GABLS1 dry and GABLS3 moist SLD plus their no-closure controls, with CUDA scalar indexing disabled. Use the approved small grids and at least two accepted steps; include one scheduled native-face profile record, one reduced series record, and GABLS3 moisture output. Check nonzero signed SGS flux at supported faces whenever K and gradients are nonzero, exact no-closure zeros, location/units/density weighting, wall substitution, and derived total-stress consistency. Compare paired prognostic state/checkpoint hashes at the same steps against the old diagnostic-only source to show that changing output evaluation did not change simulation dynamics. Cap at one new GPU job so the campaign-wide two-job limit and GABLS3 priority remain intact.
3. After that gate, **prefer fresh four-case matched GABLS1 and GABLS3 reruns** with the diagnostic-only source revision, separately versioned run/export/collection paths and manifests. The 32³ GABLS1 cases are cheap, and adaptive next-step timing adds replay risk. Checkpoint replay remains a possible separately authorized fallback only if it proves equality with original states at interval endpoints and preserves all 18 GABLS1 true half-hour means and 541 series records or all GABLS3 109/3241 records. Snapshot-time fluxes from checkpoints alone are insufficient for those time means. Never substitute `<K> ∂z<u>` or silently accept the old fluxes.
4. Root then regenerates only admitted flux/depth/production figures in Julia, retains the original exports as historical attempts, and labels any unrepaired material as unavailable. No existing DYCOMS or original GABLS1 data are changed.
