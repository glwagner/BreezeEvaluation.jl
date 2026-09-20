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
