# BreezeEvaluation.jl

Reproducible Julia workflows, compact audited data, figures, and reports for Breeze atmospheric
LES evaluations. The repository currently preserves DYCOMS-II RF01 and GABLS1 and is preparing
GABLS3.

The repository is public. Large JLD2 fields, external archives, third-party paper PDFs, and other
materials without redistribution clearance are deliberately not versioned. Their original
locations, hashes, and provenance are recorded under `provenance/`.

## Layout

- `campaigns/dycoms/`: the migrated Julia DYCOMS/GABLS1 workflow, compact exports, reports,
  figures, and reference products in its original coherent relative layout.
- `cases/gabls3/`: runner, forcing, and diagnostic contract being developed with pane 47.
- `cases/gabls3/preparation/`: independently tested forcing/preflight tables and the nine-case
  proposal; this is not yet an executable Breeze runner.
- `data/gabls3/reference/`: independently transcribed, audited GABLS3 inputs.
- `source_snapshots/`: content-addressed DYCOMS/GABLS1 runners, diagnostics, surface law,
  environments, scheduler inputs, exporters, and verifiers for each production source revision.
- `provenance/`: checksummed manifests for immutable source snapshots and external raw data.

## Verified audits

Use the pinned Julia 1.12 environment:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/verify_migrated_campaigns.jl
julia --project=. scripts/gabls3/verify_inputs.jl
julia --startup-file=no cases/gabls3/preparation/test_forcing.jl
julia --startup-file=no cases/gabls3/preparation/compare_reference.jl data/gabls3/reference
```

Workflows that need raw production data use `BreezeEvaluation.external_path`; copy
`config/paths.example.toml` to the ignored `config/local_paths.toml`, or set the corresponding
`BREEZE_EVALUATION_*` environment variable. Capture/migration scripts have historical shared-path
defaults for convenience, but every external source path can be overridden by an environment
variable.

The versioned simulation exports deliberately retain every reduced series record but only the
profile records needed by the published comparison windows: 9000, 10800, 12600, and 14400 s for
DYCOMS; 27000, 28800, 30600, and 32400 s for GABLS1. Each compact manifest preserves the full
source audit, marks itself as a non-admissible derived subset, and records this transformation
explicitly. The original plotting admission checks still require all 9 DYCOMS or 19 GABLS1
profile records. `scripts/restore_full_profiles.jl` provides a transactional, hash-verifying
local or SSH retrieval path for all 27 migrated full histories into a new analysis tree; see
`scripts/restore_full_profiles.md`. The versioned PDFs, HTML, Markdown, figures, and plot
provenance remain the truthful stored snapshot. Run
`scripts/migrate_legacy_data.jl` with `BREEZE_EVALUATION_LEGACY_REFERENCE` to rebuild the compact
snapshot from the external legacy bundle.

## Stored, reproducible, and pending

The committed master/section reports and figures are stored artifacts whose bytes are audited.
The commands above verify compact simulation data, source hashes, and both independent GABLS3
input transcriptions. `source_snapshots/README.md` explains how to reconstruct the exact DYCOMS
or GABLS1 Breeze source overlay from the pinned upstream commit; it does not submit work.

Full simulation histories can now be restored reproducibly, but complete plot/report regeneration
may still require original reference archives, auxiliary source assets, Poppler, and the pinned
Julia environment. The restoration helper establishes artifact identity and does not weaken the
original scientific admission checks. GABLS3 runner integration is under CPU validation and is
not production-authorized. No README command claims either missing capability.

## Data policy

Simulation completion and export verification do not imply physical fidelity. Manifests retain
source revisions, failed attempts, finite/coordinate audits, averaging definitions, and known
scientific caveats. Third-party PDFs and large source archives are cited and checksummed rather
than redistributed.
