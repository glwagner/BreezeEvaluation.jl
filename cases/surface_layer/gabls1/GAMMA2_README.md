# Matched GABLS1 SLD stability strength γ=2

The 32³ case changes only `stability_strength` from the admitted γ=0, 1 and 4 filtered-wall, one-face, factor-one scheme-native WENO9 cases. The 400 m cube, 12.5 m grid, seed 123, 300 s wall and SLD filters, nine-hour duration, initial potential-temperature digest and wall law are matched. The purpose is to test whether intermediate strength improves the 12.5–37.5 m shear profile without creating the 25 m dip seen at γ=4. Compare both 7–8 h and 8–9 h and preserve w², w³, resolved/numerical/SGS fluxes and local similarity factors.

A 64³ continuation, if this case is admitted, will hold the 400 m domain and physical parameters fixed. Since one face spans 12.5 m at 32³ but only 6.25 m at 64³, include a 64³ two-face SLD case to retain a 12.5 m closure extent, alongside a one-face sensitivity and a no-closure control if GPU throughput permits. A 32³–64³ comparison tests resolution sensitivity; convergence needs at least a third grid or a demonstrated asymptotic trend.

The registry and validator are `registries/gabls1_sld_stability_gamma2.toml` and `gabls1/validate_stability_gamma2_gabls1.jl`. Independent Julia audits and figures are in `gabls1/stability/`. Raw outputs, job evidence, freeze manifest and analysis are retained under `/shared/home/greg/review-coordination/sld-stability-gamma2-20260923/`.
