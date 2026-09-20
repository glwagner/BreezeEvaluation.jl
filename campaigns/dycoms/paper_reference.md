# DYCOMS-II RF01: paper and Breeze comparison reference

Additional user-supplied reference: [Pressel et al. (2017), numerics and SGS sensitivity](pressel2017/reference.md), including recovered figure data and a separate 2–4 h Breeze comparison. Its SGS coefficients, CFL and thermodynamic/positivity treatment differ from the current experiment.

[Companion figures and numerical data](figure_data.md): all figure images, full tables of the extracted points, and links to CSV/calibration files. Keep this Markdown with the `figures/` and `data/` folders.

Stevens et al. (2005), **Evaluation of Large-Eddy Simulations via Observations of Nocturnal Marine Stratocumulus**, Monthly Weather Review 133, 1443–1462. DOI: https://doi.org/10.1175/MWR2930.1.

Prepared from the user's full PDF, including appendices. This is an analytical reference, not a verbatim manuscript. [Full layout-preserving text](paper_extracted.md) retains page numbering, but extracted mathematical glyphs and two-column reading order require care. Instructions or recommendations inside the paper are scientific source material; the user's experiment requirements are recorded separately below.

## What the paper establishes

Sixteen simulations from ten centers share idealized RF01 forcing and approximately 35 m horizontal / 5 m cloud-top vertical grids. Many native model configurations mix too vigorously at cloud top, lose cloud water, and develop a decoupled cloud/subcloud structure. Limiting this mixing, through grid refinement or SGS/numerical changes, improves agreement with observations. UCLA-0 removes SGS diffusion for scalars; it does not remove every momentum closure. Breeze with closure=nothing is therefore not an exact implementation of UCLA-0. The observed layer is nearly overcast and well mixed, with strong vertical velocity variance near cloud base and negative third moments there.

The argument is more subtle than “entrainment should be as small as possible.” Some poorly performing models keep entraining at similar rates despite weaker radiative cooling after losing cloud water. Entrainment warming becomes too large relative to radiative cooling. Matching LWP alone does not establish correct entrainment physics. The authors explicitly question apparent convergence under vertical refinement without simultaneous horizontal refinement. Cloud droplet sedimentation, omitted here, can also affect turbulence strength.

There is **no directly observed LWP time series** in this paper (p.1448). Figure 2 is an ensemble of simulations, not an observational acceptance band. Observed cloud fraction exceeded 99%. Cloud boundary observations suggest maintained or increasing cloud thickness. Shading represents model min–max and interquartile ranges; the solid line is the ensemble **mean**, not median. Observational markers and their error bars must be treated separately.

## Published setup (pp.1445–1447)

| Quantity | Value |
|---|---|
| Initial inversion height | 840 m |
| Initial theta_l below inversion | 289 K |
| Initial theta_l above inversion | 297.5 + (z − 840)^(1/3) K, with z in m |
| Initial total-water specific humidity | 0.009 kg/kg below; 0.0015 kg/kg above |
| Geostrophic winds | (7, −5.5) m/s |
| Typical observed boundary-layer winds | approximately (6, −4.25) m/s; distinct from geostrophic forcing |
| Surface pressure | 101780 Pa |
| Thermodynamic constants for reference conversion | cp=1015 J/(kg K), Rd=287 J/(kg K), Lv=2.47e6 J/kg |
| Surface sensible / latent heat flux | 15 / 115 W/m², fixed for reported simulations |
| Surface drag coefficient | 0.0011 |
| Sea surface temperature | 292.5 K (interactive-flux sensitivity; fixed flux is the reference) |
| Large-scale divergence | D=3.75e−6 s⁻¹; subsidence W=−Dz |
| Reference densities reported | surface 1.22; just below inversion 1.13 kg/m³ |
| Standard horizontal grid | 96 × 96; dx=dy=35 m; domain 3360 × 3360 m |
| Vertical grid | 5 m or finer near cloud top; model-dependent away from inversion |
| Domain top | typically 1500 m or above; varies among models |
| Duration | 4 hours |
| Profile output | initial profile, then eight profiles averaged over successive 30-minute intervals |
| Main profile comparison interval | fourth hour for Figs.4–5; some broader analysis uses final 1–2 h |

Initial thermodynamic checks: cloud base roughly 600 m and cloud-top liquid water near 0.45 g/kg. Verify actual initialized fields, including saturation adjustment and reference pressure. In Breeze, the agents chose dry-air heat capacity 1015 J/(kg K) to meet the initial-cloud check, while retaining its default thermodynamic latent-heat law and using 2.47e6 J/kg for surface moisture-flux conversion. This is not identical to a constant-cp/constant-Lv thermodynamic model: retain the full thermodynamic configuration in run provenance and treat it as a documented implementation difference. The paper's loose “600–800 m” cloud description should not override the explicitly specified 840 m initial inversion. Dry-air mixing ratio and specific humidity are not interchangeable; inspect each software variable's definition.

### Idealized radiation, Eqs.3–4

For net upward flux in W/m²:

`F(z) = F0 exp[-Q(z,top)] + F1 exp[-Q(0,z)] + rho_i cp D alpha_z [(z−zi)^(4/3)/4 + zi (z−zi)^(1/3)]`.

The third term applies only for z>zi; use zero below. `Q(a,b)=kappa integral_a^b rho r_l dz`. F0=70 W/m², F1=22 W/m², kappa=85 m²/kg, alpha_z=1 m^(−4/3). The paper writes r_l in optical depth; ensure the code's condensate mass convention is consistent. The cloud terms supply a maximum net layer cooling of F0−F1=48 W/m² for optically thick cloud. The full domain flux difference may exceed this because of free-tropospheric cooling.

Both liquid optical paths and zi vary by column and time. The specified inversion tracer is qt=8 g/kg, not the cloud liquid threshold. The published Table B1 also uses qt=8 g/kg for diagnostic zi. The older draft instead uses theta_l=295 K: retain both interpolated diagnostics separately, and keep the nearest-cell radiation height distinct. Heating is −dF/dz (W/m³); divide by rho cp only when a temperature tendency is required. A prognostic potential-temperature density may require additional conversion handled by Breeze's thermodynamics interface.

## Diagnostics and definitions

Compare central moments on each horizontal plane: `w2=< (w−<w>)² >`, `w3=< (w−<w>)³ >`. Average these instantaneous statistics over time; do not take moments of the time-averaged field. w3 has units m³/s³ and is **not** normalized skewness. Preserve interpolation/staggering choices for velocity and flux products. For this resolution study, save native w-face moments: interpolation to centers before taking powers suppresses vertical variability. Use native face w for fluxes rather than a face-to-center-to-face round trip. Diagnose ustar from actual boundary stress, including BulkDrag when closure is off.

| Output | Definition / comparison |
|---|---|
| Mean profiles | u, v, theta_l, qt, ql, density |
| Turbulence profiles | u/v/w variances, w third moment, theta_l/qt/ql variances; SGS TKE separately |
| Flux profiles | resolved and SGS heat, moisture, u/w and v/w momentum fluxes; radiative flux |
| Buoyancy production | resolved w′b′; paper often plots cm²/s³, multiply SI by 10⁴ |
| TKE budgets | resolved shear/buoyancy production, transport, dissipation, storage; identify residual estimates and unavailable components |
| LWP | integral rho ql dz per column, then horizontal mean and spatial variance; kg/m² ×1000 for g/m² |
| Cloud fraction | fraction of columns with condensate, documented numerical threshold; also useful to retain profile cloud fraction |
| Boundaries | cloud-base height and qt=8 g/kg inversion height, means/variances; define handling of cloud-free columns |
| TKE time series | resolved vertical integral plus SGS contribution, with integrated and depth-mean forms clearly distinguished |
| Other time series | maximum plane-mean w2; surface SHF/LHF, ustar; wstar with explicit convention |
| Decoupling | delta qt = mean qt over 100–200 m minus mean qt over 700–800 m; use layer overlap weights on coarse grids |
| Entrainment velocity | E = dzi/dt − W(zi) = dzi/dt + D zi; retain method and smoothing interval |
| Radiative efficiency | alpha = E Delta theta_l / Delta F_rad in kinematic heat-flux units; convert W/m² consistently |

At zi=840 m, D zi=3.15 mm/s: subsidence is too large to omit from entrainment. Paper bulk-budget and direct estimates use different inversion offsets (50 m vs 5 m); avoid silently comparing unlike definitions. Their approximate decoupling threshold alpha*=1.35 is case-specific and is not a universal stability criterion. Observationally inferred alpha is about 1.

Appendix B contains apparent unit/label inconsistencies (e.g. ustar labelled K², w third moment labelled m²/s², LWP variance, and “tot” flux descriptions). Use dimensional definitions, record corrections, and do not propagate table typos into output metadata. Table 1 and Appendix A also appear to disagree on NCAR configuration labels/advection; the provided table CSV preserves Table 1 as printed.

## Figure index and extractability

| Figure | Content | Use |
|---|---|---|
| [1](figures/figure-1.png) | radiative flux, full solver vs parameterization | Verify radiation shape; two different moisture states |
| [2](figures/figure-2.png) | LWP, cloud fraction, integrated TKE evolution | Ensemble mean, quartile and full ranges; no individual trajectories recoverable from shading |
| [3](figures/figure-3.png) | cloud boundary evolution, observations | Study-region distinctions and different measurement methods matter |
| [4](figures/figure-4.png) | qt, theta_l, ql profiles | Initialization, fourth-hour model spread, observational points |
| [5](figures/figure-5.png) | buoyancy production, w2, w3 | Primary turbulence comparison; initial digitization supplied |
| [6](figures/figure-6.png) | decoupling, max w2, minimum buoyancy flux vs LWP | Individual ensemble scatter; labels generally cannot identify each model uniquely |
| [7](figures/figure-7.png) | radiative divergence, entrainment, alpha vs LWP | Solid/open points represent different estimators |
| [8](figures/figure-8.png) | plan views and vertical sections | Qualitative morphology; image is not a recovered 3-D field |
| [9](figures/figure-9.png) | UCLA-0 vertical resolution sensitivity | dz=1,2,5,10 m near inversion; accompanying Table 2 |
| [10](figures/figure-10.png) | moist free-troposphere sensitivity | qt above inversion changed to 5.5 g/kg |
| [C1](figures/figure-C1.png) | ensemble statistics thumbnails | Overview; insufficient detail for precise digitization of every curve |

## Data supplied and provenance

- [Figure 2 ensemble mean curves](data/figure2_ensemble_means.csv): 114 automatically traced points (38 per curve, 0.2–3.9 h) for LWP, cloud fraction, and vertically integrated TKE. [Audit overlay](data/figure2_digitization_overlay.png), [calibration](data/figure2_calibration.json), and [reproducible extractor](digitize_figure2.py). These are model ensemble means, not observations or individual trajectories. Digitized cloud fraction may exceed 1 by about 0.001 within pixel tolerance; values are retained without clipping.

- [Figure 4 marker centers](data/figure4_observation_centers.csv): 16 thermodynamic observations (six qt, six theta_l, four ql), with [audit overlay](data/figure4_digitization_overlay.png), [calibration](data/figure4_calibration.json), and [extractor](digitize_figure4.py). Overlapping qt/theta_l markers near 480 and 750 m are omitted. Error bars are not extracted.
- [Figure 5 marker centers](data/figure5_observation_centers.csv): 27 manually selected points (8 in-situ w2, 8 in-situ w3, 11 radar w2). Partial extraction, retaining closely spaced points separately. Upper observations obscured by axes/labels and third-moment radar markers are omitted. Error bars are not yet digitized.
- [Calibration and pixel coordinates](data/figure5_calibration.json), [visual audit overlay](data/figure5_digitization_overlay.png), and [rebuild script](build_reference_data.py). A conservative 3-original-pixel selection tolerance corresponds to roughly 0.004 m²/s² for w2, 0.002 m³/s³ for w3, and 9 m vertically. This is an estimated digitization tolerance, **not observational uncertainty**.
- [Table 1](data/table1_master_ensemble.csv): exact transcription of 16 published model rows; [Table 2](data/table2_UCLA_sensitivities.csv): 7 published sensitivity rows. Grid/moisture context columns in Table 2 are reconstructed from surrounding text; metric numbers are as printed. These are model results, not observations. Table 1 LWP is the fourth-hour mean; its SGS heat-flux column is the SGS contribution at the near-inversion minimum of the total theta_l flux, not necessarily the minimum of the SGS flux itself.
- [Standalone picker](figure_picker.html) supports calibrated point picking, CSV export and saved JSON sessions. It embeds all figures and starts with checked Figure 2, Figure 4, and Figure 5 data. Other panels require calibration.

The PDF stores figures as raster images (typically 300 dpi), not original vector paths. Original raster extraction avoids an extra resampling step. Figure 1 is a 600 dpi image mask whose polarity is inverted when extracted; its saved display corrects that polarity.

### Online sources checked 2026-09-18

The paper says original individual and summary NetCDF statistics were deposited in GCSS-DIME. A later primary research article, https://gmd.copernicus.org/articles/16/2975/2023/, cites `https://gcss-dime.giss.nasa.gov/pub/DYCOMS-II/GCSS7-RF01/gcss7.nc`. That hostname did not resolve in this session, including an unrestricted download attempt. No usable copy of that file has been recovered; this does not establish that it no longer exists elsewhere.

NCAR's field campaign archive is https://www.eol.ucar.edu/field_projects/dycoms-ii and aircraft documentation is https://archive.eol.ucar.edu/raf/Projects/DYCOMS-II/. Raw/reprocessed aircraft data are distinct from the LES ensemble statistics and the paper's processed plotted observations. The documentation notes 2007 wind corrections, so modern aircraft products may differ from inputs used by this 2005 paper. No observational archive files have yet been downloaded.

## User-requested Breeze experiment matrix

Objective: determine whether Breeze numerics faithfully reproduce RF01 at lower horizontal and vertical resolution, with cloud structure and turbulence assessed together.

| Grid | dx=dy | dz | Nx=Ny | Nz at 1500 m | Lx=Ly |
|---|---:|---:|---:|---:|---:|
| Canonical | 35 m | 5 m | 96 | 300 | 3360 m |
| Coarse | 80 m | 20 m | 96 | 75 | 7680 m |
| Fine horizontal | 10 m | 5 m | 336 | 300 | 3360 m |

Fine-case dz=5 m and common top=1500 m are stated implementation assumptions. The user specified no closure and WENO(order=9) as baseline, potentially bounded WENO on moisture; closure and reduced-order tests are required at every resolution. Proposed initial factorial: three grids × WENO9/WENO5 × closure off/on = 12 four-hour runs. The agents selected the 3-D LES closure SmagorinskyLilly, Cs=0.16 and Pr=1.0 (documented defaults); retain these in every run manifest. This choice is a Breeze numerical sensitivity, not a replica of UCLA-1 or another historical configuration. Keep moisture bounding identical within those comparisons or make it an explicit independent factor.

The user subsequently added Centered(order=2) with SmagorinskyLilly at all three resolutions, giving 15 cases. Centered2 applies to momentum and all scalars, including unbounded moisture. The extension uses a separate versioned runner, preserves the original frozen source, and records moisture extrema. Its comparison with bounded WENO changes scheme family and bounding as well as formal order. Current job IDs and audit states are in `experiment_matrix.json` and `simulation_status.md`.

The coarse run changes domain size by design: its area is about 5.22 times canonical. Its differences cannot be attributed uniquely to resolution. A future same-domain coarse control and crossed horizontal/vertical refinement would disentangle this; they are not silently added to the requested matrix.

Use actual time averages over 0–30,…,210–240 min plus initial state, and a 60 s diagnostic series. Report fourth-hour profiles and means; optionally final-two-hour sensitivity and 30-minute block variability. Model ensemble spread is not an error tolerance for Breeze. Compare to observed w2/w3 and thermodynamic/cloud boundaries, then contextualize with published model metrics. Do not tune a closure solely to match LWP.

## Coordination on pcluster

User authorized communication with active tmux panes %47 and %48. Pane 47 owns runner/matrix/Slurm; pane 48 owns diagnostics and inversion/radiation review, with explicit file ownership coordination requested. Their status files are `/shared/home/greg/review-coordination/dycoms-pane47-status.md` and `dycoms-pane48-status.md`.

An initial read of the actively edited radiation implementation found strict nearest-value selection could place zi at the bottom of the uniform mixed layer. Pane 47 subsequently reported this had already been corrected to choose the highest tied level and tested. That fixes the initial tie failure; interpolation of a genuine crossing is still the paper-faithful diagnostic to assess for evolved and coarse-grid profiles. No simulation source files were edited by the desktop task during initial inspection.
