# GABLS1 resolved-flux factor10

One nine-hour n032,400m × 400m × 400m domain,12.5m,WENO9,one-face,300s-filter,seed123 case.
Breeze physics remains commit1df78f2bb94db159e3a296f7439e1a5e90286014.
Both momentum and heat use factor10: it credits10 times measured local temporal
resolved covariance, corresponding to assumed missing numerical transport9 times
that covariance. Signed projected momentum and signed scalar ratios are retained.
The aligned deficit clips to zero when credited transport reaches its target;
opposing resolved transport can increase mixing. This does not measure numerical flux.

Case ID: gabls1_n032_weno9_surface_layer_t300_s1_rf10p0.
Existing admitted factor1 reproduces old7293 oneface300 exactly; factor1/2 remain
the comparison baseline. No additional control or parameter matrix is authorized.

Diagnostic additions at first interior face: horizontal fractions of raw clipped
deficit<=0, guard-valid AND deficit<=0, and actual coefficient<=0, for momentum and
heat separately. Every denominator is all horizontal points; none is conditioned
on the number of guard-valid points. Active fractions describe target/guard/support
validity; they do not describe positive coefficients. Existing cap fractions remain
separate. Old factor1/2 did not save these fractions and they are unavailable there.
The six fractions are read-only postprocessing fields and leave prognostics unchanged.
Stored deficit units are corrected to dimensionless in this new exporter only.

Validation is source-specific factor10 CPU/GPU: signed floor/opposing/guard/cap
properties, exact manufactured spatial fractions and read-only state, serialized
factor10 continuation, and a GPU1800s actual runner with exact native initialization,
series and averaged output schedules. Physical covariance/SGS/total fluxes remain
unscaled. Factor10 may legitimately produce zero viscosity, so actual-run SGS need
not be nonzero; coefficient and fraction contracts detect mistaken switch-off.
This fixture is not a scientific result and does not reuse old GPU admission.

Only root submits jobs. Fresh immutable source/evidence directories, strict factor10
admission, and one non-login batch wrapper avoid the prior .bash_logout teardown.
Missing/failed validation, wrong factor/source, incomplete outputs or missing durable
exit records prevent scientific admission. No original source, freeze or run is changed.
