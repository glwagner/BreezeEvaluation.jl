# SurfaceLayerDiffusivity: implementation and evaluation plan

Date: 2026-09-20. Status: CPU implementation validated; bounded scientific evaluation pending.

Tracking issue: https://github.com/NumericalEarth/Breeze.jl/issues/534

## Objective and scope

Add a shallow vertical eddy viscosity and tracer diffusivity that supplement the turbulent transport resolved by WENO. Estimate the missing fraction with local exponential time averages. Use neutral similarity coefficients initially; leave stability-function corrections for future work. No prognostic TKE equation is required.

The initial target is WENO9 at 12.5 m resolution in GABLS1, evaluated against the fixed 1 m archive median and ensemble spread. Also evaluate GABLS3 at its prepared 12.5 m resolution and the existing neutral atmospheric boundary-layer example. Retain all earlier DYCOMS, GABLS1, and GABLS3 report material. Do not replace historical experiments or overwrite their source snapshots and outputs.

This is an experimental, temporally filtered extension of the idea in Sullivan et al. (1994), not a claim to implement their exact spatially averaged, two-part closure. The first implementation acts on instantaneous vertical gradients, using slowly evolving coefficients. It does not implement their isotropy factor, modify a base Smagorinsky closure, or apply stresses to spatially averaged gradients.

## Time-filtered resolved fluxes

At each horizontal location and active interior vertical face, maintain exponential averages with a configurable physical time scale T:

```math
\partial_t \langle a\rangle_T = (a-\langle a\rangle_T)/T,
\qquad
\alpha = 1-\exp(-\Delta t/T),
\qquad
\langle a\rangle_T^{n+1}=(1-\alpha)\langle a\rangle_T^n+\alpha a^{n+1}.
```

Filter velocities, scalars, their products, and actual surface fluxes consistently. Resolved kinematic covariances are

```math
F_u^r=\langle uw\rangle_T-\langle u\rangle_T\langle w\rangle_T,
\quad F_v^r=\langle vw\rangle_T-\langle v\rangle_T\langle w\rangle_T,
\quad F_c^r=\langle cw\rangle_T-\langle c\rangle_T\langle w\rangle_T.
```

Collocate velocity and scalar samples at the appropriate flux locations before taking products. Document interpolation and sign conventions. A stable online covariance recurrence is acceptable and desirable if it reproduces these exponentially weighted moments; test it against a direct weighted reference. Do not substitute the product of filtered velocities for the resolved covariance.

Initialize means from the initial state and covariance to zero, and record startup behavior. Advance filters only for actual elapsed time; repeated update_state! calls and Runge-Kutta stages must not shorten T. Use previous/completed-step filter state consistently with the stage update ordering and document any one-step lag. Checkpoint and restore the filter state and update clock. Do not store full temporal histories merely to implement the filter.

Local temporal covariance does not remove local mean vertical advection. Retain diagnostics of mean vertical transport, storage, and relevant flux-balance residuals; do not assume horizontal homogeneity pointwise.

## Momentum coefficient

Use upward kinematic momentum flux F and downward stress tau = -F. Obtain the actual materialized momentum boundary fluxes, convert their dynamic units consistently to kinematic units using the appropriate density, and map them to compatible horizontal locations.

Let tau_0,T be the filtered downward surface-stress vector. Define

```math
u_{*,T}^2=|\boldsymbol\tau_{0,T}|,
\qquad \boldsymbol e_\tau=\boldsymbol\tau_{0,T}/|\boldsymbol\tau_{0,T}|,
\qquad \boldsymbol\tau^r=-(F_u^r,F_v^r),
\qquad \tau_\parallel^r=\boldsymbol\tau^r\cdot\boldsymbol e_\tau.
```

Thus u*,T is derived from the time-averaged stress, not the square root of an arbitrarily averaged stress magnitude and not necessarily the arithmetic average of instantaneous u*.

The neutral coefficient is

```math
\nu_{SL}=W(z)\,\kappa u_{*,T}z
\left[1-\frac{\tau_\parallel^r}{u_{*,T}^2}\right]_+,
\qquad [x]_+=\max(x,0),\quad\kappa=0.4.
```

This recovers neutral similarity viscosity with no resolved stress, halves it when half the required along-stress transport is resolved, and turns it off when that resolved transport reaches or exceeds the target. Use vector projection, not subtraction of stress magnitudes. A scalar viscosity cannot fit an arbitrary turning residual vector; diagnose transverse mismatch.

## Tracer coefficient

For a tracer with nonzero filtered upward kinematic surface flux F_c,0,T,

```math
K_{c,SL}=W(z)\,\frac{\kappa u_{*,T}z}{Pr_0}
\left[1-\frac{F_c^r}{F_{c,0,T}}\right]_+,
\qquad Pr_0=1\ \text{initially}.
```

Use signed scalar fluxes; this applies to positive and negative prescribed fluxes. Pr_0 defines the neutral reference gradient. Independent momentum and scalar corrections mean the effective nu_SL/K_c,SL is not fixed. A coupled K_c=nu_SL/Pr_0 mode may be added as an explicitly labeled alternative, but must not silently replace independent scalar-deficit correction.

For zero or numerically tiny surface stress/flux, explicitly make the corresponding similarity correction inactive and report its validity/activity. Do not divide by an artificial small denominator that creates large mixing. Choose and document unit-aware guards before production, including behavior through the GABLS3 sunrise heat-flux sign change. Test continuity/sensitivity near the guard, opposite-sign resolved flux, and bounded finite output. Positive deficit factors can exceed one for countergradient resolved flux; any upper cap or maximum diffusivity must be explicit, recorded, and diagnosed rather than silently changing the formula. Include the diffusion timestep restriction if diffusion is explicit; prefer the existing validated vertically implicit path where compatible.

Map tracer fluxes to the actually transported thermodynamic/moisture variable. GABLS3 needs potential-temperature and total-water consistency, correct dynamic-to-kinematic conversions, and evolving surface states. Unsupported thermodynamic formulations should fail clearly or have a tested conversion, not silently mix incompatible units.

## Vertical support and operators

The baseline applies only at the first interior vertical face, connecting the first and second cell centers. On a uniform bottom-bounded grid this is z=Delta z, usually face index k=2; k=1 is the actual surface boundary. Identify this from the grid rather than confusing face and center indices.

| Support | First interior face | Second interior face | All higher faces |
|---|---:|---:|---:|
| One-face | 1 | 0 | 0 |
| Two-face taper | 1 | 0.5 | 0 |

Evaluate each face's resolved deficit independently. Apply the coefficients to instantaneous vertical gradients through conservative density-weighted diffusion. Keep the existing surface flux boundary conditions unchanged. Interior fluxes redistribute momentum/tracers between adjacent cells and must not introduce a second column-integrated surface forcing.

The prescribed coefficients target missing transport at the similarity gradient; they do not enforce instantaneous residual flux exactly. Direct residual-flux insertion is a distinct experiment and is not the baseline requested here.

No explicit mixing is added above the selected faces. A grid-point support has a resolution rationale: near-wall flux-carrying eddies shrink with wall distance. It is not a prediction of the physical surface-layer depth. Horizontal resolution, aspect ratio, and effective WENO resolution may matter as well. At coarse GABLS resolution the first few faces can exceed the physical constant-flux layer; report that limitation instead of silently treating a surface-stress target as exact aloft.

## Implementation, ownership, and branch discipline

Implement the reusable closure, focused tests, and documentation in a NEW clean Breeze feature worktree/branch based on current upstream main: proposed branch glw/surface-layer-diffusivity. Record its exact base commit. Never switch, reset, clean, or modify the shared DYCOMS production checkout to do this work. Keep unrelated DYCOMS/GABLS runners, data, and provenance out of the eventual Breeze PR diff.

Persist the plan, experiment drivers, pinned dependency revisions, manifests, reduced results, Julia plotting code, and report additions in glwagner/BreezeEvaluation.jl. Use a separate evaluation worktree/branch for this study if concurrent GABLS3 preparation is dirty. Coordinate its integration with pane48, the current evaluation-repository owner. Pin each production run to an immutable committed Breeze revision and environment. Do not run against a changing worktree.

TKEBasedTurbulenceClosure supplies patterns for vertical face diffusivities and their host-model integration. FilteredSurfaceVelocities supplies a temporal-filtering pattern. Read the actual current update lifecycle rather than copying stage handling without tests. Follow applicable repository AGENTS.md guidance and GPU kernel conventions.

Current roles: pane48 owns the isolated Breeze closure/tests, scientific review, evaluation setup, exports, and report integration while pane47 is provider-spend-limited. Do not wait indefinitely or claim both are active. Publish the actual owner, revision, evidence, and paths in `/shared/home/greg/review-coordination/surface-layer-status.md`.

The user explicitly authorizes implementation and the bounded evaluations below. Do not open a PR or merge the feature: the user will decide after reviewing results. Push focused commits for reviewability when ready. BreezeEvaluation.jl is public; keep detailed implementation, test, validation, and job evidence in this repository and the coordination status files.

## Required validation before scientific runs

1. Filter tests: analytic exponential response, weighted covariance reference, variable dt, repeated stage/state calls, initialization and checkpoint restart equivalence.
2. Constitutive tests: no/partial/full/over-resolved stress; vector rotation and opposite directions; positive/negative/zero scalar surface flux; threshold and sign-crossing behavior; finite nonnegative coefficients; exact support weights.
3. Operator tests: native face locations, vertical-only support, density conversion, conservation of integrated momentum/scalars for interior fluxes, unchanged applied surface flux, diffusivity lookup for each tracer, and no full-profile truncation.
4. Neutral manufactured log-profile/constant-stress check, accounting for discrete gradients. Default formula uses physical face height z; the logarithmic-mean effective distance is a separately labeled future numerical variant, not an unrecorded adjustment.
5. CPU and bounded GPU integration for the production formulation, all requested diagnostics and scheduled output, Float32 guards and restart. Smoke success does not establish physical fidelity or nine-hour stability.

## Evaluation matrix and scheduling

Keep at most two GPU jobs running across the existing evaluation work. Preserve the currently running GABLS1 jobs and their immutable outputs. Prepare CPU code/tests while both GPUs are occupied; schedule the new small-grid runs when capacity frees. Do not cancel or duplicate existing jobs merely to obtain faster feedback. Current jobs are discovered from the live registry, not assumed from this document.

### GABLS1: first production priority for this study

Use the original 400 m cube, 32^3 cells (12.5 m isotropic), WENO9, nine hours, unchanged prescribed cooling/MOST wall setup and paired seed. Run the following same-revision comparisons:

| Case | Support | Filter time |
|---|---|---:|
| Matched WENO9/no-closure control | None | N/A |
| SurfaceLayerDiffusivity | One face | 100 s |
| SurfaceLayerDiffusivity | One face | 300 s |
| SurfaceLayerDiffusivity | Two faces, weights 1 and 0.5 | 300 s |

Existing WENO9/no-closure and Smagorinsky results remain historical comparisons. Because the clean feature branch starts from upstream main rather than the older production branch, rerun the inexpensive control with the same runner and pinned dependencies used for the new closure. Do not attribute upstream-version differences to the closure. Preserve the original 15-case registry; the new study has a separate registry.

Compare the fixed 1 m archive median and appropriate spreads, with the current report's reference provenance and limitations. Maintain original final-hour and penultimate-hour windows and full admission standards.

### GABLS3: same closure, independently validated moist case

After the existing 9-hour GABLS3 runner, forcing, humidity, sunrise transitions and outputs pass their current readiness checks, use the 800 m cube at 64^3 (12.5 m isotropic). Run a matched WENO9/no-closure control and the same three closure variants above, on one immutable dependency revision and paired initial perturbations. This is authorization for this bounded coarse-grid comparison, not a new full multi-resolution campaign.

Use the original LES period 00:00-09:00 UTC July 2, 2006, not the 24-hour SCM case. Keep the GABLS3 observational/reference and time-window distinctions. Include scalar-flux guards through sunrise as a first-class diagnostic. Clock-jump writer fixtures are plumbing tests and never admissible scientific output.

### Neutral atmospheric boundary layer

Prepare an evaluation based on examples/neutral_atmospheric_boundary_layer.jl. First validate a neutral surface-layer/constant-stress test and a bounded LES smoke. After the small GABLS comparisons, run a matched WENO9 control and the one-face 300 s configuration using a documented, affordable grid/runtime from the example; report the selected cost before a large neutral LES expansion. Keep inversion, forcing, roughness, seed, timestep policy and grid identical between controls and treatments.

## Diagnostics and report integration

Use Julia for all analysis, plotting, and figure generation; never Python. Preserve the established colorblind-friendly colors and redundant line styles. Add results to the GABLS1 and GABLS3 sections of the same master PDF/HTML/Markdown, retaining all existing DYCOMS and GABLS1 information. Include the neutral experiment as a supporting subsection when available.

Record and plot:

- Mean u/v/theta and GABLS3 moisture; near-wall gradients and nondimensional shear, resolved to their actual face heights.
- Resolved, added, and combined momentum and scalar fluxes; near-wall mismatch, transverse stress, mean vertical transport and any available budget terms.
- Time-dependent viscosity/diffusivity at each supported face, filtered u*, scalar fluxes, deficit factors, validity/guard/cap activation, and effective Prandtl numbers where defined.
- Surface stress, heat/moisture fluxes, u*, L when valid, boundary-layer depth, jet height/speed/turning, native-face w2/w3/skewness and available TKE terms.
- Filter startup and lag, GABLS3 sunrise transitions, numerical extrema, wall time, and sensitivity to averaging and support depth.

Do not call a resolved-plus-explicit flux a complete physical budget if WENO numerical transport is unmeasured. Do not label a general residual numerical dissipation. Do not interpret an improvement in means as success if resolved turbulence collapses. The 1 m GABLS1 archive is a reference ensemble, not exact truth. Missing GABLS3 raw observations/ensemble quantities remain missing, not fabricated or replaced with GABLS1 data.

Publish only completed, provenance-checked scientific cases. Keep partial runs labeled as progress. Save exact case/source/environment hashes, completion records, failed attempts, averaging definitions, CSVs and Julia figure sources beside the report in BreezeEvaluation.jl.

## Progress and completion

Issue 534 comments are reserved for major scientific or design conclusions. Detailed implementation, test, validation, and job-submission updates belong in BreezeEvaluation.jl and the coordination status files, not in issue comments. Desktop is the sole issue-posting owner; other agents provide evidence and draft conclusions without posting duplicates. Preserve the already approved [20 September 2026 comment](https://github.com/NumericalEarth/Breeze.jl/issues/534#issuecomment-5751844915). Never infer completed validation from a submission alone.

The desktop monitor should collect new completed results, rebuild and inspect the master report with existing Julia tools, and persist them to BreezeEvaluation.jl. It may post only major conclusions under the policy above and should remain quiet while healthy state is unchanged. Finish by presenting the report, scientific limitations, and a clean feature diff for the user's PR decision.

## Future work

MO stability functions (phi_m and phi_h), physically informed or aspect-ratio-aware support, a filtered-mean-shear stress variant, additional resolutions/seeds, and composition with other closures. None should be silently introduced into this initial experiment.

## References

- Sullivan, McWilliams & Moeng (1994), https://doi.org/10.1007/BF00713741; author PDF https://www2.mmm.ucar.edu/people/sullivan/talks/papers/sgs.pdf.
- Maronga, Knigge & Raasch (2020), https://doi.org/10.1007/s10546-019-00485-w.
- Existing tracking discussion: https://github.com/NumericalEarth/Breeze.jl/issues/534.
- Neutral example: https://github.com/NumericalEarth/Breeze.jl/blob/8cc115e9bb15e2dbe8c7d530eea50118055546b7/examples/neutral_atmospheric_boundary_layer.jl.
- Surface-filter pattern: https://github.com/NumericalEarth/Breeze.jl/blob/8cc115e9bb15e2dbe8c7d530eea50118055546b7/src/BoundaryConditions/filtered_surface_state.jl.
