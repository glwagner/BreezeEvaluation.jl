# Neutral supporting comparison: preparation

Prepared from `examples/neutral_atmospheric_boundary_layer.jl` at Breeze feature commit `d73c82b326c7d3715034c7254c982d25548df5ae`. This is a proposed bounded setup, not a submitted job or scientific result. It follows the authorized supporting comparison after the small GABLS cases.

## Matched cases

Use the example's 96 × 96 × 96 grid and 3000 × 3000 × 1000 m domain for both WENO9/no-closure and WENO9/SurfaceLayerDiffusivity with one interior face and T=300 s. The grid has 884736 interior cells, horizontal spacing 31.25 m and vertical spacing 10.4167 m. Run both to the example's five-hour endpoint. Keep the same immutable code/environment, paired initial arrays, precision, forcing, boundary conditions and timestep policy.

Preserve Float32 anelastic dynamics, reference potential temperature 300 K, base pressure 100000 Pa, geostrophic wind (15, 0) m/s and Coriolis parameter 1e-4 s^-1. The capping inversion starts at 468 m and rises by 8 K over six original grid levels: 62.5 m, ending at 530.5 m. Above it the initial gradient is 0.003 K/m. Preserve that physical inversion thickness if any later grid variant is proposed; recomputing six levels on another grid would change the physical case.

The example prescribes friction velocity 0.5 m/s. Its dynamic bottom momentum-flux vector has magnitude rho0 * 0.25 and points opposite the local horizontal momentum, with a small-speed guard. It does not specify a roughness-based wall law. Surface heat flux is zero. Preserve the exact materialized boundary flux and density conversion; do not replace it with the GABLS wall coefficient. For SLD, the scalar zero-flux guard should keep the added heat diffusivity inactive, while momentum viscosity responds to resolved stress. Record any transient guard activity rather than inferring it from nominal inputs.

The Gaussian sponge has width 200 m, center 1000 m and rate 0.01 s^-1. It relaxes thermodynamic density toward the initial profile and damps vertical momentum. Preserve its variables and units. Use paired seed 1994 with uniform velocity perturbations of peak-to-peak 0.01 m/s and potential-temperature perturbations of peak-to-peak 0.1 K below 400 m; no initial vertical perturbation is specified. Save a digest of the actual initial arrays for both runs.

## Validation and cost gate

Keep initial dt=0.5 s and CFL target 0.7 from the example, identical across cases. Run a short bounded smoke first, measuring post-compilation time per step and actual adaptive dt. Estimate remaining five-hour cost from measured throughput, including diagnostic/checkpoint overhead; record the estimate before production. No measured neutral throughput or completion estimate is available yet. The selected grid is the example's existing grid, not a large-domain or resolution expansion. Preserve the global two-GPU limit and existing GABLS1 priority.

Verify native-face support at z=10.4167 m, unchanged applied wall flux, interior momentum conservation, zero-flux scalar inactivity, stable covariance, and restart state. The existing manufactured discrete logarithmic-profile test is a prerequisite; the LES remains a distinct validation task.

## Diagnostics and interpretation

Use the shared evaluated diagnostics with complete native-face w2/w3/skewness, mean velocity and temperature, near-wall shear, actual wall stress, resolved/SLD/combined momentum transport, filtered-mean vertical transport, diffusivity and guard/cap activity. Preserve ten-minute profile averaging from the example and save time series. The example's centered raw moments and Smagorinsky-specific nu_e fields must not be copied as though they were valid SLD diagnostics.

Report the fixed-stress setup explicitly: this comparison diagnoses the vertical distribution of momentum and turbulence under a prescribed wall forcing. It cannot establish improved prediction of surface drag. Evaluate the final-hour means alongside their evolution and sampling variation; no statistical equilibrium or physical improvement is assumed from five hours or finite outputs alone.
