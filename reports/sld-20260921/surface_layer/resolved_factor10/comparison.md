Factors1/2 passed their original strict admission (2 admitted,0 rejected); factor10 passed separate source-specific admission (1 admitted,0 rejected). Same Breeze physics, grid and initial profiles; diagnostic-only evaluation revision for factor10. Exact schedules, physical flux partition and support rechecked locally.

Skewness is the ratio of hourly mean moments. Fluxes remain unscaled; numerical transport is not measured. The earlier control is context from another source revision.

| Window | Case | u* m/s | Heat W/m² | ∫TKE m³/s² | w²12.5m | w³12.5m | Skew12.5m | ν12.5m m²/s | SGS/total uw |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| penultimate_hour | factor1 | 0.29715 | -15.752 | 32.4533 | 0.0100155 | -0.0002997 | -0.2990 | 1.3138 | 0.8589 |
| penultimate_hour | factor2 | 0.29330 | -15.588 | 29.0919 | 0.0095090 | -0.0001738 | -0.1874 | 1.1277 | 0.8609 |
| penultimate_hour | factor10 | 0.28430 | -15.304 | 35.2916 | 0.0668137 | +0.0101105 | +0.5854 | 0.0019 | 0.0052 |
| penultimate_hour | historical_oneface300 | 0.29715 | -15.752 | 32.4533 | 0.0100155 | -0.0002997 | -0.2990 | 1.3138 | 0.8589 |
| penultimate_hour | historical_control | 0.28132 | -14.940 | 35.8210 | 0.0652588 | +0.0105535 | +0.6331 | 0.0000 | -0.0000 |
| final_hour | factor1 | 0.28860 | -15.538 | 27.2602 | 0.0081706 | -0.0001872 | -0.2535 | 1.3212 | 0.8866 |
| final_hour | factor2 | 0.28306 | -15.384 | 25.5134 | 0.0087540 | -0.0001186 | -0.1448 | 1.1180 | 0.8682 |
| final_hour | factor10 | 0.27909 | -15.233 | 35.1207 | 0.0646710 | +0.0097760 | +0.5944 | 0.0000 | 0.0001 |
| final_hour | historical_oneface300 | 0.28860 | -15.538 | 27.2602 | 0.0081706 | -0.0001872 | -0.2535 | 1.3212 | 0.8866 |
| final_hour | historical_control | 0.27916 | -15.213 | 34.1783 | 0.0635343 | +0.0090180 | +0.5631 | 0.0000 | -0.0000 |

Fresh factor1 versus old7293 oneface300: all profile values identical = true; all series values identical = true.

| Factor10 saved fraction | 7-8h | 8-9h |
|---|---:|---:|
| surface_layer_face1_momentum_deficit_zero_fraction | 0.9981934 | 0.9999349 |
| surface_layer_face1_momentum_valid_zero_deficit_fraction | 0.9981934 | 0.9999349 |
| surface_layer_face1_viscosity_zero_fraction | 0.9981934 | 0.9999349 |
| surface_layer_face1_ρθ_deficit_zero_fraction | 0.9999674 | 1.0000000 |
| surface_layer_face1_ρθ_diffusivity_zero_fraction | 0.9999674 | 1.0000000 |
| surface_layer_face1_ρθ_valid_zero_deficit_fraction | 0.9999674 | 1.0000000 |

Factor10 job7339 used the corrected non-login wrapper; its durable child record verifies exit0. The older factor2 job7331 scheduler discrepancy remains preserved: its child exited0 and full outputs were verified, while Slurm reported batch exit1. A separate login-shell logout probe reproduced that older failure pattern; the old batch shell depth was not recorded.
