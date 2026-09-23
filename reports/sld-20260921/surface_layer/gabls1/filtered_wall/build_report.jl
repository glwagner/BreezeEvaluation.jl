using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D=@__DIR__
paragraphs=String[
    "GABLS1 filtered rough-wall drag | 23 September 2026. Two new 32³, 12.5 m, WENO9 cases use a 300 s temporally filtered wall state, matched against earlier unfiltered no-closure and scheme-native one-face SLD controls. All use a 400 m cube, seed 123, and nine hours of the same cooling and geostrophic forcing. The fixed 1 m LES median is a model intercomparison reference, not observations.",
    "Filtering improves no-closure near-wall shear but leaves the SLD deficit almost unchanged. In 8–9 h, mean-wind vector shear across 6.25–18.75 m falls from 0.1861 to 0.1541 s^-1 without an interior closure, versus 0.1004 s^-1 for the fixed 1 m median profiles. With scheme-native SLD it changes only from 0.0522 to 0.0530 s^-1. The same ordering appears during 7–8 h. These are adjacent-cell-center gradients, not wall gradients; reference u and v medians were sampled at those heights before differentiation.",
    "In the no-closure pair, filtered wall drag raises final-hour mean u* from 0.2794 to 0.3019 m/s, makes mean kinematic surface heat flux more negative (-0.01146 to -0.01314 K m/s), and raises peak resolved w2 from 0.0864 to 0.1013 m2/s2. For SLD, u* rises from 0.2901 to 0.2949 m/s and peak w2 from 0.05945 to 0.06276 m2/s2. Both SLD cases continue to suppress resolved near-wall w2 and w3 relative to no closure. A single turbulent realization cannot establish a systematic effect beyond this matched sensitivity test.",
    "Filtering barely changes SLD's first-face mean momentum viscosity (1.2958 to 1.2892 m2/s) or heat diffusivity (1.2642 to 1.2396 m2/s). Filtered SLD's measured WENO u-flux correction is -0.000256 m2/s2 versus covariance -0.009609 m2/s2, about 2.7%; its heat correction is approximately zero. The small numerical correction does not explain the persistent SLD shear deficit.",
    "Validation: corrected H100 gate 7536 passed 19/19 no-closure and 21/21 SLD checks. Both science-array 7537 tasks ended with durable exit zero and CASE_DONE at 32400 s. Immutable source hash manifest 61a5a464b9d100ff2f302ad822972af9ee47e9340a25bbae0ff597890911367e was rechecked; initial theta digest matched across cases. Independent Julia raw audits verified exact 1/19/541/55 initial/profile/series/filter schedules, native 32/33 vertical levels, finite output, evolving filtered state, density-consistent wall fluxes, and both time windows. Both-face reconstructed flux identities passed for SLD. The failed first gate 7534 launched no science and remains historical evidence."
]
work=joinpath(D,"../../../../work/sld/filtered-wall/report")
pages=textpages("GABLS1: filtered wall drag",paragraphs,"filtered_wall",work;
                footer="Breeze LES evaluation | Julia | matched filtered-wall sensitivity")
append!(pages,[joinpath(D,"figures",n*".pdf") for n in
               ("filtered_profiles","filtered_shear_flux","filtered_partition","filtered_state")])
run(`pdfunite $pages $(joinpath(D,"results_section.pdf"))`)
md=read(joinpath(D,"results.md"),String)
css="body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D,"results.html"),"<!doctype html><meta charset=\"utf-8\"><title>GABLS1 filtered wall</title><style>$css</style>"*Markdown.html(Markdown.parse(md)))
println("FILTERED_WALL_REPORT_COMPLETE pages=",length(pages))
