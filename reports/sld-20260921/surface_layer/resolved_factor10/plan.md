# Factor-10 GABLS1 sensitivity

Authorized by Greg on21September2026 after reviewing the factor1/2 results. Preparation is in progress; no factor10 job has been submitted yet.

Run one new nine-hour case: WENO9, 32³ cells in the same400m cube (12.5m), one supported interior face at12.5m,300s filter, seed123, resolved_flux_factor10 for both momentum and heat. Retain Breeze commit1df78f2bb94db159e3a296f7439e1a5e90286014 and the physical runner configuration. Preserve prior immutable sources and the admitted factor1/2 runs. No new closure component restrictions or additional factors.

Factor10 shuts off a signed deficit once aligned resolved transport reaches10% of the corresponding target. It need not weaken the closure everywhere: opposite-sign transport increases the deficit. It is a strong sensitivity test, not a measured numerical-flux correction.

The existing active_fraction means the closure target/guard is valid, not that the final viscosity or diffusivity is nonzero. Add diagnostic-only horizontal fractions at the supported first face for zero deficit and zero actual viscosity/heat diffusivity, retain guard/support/cap information, and save the time series. Test synthetic positive/zero/guard states and real GPU output. Distinguish zero mixing caused by a satisfied deficit from a failed target guard. Earlier factor1/2 lack these fractions; do not infer them from horizontally averaged coefficients.

Use a new committed evaluation freeze, registry, output root, focused factor10 CPU/GPU validation, exact saved schedules and strict export admission. New batch wrappers use non-login bash with explicit runtime paths to avoid the reproduced login-shell logout cleanup failure. Do not patch old sealed wrappers. Root alone submits jobs; at most two evaluation GPUs, including original7120_2. Current GABLS3 gate7335 continues undisturbed. Prioritize this small sensitivity after the gate releasesnode1, then resume the bounded GABLS3 comparison.

Compare factor10 with admitted factors1/2 in7–8h and8–9h windows: mean profiles versus fixed1m references, w²/w³/skewness, integrated resolvedTKE, wall exchange, native resolved/SGS/total fluxes, coefficients, zero-deficit/zero-coefficient and guard/cap fractions. Physical fluxes remain unscaled. Add Julia plots and results to the same brief/master and persist in public BreezeEvaluation.jl. No additional issue comments until there is a consolidated major conclusion.

Update: GPU validation 7337 was submitted, then canceled after source review identified a synthetic reduced-field function-arity error. No factor10 science run has started. Preserve v1; prepare a new v2 evaluation freeze with the fixture-only correction, require CPU checks before the replacement GPU gate.

## Queued replacement: 2026-09-21 23:45 UTC

CPU validation passed 88 checks; exporter checks passed 71/71. CPU evidence SHA256: 5262822d0358d2deb473cadfbe545b9db6cf0c98e4f2b23fb80ee76565083f28. Evaluation commit cbe90cee275866f742275127de95b6148d2a4653; Breeze remains 1df78f2bb94db159e3a296f7439e1a5e90286014. Freeze /shared/home/greg/review-coordination/sld-factor10-freeze-20260921-v2, manifest 32ebced6c54266ce5f9d7300759635e51d599bc1b090ced070eaa6111e540b0f (779 files).

Campaign /shared/home/greg/review-coordination/gabls1-sld-factor10-20260921-v2. Gate **7338** RUNNING on node 1; science **7339** PENDING with **afterok:7338**. Logs are logs/gate_7338.out and logs/gabls1_factor10_7339.out; durable science exit record also goes in logs. Production wrapper re-admits GPU evidence before running. Original 7120_2 continues on node 2. No scientific factor10 result yet.

Next monitor: inspect 7338 and its evidence, then 7339; cancel dependency-blocked science if validation fails. On completion use cluster_runbook.md finalization/export commands with science_job=7339. Require admitted1/rejected0 before plotting. Update Julia factor1/2/10 comparison and same PDF/master; then release node1 to already validated bounded GABLS3 cases (see outputs/surface_layer/gabls3/validation_runbook_v2.md). Existing ten-minute heartbeat owns continuation; do not duplicate jobs.
