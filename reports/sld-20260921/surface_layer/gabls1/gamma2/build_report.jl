using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D = @__DIR__
paragraphs = String[
    "GABLS1 stable surface-layer diffusivity, gamma=2 | 23 September 2026. This matched nine-hour 32-cubed, 12.5 m WENO9 case changes only interior SLD stability strength. The same 400 m domain, seed 123, filtered wall, one-face support, 300 s filters, and scheme-native factor-one flux apply to gamma=0, 1, 2, and 4. The fixed 1 m LES median is an intercomparison reference, not observations.",
    "The 8-9 h vector shear at 12.5, 25, and 37.5 m is 0.09152, 0.06140, and 0.05235 per second at gamma=2, versus 0.10038, 0.06666, and 0.05607 in the median profile. These values decrease with height and remove the pronounced 25 m dip of gamma=4, whose first three shears are 0.12911, 0.03456, and 0.04001. Gamma=1 gives 0.07387, 0.07235, and 0.05350. Gamma=2 first-layer shear changed only from 0.08910 in 7-8 h to 0.09152 in 8-9 h.",
    "Shear improvement does not imply improvement in all statistics. Peak resolved w-squared is 0.05588 square meters per second squared at gamma=2 in 8-9 h, below gamma=1 at 0.06676, gamma=4 at 0.08575, and filtered no closure at 0.10125. At 18.75 m, w-cubed is +0.000937 cubic meters per second cubed, versus +0.005932 for gamma=4 and +0.01629 with no closure. The gamma=2 surface friction velocity is 0.27977 meters per second and heat flux is -0.010968 kelvin meters per second.",
    "At the first interior face, gamma=2 mean local phi-m=1.8930 and phi-h=2.4512 during 8-9 h; all saved columns stay stable and no upward-flux fallback occurs. Evolved momentum viscosity is 0.52303 square meters per second, between gamma=1 at 0.82387 and gamma=4 at 0.24517. Resolved u-w is -0.021102 and SLD u-w is -0.040393 square meters per second squared. The measured WENO numerical correction is -0.00069141 and is kept separate from covariance.",
    "Validation: CPU smoke 7595 passed 48/48; H100 gate 7596 passed CUDA parity 34/34 and its 1800 s case 48/48. Science 7615_1 ended with durable exit zero and CASE_DONE at 32400 s. Independent Julia audits verified frozen source, paired initial-theta digest, exact schedules, 46 native-height profiles, 135 series, finite fields, filter evolution, density-consistent surface flux and scheme-native transport. Local inverse Obukhov length and similarity identities passed at 55 saved times. One seed and one coarse grid do not establish universal calibration; a paired 64-cubed study follows."
]

work = joinpath(D, "../../../../work/sld/gamma2/report")
pages = textpages("GABLS1: SLD gamma=2", paragraphs, "gamma2", work;
                  footer="Breeze LES evaluation | Julia | matched stability sensitivity")
append!(pages, [joinpath(D, "figures", name * ".pdf") for name in
                ("stability_shear_flux", "stability_profiles", "stability_partition",
                 "stability_coefficients")])
run(`pdfunite $pages $(joinpath(D, "results_section.pdf"))`)

md = read(joinpath(D, "results.md"), String)
css = "body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D, "results.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>GABLS1 SLD gamma=2</title><style>$css</style>" *
      Markdown.html(Markdown.parse(md)))
println("GAMMA2_REPORT_COMPLETE pages=", length(pages))
