# Restore complete comparison histories

`restore_full_profiles.jl` creates a **new analysis directory** from the versioned campaign archive. It verifies every archived artifact, retrieves original full `profiles.csv` files and any missing original-manifest companion tables, checks their recorded hashes, and restores original manifests only for successfully recovered cases. It never modifies the repository archive or production directories. Failure removes staging and does not publish a partial destination. An existing destination is refused.

From a checkout of BreezeEvaluation.jl on a machine with the `pcluster` SSH alias:

```sh
julia --project=. scripts/restore_full_profiles.jl --destination /absolute/path/new-analysis --host pcluster
```

On pcluster, omit `--host`. Override the original source location with `--source-root /path/to/reference-bundle` if it has moved. `--case n032_weno9_none` restores only that case; other cases remain compact and are not admissible as full histories. The default restores all 27 cases available in the committed migration manifest (15 DYCOMS, 12 GABLS1). Later cases require a new audited migration manifest.

The output `restored_profiles.json` records the input migration hash, recovered profile and original-manifest hashes, and whether all migrated cases were restored. Continue to apply the original scientific admission checks. Retrieval establishes file identity, not scientific accuracy.

Validation: corruption, missing companions, destination preservation, traversal and invalid host checks pass (15 assertions). All 27 real cases restored successfully using local-source mode on pcluster. SSH transport uses the same hash checks but has not yet been exercised end to end in this handoff. Complete plot/report regeneration may still require the original reference archives, auxiliary source assets, Poppler and the pinned Julia environment; do not infer all builders are portable merely because full simulation histories were restored.

`check_restored_admission.jl` is an integration validation helper for the current 12-case GABLS1 archive. It extracts only the admission portion into a temporary file beside the original plotter to preserve relative includes, then removes it; it does not regenerate figures. All processing is Julia.
