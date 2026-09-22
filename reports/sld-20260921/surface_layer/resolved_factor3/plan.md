# Factor 3 before scheme-native reconstruction

Greg authorized one matched nine-hour GABLS1 factor3 run on22September2026. Keep Breeze1df78f2 physics, WENO9,32³ cells in400m cube,12.5m spacing,one interior face,300s filter,seed123. Apply factor3 to momentum and heat. Retain the six read-only switch-off fractions from factor10. Preserve prior1/2/10data.

Factor3 satisfies an aligned deficit when resolved transport reaches one-third of the target. It remains an assumed numerical-transport credit, not a measurement. Compare1/2/3/10 over7–8h and8–9h, referenceprofiles,w2,w3,skewness,TKE,exchange,coefficients and sampled switch-off fractions. Old1/2fractions remain unavailable.

Preparation owner factor_campaign; root alone schedules max2GPUs. Current7343_1 and7120_2 continue untouched. Plan to run this small sensitivity after7343_1 by holding only pendingG3tasks2–4; release them afterfactor3completion or handledfailure. Actual submissions and holds must be recorded before being claimed. No factor3job yet.

Defer advection-reconstruction implementation/testing until these results are shown. The later design should receive the model advection scheme through constructor integration and use scheme-consistent face transport; this is a future task, not part of this parameter run.

NEW USER SEQUENCE 2026-09-22: one matchedfactor3 beforeWENOreconstructiondevelopment. Isolatedhelperfactor_campaign preparingBreezeEvaluation-sld-factor3, sameBreeze1df,diagnosticsunchanged. Root HELD onlypendingG3tasks7343_2/3/4 (JobHeldUser confirmed),7343_1+original7120_2continueuntouched. No factor3jobyet. Queuefactor3gate afterany:7343_1 (separatevalidationnotdependentonscientificsuccess), thenonescience afterokgate,onceCPUchecks/sourcefreeze reviewed. ResumeheldG3tasksafterfactor3sciencecompletionorfailurehandled; rootmonitorownsrelease, NEVERforgetheldjobs. Userdeferredreconstructiondevelopment/testinguntilfactor3results shown. Plan outputs/surface_layer/resolved_factor3/plan.md.

## Factor 3 queued — 22 September 2026

Root reviewed the parameter-specific gate, wrappers, admission and finalizer. CPU88 checks passed, serialized restart mismatch0, exporter71/71 passed. Immutable evaluation b9c31029929650c61040a5a20f9699de9a457978; Breeze1df78f2 unchanged. Freeze /shared/home/greg/review-coordination/sld-factor3-freeze-20260922-v1; source manifest818b06d6ed93968232d8ea3049e2098b3fbbbd2c2b1764f1cdc8f3103769709b.

Campaign /shared/home/greg/review-coordination/gabls1-sld-factor3-20260922-v1. GPU gate7347 queued afterany:7343_1; one science case7348 queued afterok:7347. At submission7343_1 had just left queue; confirm its completion separately before admitting G3 results. Logs: logs/gate_7347.out and logs/gabls1_factor3_7348.out, durable exit beside science log. Read cluster_runbook.md for factor3 finalization/export commands. No factor3 result yet.

IMPORTANT: G3 tasks7343_2/3/4 are deliberately held. Release them with scontrol release after factor3science7348 completes (or failed dependency is handled); do not leave held indefinitely. Preserve healthy7120_2. If factor3 validation fails, cancel blocked7348 and diagnose; release G3 pending tasks if a repair will delay factor3. Root alone schedules. Monitor remains ACTIVE every10min; compare1/2/3/10 using Julia and update same report/publicrepo. Do not start advection-reconstruction implementation/testing until factor3 results have been shown.

USER PLOT STEERING: New factor3 plots should show only factors1 and3, plus fixed1m references whereavailable. Omit factor2,factor10 and no-closure curves in this new section; retain all historical sections/data. Full numerical comparison data may retain other factors for traceability.
