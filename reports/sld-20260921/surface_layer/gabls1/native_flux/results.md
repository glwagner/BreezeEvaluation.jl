# Scheme-native WENO transport in GABLS1

The matched 12.5 m GABLS1 experiment is complete. Both runs use a 32³ grid in a 400 m cube, WENO9, one interior closure face, a 300 s filter, factor one, seed 123, and nine hours of identical forcing. The new run changes only the closure's estimate of resolved transport: it uses the materialized WENO advective flux, including its numerical correction, rather than the filtered covariance alone. The earlier admitted factor-one run is the control.

At the first interior face, the measured 8–9 h WENO correction to upward u-momentum transport is **−0.000228 m² s⁻²**, versus a covariance of **−0.007749 m² s⁻²**: about **2.95%** of the covariance. The mean heat correction is **1.4 × 10⁻¹⁰ K m s⁻¹**, effectively zero relative to its **−0.001472 K m s⁻¹** covariance. The saved correction and covariance add to the reconstructed flux at both diagnostic faces for momentum and scalars. This direct measurement gives no support, in this case, for treating missing numerical flux as equal to or twice the covariance—the assumptions behind the earlier factors two and three.

The closure and flow change modestly over the final hour. Mean first-face momentum viscosity decreases from **1.3214** to **1.2958 m² s⁻¹** (−1.9%); heat diffusivity rises from **1.2160** to **1.2642 m² s⁻¹** (+4.0%). Integrated resolved TKE rises 3.8%, the peak resolved w² rises 3.1%, and the diagnosed boundary-layer height falls 7.4 m (3.8%). These are paired single-realization differences after nine hours of evolving turbulence, not estimates of systematic numerical error. The directly measured numerical correction is much smaller than the covariance, and some flow differences may reflect trajectory divergence.

Both 7–8 h and 8–9 h profiles are shown at native model heights against the fixed 1 m LES median where available. Mean wind, temperature, w², w³, resolved TKE, and total u–w flux show that the scheme-native run remains close to the factor-one control. Both coarse SLD runs still depart markedly from the fixed 1 m LES reference in resolved turbulence; the reconstruction change alone does not repair that discrepancy. The 1 m median is a model intercomparison reference, not an observation.

**Mean-wind shear confirms a near-surface deficit with SLD.** Across the 6.25–18.75 m layer in the final hour, vector shear is **0.0522 s⁻¹** with scheme-native SLD and **0.0511 s⁻¹** with covariance SLD, versus **0.1004 s⁻¹** from the fixed 1 m median profiles. The no-closure run is high at **0.1861 s⁻¹**. At higher levels the differences change sign, so this is a near-surface statement rather than a uniform shear bias. The same pattern appears in 7–8 h. All model gradients are differences between adjacent 12.5 m cell-center levels; the reference median u and v profiles are sampled at those heights and differentiated with the same stencil. This is shear of the componentwise median profiles, not the median of member shears or a wall gradient. See the [shear table and method](shear_comparison.md).

A focused three-treatment view adds the earlier WENO9 Smagorinsky run, whose lowest-layer vector shear is **0.1173 s⁻¹**. It is closer to the 1 m reference than either no closure or SLD at that layer, though its simulation used an earlier source revision. The [restricted comparison and log-law analysis](loglaw_comparison.md) keeps this provenance distinction explicit.

The 1 m reference is **not a neutral log-law profile** over 2–30 m: a fit of horizontal speed against log height has slope 1.123 m s⁻¹ per unit log height, versus 0.654 m s⁻¹ implied by its 8–9 h mean friction velocity and κ = 0.4. GABLS1 is stably stratified, so a positive stability correction is expected. The linear stable Monin–Obukhov term reduces the residual from a neutral profile, but does not reproduce the archived median exactly. Scheme-native SLD likewise does not produce a pure neutral logarithm or an exact stable-law profile at its four near-surface velocity levels. The wall model applies a stability-corrected transfer coefficient between the surface and the first velocity level; SLD adjusts the flux at one interior face. Neither mechanism constrains the full vertical wind profile to a prescribed law. Averaged profiles, fluxes, and componentwise medians also need not satisfy a pointwise similarity relation exactly.

The science job **7497** completed at 32,400 s with durable exit zero. Frozen Breeze/Evaluation source passed all 792 hash checks (manifest SHA-256 `72f1bc031503f0833a1b6969e29e2078ceef04e495b8e27cc3885a9843e35a25`); the paired initial-theta SHA-256 is `1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b`. Raw JLD2 audit passed exact 1/19/541 initial/profile/series schedules, native 32/33-level profiles, finite values, and covariance-plus-correction identities on both faces. The comparison uses the previously admitted factor-one output; that run was not repeated. Julia generated all figures.

![Matched profiles for two final-hour windows](figures/native_profiles.png)

![Closure coefficients and flux deficits](figures/native_activity.png)

![Measured WENO flux correction](figures/native_partition.png)

![GABLS1 mean-wind shear](figures/gabls1_shear.png)

![Requested three-treatment shear comparison](figures/gabls1_shear_requested.png)

![Neutral log-law residual and stable correction](figures/gabls1_loglaw.png)

[Julia JLD2 audit and export](audit_export.jl) · [Julia plotting and comparison](compare_plot.jl) · [Julia shear analysis](shear_analysis.jl) · [Julia three-treatment and log-law analysis](three_way_loglaw.jl) · [Audit manifest](export/audit.toml) · [Full metrics](comparison_metrics.md)
