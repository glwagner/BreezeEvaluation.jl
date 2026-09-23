# GABLS1 SLD stability-correction metrics

One seed per condition; half-hour-bin window averages; differences are descriptive. The fixed 1 m reference is an LES intercomparison median, not observations, and λ was not tuned against it.

| Case | Window | First-layer vector shear (s⁻¹) | Mean u* (m s⁻¹) | Mean surface heat flux (K m s⁻¹) | Peak w² (m² s⁻²) | w³ at 18.75 m (m³ s⁻³) | Domain L (m) |
|---|---|---:|---:|---:|---:|---:|---:|
| Filtered · no closure | 7–8 h | 0.15579 | 0.29717 | -0.012128 | 0.09216 | 1.245e-02 | 145.4 |
| Filtered · no closure | 8–9 h | 0.15407 | 0.30190 | -0.013143 | 0.10125 | 1.629e-02 | 140.9 |
| Filtered · SLD λ=0 | 7–8 h | 0.05184 | 0.29319 | -0.011724 | 0.06216 | -2.326e-04 | 144.6 |
| Filtered · SLD λ=0 | 8–9 h | 0.05302 | 0.29485 | -0.012333 | 0.06276 | -2.946e-04 | 139.8 |
| Filtered · SLD λ=1 | 7–8 h | 0.07162 | 0.28877 | -0.011264 | 0.05580 | -5.743e-06 | 143.7 |
| Filtered · SLD λ=1 | 8–9 h | 0.07387 | 0.28907 | -0.011838 | 0.06676 | 1.020e-04 | 137.2 |
| Filtered · SLD λ=4 | 7–8 h | 0.11921 | 0.28641 | -0.011218 | 0.06390 | 3.864e-03 | 140.8 |
| Filtered · SLD λ=4 | 8–9 h | 0.12911 | 0.29917 | -0.012884 | 0.08575 | 5.932e-03 | 139.8 |
| Fixed 1 m LES median | 8–9 h | 0.10038 | — | — | — | — | — |

## First-face (12.5 m) SLD transport

| Case | Window | Viscosity (m² s⁻¹) | Heat diffusivity (m² s⁻¹) | u covariance (m² s⁻²) | u numerical correction | u–w resolved (profile) | u–w SGS (profile) | w–θ resolved (K m s⁻¹) | w–θ SGS (K m s⁻¹) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Filtered · SLD λ=0 | 7–8 h | 1.2821 | 1.2243 | -0.01024 | -0.0002323 | -0.010463 | -0.055462 | -0.0019845 | -0.0089585 |
| Filtered · SLD λ=0 | 8–9 h | 1.2892 | 1.2396 | -0.0096094 | -0.00025591 | -0.0099142 | -0.058658 | -0.0020438 | -0.0095586 |
| Filtered · SLD λ=1 | 7–8 h | 0.84953 | 0.63876 | -0.012726 | -0.00045776 | -0.013079 | -0.051425 | -0.0030099 | -0.0074672 |
| Filtered · SLD λ=1 | 8–9 h | 0.82387 | 0.60453 | -0.013811 | -0.00046591 | -0.014608 | -0.052218 | -0.0034717 | -0.007677 |
| Filtered · SLD λ=4 | 7–8 h | 0.25552 | 0.096517 | -0.036306 | -0.0016129 | -0.037702 | -0.025919 | -0.0089064 | -0.0016425 |
| Filtered · SLD λ=4 | 8–9 h | 0.24517 | 0.088672 | -0.043396 | -0.001743 | -0.045186 | -0.027868 | -0.010566 | -0.0016075 |

## λ=4 local stability state (horizontal means of local values)

| Window | Stable fraction | Upward-flux fraction | Mean φₘ | Mean φₕ | Mean 1/φₘ | Mean 1/φₕ | Median stable local L (m) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 7–8 h | 1.0000 | 0.0000 | 2.7025 | 3.7665 | 0.3706 | 0.2661 | 141.8 |
| 8–9 h | 1.0000 | 0.0000 | 2.7169 | 3.7900 | 0.3685 | 0.2643 | 140.4 |
