# Factor-3 report verification

`factor_results_section.pdf` is five pages: two text pages and three Julia figures.
Matching Markdown and HTML are `results.md` and `results.html`.

The latest user preference is applied: new profile, flux and coefficient plots show only
factors 1 and 3, plus fixed 1 m LES reference curves wherever available. Switch-off panels
show only factor 3 because factor 1 did not save these fractions. Earlier factor-2/10
sections are untouched; their data remain available in the detailed numerical comparison.

The Julia audit verifies source/readers, strict collection and export checksums, registry,
GPU evidence and durable child-exit binding; identical initial native profiles; 19 exact
profile times and 541 exact series times; finite values and native coordinates; one-face
SGS support; covariance-plus-SGS consistency; and valid sampled fraction bounds. Both
7-8 h and 8-9 h comparisons are retained. Source-specific strict admission is 1 admitted,
0 rejected. The earlier factor-1 historical reproducibility check remains bitwise exact.

All five PDF pages were rendered with Poppler and visually inspected. Text, legends,
scientific units and line styles are legible without clipping or overlaps. Factor 1 uses
blue dashed lines/circles; factor 3 uses vermilion solid lines/triangles; references use
black dash-dot lines. No factor-2/10 or no-closure curve appears in the new figures.

The report explicitly distinguishes sampled horizontal point-time fractions from
continuous switch-off, missing factor-1 fraction diagnostics from physical zeros, and
covariance-plus-actual-SGS transport from scheme-native WENO transport. It does not infer
the latter's numerical correction or claim that recovered variance calibrates accuracy.
The verified job outcome is child exit zero; no unavailable batch-exit status is inferred.

The PDF skill marker succeeded once before the first authoring command:

`node /Users/glwagner/.codex/plugins/cache/openai-primary-runtime/pdf/26.909.12148/skills/pdf/container_tools/mark_artifact_operation_started.mjs --operation-kind create --expected-output-count 4 --output-format pdf`

The bundled Node executable was used. Scientific analysis, plotting and document authoring
used Julia; Poppler assembled and checked the PDF. No Python, new simulation, or advection
reconstruction implementation was used for this report.

PDF SHA-256: `79fffcc223ae8cf74292ae76bd039fa2ed48085c4908fa05bc2d83a876daef5d`.
Markdown SHA-256: `754300eee71226911449ffde055f60d717bef134801ebbbe4f77f6e56c6db24a`.
