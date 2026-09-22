# SurfaceLayerDiffusivity scientific export

This directory owns the Julia-only, analysis-side export and admission contract for the
separate bounded four-case GABLS1 and four-case GABLS3 SurfaceLayerDiffusivity studies.
It does not submit, monitor, or modify simulations. The sealed GPU harness snapshot and
the original GABLS1 production campaign remain unchanged.

## Admission boundary

`export_case.jl` publishes a case only when all of the following are true:

- the structured attempt registry has exactly one active top-level entry for the case;
- that entry is a completed scientific candidate and not a smoke or clock-jump fixture;
- the exact active log, `ATTEMPT_STARTED`, and `CASE_DONE` hashes match the registry;
- `CASE_DONE` reports 32400 seconds and `CASE_FAILED` is absent;
- `ATTEMPT_STARTED` identifies the exact frozen scientific registry and case index;
- the registry-pinned 761-file source snapshot and the separately pinned analysis snapshot pass complete
  SHA-256 audits;
- a `gpu_full` / `CUDAGPU` validation bundle, including disabled CUDA scalar indexing,
  admits that same source snapshot;
- captured runner, diagnostics, forcing, surface-law, Project, Manifest, and Breeze source
  match the immutable snapshot, and paired initial-array digests match the case registry;
- raw JLD2 schedules, profile locations/shapes, and every exported number satisfy the
  family-specific finite-data contract.

Queue absence is never consulted. A completion sentinel by itself is never sufficient.
The unsubmitted registry scaffolds under `registries/` intentionally contain `UNASSIGNED`
fields and therefore fail admission. Activation must occur in a later, pinned registry
revision after GPU validation and a real run; old attempts belong in separate history and
must not be nested where they can be mistaken for active fields.

## Lossless analysis products

Each admitted case directory contains:

- `profiles.csv`: long-format full native-height history with `Center` or `Face`, explicit
  units, record kind, and averaging bounds;
- `series.csv`: full wide reduced-series history;
- `points.csv`: full native-variable point history for GABLS3 only;
- the required comparison mean profiles; and
- `manifest.toml` plus `manifest.json`, including raw-file and output hashes, shapes,
  coordinates, definitions, availability metadata, support faces/heights/weights, guard
  metadata, and the complete admission audit.

CSV output uses 17 significant decimal digits after conversion to `Float64`, sufficient to
round-trip both raw `Float32` and `Float64` diagnostic values. No time records are decimated.
Unavailable diagnostics remain absent and are described by availability metadata; they are
never converted to physical zero.

The GABLS3 32,400 s record stores only the three prescribed surface forcing scalars
(`pressure`, `theta`, and `q`) as `Float32`; their preceding 3,240 records are `Float64`.
The exporter accepts precisely this final-record storage exception, retains the exact
numeric values, and records raw element-type counts per variable in the manifest.
Other type changes, including an earlier change or a change in another variable,
remain admission errors.

GABLS1 preserves a separate instantaneous initial profile, 18 true preceding-half-hour
averages at 1800:1800:32400 seconds, and 541 one-minute series records. Oceananigans also
writes an iteration-zero record into the averaged statistics file. The exporter requires
that record to exactly match every variable in the separate instantaneous initial file,
records its existence in the manifest, and excludes only that verified duplicate from
`profiles.csv`; accumulation begins at t=0 for the first 0–1800 s window. Its penultimate and
final hour products are equal means of `(27000, 28800)` and `(30600, 32400)` respectively.

GABLS3 preserves 109 instantaneous profiles at 0:300:32400 seconds and 3241 series and
point records at 0:10:32400 seconds. The t=0 series/point records are Oceananigans
initialization output; the installed SpecifiedTimes schedules remain 10:10:32400.
Its paper comparison is the equal mean of the 12
instantaneous profiles at 11100:300:14400 seconds; the 10800-second left boundary is not
included. GABLS1 reference products are not substituted into GABLS3.

## Commands for desktop collection and plotting

Use Julia 1.12.6 and the frozen runner environment. These commands are templates: the
attempt registry must first be copied to a new version and populated with the admitted
source/analysis freezes, GPU evidence, and exact active-attempt paths and hashes.

```sh
JULIA=/shared/home/greg/.juliaup/bin/julia
PROJECT=/path/to/analysis-freeze/source/BreezeEvaluation.jl/cases/gabls3/runner
ANALYSIS=/path/to/analysis-freeze/source/BreezeEvaluation.jl/cases/surface_layer/analysis

$JULIA --startup-file=no --project=$PROJECT \
  $ANALYSIS/export_case.jl ATTEMPTS.toml CASE_ID ANALYSIS_EXPORT_ROOT

$JULIA --startup-file=no --project=$PROJECT \
  $ANALYSIS/collect_admitted_exports.jl ATTEMPTS.toml ANALYSIS_EXPORT_ROOT COLLECTION_DIR
```

Julia plot or report code can include `SurfaceLayerAnalysisData.jl` and call
`load_case_export(case_directory)`. That loader rechecks all exported artifact hashes and
rejects fixture or unverified manifests. `read_wide_series` and `read_long_profiles` are
available for explicitly non-scientific pipeline development without weakening admission.

## CPU fixture test

```sh
/shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project=cases/gabls3/runner \
  cases/surface_layer/analysis/test_export_pipeline.jl
```

The synthetic fixtures are labeled `fixture_non_scientific=true` and
`export_verified=false`. They test I/O, schedule, coordinate, averaging, finite-value,
shape, hash-corruption, and collector rejection behavior only; they are not LES results.

## Admitted-only scientific figure and report-section preparation

`SurfaceLayerScientificPlots.jl` loads every case through `load_case_export`; the
command below refuses absent, fixture, unverified, or hash-corrupted exports and
requires all four distinct matched variants from one family. It creates a six-panel
two-row (full depth / near wall), three-column (mean u / momentum-flux partition /
native-face w variance) lead comparison, companion thermodynamic/scalar-flux and
native-face w³/skewness views, a forcing/response timeline, a coefficient/deficit/
guard/cap-activity timeline, and a Markdown section with manifest and PDF/PNG
figure hashes. No LES figure is generated
from the synthetic export fixtures, and no output is available until scientific
cases are admitted.

Use the report's Julia environment with CairoMakie and JSON; this is a separate
plotting dependency from the frozen scientific runner and exporter. For GABLS1,
the fixed 1 m archive median JSON is required, including `series/ustar` and
`series/surface_theta_flux` on the comparable elapsed-time panels. GABLS3
must pass `none` in that argument and never inherits GABLS1 reference data.
Example after all four
exports have passed admission:

```sh
JULIA=/shared/home/greg/.juliaup/bin/julia
PLOT_PROJECT=/path/to/dycoms-reference/julia
PLOT_SCRIPT=/path/to/BreezeEvaluation.jl/cases/surface_layer/analysis/plot_admitted_comparisons.jl
EXPORT_ROOT=/path/to/admitted-sld-exports
REFERENCE=/path/to/dycoms-reference/gabls/reference_data/fixed_1m_medians.json

$JULIA --startup-file=no --project=$PLOT_PROJECT $PLOT_SCRIPT \
  GABLS1 /path/to/report/surface_layer $REFERENCE \
  $EXPORT_ROOT/gabls1_n032_weno9_control \
  $EXPORT_ROOT/gabls1_n032_weno9_surface_layer_t100_s1 \
  $EXPORT_ROOT/gabls1_n032_weno9_surface_layer_t300_s1 \
  $EXPORT_ROOT/gabls1_n032_weno9_surface_layer_t300_s2
```

For GABLS3 use its four `n064_weno9_*` directories and `none`. Profiles
preserve the exported native Center/Face z coordinates and use the official
GABLS1 final two half-hour bins or GABLS3 twelve 03:00–04:00 UTC instantaneous
records. Skewness is a ratio of window-averaged native-face w³ and w², not an
average of instantaneous skewness. The historical GABLS1 1 m upper-level
momentum-flux reference above 300 m is omitted from figures, not altered in
downloadable reference data. The report builder should append the generated
`*_sld_admitted_section.md` and five PDFs only after this command succeeds;
the current report remains an explicitly pending comparison until then.

The plotting-module fixture test renders all layouts for dry and moist families
inside temporary directories with a `NON_SCIENTIFIC` filename and title. It
also checks that the public loader refuses unverified fixtures and that the
actual archived GABLS1 series has the required reference mappings:

```sh
$JULIA --startup-file=no --project=$PLOT_PROJECT \
  cases/surface_layer/analysis/test_scientific_plots.jl
```

## Neutral fixed-stress 5 h pair (separate campaign)

`NeutralScientificExport.jl` is a separate Julia-only contract for the canonical
96³, 3000 × 3000 × 1000 m WENO9 control versus one-face, 300 s SLD pair.
It never edits the frozen a14c358/02a1647 model source. It requires the exact
paired seed-1994 initial digests, 30 preceding-600 s averaged native-height
profiles plus a separate t=0 profile, 301 one-minute series and state bounds,
and six finite hourly checkpoints including t=0. The full native-coordinate
history and equal six-bin final/penultimate-hour profiles are retained.

The original 7367 array completed both solvers but the version-1 launch wrapper
recorded code 3 and `CASE_FAILED` because `rg` is absent on the compute node.
Those records remain failures. `NeutralSavedScienceAudit.jl` separately proves
the frozen wrapper could only reach the failing `rg` check after a zero Julia
child exit; requires the unique postprocessing error after `RUN_DONE`, exact
`CASE_DONE` and 18,000 s, and independently audits every raw scientific output.
Its evidence explicitly says `scientific_admission=false` and cannot be
exported without a separate root-created `ROOT_ACCEPTANCE.toml` bound to the
evidence SHA. The root-acceptance reader rechecks all raw/source/log/exit
hashes. Do not reinterpret the original batch as exit zero.

The portable, versioned `run_neutral_science_pair_v2.sh` replaces only the
post-run `rg` check with bash built-ins and is an unsubmitted fallback.
The zero-exit finalizer accepts a fresh root-recorded job/campaign only with
that exact wrapper SHA. `finalize_neutral_saved_science.jl` is the alternate
root-accepted route for the original 7367 raw results. Both modes feed the
same strict case exporter and pair collector; no partial pair is collected.
The root owns acceptance, scheduler actions, plotting, and report integration.
