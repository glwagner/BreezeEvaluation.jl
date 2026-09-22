## GABLS3 matched SurfaceLayerDiffusivity comparison

Four completed cases were loaded through `load_case_export`, which verifies scientific admission and all exported artifact hashes. The comparison uses native Center/Face heights, never interpolated model levels. The matched control and three SLD variants share the frozen scientific source and paired initialization recorded in their manifests.

Profiles are equal means of the twelve instantaneous records at 11100:300:14400 s (03:00–04:00 UTC); 10800 s is the left boundary, not a sample. No GABLS1 archive curves are used as GABLS3 observations.

At interior faces, thick momentum-flux curves show resolved plus explicitly modeled SGS flux; thin curves show the resolved share. The bottom boundary flux is wall-prescribed. This sum excludes unmeasured WENO numerical transport. Skewness is the ratio of window-mean native-face w³ and w², not a mean of instantaneous skewness. Missing/invalid boundary-layer heights are not converted to physical zero. These are single-seed comparisons, not sampling-uncertainty estimates.

Plot-source SHA-256: `345e24eb4712d3bf593d924a5bae808e3001b39ac64343e407ac97060822d471`.

- `n064_weno9_none`: admitted manifest `8e7740dd40cc791bcc57181bc5a4d58ba1cb4bcac7e7929c2f0e76914b0a5260`.
- `n064_weno9_surface_layer_t100_s1`: admitted manifest `ae08b3ddc1681da0feedae9a54f03211ea6bb6907c1e5644dab396ada3f25f36`.
- `n064_weno9_surface_layer_t300_s1`: admitted manifest `d9d5926bf8b06ceee29cb64cf69a1971e360ac7735f2ed7e141ac27d22197073`.
- `n064_weno9_surface_layer_t300_s2`: admitted manifest `71f0f2deff1f68c30e7108a14491a1cbe0120543bd3d7eec2c5a622380004644`.

![gabls3_sld_profiles.png](gabls3_sld_profiles.png)

[Vector figure](gabls3_sld_profiles.pdf) · PDF SHA-256 `293b577d1eb28656b1e6def3a5805cdd5c59d8d08c01da61ee4647e10f179ed5` · PNG SHA-256 `4b2fc1205e4b57a9abb7cf4027caa2783e047d2a24a3f55bf34b9482ce2bdc3f`.

![gabls3_sld_scalars.png](gabls3_sld_scalars.png)

[Vector figure](gabls3_sld_scalars.pdf) · PDF SHA-256 `83a168e925aa6e19c4da7b4e67808a1519e0c26295b9fd5f8ed063fad9e7af11` · PNG SHA-256 `8d8ed786eb09f48da2561b91274d7af0841b7b8d326a5d1c7f8395d308744297`.

![gabls3_sld_moments.png](gabls3_sld_moments.png)

[Vector figure](gabls3_sld_moments.pdf) · PDF SHA-256 `8b0c99fe8aa4c8c96ca205b8fce2ac779d393057abd3cc6b1f64afc28618d267` · PNG SHA-256 `3b17eeb301ea4e4b13dba856e7f20f5df3b6d6a49f201d2c68c0ee82ab20eeef`.

![gabls3_sld_timeline.png](gabls3_sld_timeline.png)

[Vector figure](gabls3_sld_timeline.pdf) · PDF SHA-256 `21c4cae8cc118d5ee1a4ef77f93bd0bca4c4b499850dfc62fa74f6019d3ebb69` · PNG SHA-256 `1b94cc1e0f98b12ddb413334851e794a9b50851f6387b47e7449ac0cf0c8a45f`.

![gabls3_sld_closure.png](gabls3_sld_closure.png)

[Vector figure](gabls3_sld_closure.pdf) · PDF SHA-256 `9e016cff8d5d9cafaf8d3e34988f19538c6b3f2f3f2b4e9f320bcbd7e20afa3b` · PNG SHA-256 `cb51aae634e070bd512920761de48f3c69357eaf86bced3cb8791a9702128bab`.

