# BreezeEvaluation.jl

Reproducible Julia workflows, compact audited data, figures, and reports for Breeze atmospheric
LES evaluations. The repository currently preserves DYCOMS-II RF01 and GABLS1 and is preparing
GABLS3.

The repository is private while the GABLS3 setup and third-party redistribution permissions are
audited. Large JLD2 fields, external archives, and paper PDFs are deliberately not versioned.
Their original locations, hashes, and provenance are recorded under `provenance/`.

## Layout

- `scripts/dycoms/`, `scripts/gabls1/`: Julia collection, audit, plotting, and report workflows.
- `cases/gabls3/`: runner, forcing, and diagnostic contract being developed with pane 47.
- `data/<campaign>/reference`: redistributable compact reference products and provenance.
- `data/<campaign>/simulations`: audited time series and comparison-window profiles.
- `reports/`: generated report sources and figures.
- `provenance/`: checksummed manifests for immutable source snapshots and external raw data.

## Reproduce

Use the pinned Julia 1.12 environment:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/dycoms/build_report.jl
julia --project=. scripts/gabls1/plot_results.jl
```

Workflows that need raw production data use `BreezeEvaluation.external_path`; copy
`config/paths.example.toml` to the ignored `config/local_paths.toml`, or set the corresponding
`BREEZE_EVALUATION_*` environment variable. No reproduction step depends only on a mutable
machine-specific absolute path.

## Data policy

Simulation completion and export verification do not imply physical fidelity. Manifests retain
source revisions, failed attempts, finite/coordinate audits, averaging definitions, and known
scientific caveats. Third-party PDFs and large source archives are cited and checksummed rather
than redistributed.

