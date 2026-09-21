# Resolved-flux factor sensitivity

Authorized by Greg, 21 September 2026. Status: isolated implementation and matched-case preparation; no new scientific result yet.

## Question and interpretation

The measured resolved covariance excludes the transport contributed by the numerical scheme. Test a simple assumption that this unmeasured transport is aligned with and proportional to the resolved flux. Define a dimensionless factor a so the closure credits a F_resolved toward its transport target. a=2 assumes an additional numerical contribution equal to the resolved contribution; a=1.2 would assume 20% of the resolved contribution, not 20% of their sum. Only a=2 versus a=1 is authorized for this first sensitivity test.

For momentum, multiply the signed along-surface-stress projection inside the deficit:

    nu_SL = W kappa u_star z max(0, 1 - a tau_resolved_parallel / |tau_surface|).

For each active scalar, retain its signed surface-flux ratio:

    K_SL = W kappa u_star z / Pr0 max(0, 1 - a F_resolved / F_surface).

The same factor will apply to momentum and heat in this bounded GABLS1 test. Guard thresholds, caps, filter evolution, wall conditions and implicit operators remain unchanged. A same-sign resolved fraction of 0.3 changes the deficit from 0.7 at a=1 to 0.4 at a=2; half-resolved aligned transport shuts off the a=2 correction. Opposite-sign transport increases the deficit. Therefore a=2 is neither a doubling of viscosity nor a uniform halving of viscosity.

The factor is an assumed contribution used by the closure, not a measurement or recovery of numerical flux. Actual numerical transport need not have the same sign, direction, spatial support, or proportionality for heat and momentum, and need not vanish wherever resolved covariance vanishes. Preserve unscaled covariances and native resolved/SGS/total diagnostic fluxes. Any displayed a F_resolved quantity must be separately labeled as an assumption used in the deficit. Resolved plus SGS remains the measured transport partition available here, not a full discretization budget.

## Matched experiment

Two new nine-hour GABLS1 cases: WENO9, 400 m cube, 32^3 cells (12.5 m), one active interior face, 300 s filter, factors 1 and 2. Pair initialization, seed, forcing, output cadence, timestep policy and exact committed dependency revisions. Use a new isolated source freeze and registry; preserve original7293 and all previous data. No new support/filter-time matrix, factor1.2, or u/v-only modification is included.

Run meaningful CPU and bounded new-source GPU checks before production, including the factor actually reaching both constitutive paths, default1 equivalence, signed deficits, guards/caps/support, implicit coefficients and native flux consistency. Validate any changed reconstruction/restart path. Root alone schedules, with at most two evaluation GPU jobs including original7120_2; use one array task at a time. Preserve agent48's separate GABLS3 humidity-correction work.

Compare 8–9 h and 7–8 h mean profiles, first-face and peak w², w³/skewness, resolved-TKE integral, wall exchange, native flux partitions, closure coefficients and deficit/guard/cap activity. Retain fixed1m references. Assess whether reduced modeled transport permits recovery of resolved turbulence and whether mean profiles improve together with moments. Similar mean profiles alone are insufficient. One seed supplies sensitivity evidence, not uncertainty or a calibrated numerical-flux estimate.

## What the existing support/time tests show

| Configuration | First-face w² (m²/s²) | Peak w² (m²/s²) | Resolved TKE integral (m³/s²) | u_star (m/s) |
|---|---:|---:|---:|---:|
| No interior closure | 0.06353 | 0.08640 | 34.18 | 0.2792 |
| One face, 100 s | 0.00924 | 0.05776 | 28.16 | 0.2922 |
| One face, 300 s | 0.00817 | 0.05756 | 27.26 | 0.2886 |
| Two faces, 300 s | 0.00451 | 0.06148 | 29.09 | 0.3015 |

All three SLD settings have the same broad response: reduced near-wall resolved turbulence and larger tested mean-u, mean-theta and w² discrepancies from the fixed1m LES median. Changing the averaging time by a factor of three has a modest effect here. Two-face support is not interchangeable near the wall: first-face w² is 45% below one-face300, even though peak variance and integrated energy remain similar. These statistics do not identify the mechanism or establish convergence with filter time/support.

Source: current corrected7293 exports and physical_response_summary.json in gabls1/. All calculations and plots use Julia.
