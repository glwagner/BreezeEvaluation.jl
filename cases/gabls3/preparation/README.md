# GABLS3 preparation handoff

This is a CPU-tested forcing/preparation module, **not an executable Breeze simulation**.
No jobs are submitted and no current GABLS1/DYCOMS source or results are changed.
The desktop fallback agent owns this directory because remote pane47 hit its provider spend limit.
Pane48 owns repository integration, reference audit, provenance, and export.

## Primary input authority

Sukanta Basu, *GABLS3 LES Intercomparison Case Description*, revised October6,2008:
[author repository copy](https://github.com/Sukantabasu/jax-alfa/blob/aa7baebf99282711416dadbde7dfdfcba8940524/examples/SBL_GABLS3/GABLS3_LES_Revised.docx).
DOCX SHA256: `c1f815de95c22b413ca5d1728d90ae470a5e1b8b86b2c96e29880818ee07c6ee`.
Inputs were transcribed from its tables; pressure hPa converted to Pa. Numeric facts were implemented
independently in Julia; no Python was executed or translated as source code. Pane48 must independently
compare every transcribed row to the original document before marking that gate complete.

[Basu et al. workshop paper](https://www.ecmwf.int/sites/default/files/elibrary/2012/7965-gabls3-les-intercomparison-study.pdf)
describes the nine-hour LES experiment. This is **00–09UTC July2,2006**, not the24-hour GABLS3 SCM case.
The domain is800m cubed; canonical isotropic spacing6.25m. Our proposed64³,128³,256³ matrix uses
12.5,6.25,3.125m and exactly WENO9/none,WENO5/none,WENO9/Smagorinsky: nine cases.

## Implemented and testable now

Run `julia --startup-file=no test_forcing.jl` and `julia --startup-file=no prepare_cases.jl`.
Only Julia stdlibs are needed. Load with `load_case("inputs.toml")`.

- `surface_state(d,t)`: pressure Pa, prescribed theta K and specific humidity kg/kg at0.25m;
  hourly values linearly interpolated. Momentum roughness is0.15m. Scalar roughness is not substituted.
- `geostrophic_wind(d,z,t)`: interpolate surface Ug/Vg in time, then linearly toward(-2,2)m/s at2000m.
- `advection(d,z,t)`: signed RHS tendencies u/v[m/s²],theta[K/s],q[kg/kg/s]; height factor min(z/200,1).
  Duplicate-time rows are exact right-continuous jumps at1,2,3,5,6h. They are not smeared into hourlong ramps.
  Runner must end a time step at each event and evaluate each RKstage on its correct side.
- `initial_state(d,z)`: published u/v/theta/q/pressure interpolation in covered heights only.
  Values below10m are deliberately rejected pending an explicit lower-level initialization policy.
- `scalar_flux`: case-spec0.25m MOST scalar flux expression with caller-provided stabilityfunction.
  Included stable branch is psi=-5z/L. It explicitly rejects unstable z/L; a full morning branch is still needed.
- `preflight` rejects unresolved readiness gates; it must run before any submission or model construction.

## Runner integration contract and unresolved choices

The actual runner must be independently reviewed and CPU-tested before GPU smoke. Do not copy GABLS1's
constant geostrophic forcing, constant cooling, dry thermodynamics, scalar roughness, or stable-only wall model.

1. Resolve initialization below10m on all three grids. Use the known0.25m scalar state appropriately;
   document wind reconstruction and do not silently clamp or extrapolate the10m wind.
2. Audit Breeze prognostic humidity convention. Input q is specific humidity (mass vapor/mass moist air),
   not dry-air mixing ratio. If Breeze uses r=q/(1-q), tendencies transform by dr/dt=(dq/dt)/(1-q)^2;
   verify the actual conservative mass formulation before applying this relation. Review virtual buoyancy,
   theta/entropy conversion, hydrostatic reference pressure and treatment of time-dependent surface pressure.
3. Implement the coupled local or plane-mean MOST solve,0.15m momentum roughness,0.25m scalar references,
   stable psi=-5z/L, and an explicitly selected unstable morning formulation with documented limits.
   Latent/moisture flux affects Obukhov length; a dry-only heat flux solve is not sufficient without justification.
4. Free-slip impermeable top,periodic sides. Optional inversion gradient0.0029K/m.
   If damping used, lower limit550–600m; coefficient/profile and targeted fields need an explicit reviewed choice.
5. Perturbations below200m: u and v Gaussian variance0.2(1-z/200)^2[m²/s²],theta Gaussian variance0.1[K²].
   Standard deviation is square root of variance. Initial SGS TKE if prognosed is0.15(1-z/200)^2[m²/s²].
   Record seed; no initial w perturbation is specified by this document. Do not substitute GABLS1 noise.
6. Initial timestep must scale with grid and actual maximum speed; inherited0.5s is unsafe at finer grids.
   Audit current Breeze/Oceananigans interfaces, tendencies signs,Coriolis orientation, staggering and event stops.
7. Model diagnostics need full vertical support, surface corrections at the boundary only, and resolved/SGS/total
   fields separately. Preserve the GABLS1 KFO fix and test true vertical size on CPU and GPU.

## Diagnostic/export contract

The original spec requests **instantaneous horizontal-plane means**, no temporal averaging,
every300s starting00:05UTC. Fields: u,v,theta,q; resolved u²,v²,w²,theta²,q²; SGS TKE where defined;
resolved and SGS uw,vw,wtheta,wq. Add centered w³/skewness with an explicit small-variance mask,
jet diagnostics, local stress magnitude and TKE terms. Explicit unavailable flags replace fabricated values.

Surface plane-mean uw,vw,wtheta,wq every10s starting00:00:10; also ustar,L,surface state/iterationresidual.
Point samples every10s at horizontal center and nearest heights10,25,50,100,200m:
u,v,w,theta,q,SGS TKE if defined. Record actual cell heights. Optional extra180m point targets the paper's burst.
Original3D snapshots hourly starting03UTC are external raw artifacts, with hashes and storage manifests.

For03–04UTC paper comparison, interpolate each5min sample to10:10:800m without extrapolation, then
calculate ensemble quantiles. Paper pools11models×12samples; preserve separate within-model statistics.
Document which endpoint is excluded to retain12samples (the paper does not settle this convention).
Tower observations are10min samples with median/min/max; profiler30min samples are hourly means.
**Observed total variance and resolved LES variance are distinct.** The paper's single1mLES is distinct
from the11-model6.25m ensemble and from observations; never call it a GABLS1-style1m ensemble median.

## Readiness

Input interpolation and exact jump handling can pass CPU unit tests independently of a model.
That does not establish model integration, GPU safety, nine-hour stability, or physical fidelity.
All readiness gates in inputs.toml remain false until their evidence exists. No production authorized;
GABLS1 retains priority and the campaign-wide maximum is two active GPU jobs.
