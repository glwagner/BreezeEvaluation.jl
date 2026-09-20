# GABLS3: observational evaluation and case preparation

Status: preparation, with no GABLS3 production results yet. All DYCOMS and GABLS1 material remains in this master report. GABLS1's fixed 1 m ensemble reference is retained in its own comparison.

## Published LES case

The original GABLS3 LES experiment covers 00-09 UTC on 2 July 2006 at Cabauw. It uses an 800 m cube with a common 6.25 m grid. Initial profiles combine tower, wind-profiler and sounding measurements. Geostrophic wind and advective tendencies vary in time and height. Prescribed potential temperature and humidity at 0.25 m replace interactive land-surface and radiation schemes; aerodynamic roughness is 0.15 m. [Basu, Holtslag and Bosveld (2012), sections 2-3](https://www.ecmwf.int/sites/default/files/elibrary/2012/7965-gabls3-les-intercomparison-study.pdf).

For 03-04 UTC, the ensemble reproduced jet height, strength, directional shear and fluxes reasonably well, but near-surface shear was deficient. A 1 m simulation mixed less and produced a stronger jet. Observed submesoscale variability and a turbulence burst were missed. Published LES variances are resolved, whereas observations include total variance. The ensemble percentiles pool models and five-minute samples; tower whiskers show hourly minima/maxima, not confidence intervals. [Basu et al. (2012), sections 4-5 and figures 1-4](https://www.ecmwf.int/sites/default/files/elibrary/2012/7965-gabls3-les-intercomparison-study.pdf).

The related 24-hour SCM experiment begins at noon on 1 July and couples the atmosphere to land-surface and radiation schemes. Its input tables must not silently replace the LES specification. [Bosveld et al. (2014), case selection and setup](https://research.wur.nl/en/publications/the-third-gabls-intercomparison-case-for-evaluation-studies-of-bo-2/).

## Breeze experiment under preparation

Our proposed resolution comparison keeps the 800 m cube fixed: 12.5 m (64 cubed), 6.25 m (128 cubed), and 3.125 m (256 cubed). These nine proposed cases use exactly the user's three configurations: WENO9 without interior closure, WENO5 without interior closure, and WENO9 with Smagorinsky. The added coarse and fine grids are our experiment design, not a claim about the historical intercomparison matrix. Case preparation and validation precede production scheduling; no GABLS3 production run is claimed here.

We will verify the initial profiles, forcing tables, UTC origin, units, moisture convention, roughness lengths, near-surface reference height, wall stability functions through sunrise, damping and perturbations before freezing the setup. Surface exchange remains active in runs without an interior closure. Unresolved parameters stay explicit; GABLS1 defaults cannot substitute for missing GABLS3 inputs.

The comparison will retain observed points and their sampling ranges, published ensemble ranges, and any individual high-resolution LES as distinct references. A single 1 m GABLS3 run is not the two-model GABLS1 median and is not observational truth. Resolution agreement and agreement with observations will be assessed separately.

The author's revised instructions specify instantaneous plane-averaged profiles every five minutes, and surface/point time series every ten seconds. We will preserve that sampling, rather than applying GABLS1 half-hour output averaging. The 0.25 m scalar reference height is distinct from momentum roughness; the wall treatment must handle both stable nighttime and unstable morning conditions. [Revised participant specification, archived in the author's repository](https://github.com/Sukantabasu/jax-alfa/blob/aa7baebf99282711416dadbde7dfdfcba8940524/examples/SBL_GABLS3/GABLS3_LES_Revised.docx).

Planned output includes mean u/v/potential temperature/humidity, velocity variances, vertical-velocity third moment and skewness, resolved/SGS/total momentum, heat and moisture fluxes, available TKE terms, jet height and speed, and surface fluxes, friction velocity and Obukhov length. We will compare the paper's 03-04 UTC interval and the complete night-to-morning evolution. Missing observed third moments or SGS quantities will remain unavailable. Numerical budget residuals will not be labeled dissipation without a closed budget.

Preparation checks cover forcing interpolation and jumps, units, profile shapes, surface fluxes and time stepping. GPU smoke tests retain the two-job limit and GABLS1 priority. Scientific admission requires source/input hashes, completion evidence and audited exports.

## Persistent evaluation repository

Created as a private repository: [glwagner/BreezeEvaluation.jl](https://github.com/glwagner/BreezeEvaluation.jl). Migration, GABLS3 preparation and scientific completion are tracked separately. The combined report and all plots use Julia.

The repository will retain DYCOMS and GABLS1 case definitions, pinned dependencies, provenance, audited results, reference data, plotting/report code, figures and this report. Frozen production, failed attempts and raw fields remain on pcluster with checksummed manifests. Original simulation identities and hashes are preserved. Third-party papers are linked.

All analysis and plots use Julia. Existing completed experiments and running GABLS1 jobs continue unchanged during migration. Future evaluations will live in BreezeEvaluation.jl, with their Breeze dependency revision pinned explicitly.
