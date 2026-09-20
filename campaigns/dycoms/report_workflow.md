# DYCOMS report workflow — Julia only

The user requires Julia for all plots and no Python use. Active data collection, numerical analysis, envelope digitization, plotting, report generation and packaging are now Julia scripts. Historical `.py` files are retained as an audit trail only; do not invoke them. Production simulations and exports were already Julia.

From the task workspace:

```sh
julia --project=outputs/julia outputs/collect_simulations.jl
julia --project=outputs/julia outputs/digitize_figure2_envelope.jl
julia --project=outputs/julia outputs/plot_simulations.jl
julia --project=outputs/julia outputs/pressel2017/plot_reference.jl
julia --project=outputs/julia outputs/pressel2017/build_reference.jl
julia --project=outputs/julia outputs/build_simulation_report.jl
julia --project=outputs/julia outputs/package_report.jl --sync
```

The standalone `julia/Project.toml` and pinned dependency manifest use CairoMakie 0.15.14. They were derived from the user's installed Julia environment without changing that environment. On a new machine, instantiate this plotting environment only. PDF assembly uses Poppler `pdfunite`; packaging uses system `zip` and `tar`. Render the generated PDF with `pdftoppm` for visual review.

## Preserve the user's plotting preferences

- Okabe-Ito colors: blue WENO9/no SGS, vermilion WENO5/no SGS, teal WENO9/Smagorinsky, purple WENO5/Smagorinsky; black Centered2/Smagorinsky with dash-dot-dot lines and star markers. Distinct dashes and circle/square/triangle/diamond markers reinforce color.
- Separate resolution panels with shared scales; keep the five configurations per grid distinct.
- Cloud fraction has a zoom chosen from the simulated range plus a full-range panel. Paper envelopes appear in the full-range panel; do not magnify raster-edge uncertainty in the zoom panel.
- Figure 2 light-gray shading is model ensemble min–max; dark shading is its interquartile range. Neither is observational uncertainty. Source pixels, missing subpixel early cloud-fraction bands, calibration and a visual overlay are retained in `data/figure2_ensemble_envelope.csv` and companion provenance files.

## Production and checks

Monitoring update (2026-09-19 04:50 UTC): pane48 installed a persistent Julia exporter in tmux pane %49. Script `/shared/home/greg/review-coordination/dycoms_export_watcher.jl`; log `dycoms-export-watcher.log`; state `dycoms-export-watcher.state`. It polls both production roots, requires both success markers, exports and Julia-verifies, and exits at 15/15. It is independent of agent usage limits; do not launch a duplicate exporter. Latest heartbeat was 8/15 at 04:41:58 UTC. Scheduler monitoring uses file ages because fine9 batch stdout is not showing live solver progress. On this cluster `find` is bfs; use `-mmin`, not relative strings with `-newermt`.

Fine9 actual checkpoint cadence: initial 03:42:56, first hourly checkpoint (iteration9314) 04:05:09, second (iteration19190) 04:28:01 UTC. The latter establishes about23 wall minutes per simulated hour, supporting completion around05:14UTC. Earlier estimates based on only the first checkpoint or short probes are superseded. Use subsequent file evidence to refine; checkpoint cadence is an estimate, not a completion claim.

Array 7064 on `ssh pcluster` uses frozen source under `/shared/home/greg/review-coordination/dycoms-production-20260919`. Pane 47 owns run health; pane 48 owns transactional Julia export. Do not modify frozen source or submit duplicate jobs. The heartbeat `finish-dycoms-comparison-report` checks every30minutes and pauses after all 15 cases are audited and the final report delivered.

The cluster `analysis_export/refresh_exports.sh` invokes the Julia exporter. Coordinate with pane48 before refreshing to avoid concurrent exports. Never run the old Python verifier; local `dycoms_data.jl` performs Julia checks. Slurm accounting is disabled, so completion requires both success sentinels, absence from active queue and full-duration audited output.

Require241 samples at0:60:14400s, nine profile times at0:1800:14400s,32 series variables and46 profile variables. Fourth-hour profiles average only records12600 and14400. Native w moments are on faces; scalar means are on centers. Series averages integrate3–4h, not endpoint values. The source exporter records replicated-array horizontal reduction, shapes, units and source hashes.

Evaluate turbulence and cloud persistence together. Coarse-domain size, single-seed sampling and unavailable prognostic SGS TKE limit conclusions. PDF/HTML/Markdown report filenames remain stable; synchronize report figures/data to the shared cluster reference after updates. Large raw JLD2 files and checkpoints stay on pcluster.

## Centered2 extension

Smoke7073 passed its finite-value audit on all three grids and released array7074 at10:08:15UTC September19. The audit still found negative total water: minima across11 one-minute samples were coarse+1.0872g/kg,canonical−0.060457g/kg,fine−1.3679g/kg. Preserve `cluster/centered2/c2-smoke-7073.log` and derived `smoke_audit.csv`; the finite gate is not a positivity/physical-validity check. Keep smoke observations separate from full-run statistics and do not silently bound or clip the frozen Centered2 runs.

Confirmed submission: smoke 7073; production array 7074 tasks 1=coarse, 2=canonical, 3=fine, dependent on afterok:7073. Root is `/shared/home/greg/review-coordination/dycoms-centered2-20260919`; logs `dycoms-c2-7074_<task>.log`. The local matrix contains these identifiers.

The user added Centered(order=2) with Smagorinsky at all three grids. Pane 47 owns the isolated runner, GPU finite/moisture-extrema smoke and separate submissions; pane 48 owns its Julia export and audit. Consult each case’s remote_production_root, slurm_array_job_id and remote_log_filename in experiment_matrix.json; the collector supports multiple roots/jobs. Pending preparation is not a submitted or successful run. Original array 7064 and its frozen source remain unchanged. Centered2 applies to all advected variables, with unbounded moisture; retain this distinction in comparisons. The plotting/metrics schema uses advection_scheme and advection_order. The legacy weno column is blank for Centered2. Completion is determined from the entire current matrix.

## Pressel et al. (2017) reference

`velocity_window_comparison.csv` now records both2–4h and3–4h minima for the dimensional third moment and normalized skewness. Compare the same statistic across windows; do not attribute a difference between fourth-hour w3 and2–4h skewness solely to averaging time, because normalization also changes. The report includes fine-grid values side by side.

`pressel2017/plot_reference.jl` now also includes `plot_skewness.jl`. The latter can be run alone to refresh the 2–4 h canonical Figure 7 comparison and separate resolution panels. It uses the ratio of time-averaged native-face central moments, not the unavailable average of instantaneous skewness. Retain that qualification: Pressel's order of temporal averaging and normalization is not unambiguously documented. Equal half-hour bins ending 9000,10800,12600,14400 are validated against CSV window metadata. Mask variance ≤1e-6 m²/s²; preserve all values and the separately normalized half-hour sensitivity diagnostic in `pressel2017/data/breeze_skewness_2_4h.csv`. The main report and reference embed both figures; future refreshes pick up new completed cases automatically.

The second user-supplied paper is DOI 10.1002/2016MS000778, also RF01. `pressel2017/reference.md` records its setup and data. Figures 1–7 contain 105 extracted model curves; Tables 3–4 enumerate 15 cases. Raw output was offered by author request; do not describe the vector extraction as raw LES output. Compare matching 2–4 h means using four Breeze half-hour bins ending 9000,10800,12600,14400. Keep the existing Stevens fourth-hour comparison separate. Figure7 is skewness, not w3. Pressel Cs=.17, Pr=1/3, CFL≈.3 and clipping differ from current runs; the no-interior-SGS cases still retain surface-layer treatment. No frozen run was changed to match. Rebuild `plot_reference.jl` and `build_reference.jl` before the main report as new cases finish. Centered2 maps to22MS by scheme family. Paper comparison currently displays canonical cases only because that matches the published grid/domain. Preserve source calibration, exact table crosschecks and extraction provenance.

## Final completion — 2026-09-19

All 15 cases completed and passed the remote Julia export audit. The persistent watcher recorded `WATCHER_COMPLETE verified=15/15` at 11:51:52 UTC and exited normally. The final fine Centered2 solver took 4212.2 s over 39,273 iterations. All three Centered2 runs contain physically inadmissible negative total water: sampled global minima are −4.3385, −7.6972 and −7.4007 g/kg for coarse, canonical and fine; respectively 227, 231 and 234 of 241 samples contain negative moisture. Complete/verified denotes finite full-duration output, not physical fidelity. Earlier monitoring snapshots and ETA paragraphs above are historical. No jobs remain in the queue. The final report refresh is followed by pausing the desktop heartbeat; do not restart runs or watchers without a new request.
