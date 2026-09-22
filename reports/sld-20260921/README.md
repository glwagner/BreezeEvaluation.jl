# SurfaceLayerDiffusivity: coarse GABLS1 results and corrected transport

[Read the findings](surface_layer/gabls1/results.md) · [Illustrated brief](surface_layer/surface_layer_results.pdf) · [Complete DYCOMS/GABLS master report](breeze_les_master.pdf)

Four paired 9 h runs at 12.5 m strongly suppress near-wall turbulence, but the three closure configurations worsen mean-u, mean-theta and w² profile errors against the fixed 1 m median in this test. SGS supplies 86–95% of first-level u-momentum transport; total transport changes much less than its resolved contribution. This is one grid and one seed, not a general closure verdict.

The historical 12.5 m WENO9 + Smagorinsky case has almost no resolved vertical turbulence despite smaller mean-wind error. Its source differs from the matched treatments, and it is labeled throughout. Four Julia figure pages show profiles, moments, surface exchange, logarithmic variance and corrected resolved/SGS/total transport. Data, original manifests and native coordinates accompany the plots.

Current figures use corrected array 7293 and `surface_layer/gabls1/exports_e0655cf/`. All four cases passed source/hash verification, exact schedules, native implicit-flux semantics and total = resolved + SGS. Mean fields and resolved moments exactly reproduce the earlier runs. Historical array 7156 and `exports_0bfa03d/` remain unchanged, with invalid fluxes and dependent diagnostics explicitly excluded in [the historical exclusion record](surface_layer/gabls1/diagnostic_exclusions.md). The preceding brief is retained as `surface_layer/historical_7156_results.pdf`.

All analysis and plots use Julia. With Julia 1.12 and Poppler (`pdfunite`):

```sh
julia --project=julia -e 'using Pkg; Pkg.instantiate()'
julia --project=julia verify_snapshot.jl
julia --project=julia surface_layer/gabls1/audit_corrected_fluxes.jl
julia --project=julia surface_layer/gabls1/present_results.jl
julia --project=julia surface_layer/gabls1/plot_fluxes.jl
julia --project=julia surface_layer/presentation.jl
julia --project=julia surface_layer/gabls1/build_brief.jl
```

Run snapshot verification before regenerating outputs: generated PDFs can differ bytewise across library/runtime versions. `files_sha256.toml` identifies the published bytes. Reduced complete histories are included; raw 3-D/checkpoint JLD2 files remain on pcluster. The master PDF preserves all original DYCOMS/GABLS1 material. GABLS3 replacements passed corrected-source validation and are running as sequential array7343; no new GABLS3 science is yet claimed.

Corrected run sources: [Breeze 02a1647](https://github.com/NumericalEarth/Breeze.jl/commit/02a16478869abf556a464f0874925510bb7c233c), [evaluation a14c358](https://github.com/glwagner/BreezeEvaluation.jl/commit/a14c3586708de70cd3a47f44878991a440678442), [analysis e0655cf](https://github.com/glwagner/BreezeEvaluation.jl/commit/e0655cf77568bc24af1b0bcd7a4c9efe46aa9f45). Source-bound GPU evidence and the separate corrected collection/audit are stored alongside the report.

## Matched resolved-flux factor sensitivity

[Factor-2 findings and figures](surface_layer/resolved_factor/results.md) · [Four-page comparison](surface_layer/resolved_factor/factor_results_section.pdf). The illustrated brief is now 12 pages; the master is 58 pages, with all earlier material preserved.

Two fresh one-face/300 s cases at 12.5 m passed strict admission. Factor1 exactly reproduces every exported value from the corrected7293 one-face300 case. Factor2 lowers first-face viscosity15.4% and heat diffusivity36.3%, but final-hour integrated resolvedTKE and peakw² fall6.4% and6.3%. First-levelw² increases7.1% in8–9h but decreases5.1% in7–8h. This does not demonstrate broad turbulence recovery or measure numerical flux. The report retains the scheduler/model-exit discrepancy and successful independent output audit.

Reproduce with Julia, after snapshot verification:

```sh
julia --project=julia surface_layer/resolved_factor/compare.jl
julia --project=julia surface_layer/resolved_factor/plot_comparison.jl
julia --project=julia surface_layer/resolved_factor/build_report.jl
julia --project=julia surface_layer/gabls1/build_brief.jl
```


## Factor 10: near-complete mixing shutoff

[Factor1/2/10 findings](surface_layer/resolved_factor10/results.md) · [Illustrated comparison](surface_layer/resolved_factor10/factor_results_section.pdf). One separately validated nine-hour case uses the same Breeze physics, grid, seed, support and filter as factors1/2. The factor10 evaluation adds read-only switch-off diagnostics. Final-hour first-face variance is0.06467m²/s², close to earlier no-closure0.06353; skewness is+0.594 rather than factor1−0.253. Added momentum viscosity is zero at99.9935% of sampled horizontal-point/time pairs and heat diffusivity at100%. This exposes closure shutoff under the assumed factor; it does not measure or calibrate numerical transport. All historical sections are retained.

The reported combined flux is covariance+constitutiveSGS, excluding the scheme-native WENO reconstruction correction. The proposed reconstruction experiment is on hold until Greg reviews factor10.

Reproduce with Julia: run surface_layer/resolved_factor10/compare.jl, plot_comparison.jl, build_report.jl, then surface_layer/gabls1/build_brief.jl after snapshot verification.


## Factor 3 and completed original GABLS1 matrix

[Factor1 versus3 findings](surface_layer/resolved_factor3/results.md) · [Illustrated comparison](surface_layer/resolved_factor3/factor_results_section.pdf). The new plots show only factors1 and3 with the fixed1m reference where available; historical factor2/10 sections and data remain intact. Final-hour first-face w² rises from0.00817 to0.06073m²/s²; factor3 viscosity is zero at98.4733% of saved point-times and heat diffusivity at99.9756%. This is strong sensitivity to the assumed credit, not a numerical-flux measurement.

The original GABLS1 matrix is now complete:15 admitted cases,0 rejected. Updated13figure sets and summary/audit are in gabls/. The final1m Smagorinsky case has peak w²0.09851m²/s²; all original compact data are persisted on the repository main branch. GABLS3 control completed; the three closure cases are released and awaiting resources.

Use Julia to run surface_layer/resolved_factor3/compare.jl, plot_comparison.jl and build_report.jl, then surface_layer/gabls1/build_brief.jl after snapshot verification.

## Corrected GABLS3 results, 22 September 2026

The earlier GABLS3 queue statement above is historical. All four corrected 9-hour cases passed strict collection and independent physical-flux audits. [Read the new comparison](surface_layer/gabls3/results.md) or its [eight-page PDF](surface_layer/gabls3/sld_results_section.pdf). During 03–04 UTC, SLD suppresses first-face w² by 88–96%; during 08–09 UTC it remains 28–35% lower while integrated resolved TKE is 30–36% higher than the control. This is a matched sensitivity comparison, not an observational fidelity ranking. Full exported histories, exact manifests, audit evidence, Julia plots and summaries are in `surface_layer/gabls3/`. Historical DYCOMS/GABLS1 results remain preserved.
