# GABLS3 prescribed inputs

These compact tables transcribe Tables 1--7 of the revised 6 October 2008 GABLS3 LES
instructions. Pressure was converted exactly from hPa to Pa. Humidity is **specific humidity** in
kg/kg, not mixing ratio. Time is relative to 00:00 UTC on 2 July 2006.

- Surface pressure, 0.25 m potential temperature, and 0.25 m specific humidity are linearly
  interpolated in time.
- Surface geostrophic components are linearly interpolated in time and then linearly in height to
  `u_g=-2 m/s`, `v_g=2 m/s` at 2000 m.
- Large-scale tendencies have the sign convention `dϕ/dt = ... + tendency`. They are constant
  from 200--800 m and taper linearly to zero at the ground. Duplicate timestamps denote specified
  jumps; `before` is the left limit and `after` applies at and after the timestamp.
- The signed `u` and `v` components are retained verbatim. They must not be converted from a
  meteorological “wind-from” direction or silently sign-flipped.

The instructions specify `z0=0.15 m`, linear stable functions `ΨM=ΨH=ΨQ=-5z/L`, an optional
damping layer beginning near 550--600 m, an 800 m periodic cube, free-slip impermeable top, and
inversion strength 0.0029 K/m if needed. They do not specify an unstable surface function for the
morning transition. JAX-ALFA uses a Businger-Dyer unstable branch with `(1-15z/L)`; Breeze must
record its selected general unstable-capable MOST law rather than reusing GABLS1's neutral
fallback.

Initial perturbations in the JAX-ALFA transcription are Gaussian below 200 m: independent `u`
and `v` standard deviation `sqrt(0.2)*(1-z/200) m/s`, potential-temperature standard deviation
`0.1 K`, and no stated humidity perturbation. The revised DOCX equations are not rendered by the
plain-text converter; this perturbation prescription remains cross-checked against the JAX-ALFA
transcription and requires pane 47 to record the actual seeded implementation.

See `provenance/gabls3_sources.json` for URLs, commits, hashes, and unresolved provenance.
