# GABLS3 diagnostic and export contract

Time is seconds since 00:00 UTC on 2 July 2006. Save an explicitly labelled instantaneous initial
record, then instantaneous horizontal profile statistics every five minutes at 300, 600, ...,
32400 s. This follows the revised intercomparison instructions, which explicitly specify no
temporal averaging. The exact 03:00--04:00 UTC paper comparison uses the twelve records at
03:05--04:00 UTC, or 11100:300:14400 s. Any separately accumulated interval means must use
different variable names and record metadata; they cannot replace the required instantaneous
profiles.

Profiles must retain native vertical locations and coordinates. Required diagnostics are mean
`u`, `v`, potential temperature, and specific humidity; native-face central `w²` and `w³`; a
clearly defined skewness derived from consistently averaged central moments; resolved, SGS, and
total momentum, sensible-heat, and moisture fluxes; resolved/SGS/total TKE where available; jet
height/speed; surface fluxes, friction velocity, Obukhov length; and morning-transition measures.
Resolved central moments and fluxes use freshly computed plane means. Never reconstruct native
face velocity from an already centered velocity.

Export schema:

- `series.csv`: wide, first column `time_s`, with units and definitions in `manifest.json`.
- `profiles.csv`: long columns `variable,time_s,z_m,value,location` plus optional metadata.
- `manifest.json`: grid, scheme, closure, source hashes, forcing hashes, temporal-sampling semantics,
  coordinate and finite audits, physical-audit flags, and failed-attempt history.

Observations, the multi-model LES ensemble, and a single 1 m LES are separate reference roles.
Missing statistics stay missing; no moment, flux, or observation may be fabricated.
