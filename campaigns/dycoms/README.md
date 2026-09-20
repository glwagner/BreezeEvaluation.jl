# DYCOMS-II RF01 paper and simulation reference

**Additional paper:** [Pressel et al. (2017): reference, all seven figures and extracted curves](pressel2017/reference.html) ([Markdown](pressel2017/reference.md)). Includes 105 model curves, 14,895 resampled coordinates, exact bulk tables, source/provenance, and a separate Julia comparison using the paper’s 2–4 h window.

**Simulation results:** open the [illustrated report](dycoms_report.html), [PDF](dycoms_report.pdf), or [Markdown](dycoms_report.md). The report states how many of the 15 GPU cases are complete; it is preliminary until all cases are audited. [Run status](simulation_status.md) and [fourth-hour metrics](simulation_data/fourth_hour_metrics.csv) are refreshed alongside it.

[Companion figures and numerical data](figure_data.md): all figure images, full tables of the extracted points, and links to CSV/calibration files. Keep this Markdown with the `figures/` and `data/` folders.

Start with [the checked paper reference](paper_reference.md) for the case specification, findings, figure index, comparison conventions, and experiment matrix. [The extracted paper text](paper_extracted.md) preserves page boundaries but is not a corrected mathematical transcription.

Open [figure_picker.html](figure_picker.html) directly in a browser. It is standalone and embeds all 11 figure images. It starts with 157 digitized points: 114 ensemble-mean curve points in Figure 2, 16 thermodynamic observations in Figure 4, and 27 turbulence observations in Figure 5. Pick a figure and panel, select or enter a series label, and click to add points. For a new panel, calibrate two labelled x ticks and two labelled y ticks before picking. Save a JSON session to preserve calibration and points; export CSV for analysis. The visible export text can be copied if the browser does not allow a download.

## Data and reproducibility

- `data/figure2_ensemble_means.csv`: LWP, cloud fraction, vertically integrated TKE. These are published LES ensemble means, not observations.
- `data/figure4_observation_centers.csv`: partial total-water, liquid-water potential-temperature, and cloud liquid-water observations. Overlapping markers and error bars are omitted.
- `data/figure5_observation_centers.csv`: partial in-situ w variance/third-moment and radar w-variance extraction. Error bars have not been extracted. Do not interpret the pixel tolerance as observational uncertainty.
- `data/table1_master_ensemble.csv` and `data/table2_UCLA_sensitivities.csv`: visually checked table transcriptions, with context and limitations in the paper reference.
- Calibration JSON files, source pixel coordinates, visual audit overlays, and `data/provenance.json` preserve the extraction trail.
- Historical extraction scripts remain for provenance only. Active workflow is Julia-only; see [report_workflow.md](report_workflow.md).

## Simulation comparisons

All comparison figures are now generated in Julia/CairoMakie and supplied in `report_figures/` as PNG, vector SVG and vector PDF. All 32 reduced time series and 46 profile diagnostics are retained under `simulation_data/<case_id>/`, with units, grid locations, source hashes, and audit manifests. See [report_workflow.md](report_workflow.md) for the read-only collection and rebuild workflow.

`experiment_matrix.json` specifies 15 four-hour cases: three grids × WENO9/WENO5 × closure off/SmagorinskyLilly, plus Centered(order=2) with SmagorinskyLilly at all three grids. It records the submitted job mapping; [simulation_status.md](simulation_status.md) distinguishes preparation, validation, queued jobs, and completed runs. Fine-grid dz=5 m is an implementation assumption. WENO moisture bounds are held fixed; Centered2 moisture is unbounded and has a separate extrema audit. The Centered2 extension uses an isolated runner and leaves the original frozen source unchanged.

Evaluate cloud and turbulence together:

1. Compare the 60-second LWP/cloud-fraction/TKE series with Figure 2 for spin-up and persistence, retaining the distinction between ensemble context and observational evidence.
2. Combine the 180–210 and 210–240 minute profile averages for fourth-hour profiles. Average instantaneous central moments, rather than taking moments of time-averaged velocities. Compare native-face w variance and w third central moment with Figure 5.
3. Check theta_l, q_t, q_l, cloud base, inversion height, and decoupling. Use the interpolated q_t=8 g/kg inversion diagnostic for the paper convention; retain the separate theta_l=295 K and radiation-internal estimators.
4. Compute entrainment as d(zi)/dt + D zi. At zi=840 m the subsidence correction is 3.15 mm/s, so it cannot be neglected.
5. Compare paired closure/order cases on each grid. The coarse domain is larger by design, so comparisons with canonical combine resolution and domain-size effects. One seed per case does not establish statistical convergence.

The remote shared copy is `/shared/home/greg/review-coordination/dycoms-reference/`. Cluster validation and job status are maintained separately from the scientific reference data.

## Figure 2 model envelope

The [digitized envelope](data/figure2_ensemble_envelope.csv) includes min/max and quartiles, with [overlay](data/figure2_envelope_overlay.png) and [provenance](data/figure2_envelope_provenance.json). Rebuild with `julia --project=julia digitize_figure2_envelope.jl` from this folder. Unresolved early cloud-fraction bounds remain missing. The plotted envelope is model spread, not observational uncertainty.
