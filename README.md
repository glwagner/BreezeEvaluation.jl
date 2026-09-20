# BreezeEvaluation.jl

Reproducible Julia workflows, compact audited data, figures, and reports for Breeze atmospheric
LES evaluations. The repository currently preserves DYCOMS-II RF01 and GABLS1 and is preparing
GABLS3.

The repository is private while the GABLS3 setup and third-party redistribution permissions are
audited. Large JLD2 fields, external archives, and paper PDFs are deliberately not versioned.
Their original locations, hashes, and provenance are recorded under `provenance/`.

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
profile records. Until a portable full-history fetch/decompression command is added, the
versioned PDFs, HTML, Markdown, figures, and plot provenance are the truthful reproducible
snapshot; complete plot regeneration remains explicitly pending. Run
`scripts/migrate_legacy_data.jl` with `BREEZE_EVALUATION_LEGACY_REFERENCE` to rebuild the compact
snapshot from the external legacy bundle.

## Stored, reproducible, and pending

The committed master/section reports and figures are stored artifacts whose bytes are audited.
The commands above verify compact simulation data, source hashes, and both independent GABLS3
input transcriptions. `source_snapshots/README.md` explains how to reconstruct the exact DYCOMS
or GABLS1 Breeze source overlay from the pinned upstream commit; it does not submit work.

Full plot regeneration is pending a portable, hash-verifying retrieval mechanism for the complete
profile histories. GABLS3 currently has a tested forcing/preflight implementation and case matrix,
not a complete Breeze model runner. No README command claims either missing capability.

## Data policy

Simulation completion and export verification do not imply physical fidelity. Manifests retain
source revisions, failed attempts, finite/coordinate audits, averaging definitions, and known
scientific caveats. Third-party PDFs and large source archives are cited and checksummed rather
than redistributed.
