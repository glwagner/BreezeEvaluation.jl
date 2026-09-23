using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D = @__DIR__
paragraphs = String[
    "GABLS1 stability-corrected surface-layer diffusivity | 23 September 2026. A matched nine-hour 32-cubed, 12.5 m, WENO9 run changes only the interior SLD stable-similarity strength from lambda=0 to lambda=1. Both use one-face scheme-native flux, 300 s wall and SLD filters, a 400 m cube, and seed 123. The fixed 1 m LES median is an intercomparison reference, not observations or a tuning target.",
    "The correction raises 8-9 h first-layer vector shear from 0.05302 to 0.07387 per second. The fixed 1 m median sampled at the same two cell-center heights is 0.10038 per second. About 44 percent of the neutral SLD shortfall is closed, but the corrected profile still has too little near-wall shear. The 7-8 h shear moves similarly, from 0.05184 to 0.07162 per second.",
    "At the first interior face, mean local stable gradient functions over 8-9 h are phi-m=1.437 and phi-h=1.710; every saved column is on the stable branch. The evolved SLD viscosity falls from 1.2892 to 0.8239 square meters per second, and heat diffusivity from 1.2396 to 0.6045. Mean friction velocity changes modestly, from 0.29485 to 0.28907 meters per second, as does kinematic heat flux, from -0.012333 to -0.011838 kelvin meters per second.",
    "Peak resolved w-squared increases only from 0.06276 to 0.06676 square meters per second squared, below the filtered no-closure value of 0.10125. At 18.75 m, w-cubed changes from -0.000295 to +0.000102 cubic meters per second cubed, versus +0.0163 without closure. The stable correction improves mean shear but does not recover strong near-surface turbulent asymmetry. One seed at one resolution establishes a matched sensitivity, not an optimal universal parameter.",
    "Transport is separated into resolved covariance, the measured WENO numerical correction, and the SLD constitutive flux. At 8-9 h, first-face resolved u-w becomes more negative (-0.00991 to -0.01461), while SLD u-w becomes less negative (-0.05866 to -0.05222) in square meters per second squared. The numerical correction is small compared with the change in the SLD transport.",
    "Validation: H100 gate 7580 passed CUDA parity 34/34 and the 1,800 s GABLS1 check 48/48. Science 7581 ended with durable exit zero and CASE_DONE at 32,400 s. Independent Julia audits verified the immutable source manifest, paired initial theta digest, exact schedules, 46 native-height profiles and 135 series, finite data, wall flux density consistency, local inverse Obukhov length and phi identities, and scheme-native transport accounting. No upward-flux fallback occurred after one hour. The source freeze omits .git; its verified SHA-256 manifest and recorded commits provide provenance."
]

work = joinpath(D, "../../../../work/sld/stability/report")
pages = textpages("GABLS1: stable SLD correction", paragraphs, "stability", work;
                  footer="Breeze LES evaluation | Julia | matched stability sensitivity")
append!(pages, [joinpath(D, "figures", name * ".pdf") for name in
                ("stability_shear_flux", "stability_profiles", "stability_partition",
                 "stability_coefficients")])
run(`pdfunite $pages $(joinpath(D, "results_section.pdf"))`)

md = read(joinpath(D, "results.md"), String)
css = "body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D, "results.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>GABLS1 stable SLD</title><style>$css</style>" *
      Markdown.html(Markdown.parse(md)))
println("STABILITY_REPORT_COMPLETE pages=", length(pages))
