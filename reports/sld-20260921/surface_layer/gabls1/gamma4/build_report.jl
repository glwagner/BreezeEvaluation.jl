using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D = @__DIR__
paragraphs = String[
    "GABLS1 stable surface-layer diffusivity, gamma=4 | 23 September 2026. A matched nine-hour, 32-cubed, 12.5 m WENO9 case changes only the interior SLD stable-similarity strength from gamma=1 to gamma=4. Neutral gamma=0 and filtered no-closure are admitted controls. The fixed 1 m LES median is an intercomparison reference, not observations.",
    "During 8-9 h, first-layer vector shear is 0.12911 per second at gamma=4, versus 0.05302 at gamma=0, 0.07387 at gamma=1 and 0.10038 for the reference sampled at the same heights. Gamma=4 overshoots the reference by 0.02873 per second; gamma=1 undershoots by 0.02651. The two strengths bracket the median, with nearly equal absolute shear errors. The 7-8 h gamma=4 shear is 0.11921 per second.",
    "Peak resolved w-squared during 8-9 h is 0.08575 square meters per second squared, up from 0.06276 for gamma=0 and 0.06676 for gamma=1. At 18.75 m, w-cubed is +0.005932 cubic meters per second cubed, versus -0.000295 and +0.000102. These moments are closer to the reference profile, while the overshot mean shear limits the overall improvement. Gamma=4 w-squared and w-cubed rose between 7-8 and 8-9 h, so statistical equilibration remains uncertain.",
    "At the first interior face, mean gamma=4 local similarity functions over 8-9 h are phi-m=2.7169 and phi-h=3.7900. Every saved column is on the stable branch, with no upward-flux fallback. The evolved viscosity is 0.24517 square meters per second, versus 1.2892 at gamma=0 and 0.82387 at gamma=1. Heat diffusivity is 0.088672 versus 1.2396 and 0.60453. The wall law and filters are unchanged.",
    "Reduced closure changes the transport partition: first-face resolved u-w is -0.045186 and SGS u-w is -0.027868 square meters per second squared at gamma=4, compared with -0.014608 and -0.052218 at gamma=1. Resolved w-theta becomes -0.010566 and SGS w-theta -0.001608 kelvin meters per second. The measured WENO u-flux correction is -0.001743, tracked separately from covariance.",
    "Validation: CPU smoke 7583 passed 48/48; H100 gate 7584 passed CUDA parity 34/34 and the 1800 s case 48/48. Science 7585 ended with durable exit zero and CASE_DONE at 32400 s. Independent Julia audits verified the immutable source manifest, paired initial-theta digest, 46 native-height profiles, 135 series, finite values, exact schedules, filter evolution, density-consistent wall flux, local inverse Obukhov length and similarity identities at 55 times, and reconstructed transport accounting. The result is one seed at one coarse resolution, not a universal parameter calibration."
]

work = joinpath(D, "../../../../work/sld/gamma4/report")
pages = textpages("GABLS1: SLD gamma=4", paragraphs, "gamma4", work;
                  footer="Breeze LES evaluation | Julia | matched stability sensitivity")
append!(pages, [joinpath(D, "figures", name * ".pdf") for name in
                ("stability_shear_flux", "stability_profiles", "stability_partition",
                 "stability_coefficients")])
run(`pdfunite $pages $(joinpath(D, "results_section.pdf"))`)

md = read(joinpath(D, "results.md"), String)
css = "body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D, "results.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>GABLS1 SLD gamma=4</title><style>$css</style>" *
      Markdown.html(Markdown.parse(md)))
println("GAMMA4_REPORT_COMPLETE pages=", length(pages))
