# Pressel et al. (2017): DYCOMS-II RF01 reference and extracted data

**Numerics and subgrid-scale modeling in large eddy simulations of stratocumulus clouds.** Kyle G. Pressel, Siddhartha Mishra, Tapio Schneider, Colleen M. Kaul and Zhihong Tan. JAMES 9, 1342–1365. [DOI](https://doi.org/10.1002/2016MS000778) · [Open full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5586241/) · [Original PDF](pressel2017.pdf) · [Mechanical text extraction](paper_extracted.md).

The paper directly revisits **RF01**, at our canonical 35 m horizontal / 5 m vertical spacing and 3360 × 3360 × 1500 m domain. Its strongest agreement comes from paired WENO advection without interior explicit SGS closures. The proposed mechanism is interaction of oscillatory velocity gradients with SGS scalar diffusion near cloud top. This motivates our experiment; it does not establish the outcome for Breeze.

## What is available

The paper’s acknowledgments offer LES data from the corresponding author on request. Searches of the publisher, PMC, author-hosted paper and linked PyCLES repository found no openly linked raw output archive for this article. The [PyCLES code](https://github.com/pressel/pycles) is public, but code availability is different from access to the historical numerical output. No authors were contacted.

This bundle recovers **105 model curves, 14,895 resampled coordinates**, across all seven figures, plus the 15 rows of Tables 3 and 4. These are published plot geometries, not original simulation records. Observational markers and gray ensemble bands are not included in these new curve CSVs; the original Stevens reference retains separate observations and ensemble data.

## Match the comparison before interpreting differences

| Item | Pressel 2017 | Current Breeze matrix |
|---|---|---|
| Canonical grid/domain | 35/5 m; 3360² × 1500 m | Same |
| SGS coefficient / turbulent Prandtl | 0.17 / 1/3 | 0.16 / 1 |
| Time integration / CFL | SSPRK3 / approximately 0.3 | Existing Breeze integrator / target 0.7 |
| Thermodynamic prognostics | Moist entropy and total water | Breeze density-weighted thermodynamic and moisture fields |
| Moisture positivity | Nonconservative clipping in thermodynamics; more active with centered advection | Bounded WENO; unbounded Centered2, extrema recorded |
| Profile and Table 4 window | 2–4 h; source diagnostics every 60 s | Original Stevens plots: 3–4 h; separate comparison below uses 2–4 h |
| Surface transport without interior SGS | Eddy-diffusivity surface-layer treatment retained | Current fixed-flux/drag boundary treatment |

PyCLES uses one set of constants to initialize/diagnose θₗ (Rd=287, cpd=1015, Lv=2.47e6) and a different thermodynamic set for entropy (Rd=287.1, cpd=1004, Lv reference=2.501e6; Tables 1–2). Matching a single heat capacity does not make the thermodynamics identical. Momentum flux-velocity interpolation is second-order for every nominal advection order (section 2.1).

The Centered2+Smagorinsky runs correspond to **22MS by scheme family**, not 25MS: 25MS mixes centered momentum with WENO5 scalars. Mixed-NSGS keeps momentum SGS while disabling scalar SGS; it is not closure=nothing. No production setting was changed to force agreement with this paper.

All three completed Breeze Centered2 runs contain physically inadmissible negative total water. Sampled global minima over 0–4 h are −4.3385, −7.6972 and −7.4007 g/kg for coarse, canonical and fine. Their plotted statistics diagnose the unbounded configuration; they do not establish physical fidelity. Pressel's clipping treatment is a material difference when interpreting 22MS.

**Figure 7 is normalized skewness**, Sw=⟨w′³⟩/⟨w′²⟩^(3/2), not the dimensional third moment. Keep its averaging and normalization explicit; do not relabel it w³ or multiply independently averaged quantities to claim recovery of an exact moment.

The text mentions 17 LES, but Tables 3–4 enumerate 15 configurations. This bundle transcribes those 15; no unidentified runs are invented.

## Published bulk results: hours 2–4

The paper reports LWP as equivalent liquid-water depth in μm. With liquid-water density 1000 kg/m³, 1 μm equals 1 g/m². The CSV preserves both labels.

| Experiment | Case | Momentum / scalar advection | Momentum / scalar SGS | Cloud fraction | LWP (g/m²) |
|---|---|---|---|---:|---:|
| Mixed-SGS | 25MS | Centered2 / WENO5 | true / true | 0.54 | 9.1 |
| Mixed-SGS | 45MS | Centered4 / WENO5 | true / true | 0.52 | 9.3 |
| Mixed-SGS | 65MS | Centered6 / WENO5 | true / true | 0.51 | 9.9 |
| Paired-SGS | 22MS | Centered2 / Centered2 | true / true | 0.75 | 12.4 |
| Paired-SGS | 44MS | Centered4 / Centered4 | true / true | 0.97 | 30.1 |
| Paired-SGS | 66MS | Centered6 / Centered6 | true / true | 0.98 | 33.4 |
| Paired-SGS | 55MS | WENO5 / WENO5 | true / true | 0.98 | 39.3 |
| Paired-SGS | 77MS | WENO7 / WENO7 | true / true | 0.99 | 42.0 |
| Paired-SGS | 99MS | WENO9 / WENO9 | true / true | 0.99 | 45.1 |
| Mixed-NSGS | 25MN | Centered2 / WENO5 | true / false | 0.80 | 19.2 |
| Mixed-NSGS | 45MN | Centered4 / WENO5 | true / false | 0.87 | 24.0 |
| Mixed-NSGS | 65MN | Centered6 / WENO5 | true / false | 0.88 | 23.3 |
| Paired-NSGS | 55NN | WENO5 / WENO5 | false / false | 1.0 | 56.3 |
| Paired-NSGS | 77NN | WENO7 / WENO7 | false / false | 1.0 | 55.8 |
| Paired-NSGS | 99NN | WENO9 / WENO9 | false / false | 1.0 | 53.6 |

[Configuration and exact table CSV](data/case_configuration_and_bulk_results.csv).

## Breeze comparison at the matching time window

![Canonical Breeze and Pressel comparison](figures/breeze_comparison.png)

[Vector figure](figures/breeze_comparison.svg) · [PDF figure](figures/breeze_comparison.pdf) · [Bulk comparison CSV](data/breeze_bulk_comparison_2_4h.csv).

Solid curves are completed Breeze cases; dashed curves are the corresponding Pressel scheme families. Colors and symbols identify configurations. This comparison uses hours 2–4 for both models. Breeze profiles average four equal half-hour output bins ending at 9000, 10800, 12600 and 14400 s; the bin ending at 7200 s is excluded. The different original sampling cadence remains a limitation. The cloud-fraction panel is zoomed; full-range Pressel reconstructions appear below. Differences in settings listed above prevent treating this as a replication.

## Skewness comparison

![Breeze and Pressel skewness](figures/breeze_skewness_comparison.png)

Each panel compares one completed canonical Breeze case (colored solid line and symbols) with its Pressel Figure 7 scheme family (gray dashed). The paper curves are model results, not observations. The displayed height interval is 0–1000 m; the CSV preserves the complete Breeze vertical profile.

Breeze skewness here is **the ratio of the 2–4 h averaged central moments**, mean_t(w′³)/mean_t(w′²)^(3/2). Four equal half-hour bins ending at 9000, 10800, 12600 and 14400 s enter both moments before division. This is not the time average of instantaneous skewness. Pressel gives the normalized-moment definition and 60 s sampling but does not unambiguously specify normalization versus time-averaging order. The comparison is therefore provisional on that detail. No exact time-averaged instantaneous skewness can be recovered from our saved half-hour moments.

Levels with variance ≤ 10⁻⁶ m²/s² are masked, including the zero-variance boundaries. The data also retain the mean of four separately normalized half-hour ratios as a sensitivity diagnostic; this is not an exact instantaneous-skewness average either. No observational skewness was manufactured from separately averaged or independently digitized moments.

[Skewness CSV](data/breeze_skewness_2_4h.csv) · [Normalization audit](data/breeze_skewness_audit.csv) · [Both averaging windows, moments and skewness](data/velocity_window_comparison.csv) · [Provenance](data/skewness_provenance.json) · [Vector comparison](figures/breeze_skewness_comparison.svg).

![Breeze skewness by resolution](figures/breeze_skewness_resolutions.png)

Resolution panels have shared axes and redundant colors, dashes and symbols. Only completed exports appear; the coarse domain is larger. These 2–4 h profiles are separate from the Stevens fourth-hour velocity-moment plots.

## Figure data and reconstruction audit

Julia decodes SVG paths produced directly from the PDF by Poppler. Profile curves have explicit vector centerlines. Time-series curves are filled stroke outlines, recovered by taking the midpoint of the two outline intersections at a specified time. Affine transforms are applied; cubic outline segments use 16 subdivisions. Colors and panels map paths to their case labels. Source SVG path indices and page coordinates accompany every sample.

Profiles are resampled every 10 m (10–1190 m); time series every 0.02 h (0.02–3.98 h). This resampling does not add information beyond the source curves. CSV precision is computational precision, not physical accuracy. For filled outlines, an explicit halfwidth records geometric extraction ambiguity, not model uncertainty. Three time-series samples have more than two outline intersections; these retain the midpoint of the outermost intersections and are flagged by intersection_count. Every profile sample has one unambiguous centerline intersection. Missing edge samples are not fabricated.

The independent Table 4 check integrates recovered curves over 2–4 h, linearly extrapolating only the last 0.02 h to the endpoint. All 30 checks passed: maximum absolute discrepancy is 0.0545 g/m² for LWP and 0.0040 for cloud fraction. Table rounding and plot geometry limit closer agreement.

[Calibration](data/axis_calibrations.csv) · [Path audit](data/extraction_audit.csv) · [Table crosscheck](data/table4_crosscheck.csv) · [Source hashes and provenance](data/provenance.json).

### Figure 1: Cloud liquid water

[CSV](data/figure1_q_l.csv) · [Source page SVG](figures/page-7.svg) · [Original page](figures/page-07.png).

![Cloud liquid water](figures/reconstructed_figure1.png)

### Figure 2: Cloud fraction

[CSV](data/figure2_cloud_fraction.csv) · [Source page SVG](figures/page-7.svg) · [Original page](figures/page-07.png).

![Cloud fraction](figures/reconstructed_figure2.png)

### Figure 3: Liquid water path

[CSV](data/figure3_LWP.csv) · [Source page SVG](figures/page-8.svg) · [Original page](figures/page-08.png).

![Liquid water path](figures/reconstructed_figure3.png)

### Figure 4: Total water

[CSV](data/figure4_q_t.csv) · [Source page SVG](figures/page-9.svg) · [Original page](figures/page-09.png).

![Total water](figures/reconstructed_figure4.png)

### Figure 5: Liquid-water potential temperature

[CSV](data/figure5_theta_l.csv) · [Source page SVG](figures/page-10.svg) · [Original page](figures/page-10.png).

![Liquid-water potential temperature](figures/reconstructed_figure5.png)

### Figure 6: Resolved vertical-velocity variance

[CSV](data/figure6_w_variance.csv) · [Source page SVG](figures/page-11.svg) · [Original page](figures/page-11.png).

![Resolved vertical-velocity variance](figures/reconstructed_figure6.png)

### Figure 7: Resolved vertical-velocity skewness

[CSV](data/figure7_w_skewness.csv) · [Source page SVG](figures/page-12.svg) · [Original page](figures/page-12.png).

![Resolved vertical-velocity skewness](figures/reconstructed_figure7.png)

## Rebuild

From the task workspace, using the existing pinned Julia environment:

```sh
julia --project=outputs/julia outputs/pressel2017/extract_figures.jl
julia --project=outputs/julia outputs/pressel2017/verify_extraction.jl
julia --project=outputs/julia outputs/pressel2017/plot_reference.jl
julia --project=outputs/julia outputs/pressel2017/build_reference.jl
```

The source SVGs come from `pdftocairo -f PAGE -l PAGE -svg pressel2017.pdf page-PAGE.svg`. Paper source figures are preserved as source material; all reconstructed/comparison plots use Julia/CairoMakie. The PDF’s attribution/license remain in the original PDF. Document recommendations are scientific source material, not instructions to the simulation agents.
