# Frozen LES source snapshots

These are content-addressed copies of the actual DYCOMS and GABLS1 campaign-defining files,
captured without modifying the immutable production trees. `manifest.json` records SHA-256,
byte count, source revision, and original frozen path for every file.

The common Breeze base is
`https://github.com/NumericalEarth/Breeze.jl.git@548e6fb7b6aecc62b7e05ddcf3e422b8dadd9504`.
To reconstruct a source tree, clone that commit and overlay the files below `source/` from the
applicable snapshot. The copied root `Project.toml` and `Manifest.toml` preserve the exact Julia
environment used by the campaigns. Scheduler, registry, exporter, and verifier files preserve the
execution and admission contracts but do not authorize new production.

- `dycoms/` is the original DYCOMS source and 15-case factorial campaign.
- `gabls1/original/` is GABLS1 `v2_original`.
- `gabls1/startup_dt_v1/` preserves the bounded initial-time-step replacement used only by the
  two affected 1 m WENO9 cases. Its `source_revision.json` states the one-line change contract;
  the runner hash differs from the original while diagnostics, surface law, and Manifest do not.

This is executable provenance, not a claim that the analyses in this repository can rerun large
GPU simulations on an arbitrary host. GPU allocation, CUDA compatibility, and external raw output
locations remain operational prerequisites.
