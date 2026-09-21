# Physical SGS-flux diagnostic revision

`LegacyGABLSDiagnosticsAdaptation.jl` loads the preserved GABLS1 diagnostic source by its
original SHA-256 and adapts it in memory. GABLS3 uses that same helper. The frozen helper
passed `time_discretization(closure)` to Oceananigans' vertical SGS-flux operators. For
`SurfaceLayerDiffusivity`, that is `VerticallyImplicitTimeDiscretization`, whose interior
explicit-tendency flux is zero because the vertical transport is applied by the implicit
solver. It is **not** the full constitutive SGS flux.

For diagnostic output only, this revision evaluates SLD with
`ExplicitTimeDiscretization()` in the existing Breeze density-weighted flux wrappers. This
recovers the constitutive `-νz ∂z u`, `-νz ∂z v`, and `-κz ∂z scalar` at their native faces,
using the same coefficient locations as Oceananigans' implicit solver. It does **not**
change `model.closure`, its time discretization, the implicit solver, prognostic stepping,
surface boundary conditions, or the frozen source snapshot. The no-closure zero path and
all other closure discretizations remain unchanged. Bottom total flux still comes from
the actual wall BoundaryConditionOperation; it is not inferred from the interior SGS law.

The original GABLS1 SLD exports and any GABLS3 SLD output produced with the earlier
diagnostic revision are not repaired in place. In those files, the following interior
profiles or series are invalid as full physical quantities:

- `sgs_u_w_flux`, `sgs_v_w_flux`, `sgs_w_theta_flux`, and GABLS3 `sgs_w_q_flux`;
- their `total_*` counterparts, `total_stress_magnitude`, `sgs_buoyancy_flux`, and
  `total_buoyancy_flux`;
- `sgs_tke_shear_production`, `total_tke_shear_production`,
  `sgs_tke_buoyancy_production`, and `total_tke_buoyancy_production`;
- `stress_height_0_05`, `boundary_layer_height`, and `boundary_layer_height_valid`,
  which were computed from the incomplete total-stress profile.

The actual wall fluxes and friction velocity, mean state, resolved fluxes, native-face
w moments, resolved TKE/transport, low-level jet, and saved SLD viscosity/diffusivity,
filter, deficit, guard, cap, and support diagnostics remain interpretable. A value of
`boundary_layer_height_valid=1` in a pre-fix SLD export validates only the crossing in
the *wrong* stress profile. The no-closure control's zero interior SGS remains correct.

Hourly checkpoints retain full 3-D state and SLD coefficients, so corrected
**instantaneous checkpoint-time** constitutive fluxes can be reconstructed after
independent validation. The 30-minute mean GABLS1 SGS profiles, complete minute-by-minute
stress-height series, and GABLS3 03:00–04:00 UTC flux average cannot be recovered exactly
from saved reduced profiles or hourly checkpoints alone: `<K ∂z u>` is not
`<K> ∂z<u>`. Complete recovery requires deterministic checkpoint replay with new
writers or fresh matched runs, both producing separately versioned outputs and admission.

Focused CPU regression using the GPU-admitted frozen runner environment:

```sh
/shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project=/path/to/admitted-core/source/BreezeEvaluation.jl/cases/gabls3/runner \
  cases/surface_layer/test_implicit_sgs_flux_diagnostics.jl
```

The test compares nonzero analytic momentum, heat, and moisture fluxes with the exact
`ivd_diffusivity` coefficients at native F-C-F, C-F-F, and C-C-F locations; checks
density-weighted Breeze wrappers; demonstrates the old implicit-tendency zero path;
and requires the no-closure diagnostic to remain zero. A separate short writer fixture
checks that GABLS3 can construct and write all diagnostic profiles on CPU. GPU writer
validation and any replacement science remain separate gates owned by the scheduler.
