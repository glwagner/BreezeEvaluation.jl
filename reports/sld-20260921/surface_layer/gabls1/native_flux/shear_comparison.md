# GABLS1 mean-wind shear comparison

The gradients use differences between adjacent 12.5 m cell-center levels. The fixed 1 m LES componentwise median u and v profiles are first sampled at those same heights and then differentiated identically; this is shear of the median profiles, not the median of member shears. The reference is available for 8–9 h only. Shear at z=12.5 m describes the 6.25–18.75 m layer, not the wall gradient.

| Window | Case | ∂u/∂z at 12.5 m (s⁻¹) | Vector shear at 12.5 m (s⁻¹) | Mean vector shear 12.5–100 m (s⁻¹) |
|---|---|---:|---:|---:|
| 7–8 h | No closure | 0.17491 | 0.19650 | 0.05058 |
| 7–8 h | SLD covariance | 0.04481 | 0.05326 | 0.04591 |
| 7–8 h | SLD scheme-native | 0.04385 | 0.05225 | 0.04547 |
| 8–9 h | No closure | 0.16739 | 0.18605 | 0.05028 |
| 8–9 h | SLD covariance | 0.04359 | 0.05114 | 0.04712 |
| 8–9 h | SLD scheme-native | 0.04437 | 0.05219 | 0.04711 |
| 8–9 h | Fixed 1 m median | 0.08907 | 0.10038 | 0.05773 |

![Mean-wind shear](figures/gabls1_shear.png)

The no-closure and covariance-SLD cases use the earlier corrected GABLS1 exports; the scheme-native SLD case uses the later measured-flux source. All use the same grid and forcing. The 1 m median is an LES intercomparison reference, not an observation.
