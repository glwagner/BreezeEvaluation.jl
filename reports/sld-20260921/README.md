# SurfaceLayerDiffusivity: first coarse GABLS1 results

[Read the findings](surface_layer/gabls1/results.md) · [Seven-page illustrated brief](surface_layer/surface_layer_results.pdf) · [Complete 53-page DYCOMS/GABLS master report](breeze_les_master.pdf)

**Preliminary usable-diagnostic subset, 21 September 2026.** Four completed paired runs at 12.5 m strongly change near-wall turbulence, but the three closure configurations worsen the mean-u, mean-theta and w² profile errors against the fixed 1 m median in this test. Single seed; not a general closure verdict.

**Historical Smagorinsky comparison added:** the earlier WENO9 + Smagorinsky 12.5 m run has almost no resolved vertical turbulence, despite a smaller mean-wind error. Three figure pages compare mean profiles, surface exchange, moments and log-scale variance. Its unchanged CSVs and original manifest are retained under `surface_layer/gabls1/historical_smagorinsky/`; its source differs from the four matched treatments and is labeled throughout. The figure script verifies its original export hashes and output times separately from the strict matched-case loader.

**Read [diagnostic exclusions](surface_layer/gabls1/diagnostic_exclusions.md) before using the data.** Original exported files and admission manifests are preserved byte-for-byte, including their historical `export_verified` flags. Subsequent physical review found an omitted implicit contribution in SGS flux diagnostics. Those fluxes, their totals, stress-derived depth and dependent budget terms must not be used. The report uses only unaffected mean fields, resolved turbulence and direct surface exchange. No corrected flux result or new physical validation is implied by this report snapshot.

All figures and analysis use Julia. From this directory, with Julia 1.12 and Poppler (`pdfunite`) available:

```sh
julia --project=julia -e 'using Pkg; Pkg.instantiate()'
julia --project=julia surface_layer/gabls1/present_results.jl
julia --project=julia surface_layer/presentation.jl
julia --project=julia surface_layer/gabls1/build_brief.jl
```

The output metrics file records window definitions, reference/source hashes and native-level error calculations. Full reduced histories and original case manifests are in `surface_layer/gabls1/exports_0bfa03d/`; raw 3-D/checkpoint JLD2 files remain external. All four stored exports are verified locally against their `output_sha256` maps before plotting. `files_sha256.toml` records this published snapshot. This new directory does not modify any older DYCOMS/GABLS1 case, snapshot or historical report.

Physical run sources: [Breeze 02a1647](https://github.com/NumericalEarth/Breeze.jl/commit/02a16478869abf556a464f0874925510bb7c233c), [evaluation 9fb39dc](https://github.com/glwagner/BreezeEvaluation.jl/commit/9fb39dc8b82cd20559b2a74dfa9545dcf395c4c6); [export 0bfa03d](https://github.com/glwagner/BreezeEvaluation.jl/commit/0bfa03d0ce2df07faaa14d22e3f59b3d1e06c66d). These identify the original runs; a diagnostic correction is under preparation and has not been substituted into this evidence.
