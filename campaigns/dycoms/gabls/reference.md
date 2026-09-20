# GABLS1 reference and setup

Reference material retrieved 2026-09-19. Current Breeze run status is maintained in [the master report](../breeze_les_master.md) and [workflow](workflow.md).

Beare et al. (2006), *An Intercomparison of Large-Eddy Simulations of the Stable Boundary Layer*, Boundary-Layer Meteorology 118, 247–272. [DOI](https://doi.org/10.1007/s10546-004-2820-6). [Saved paper](beare2006.pdf). [Author's university copy](https://empslocal.ex.ac.uk/people/staff/rjb215/public_html/gabls_les_pub.pdf).

This is GABLS1, the idealized moderately stable case, not the later GABLS diurnal-cycle or strongly stable cases.

## Common initial conditions and forcing

Sources: paper Section 2, pp. 249–250; [official description](https://gabls.metoffice.gov.uk/description.html); [original participant specification](https://gabls.metoffice.gov.uk/description.ps), pp. 1–2, saved as [PostScript](original_instructions.ps).

| Quantity | Value |
|---|---|
| Domain | 400 × 400 × 400 m; horizontally periodic |
| Geostrophic wind | (8, 0) m/s |
| Coriolis parameter | 1.39 × 10⁻⁴ s⁻¹; 73°N |
| Initial potential temperature | 265 K below 100 m; 265 + 0.01(z−100) K above |
| Initial wind | Geostrophic above the surface; paper specifies zero at bottom grid point |
| Perturbations | Zero-mean temperature noise, amplitude 0.1 K, below 50 m |
| Surface potential temperature | 265 − 0.25t K, with t in hours; 262.75 K at hour 9 |
| Surface flux treatment | Monin–Obukhov similarity; κ=0.4, βm=4.8, βh=7.8 |
| Roughness lengths | z0m=z0h=0.1 m |
| Reference constants | θref=263.5 K, ρref=1.3223 kg/m³, g=9.81 m/s² |
| Upper boundary | w=0, free slip; wave damping above 300 m recommended |
| Lower boundary | Impermeable, stationary rough wall; modeled surface stress |
| Duration and statistics | 9 h; separate horizontal/time averages over 7–8 h and 8–9 h |
| Prognostic SGS-TKE initialization, if needed | 0.4(1−z/250)³ m²/s² below 250 m; zero above |

The prescribed cooling is a temperature tendency; surface heat flux is diagnosed. The buoyancy reference 263.5 K is distinct from the initial ground temperature 265 K. Exact wall implementation, stability functions, SGS Prandtl number, damping profile, and time-stepping require explicit choices in a Breeze implementation; the intercomparison did not mandate one common advection/SGS algorithm. Original document submission instructions are historical source content, not instructions to this task.

## Grid arithmetic

These counts are calculated from the common 400 m extent. The selected Breeze configurations and current job mappings are recorded separately in [the experiment matrix](experiment_matrix.json).

| Isotropic spacing | Grid | Cells |
|---|---|---:|
| 12.5 m | 32³ | 32,768 |
| 6.25 m | 64³ | 262,144 |
| 3.125 m | 128³ | 2,097,152 |
| 2 m | 200³ | 8,000,000 |
| 1 m | 400³ | 64,000,000 |

## Reference data

[Official archive description](https://gabls.metoffice.gov.uk/lem_data.html). Saved [original archive](gabls_data.tar.gz) contains 423 files; [inventory](data_inventory.txt). Archive file paths and representative MO A9/B9 files were inspected; individual model submissions have not yet undergone a complete numerical audit. Cite Beare et al. when using these data.

A: mean u, v, θ. B: resolved u/v/w variances, vertical-velocity skewness, SGS TKE, θ variance. C: resolved and SGS momentum/heat fluxes. D: TKE budget. E: time series (h, surface heat flux, u*, Obukhov length, max|w|). A8–D8 average hours 7–8; A9–D9 average hours 8–9. Missing-data sentinel in the specification is −0.9999999E+07. Variable blocks carry native coordinates; do not assume every file contains every nominal grid level or a row-oriented table.

[Table IV transcription](table4_boundary_layer_heights.csv) was checked against PDF page 7. Heights are metres; blank means unavailable. Ensemble membership changes with resolution, so its mean row is not a controlled convergence sequence. Paper boundary-layer height uses total stress: h=h_0.05/0.95, where h_0.05 is the height at 5% of surface stress magnitude.

## Notes for later experiment design

Our scientific question can be whether high-order transport preserves resolved shear-driven turbulence at a coarser grid. A no-interior-closure arm must still retain the specified wall stress/heat exchange. Compare both resolved and total fluxes, not just mean profiles. Preserve fixed domain size for an interpretable resolution comparison. Save w³ as well as skewness, and distinguish a moment ratio from an average of instantaneous ratios. Check 7–8 versus 8–9 h stationarity rather than assuming equilibrium.

## Retrieval provenance

Paper download used verified HTTPS. The legacy Met Office host presents a mismatched TLS certificate; public specification/data downloads used certificate verification disabled, without credentials. The specification was cross-checked against the journal paper. [SHA-256 checksums](checksums.sha256) identify local originals. The archive is reduced intercomparison statistics, not full instantaneous 3D fields. Paper text extraction is retained in workspace scratch. This reference document was prepared before simulation submission; current production provenance is recorded separately.
