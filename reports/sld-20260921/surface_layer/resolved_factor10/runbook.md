# Factor-10 run status

User authorized one matched nine-hour GABLS1 sensitivity. Root alone schedules jobs; max two concurrent evaluation GPUs including original 7120_2 on node 2. Use node 1 for factor 10, then the already validated GABLS3 four-case comparison.

## Preserved first validation attempt

- Freeze: `/shared/home/greg/review-coordination/sld-factor10-freeze-20260921-v1`
- Evaluation commit: `0faac3b2432cf58fd36d7febeeed8269c21b213a`
- Breeze physics commit: `1df78f2bb94db159e3a296f7439e1a5e90286014`
- Manifest SHA256: `ecfacdc388551dbdb744f6f6604419eb91ad0a1d2514eb5e09af19a3f1b256a0`
- Campaign: `/shared/home/greg/review-coordination/gabls1-sld-factor10-20260921-v1`
- GPU validation job 7337: submitted 2026-09-21 23:38 UTC, then canceled. Source review found manufactured reduced-field setters used `(x,y,z)` rather than `(x,y)`. No science case was submitted.
- Preserve this attempt unchanged; it does not constitute passed GPU validation.

## Next action

Helper `factor_campaign` owns a new fixture-corrected v2 evaluation freeze. Await its focused CPU and exporter checks before root submits the fresh GPU gate. Scientific code remains unchanged. After source-specific GPU validation passes, submit the single `gabls1_n032_weno9_surface_layer_t300_s1_rf10p0` case via the frozen non-login batch wrapper. Record actual new source hashes, paths, and job IDs here before ending the scheduling turn.

After nine-hour completion, finalize the attempt, strictly export/admit the source-specific output, pull compact data, and compare factors 1, 2, and 10 using Julia in both 7–8 h and 8–9 h windows. Preserve the existing reports and unavailable switch-off fractions for older factors. Add figures and results to the same SurfaceLayerDiffusivity brief and master PDF, and commit the scoped report snapshot to public BreezeEvaluation.jl.

## Queued replacement: 2026-09-21 23:45 UTC

CPU validation passed 88 checks; exporter checks passed 71/71. CPU evidence SHA256: 5262822d0358d2deb473cadfbe545b9db6cf0c98e4f2b23fb80ee76565083f28. Evaluation commit cbe90cee275866f742275127de95b6148d2a4653; Breeze remains 1df78f2bb94db159e3a296f7439e1a5e90286014. Freeze /shared/home/greg/review-coordination/sld-factor10-freeze-20260921-v2, manifest 32ebced6c54266ce5f9d7300759635e51d599bc1b090ced070eaa6111e540b0f (779 files).

Campaign /shared/home/greg/review-coordination/gabls1-sld-factor10-20260921-v2. Gate **7338** RUNNING on node 1; science **7339** PENDING with **afterok:7338**. Logs are logs/gate_7338.out and logs/gabls1_factor10_7339.out; durable science exit record also goes in logs. Production wrapper re-admits GPU evidence before running. Original 7120_2 continues on node 2. No scientific factor10 result yet.

Next monitor: inspect 7338 and its evidence, then 7339; cancel dependency-blocked science if validation fails. On completion use cluster_runbook.md finalization/export commands with science_job=7339. Require admitted1/rejected0 before plotting. Update Julia factor1/2/10 comparison and same PDF/master; then release node1 to already validated bounded GABLS3 cases (see outputs/surface_layer/gabls3/validation_runbook_v2.md). Existing ten-minute heartbeat owns continuation; do not duplicate jobs.
