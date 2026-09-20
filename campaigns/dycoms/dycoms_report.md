# Breeze DYCOMS-II RF01: resolution and numerics

**Complete: 15 cases analyzed** · Data checked 2026-09-19T11:58:17.096Z

## Current result

All 15 requested four-hour cases are analyzed. This matrix does not establish faithful low-resolution DYCOMS turbulence: the four coarse WENO cases retain the wrong third-moment sign in the 600–760 m layer, and refining WENO9/no-SGS from 35 m to 10 m horizontal spacing substantially improves the third moment despite little improvement in variance-marker error. Fine WENO9/no-SGS has the smallest third-moment marker RMSE among the tested WENO cases. All three unbounded Centered2 cases develop negative total water and cannot establish physical fidelity. Cloud persistence alone is therefore insufficient. These are single-seed comparisons; the fine grid is not a proven converged solution, and the larger coarse domain confounds the resolution comparison.

- Completed Centered2 runs contain physically inadmissible negative total water (sampled minima: coarse: -4.338 g/kg; canonical: -7.697 g/kg; fine: -7.401 g/kg). Their cloud and turbulence statistics are retained as diagnostics of this unbounded numerical configuration, not evidence of a physically faithful solution. The production extrema figure shows the full sampled time history; verification here means complete finite output, not physical validity.
- Centered2 smoke audit: all three grids stayed finite over the first 600 simulated seconds, but canonical and fine cases produced negative total water. Across the 11 one-minute samples, minimum qₜ was coarse: 1.0872 g/kg; canonical: -0.0605 g/kg; fine: -1.3679 g/kg. Passing the finite-value gate establishes neither moisture positivity nor physical validity. Production retains unbounded centered moisture; full-run extrema are reported separately in the production audit. These are smoke-test results, not completed four-hour Centered2 statistics.
- At 10 m horizontal / 5 m vertical spacing with WENO9, adding Smagorinsky changes fourth-hour minimum w′³ over 600–760 m from -0.0622 to -0.0304 m³/s³, third-moment marker RMSE from 0.0159 to 0.0313 m³/s³, and variance-marker RMSE from 0.0631 to 0.0769 m²/s². LWP changes from 55.48 to 53.23 g/m². Solver wall increases by 10.1%. This closure weakens the negative third moment and increases both marker errors in this paired single-realization comparison; it is not evidence against every possible closure or coefficient choice.
- At 10 m horizontal / 5 m vertical resolution without SGS, WENO5 uses 70.5 solver wall minutes versus 92.8 for WENO9 (24.0% less). However, its fourth-hour third-moment RMSE against digitized in-situ markers is 0.0310 rather than 0.0159 m³/s³. Its minimum w′³ in 600–760 m is -0.0372 versus -0.0622 m³/s³. Lower advection order saves wall time but weakens the negative third moment in this realization. Timings include output within the solve and exclude startup/compilation before the solve; they are not isolated kernel benchmarks.
- Fine Centered2 with Smagorinsky completes in 70.2 solver wall minutes, 31.3% less than fine WENO9 with Smagorinsky. Its fourth-hour LWP is 44.17 versus 53.23 g/m², and third-moment marker RMSE is 0.0382 versus 0.0313 m³/s³. Negative total water prevents interpreting this cheaper run as an acceptable physical solution. Timing includes diagnostics and differing timestep counts; no GPU profiling was performed to identify the cost mechanism.
- At fixed 5 m vertical spacing and fixed horizontal domain, changing WENO9/no-SGS from 35 m to 10 m horizontal spacing changes the fourth-hour minimum w′³ over 600–760 m from -0.0126 to -0.0622 m³/s³. The fine case is negative throughout 600–760 m, agreeing with the sign of the retained in-situ observations there.
- For this same 35 m to 10 m comparison, unweighted RMSE against the digitized in-situ third-moment markers changes from 0.0454 to 0.0159 m³/s³; variance-marker RMSE changes from 0.0606 to 0.0631 m²/s². The third moment improves substantially, while variance does not improve by this metric. These are single realizations without observational error-bar weighting, not a convergence demonstration.
- All 4 completed coarse WENO cases have positive fourth-hour w′³ throughout 600–760 m, while the retained in-situ observations there are negative. Cloud persistence therefore does not establish faithful coarse-grid turbulence.
- Coarse, WENO9 without closure: fourth-hour LWP 49.87 g/m², cloud fraction 99.34%, peak w² 0.395 m²/s², and Δqₜ 0.019 g/kg.
- At coarse resolution without closure, WENO9 minus WENO5 changes fourth-hour LWP by 3.42 g/m² and peak w² by 0.099 m²/s². These are paired single-realization differences, not statistically established scheme effects.
- At coarse resolution with WENO9, adding Smagorinsky changes fourth-hour LWP by -6.54 g/m² and peak w² by -0.038 m²/s². Third-moment marker RMSE changes from 0.0704 to 0.0595 m³/s³.
- Canonical, WENO9 without closure: fourth-hour LWP 61.69 g/m², cloud fraction 99.91%, peak w² 0.521 m²/s², and Δqₜ 0.003 g/kg.
- At canonical resolution without closure, WENO9 minus WENO5 changes fourth-hour LWP by 2.09 g/m² and peak w² by 0.054 m²/s². These are paired single-realization differences, not statistically established scheme effects.
- At canonical resolution with WENO9, adding Smagorinsky changes fourth-hour LWP by -9.50 g/m² and peak w² by -0.067 m²/s². Third-moment marker RMSE changes from 0.0454 to 0.0444 m³/s³.
- Fine, WENO9 without closure: fourth-hour LWP 55.48 g/m², cloud fraction 99.95%, peak w² 0.472 m²/s², and Δqₜ 0.031 g/kg.
- At fine resolution without closure, WENO9 minus WENO5 changes fourth-hour LWP by -2.06 g/m² and peak w² by -0.011 m²/s². These are paired single-realization differences, not statistically established scheme effects.
- At fine resolution with WENO9, adding Smagorinsky changes fourth-hour LWP by -2.25 g/m² and peak w² by -0.027 m²/s². Third-moment marker RMSE changes from 0.0159 to 0.0313 m³/s³.
- Coarse, Centered2 with Smagorinsky: sampled global qₜ extrema over 0–4 h were -4.3385 to 15.0839 g/kg; 227 of 241 samples contained negative moisture. These are 60-second samples, not bounds on every timestep.
- At coarse resolution with Smagorinsky, Centered2 minus WENO9 changes fourth-hour LWP by 5.52 g/m² and peak w² by 0.053 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.
- At coarse resolution with Smagorinsky, Centered2 minus WENO5 changes fourth-hour LWP by 6.59 g/m² and peak w² by 0.095 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.
- Canonical, Centered2 with Smagorinsky: sampled global qₜ extrema over 0–4 h were -7.6972 to 17.4041 g/kg; 231 of 241 samples contained negative moisture. These are 60-second samples, not bounds on every timestep.
- At canonical resolution with Smagorinsky, Centered2 minus WENO9 changes fourth-hour LWP by -16.49 g/m² and peak w² by -0.027 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.
- At canonical resolution with Smagorinsky, Centered2 minus WENO5 changes fourth-hour LWP by -15.33 g/m² and peak w² by -0.006 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.
- Fine, Centered2 with Smagorinsky: sampled global qₜ extrema over 0–4 h were -7.4007 to 18.0746 g/kg; 234 of 241 samples contained negative moisture. These are 60-second samples, not bounds on every timestep.
- At fine resolution with Smagorinsky, Centered2 minus WENO9 changes fourth-hour LWP by -9.06 g/m² and peak w² by -0.072 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.
- At fine resolution with Smagorinsky, Centered2 minus WENO5 changes fourth-hour LWP by -7.54 g/m² and peak w² by -0.082 m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.

## Fourth-hour metrics

| Case | LWP (g/m²) | Cloud (%) | Peak w² (m²/s²) | Δqₜ (g/kg) | E (mm/s) |
|---|---:|---:|---:|---:|---:|
| Coarse / WENO9 / no SGS | 49.87 | 99.34 | 0.395 | 0.019 | 4.75 |
| Coarse / WENO5 / no SGS | 46.45 | 98.91 | 0.296 | 0.015 | 4.70 |
| Coarse / WENO9 / Smagorinsky | 43.33 | 99.07 | 0.356 | 0.080 | 5.21 |
| Coarse / WENO5 / Smagorinsky | 42.27 | 98.52 | 0.314 | 0.047 | 4.93 |
| Coarse / Centered2 / Smagorinsky | 48.85 | 99.44 | 0.409 | 0.214 | 7.27 |
| Canonical / WENO9 / no SGS | 61.69 | 99.91 | 0.521 | 0.003 | 4.32 |
| Canonical / WENO5 / no SGS | 59.61 | 99.92 | 0.467 | 0.020 | 5.19 |
| Canonical / WENO9 / Smagorinsky | 52.19 | 99.37 | 0.454 | 0.023 | 5.24 |
| Canonical / WENO5 / Smagorinsky | 51.04 | 98.95 | 0.433 | 0.060 | 5.24 |
| Canonical / Centered2 / Smagorinsky | 35.70 | 99.59 | 0.427 | 0.250 | 6.57 |
| Fine / WENO9 / no SGS | 55.48 | 99.95 | 0.472 | 0.031 | 5.34 |
| Fine / WENO5 / no SGS | 57.54 | 99.90 | 0.483 | 0.007 | 5.24 |
| Fine / WENO9 / Smagorinsky | 53.23 | 99.89 | 0.445 | 0.036 | 5.09 |
| Fine / WENO5 / Smagorinsky | 51.71 | 99.77 | 0.455 | 0.034 | 5.48 |
| Fine / Centered2 / Smagorinsky | 44.17 | 99.98 | 0.373 | 0.154 | 6.44 |

Peak w² is the maximum of the fourth-hour mean native-face profile; E includes subsidence. [Full metrics](simulation_data/fourth_hour_metrics.csv) · [Paired contrasts](simulation_data/paired_effects.csv).

## Plot conventions and envelope

All scientific figures are generated in Julia with CairoMakie. Numerical configurations use fixed Okabe-Ito colors, distinct dashes and marker shapes; different resolutions occupy panels with shared scales. The cloud-fraction zoom follows the simulated range, while a separate full-range panel preserves the paper ensemble spread.

Light gray is the paper’s model-ensemble minimum–maximum; darker gray is its interquartile range. These are not observational uncertainty bands or validation tolerances. The mean and envelope were digitized from Figure 2 at approximately 0.2–3.9 h. Original pixel coordinates, calibration, extraction settings and an overlay are retained. Subpixel early cloud-fraction bands are left missing. Only rendered cloud-fraction band edges are clipped to the physical 0–1 range; CSV values preserve raw digitization. The zoom panel omits the paper bands to avoid magnifying raster-edge uncertainty.

[Envelope CSV](data/figure2_ensemble_envelope.csv) · [Extraction audit overlay](data/figure2_envelope_overlay.png) · [Envelope provenance](data/figure2_envelope_provenance.json).

## Measured solver cost

| Case | Solver wall (min) | Iterations |
|---|---:|---:|
| coarse_none_weno9 | 4.05 | 7270 |
| coarse_none_weno5 | 3.99 | 7266 |
| coarse_smagorinsky_weno9 | 4.10 | 7264 |
| coarse_smagorinsky_weno5 | 4.13 | 7264 |
| canonical_none_weno9 | 12.11 | 19184 |
| canonical_none_weno5 | 11.96 | 18859 |
| canonical_smagorinsky_weno9 | 11.70 | 18147 |
| canonical_smagorinsky_weno5 | 11.32 | 17651 |
| fine_none_weno9 | 92.83 | 38996 |
| fine_none_weno5 | 70.54 | 38678 |
| fine_smagorinsky_weno9 | 102.17 | 38499 |
| fine_smagorinsky_weno5 | 80.34 | 38229 |
| coarse_smagorinsky_centered2 | 4.21 | 7299 |
| canonical_smagorinsky_centered2 | 12.37 | 19156 |
| fine_smagorinsky_centered2 | 70.20 | 39273 |

Measured per-run solver wall includes output during time integration and excludes earlier Julia startup/compilation and queue waiting. Differences in timestep counts and diagnostic overhead contribute. These single-run timings are not isolated advection-kernel benchmarks. [Cost CSV](simulation_data/solver_costs.csv).

## Cloud persistence and ensemble context

![Cloud persistence and ensemble context](report_figures/evolution.png)

[Vector SVG](report_figures/evolution.svg) · [Vector PDF](report_figures/evolution.pdf).

## Fourth-hour thermodynamic structure

![Fourth-hour thermodynamic structure](report_figures/mean_profiles.png)

[Vector SVG](report_figures/mean_profiles.svg) · [Vector PDF](report_figures/mean_profiles.pdf).

## Fourth-hour vertical-velocity moments

![Fourth-hour vertical-velocity moments](report_figures/vertical_velocity_moments.png)

[Vector SVG](report_figures/vertical_velocity_moments.svg) · [Vector PDF](report_figures/vertical_velocity_moments.pdf).

## Scalar fluxes and buoyancy production

![Scalar fluxes and buoyancy production](report_figures/flux_profiles.png)

[Vector SVG](report_figures/flux_profiles.svg) · [Vector PDF](report_figures/flux_profiles.pdf).

## Cloud boundaries and decoupling

![Cloud boundaries and decoupling](report_figures/boundaries_decoupling.png)

[Vector SVG](report_figures/boundaries_decoupling.svg) · [Vector PDF](report_figures/boundaries_decoupling.pdf).

## Resolution and numerical choices

![Resolution and numerical choices](report_figures/factorial_summary.png)

[Vector SVG](report_figures/factorial_summary.svg) · [Vector PDF](report_figures/factorial_summary.pdf).

## Centered2 moisture validity

![Centered2 moisture validity](report_figures/moisture_extrema.png)

[Vector SVG](report_figures/moisture_extrema.svg) · [Vector PDF](report_figures/moisture_extrema.pdf).

## Averaging-window comparison for the fine grid

Compare the same statistic across windows: changing from dimensional third moment to skewness also changes normalization. Both effects must be kept separate. Values below are minima over 600–760 m; skewness is the ratio of time-averaged central moments.

| Fine case | Window | Minimum w′³ (m³/s³) | Minimum skewness |
|---|---|---:|---:|
| fine_none_weno9 | 2-4 h | -0.0497 | -0.1503 |
| fine_none_weno9 | 3-4 h | -0.0622 | -0.1928 |
| fine_none_weno5 | 2-4 h | -0.0433 | -0.1334 |
| fine_none_weno5 | 3-4 h | -0.0372 | -0.1109 |
| fine_smagorinsky_weno9 | 2-4 h | -0.0419 | -0.1394 |
| fine_smagorinsky_weno9 | 3-4 h | -0.0304 | -0.1026 |
| fine_smagorinsky_weno5 | 2-4 h | -0.0163 | -0.0538 |
| fine_smagorinsky_weno5 | 3-4 h | -0.0160 | -0.0521 |
| fine_smagorinsky_centered2 | 2-4 h | -0.0236 | -0.1206 |
| fine_smagorinsky_centered2 | 3-4 h | -0.0272 | -0.1309 |

[All-resolution window-comparison CSV](pressel2017/data/velocity_window_comparison.csv). These minima may occur at different heights; they do not describe a single fixed-height plume.

## Skewness and the Pressel comparison

![Skewness compared with Pressel](pressel2017/figures/breeze_skewness_comparison.png)

Colored solid curves and symbols are completed canonical Breeze cases; gray dashed curves are Pressel Figure 7 model results, not observations. Both use hours 2–4. Breeze is the ratio of time-averaged central moments, mean_t(w′³)/mean_t(w′²)^(3/2), formed from four half-hour bins. It is not the time average of instantaneous skewness. Pressel's normalization versus time-averaging order is not unambiguously specified, so that part of the comparison remains provisional. Variance ≤ 10⁻⁶ m²/s² is masked.

![Skewness across resolutions](pressel2017/figures/breeze_skewness_resolutions.png)

Only completed exports are shown; the coarse domain is larger. The displayed height range is 0–1000 m. [Full-height skewness and moment CSV](pressel2017/data/breeze_skewness_2_4h.csv) · [Normalization sensitivity audit](pressel2017/data/breeze_skewness_audit.csv) · [Definitions and provenance](pressel2017/data/skewness_provenance.json).

## Pressel et al. (2017): separate 2–4 h comparison

This paper revisits RF01 with the same canonical grid and domain. The comparison below uses its 2–4 h window, separate from the fourth-hour Stevens plots above. Its SGS coefficients, CFL, thermodynamics, surface treatment and moisture handling differ from the current Breeze setup. Dashed curves are published model results, not observations.

![Breeze and Pressel](pressel2017/figures/breeze_comparison.png)

[Paper reference and all seven figures](pressel2017/reference.md) · [Extracted data and audit](pressel2017/data/provenance.json) · [Exact 2–4 h bulk comparison](pressel2017/data/breeze_bulk_comparison_2_4h.csv).

## Experiment and interpretation

### Experimental design

Three grids: coarse 96 × 96 × 75 at 80 × 80 × 20 m in a 7.68 × 7.68 × 1.5 km domain; canonical 96 × 96 × 300 at 35 × 35 × 5 m in 3.36 × 3.36 × 1.5 km; fine 336 × 336 × 300 at 10 × 10 × 5 m in the same canonical domain. Fine dz=5 m is the stated implementation assumption. Each grid crosses WENO9/WENO5 with no closure/Smagorinsky-Lilly (Cs=0.16, Pr=1). WENO moisture uses bounds=(0,1) at both orders; order changes apply to all advected variables. Three additional runs apply Centered(order=2) to momentum and all scalars, including moisture, with the same Smagorinsky-Lilly settings: 15 cases total. Centered moisture is unbounded, so comparisons with WENO change scheme family and bounding as well as order. Finite diagnostics and moisture extrema must be checked before interpreting these cases.

### Physics and initial conditions

Breeze uses anelastic dynamics, warm-phase saturation adjustment, fixed surface sensible/latent heat fluxes 15/115 W/m², drag coefficient 0.0011, divergence D=3.75×10⁻⁶ s⁻¹, geostrophic winds (7,−5.5) m/s and the RF01 idealized longwave radiation. Initial inversion is 840 m, θl=289 K and qt=9 g/kg below, θl=297.5+(z−840)^(1/3) K and qt=1.5 g/kg above. No drizzle or droplet sedimentation. All runs use Float32, seed 123 and four simulated hours. The fixed-flux moisture conversion uses Lv=2.47×10⁶ J/kg; Breeze retains its default thermodynamic latent-heat law with dry-air cp=1015 J/(kg K), which differs from a strictly constant-mixture-cp implementation.

### Averaging and grid locations

Profiles are averages of instantaneous horizontally reduced statistics. The fourth hour combines the equal-duration bins ending at 12,600 and 14,400 s; it excludes the bin ending at 10,800 s. Scalar means are on centers; w variance and third central moment remain on native vertical faces. The third moment has units m³/s³, not normalized skewness. Series means use trapezoidal integration of 60 s samples between 10,800 and 14,400 s. Two half-hour LWP means give a descriptive temporal spread, not a confidence interval.

### Cloud and entrainment definitions

Column cloud fraction uses ql>10⁻⁶ kg/kg in any cell. Cloud-base means exclude clear columns. Inversion height uses the first downward qt=8 g/kg crossing with linear interpolation; its valid fraction is checked. The theta_l=295 K contour and the nearest-cell height used internally by radiation are retained separately. Fourth-hour entrainment is [zi(4h)−zi(3h)]/3600 + D·mean(zi), including subsidence. Decoupling is mean qt over 100–200 m minus mean qt over 700–800 m, with exact layer-overlap weights.

### Reference data and comparison limits

Stevens et al. (2005), DOI 10.1175/MWR2930.1, supplies the RF01 comparison. Figure 2 is a model ensemble mean, not observations or an acceptance band; the paper has no observed LWP time series. Observed cloud cover exceeds 99%. Figure 4 and 5 markers are partial digitizations, with source pixels retained and error bars not extracted. Marker RMSE is an unweighted descriptive distance to retained in-situ points; it is not a likelihood, uncertainty-normalized score, or formal validation criterion. Radar markers are plotted separately. Resolved TKE is plotted against the historical ensemble for context; a prognostic SGS-TKE contribution is unavailable for these closures.

### What this design can establish

The coarse domain has 5.22 times the canonical horizontal area, so coarse-versus-canonical differences combine changes in horizontal spacing, vertical spacing and domain size. Fine-versus-canonical holds domain and vertical spacing fixed. Closure/order comparisons share a seed within a grid, but one seed gives no ensemble uncertainty and different grids do not share identical perturbation fields. UCLA-0 in the paper disables scalar SGS mixing while retaining momentum treatment; it is not identical to Breeze closure=nothing. Neither matching LWP nor agreement with one fine simulation establishes convergence.

### Numerical and output audit

The original WENO runs use an immutable source snapshot with per-file hashes and a pinned Julia 1.12.6 workspace. The Centered2 extension uses a separate versioned runner and provenance while preserving the original source. GPU smoke runs checked all grids and the diagnostic output path before production. Exports require completed jobs, end-of-run sentinels, finite numeric records, exactly nine profile times and 241 series times, 46 profile variables and 32 series variables. Native face/center coordinates and fixed fluxes are checked again locally. Replicated budget arrays, where present, are horizontally averaged by the exporter and their original shape/spread recorded. The TKE residual is a budget-closure residual, not a measured numerical dissipation.

## Run state

| Case | State | Analyzed |
|---|---|---|
| coarse_none_weno9 | COMPLETED | yes |
| coarse_none_weno5 | COMPLETED | yes |
| coarse_smagorinsky_weno9 | COMPLETED | yes |
| coarse_smagorinsky_weno5 | COMPLETED | yes |
| canonical_none_weno9 | COMPLETED | yes |
| canonical_none_weno5 | COMPLETED | yes |
| canonical_smagorinsky_weno9 | COMPLETED | yes |
| canonical_smagorinsky_weno5 | COMPLETED | yes |
| fine_none_weno9 | COMPLETED | yes |
| fine_none_weno5 | COMPLETED | yes |
| fine_smagorinsky_weno9 | COMPLETED | yes |
| fine_smagorinsky_weno5 | COMPLETED | yes |
| coarse_smagorinsky_centered2 | COMPLETED | yes |
| canonical_smagorinsky_centered2 | COMPLETED | yes |
| fine_smagorinsky_centered2 | COMPLETED | yes |

## Reproducibility

All active collection, analysis, digitization, plotting and report scripts are Julia. From the task workspace:

```sh
julia --project=outputs/julia outputs/collect_simulations.jl
julia --project=outputs/julia outputs/digitize_figure2_envelope.jl
julia --project=outputs/julia outputs/plot_simulations.jl
julia --project=outputs/julia outputs/pressel2017/plot_reference.jl
julia --project=outputs/julia outputs/pressel2017/build_reference.jl
julia --project=outputs/julia outputs/build_simulation_report.jl
julia --project=outputs/julia outputs/package_report.jl --sync
```

The pinned plotting environment is in `julia/`. PDF assembly uses Poppler's `pdfunite`; packaging uses `zip` and `tar`. Historical Python scripts are retained only as an audit trail and are not used. Original JLD2 files and checkpoints remain on pcluster; reduced CSVs, metadata and all figure formats accompany this report.

[Paper reference](paper_reference.md) · [Figures and extracted data](figure_data.md) · [Source provenance](cluster/source_provenance.json) · [Exact matrix](experiment_matrix.json) · [Workflow](report_workflow.md).

Stevens et al. (2005), Monthly Weather Review 133, 1443–1462. DOI: https://doi.org/10.1175/MWR2930.1.
