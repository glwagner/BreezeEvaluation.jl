using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D = @__DIR__
paragraphs = String[
    "GABLS1 32-cubed to 128-cubed resolution sensitivity | 24 September 2026. Matched nine-hour WENO9 cases use a 400 m cube, seed 123, paired initial perturbations, filtered rough-wall drag, and gamma=2 scheme-native SLD with a 300 s filter. The fixed 1 m LES medians are intercomparison references, not observations. The 128-cubed grid spacing is 3.125 m. Shear below is computed on common 12.5 m intervals after interpolating both u and v to 32-cubed cell centers. Native shear is shown separately.",
    "During 8-9 h, one-face SLD shear at 12.5, 25, and 37.5 m is 0.09152/0.06140/0.05235 per second at 32 cubed, 0.10144/0.05600/0.03951 at 64 cubed, and 0.09080/0.04759/0.03967 at 128 cubed. The fixed 1 m median is 0.10038/0.06666/0.05607. The 128-cubed two-face result is 0.09242/0.04739/0.04083. The third grid does not establish convergence or eliminate the upper-shear deficit. Both 7-8 h and 8-9 h windows appear in the figures.",
    "Peak resolved w-squared in 8-9 h is 0.05588/0.09688/0.11556 square meters per second squared for 32/64/128-cubed one-face SLD; 128-cubed no closure gives 0.11063, and two-face SLD gives 0.11171. Resolved turbulence remains grid-sensitive. At 18.75 m, interpolated w-cubed is +0.002489 and +0.002144 cubic meters per second cubed for 128 one/two-face, compared with negative values at 64 cubed. No w-cubed median is available, so the sign change is sensitivity, not a fidelity ranking.",
    "The one-face closure reaches z=12.5/6.25/3.125 m at 32/64/128 cubed. Two-face support reaches 12.5 m at 64 cubed but only 6.25 m at 128 cubed. The current implementation supports at most two faces; none of the 128-cubed cases retains the 12.5 m physical footprint. Refinement therefore changes closure reach as well as grid spacing. At 128 face two, mean viscosity is 0.04693 square meters per second, resolved u-w is -0.05477, SGS u-w is -0.00619, and the separate WENO correction is -0.01079 square meters per second squared.",
    "Validation: immutable 128-cubed source-manifest SHA-256 dfdcd8846a756b73b7006b67a0bdcd565a2df5400bf769e64f9d7d5345e3e233. H100 gate 7674 passed CUDA parity34/34 and 15/15, 32/32, 38/38 short-case checks. Science array7688 tasks1-3 each ended with durable exit zero and CASE_DONE at32400 s. Independent Julia audits verified source, paired initial state, native128/129 levels, exact schedules, finite fields, evolving wall filter, density-consistent surface flux, and scheme-native flux identities. Both SLD cases passed55 local1/L and stability records through nine hours. An audit-only face-two height was corrected to6.25 m; the frozen simulation was unchanged. Compact exports, scripts and evidence accompany this chapter. Three grids show a trend, not a formal convergence proof."
]

work = joinpath(D, "../../../../work/sld/n128/report")
pages = textpages("GABLS1: 128³ resolution study", paragraphs, "n128", work;
                  footer="Breeze LES evaluation | Julia | paired resolution sensitivity")
append!(pages, [joinpath(D, "figures", name * ".pdf") for name in
                ("n128_common_shear", "n128_native_shear", "n128_profiles", "n128_wall_transport")])
run(`pdfunite $pages $(joinpath(D, "results_section.pdf"))`)

md = read(joinpath(D, "results.md"), String)
css = "body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D, "results.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>GABLS1 128-cubed resolution study</title><style>$css</style>" *
      Markdown.html(Markdown.parse(md)))
println("N128_REPORT_COMPLETE pages=", length(pages))
