# Matched GABLS1 scheme-native surface flux case

This one-case experiment compares the previously admitted factor-one GABLS1
SurfaceLayerDiffusivity result with the new scheme-native resolved transport.
The new case is `gabls1_n032_weno9_surface_layer_t300_s1_rf1p0_native`.

Both cases use 32³ cells in a 400 m cube (12.5 m isotropic spacing), WENO9,
one interior closure face, a 300 s filter, factor one, seed 123, and nine
simulated hours. The runner retains the historical GABLS1 forcing, rough-wall
law, initial perturbation generator, time-step wizard, and half-hour/one-minute
diagnostic schedules. The new registry requires initial-temperature SHA-256
`1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b`.
The comparison control is the admitted factor-one result; it is not rerun.

The only intended physics change is
`SurfaceLayerDiffusivity(resolved_transport=:scheme_native,
resolved_flux_factor=1)`. The closure uses the materialized WENO9 operator for
the near-wall resolved flux estimate. New one-minute outputs retain filtered
covariance and separately save raw operator flux, filtered numerical correction,
and their reconstructed sum for momentum and prognostic scalars at both
diagnostic faces. The coefficient uses the first face. Existing resolved and
SGS transport diagnostics remain available for comparison. Scheme flux here is
sampled at accepted steps and is not an RK-stage-integrated transport budget.

The isolated evaluation branch pins the validated Breeze feature revision.
`create_native_snapshot.jl` archives both commits, copies the reviewed Breeze
root manifest, verifies every file SHA-256, and makes the result read-only.
The runner's relative Breeze dependency resolves to the same feature worktree
before freezing and to its archived copy afterward. Gate and production jobs
must use only the archived source.

Validation order: CPU 120 s build/integration/writer check; H100 1800 s gate
with the exact frozen source and saved scheme-native terms; then one nine-hour
H100 production case. Admission requires a zero child exit, `CASE_DONE`, exact
source/input hashes, paired initial digest, finite native-grid outputs, and
the expected 19 profile and 541 series times. The output is compared with the
admitted factor-one case over 7–8 h and 8–9 h. A single seed does not establish
sampling uncertainty or a universal closure calibration.
