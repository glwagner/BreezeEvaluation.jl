# GABLS3 LES evaluation

GABLS3 is the nine-hour LES case for 00:00--09:00 UTC on 2 July 2006 at Cabauw, not the separate
24-hour SCM experiment. The repository now contains a case-local Breeze runner, surface/forcing
implementation, instantaneous diagnostics, audited input preparation, and reference data. The
runner is under CPU validation; it is not production-authorized.

Planned matrix: an 800 m cube at 64³ (12.5 m), 128³ (6.25 m canonical), and 256³ (3.125 m), each
with WENO9/no interior closure, WENO5/no interior closure, and WENO9/Smagorinsky. Preparation and
bounded smoke tests do not authorize an expensive production campaign.

Do not substitute GABLS1 constants. GABLS3 requires verified time-height geostrophic and
large-scale advective forcing, time-dependent 0.25 m temperature and specific humidity boundary
values, the published roughness, the unstable morning MOST branch, damping, and documented
perturbations.

## Implemented choices

- Below 10 m, potential temperature, specific humidity, and pressure are linearly reconstructed
  between the prescribed 0.25 m surface state at 00 UTC and the 10 m sounding. Wind follows a
  logarithmic profile from zero at `z0m=0.15 m` to the measured 10 m vector. No unlabelled clamp
  to the 10 m observation is used.
- Input `q` is Breeze total specific water, in kg water per kg moist air. Warm-phase saturation
  adjustment supplies moist thermodynamics. The anelastic reference is hydrostatically rebuilt
  from the observed initial temperature and humidity profiles with the 00 UTC surface pressure.
  Observed time-varying surface pressure converts prescribed surface potential temperature to
  temperature and is exported, while the anelastic pressure profile itself remains fixed.
- Surface transfer is local, coupled through the moist virtual-potential-temperature bulk
  Richardson number. Momentum uses `z0m=0.15 m`; heat and moisture use the specified 0.25 m
  scalar reference. Stable `psi_m=psi_h=-5z/L`; unstable transfer uses Businger--Dyer with
  coefficient 16. The bounded solve uses `-100 <= z/L <= 10`, and diagnostics record cap and
  unstable area fractions.
- Coriolis is computed from Cabauw latitude 51.9711 degrees N. Stage-time geostrophic profiles
  and all signed advection tendencies use the audited tables. Scheduled callbacks at every
  forcing discontinuity force time-step alignment with the exact right-continuous events.
- A 300 s vertical-velocity relaxation is zero below 600 m and ramps linearly to full strength at
  800 m. Horizontal velocity is not nudged. The top remains free-slip and impermeable.
- Seed 20260702 produces independent Gaussian `u` and `v` perturbations with variance
  `0.2(1-z/200)^2 m2/s2` and Gaussian potential-temperature variance `0.1 K2` below 200 m.
  No initial `w` perturbation is added. Smagorinsky has no prognostic SGS-TKE field, so the
  specified initial SGS TKE is recorded as unavailable rather than fabricated.
- Initial timestep is `min(0.5, 0.5 dx / 15)` seconds; the runtime wizard retains CFL 0.7.
  The authorized closure is `SmagorinskyLilly(C=0.16, Cb=1, Pr=1)`.

Diagnostics preserve native-face central `w2` and `w3`, freshly centered resolved fluxes,
resolved/SGS/total momentum, heat and moisture fluxes, TKE terms, surface fluxes, friction
velocity, moist Obukhov length, jet and boundary-layer measures, moisture extrema, and center
column points. Profiles are instantaneous at 0 and every 300 s; surface/point series are every
10 s. The 03--04 UTC comparison is exactly 11100:300:14400 s.

CPU construction and short-run commands use the committed case-local environment:

```sh
GABLS3_ARCH=cpu GABLS3_NX=64 GABLS3_STOP_SECONDS=1 GABLS3_DIAGNOSTICS=0 \
  julia --project=cases/gabls3/runner cases/gabls3/runner/gabls3_case.jl
```

The separately labeled integration fixture jumps the model clock to exercise an
actual common 300 s profile / 10 s series-and-point output time and the 06:00
forcing event without paying for a nine-hour CPU evolution:

```sh
julia --project=cases/gabls3/runner cases/gabls3/test_runner_integration.jl OUTPUT_DIRECTORY
```

Its states are deliberately nonphysical and must never be admitted as scientific
results or cited as evidence of nine-hour numerical stability.

`cases/gabls3/test_event_alignment.jl` is a narrower, non-integrating CPU
fixture. It constructs the actual runner callbacks, jumps the clock to 3599 s,
checks that the no-op forcing-event callback is scheduled after a step, verifies
the exact 3600 s alignment/actuation and event-side forcing values, and confirms
the separate surface-humidity callback remains at the update-state callsite.
It does **not** establish that `Simulation.run!` crosses the event correctly;
the pinned supplemental GPU gate tests that integration and its native writers.

GPU smoke and production remain gated by free capacity, the full diagnostic/writer contract,
and an explicit campaign freeze. GABLS1 jobs retain priority and no GABLS3 scheduler files exist.
