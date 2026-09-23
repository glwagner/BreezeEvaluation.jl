# GABLS1 shear and log-law diagnostic

This view shows only no closure, scheme-native SLD, Smagorinsky, and the fixed 1 m LES median. The first three use 12.5 m WENO9 on a 32³ grid; Smagorinsky has a different source revision. The reference is an LES intercomparison median, not an observation.

| 8–9 h case | u* (m/s) | L (m) | 6.25–18.75 m vector shear (s⁻¹) |
|---|---:|---:|---:|
| No closure | 0.2792 | 127.7 | 0.18605 |
| Scheme-native SLD | 0.2901 | 140.4 | 0.05219 |
| Smagorinsky | 0.2230 | 107.9 | 0.11732 |
| Fixed 1 m median | 0.2617 | 127.2 | 0.10038 |

The fixed 1 m reference shear is computed from separately median u and v profiles sampled at the same 12.5 m centers; it is not the median of member shears. All plotted shear values are finite differences across cell-center levels, not wall derivatives.

A neutral log-law would require U(z)-U(z₁)=(u*/κ)ln(z/z₁), with κ=0.4 and horizontal wind speed U. GABLS1 is stably stratified. The wall model instead uses a linear stable MOST correction, giving an expected additional (u*/κ)βₘ(z−z₁)/L with βₘ=4.8 when local fluxes are approximately constant. It computes a transfer coefficient between the surface and the first velocity level; SLD acts at one interior face. Neither enforces a log profile across the column.

For the fixed 1 m median, a neutral-log fit over 2–30 m has slope 1.123 m/s per log-height, versus mean u*/κ=0.654. Its neutral anchored residual RMS is 0.770 m/s; including the stable term with L≈127.2 m gives 0.365 m/s. The reference therefore is not a pure neutral log-law. The median u/v profiles, u*, and heat flux come from separately aggregated archive curves, so the derived L and comparison are diagnostic rather than an exact MOST identity.

For scheme-native SLD over 6.25–43.75 m, the anchored neutral-log residual RMS is 0.475 m/s; the stable-MOST residual RMS is 0.250 m/s using mean u*=0.290 m/s and L=140.4 m. These are only four coarse levels.

![Requested three-treatment wind and shear plot](figures/gabls1_shear_requested.png)

![Neutral log-law residual and stable correction](figures/gabls1_loglaw.png)
