# Post-admission diagnostic exclusion — array 7156

Identified 2026-09-21 during root review of scientific figures, after the 0bfa03d exporter passed its structural, finite-value, schedule and provenance checks. Preserve original manifests and CSV bytes; their `export_verified` flag does not supersede this subsequent semantic finding.

For SLD variants, the generic flux helper selects the model's vertically implicit time discretization. Its reported interior SGS vertical momentum and scalar flux omit the implicit contribution and are zero despite nonzero SLD coefficients and mean gradients. Both GABLS1 and GABLS3 use the helper. The simulation's implicit transport is a separate path.

Excluded pending correction: SGS momentum/scalar/buoyancy fluxes; resolved-plus-SGS total interior fluxes; SGS/total shear and buoyancy production; stress-threshold boundary-layer depths and diagnostics derived from those depths. No claim of missing model transport or a shallow/collapsed layer follows from these diagnostics. Missing SGS dissipation remains unavailable.

Usable for the preliminary physical-response presentation: direct mean velocities/scalars, resolved variances and central third moments, ratios derived from those moments with variance masks, resolved TKE integral, wall-prescribed surface flux and friction velocity, and direct closure coefficient/activity diagnostics. All retain original time windows and source hashes.

Original automatically generated five-figure comparison is excluded from the report and archived outside the deliverable tree. The custom `present_results.jl` uses only the above usable subset, verifies original exported hashes, and discloses the exclusion on each figure.

Exact mean SGS flux cannot be recovered as mean coefficient times mean gradient: their covariance matters. Any checkpoint reconstruction must be labeled instantaneous and must not substitute for the missing time averages. Diagnostic repair and replacement-run admission remain pending.


## Corrected replacement, 21 September 2026

This exclusion remains in force for historical array 7156 and `exports_0bfa03d`. Current figures now use the separate array 7293 (`exports_e0655cf`, evaluation a14c358, analysis e0655cf). All four replacement exports passed native implicit-flux checks, exact output schedules, source/hash verification and interior total = resolved + SGS. See [current results](results.md), [corrected collection](collection_e0655cf/manifest.toml) and [flux audit](corrected_flux_audit.json). No historical files or admission records were overwritten.
