# Neutral 7367 saved-science audit and finalization handoff

2026-09-22 UTC. Codex root accepted the independently audited saved scientific output, and pane 48 finalized, exported, and collected the two cases into fresh paths. **Collection: 2 admitted, 0 rejected.** Root retains Julia plots and report. No GPU rerun, cancellation, frozen model/source change, issue comment, or WENO-reconstruction work was performed. The original 7366 failed parent, 7367 wrapper failures, and separate v4 saved-output cost gate remain unchanged.

## Outcome and honest attempt status

Both original array 7367 solvers reached the canonical **18,000 s** and wrote `NEUTRAL_ABL_RUN_DONE` and exact `CASE_DONE`. Both original version-1 wrappers then failed their post-run `rg` sentinel check because `rg` is absent on the GPU node. Their original `CASE_FAILED` files and durable child exits remain **code 3**, not zero. The pinned wrapper has `rg` only inside `if [[ "$child_exit_code" == 0 ]]`; the single log occurrence of `line 75: rg: command not found` after `RUN_DONE` therefore proves that Julia returned zero before this postprocessing failure. Both logs have the ordered solver start/stop, unique `rg` error and matching code-3 exit record, with no solver error/exception record. The harmless iteration-zero progress rate `NaN s/step` is not a model-state NaN; every saved scientific field/state-bound/checkpoint prognostic array is independently finite.

The separate full-science raw audit passed for **both** cases. Each has a distinct instantaneous t=0 profile, **30 exact preceding-600 s averaged profiles**, **301** 60 s series and state-bound records, and **six** hourly finite checkpoints including t=0 and 18,000 s. Native Center/Face heights, native-face w²/w³ and resolved/SGS/total flux splits, complete source/environment captures, canonical paired initial digests, frozen 761-file source manifest and prior GPU gates all pass. Control SGS momentum flux is zero; SLD first-supported-face SGS momentum flux is nonzero (maximum 0.1675216556 m² s⁻²) with positive one-face viscosity (maximum 2.071447134 m² s⁻¹). Neutral scalar/heat flux guards are inactive. The norm of the horizontally averaged wall-stress vector can be below the **local** prescribed 0.25 m² s⁻², so the audit uses its upper bound and checks diagnosed friction velocity against the mean vector; it does not mistake vector cancellation for a violated fixed-stress law.

## Pinned evidence and accepted export

- Evaluation branch `glw/surface-layer-evaluation`, reviewed source commit **`c9220b1a32985ca584dab19809b83130a028b1c3`** pushed. The evidence binds this commit and ten exact analysis/launcher file SHA-256 values. Worktree is clean.
- New v2 evidence directory: `/shared/home/greg/review-coordination/neutral-7367-saved-science-audit-v2-20260922`; `neutral_saved_science_audit.toml` SHA **`1289749a633d08cf2d9d0ca3b3c33a77fb3e0ef4c5c09cf23ba6a2db0a439021`**. `NEUTRAL_SAVED_SCIENCE_AUDIT_DONE` binds that SHA and explicitly states `scientific_admission=false`, `original_batch_success=false`, `root_acceptance_required=true`.
- The earlier v1 audit directory remains preserved but is superseded by v2 because the acceptance attribution was corrected. No v1 evidence was overwritten. Codex root wrote `$EVIDENCE/ROOT_ACCEPTANCE.toml` after independent review; SHA-256 **`4c615d70d622e7925bc09f88e687ce13aa3589c5052d96017784c7ff445131aa`**, accepted evidence SHA **`1289749a633d08cf2d9d0ca3b3c33a77fb3e0ef4c5c09cf23ba6a2db0a439021`**. This is acceptance by Codex root under the existing authorized workflow, **not** a claim that Greg personally reviewed the repair.
- `cases/surface_layer/analysis/NeutralSavedScienceAudit.jl` is the versioned supplemental auditor. `NeutralScientificExport.jl` is the strict finalized-registry/export/collector contract. Julia tests: **60/60** exporter/fixture tests and **29/29** saved-science proof/corruption/attribution tests pass under the frozen Julia 1.12.6 runner project. The full saved evidence was separately revalidated after commit. The plain zero-exit finalizer refuses the existing `CASE_FAILED` and creates no registry.
- The root-acceptance reader passed on the pinned evidence and printed `NEUTRAL_SAVED_SCIENCE_ROOT_ACCEPTED`. The strict saved-output finalizer passed both cases and wrote `/shared/home/greg/review-coordination/neutral-7367-saved-attempts-v2-accepted.toml` (SHA-256 **`bcf68f66e5b6814d53ab41ed94a2a0434fa617ed448dbefe4d4250b946859394`**). It pins the original code-3 exits, `CASE_FAILED` records and hashes as failures rather than reclassifying the original batch as successful.
- Both case exporters returned `NEUTRAL_SCIENTIFIC_EXPORT_VERIFIED`; the collector returned `NEUTRAL_COLLECTION admitted=2 rejected=0`. The collection manifest at `/shared/home/greg/review-coordination/neutral-7367-collection-v2-accepted/manifest.toml` has SHA-256 **`f926dcd0aafae50d384af0dca8f8d21c90f2e324f507e86ebbadb8da88b27cc8`**. It binds the two case manifests, SHA-256 **`39916c75547701dd3a138e0b9f858d90437d86f553571699bc85cc80899ad2c3`** (control) and **`41acc21b098da422bc8ebee346b6ecca394289a73315cec399927ae100609f8c`** (one-face 300 s).
- Each admitted case reaches exactly 18,000 s, has 30 preceding-600 s mean profile records plus a separate instantaneous initial profile, 301 series records, six finite checkpoint records and native vertical coordinates. The exported manifest declares final-hour source times `[15000,15600,16200,16800,17400,18000]` s and penultimate `[11400,12000,12600,13200,13800,14400]` s. Control exports 47 profile and 30 series variables; SLD exports 49 and 95, respectively. Both manifest flags say `original_7367_batch_success=false`, `active_batch_success=false`, `scientific_admission=passed_root_accepted_saved_output`.

## Executed Julia commands and data paths

Use exact frozen environment:

```sh
JULIA=/shared/home/greg/.juliaup/bin/julia
PROJECT=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647/source/BreezeEvaluation.jl/cases/gabls3/runner
ANALYSIS=/shared/home/greg/Projects/BreezeEvaluation-surface-layer/cases/surface_layer/analysis
EVIDENCE=/shared/home/greg/review-coordination/neutral-7367-saved-science-audit-v2-20260922

$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/validate_neutral_saved_science.jl" "$EVIDENCE"
```

The root acceptance file existed before these commands. Exact execution used the fresh paths below; source, evidence, original logs, exits, and run directories were not rewritten:

```sh
REGISTRY=/shared/home/greg/review-coordination/neutral-7367-saved-attempts-v2-accepted.toml
EXPORT_ROOT=/shared/home/greg/review-coordination/neutral-7367-analysis-export-v2-accepted
COLLECTION=/shared/home/greg/review-coordination/neutral-7367-collection-v2-accepted

$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/admit_neutral_saved_science.jl" "$EVIDENCE"
$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/finalize_neutral_saved_science.jl" "$EVIDENCE" "$REGISTRY"
$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/export_neutral_case.jl" "$REGISTRY" neutral_n096_weno9_control "$EXPORT_ROOT"
$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/export_neutral_case.jl" "$REGISTRY" neutral_n096_weno9_surface_layer_t300_s1 "$EXPORT_ROOT"
$JULIA --startup-file=no --project="$PROJECT" "$ANALYSIS/collect_neutral_exports.jl" "$REGISTRY" "$EXPORT_ROOT" "$COLLECTION"
```

The finalized registry pins original code-3 exits and `CASE_FAILED` hashes **as failures**, the separate root acceptance SHA, the v2 evidence SHA, all raw/checkpoint hashes and exact source revision. Export manifests retain `original_7367_batch_success=false` and label the scientific route `passed_root_accepted_saved_output`; they do **not** claim zero batch exit. Collector refuses a partial pair and rechecks all CSV, raw and checkpoint hashes. Root owns subsequent Julia plots/report.

Portable pinned Julia analysis/neutral source bundle for root plots: `/shared/home/greg/review-coordination/neutral-7367-analysis-source-c9220b1.tar.gz`, SHA-256 **`615b43baf62579476cc76ef0e03f12932d5cdb3095613cd9fb7accb2c18ada7f`**. It is `git archive` of commit `c9220b1a32985ca584dab19809b83130a028b1c3`, paths `cases/surface_layer/analysis` and `cases/surface_layer/neutral` (35 archive entries); it does not embed frozen model dependencies or raw JLD2. Use the exact frozen runner environment and accepted export paths above. Extract with `tar -xzf neutral-7367-analysis-source-c9220b1.tar.gz -C DEST` into a new destination for portable source review.

The unsubmitted portable version-2 launcher is retained only as fallback: `cases/surface_layer/neutral/run_neutral_science_pair_v2.sh`, SHA `68ac700978b8c83a25b18648a7f4e74c0ef205443452f6ee6bbfa54811f5e268`. It passed `bash -n` and exact/wrong/missing `CASE_DONE` checks, but the current saved-output route avoids a GPU rerun. Original array 7367 is never retroactively marked successful.
