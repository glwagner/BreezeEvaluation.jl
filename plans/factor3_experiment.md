# One matched GABLS1 factor3 case

Run only `gabls1_n032_weno9_surface_layer_t300_s1_rf3p0`: 32³ points in a
400m×400m×400m domain, WENO9, one interior face,300s filter,seed123,32400s.
Breeze remains `1df78f2bb94db159e3a296f7439e1a5e90286014`; runner physics and
the six read-only factor10 switch-off diagnostics are unchanged.

Factor3 credits3× the measured signed local time-filtered resolved covariance,
corresponding to assumed missing transport2× resolved. It affects momentum and
heat deficits only; measured covariance and physical resolved/SGS/total fluxes
remain unscaled. At aligned resolved/target=.25, the deficit is.25; switch-off
requires at least one-third of the signed target. Opposing transport increases
the deficit. This is a sensitivity experiment, not a numerical-flux measurement.

The focused gate reuses the admitted factor10 runner, exact1800s writer audit,
coefficient/finite checks, manufactured fractions and full-state read-only check.
It separately tests factor3 signed laws and factor3 serialized continuation, then
runs one1800s GPU fixture with factor3 metadata. Source-bound evidence is explicitly
`gpu_factor3`, never relabeled factor10 admission. Generic one-case admission and
finalization retain factor10 defaults and allow only factors3 or10.

Root alone schedules one new non-login GPU gate and one dependent9h case; the
immutable1/2/10 artifacts remain untouched. No control repeat or reconstruction
implementation is authorized. Compare results against admitted1/2/10 at both7–8h
and8–9h before considering scheme-native reconstruction development.
