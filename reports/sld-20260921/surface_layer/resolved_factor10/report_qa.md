# Factor-10 report verification

The Julia comparison, plotting, and report builders completed successfully. The section is
`factor_results_section.pdf` (five pages: two text pages and three scientific figures),
with matching `results.md` and `results.html`.

The audit independently verified collection and export checksums; source, registry, GPU
evidence and durable child-exit bindings; identical initial native profiles; exact 19-profile
and 541-series schedules; finite output; first-face-only SGS support; native interior
covariance-plus-SGS consistency; and six finite, consistent factor-10 switch-off fractions.
Earlier factor-1/2 exports and their report were preserved. New fraction diagnostics are
unavailable for those earlier runs, not filled with zero.

PDF text was extracted with Poppler and all five rendered pages were visually inspected.
Text and figures are legible without clipping or overlaps. Factor 10 uses a prominent
vermilion solid line with triangular profile markers, contrasted with blue dashed factor 1,
green dash-dot factor 2, gray dotted historical control, and black fixed 1 m references.

Scientific interpretation checks:

- Final-hour momentum/heat zero-coefficient fractions refer to one-minute sampled horizontal
  point-times, not guaranteed continuous switch-off. Tiny nonzero averaged SGS heat flux is
  explicitly retained.
- The plotted interior total is covariance plus actual constitutive SGS, not scheme-native
  WENO transport. Its numerical correction remains unmeasured and unimplemented.
- Similarity to the no-closure run is not presented as proof of agreement with the fixed
  1 m LES reference or as calibration of the multiplier.
- Reported completion is the verified child exit zero. No unavailable Slurm batch-exit
  status is inferred from the non-login wrapper.

PDF skill marker succeeded exactly once before first authoring:

`node /Users/glwagner/.codex/plugins/cache/openai-primary-runtime/pdf/26.909.12148/skills/pdf/container_tools/mark_artifact_operation_started.mjs --operation-kind create --expected-output-count 4 --output-format pdf`

The bundled Node executable was used. All scientific analysis, plots, and report authoring
used Julia; PDF assembly and visual verification used Poppler. No Python was used.

Section PDF SHA-256: `bfc1424598cfd151b03b0acbbd793e634766cb366f39711f01c517b1b8dbc28e`.
