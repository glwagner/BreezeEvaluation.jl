using Markdown
include("../../../report_layout.jl")
using .ReportLayout

const D = @__DIR__
paragraphs = String[
    "GABLS1 32-cubed to 64-cubed resolution sensitivity | 23 September 2026. Matched nine-hour WENO9 cases use a 400 m cube, seed 123, filtered rough-wall drag, and paired initial perturbations. The gamma=2 scheme-native SLD uses a 300 s filter. Fixed 1 m LES medians are intercomparison references, not observations. Shear below is computed on common 12.5 m physical-height intervals after interpolating both u and v to coarse-grid centers; native shear is shown separately.",
    "During 8-9 h, the 64-cubed one-face SLD shear at 12.5, 25, and 37.5 m is 0.10144, 0.05600, and 0.03951 per second. The two-face values are 0.10348, 0.05945, and 0.03972. The fixed 1 m median is 0.10038, 0.06666, and 0.05607. The second face improves 25 m agreement modestly but does not repair the 37.5 m deficit. Filtered no closure at 64-cubed nearly matches the first reference shear, 0.09953, yet is low at the next two heights. Two grids reveal sensitivity, not established convergence.",
    "Peak resolved w-squared in 8-9 h rises from 0.05588 square meters per second squared for 32-cubed one-face SLD to 0.09688 for 64-cubed one-face and 0.08933 for 64-cubed two-face, near the 64-cubed no-closure value 0.10113. At 18.75 m, interpolated w-cubed changes from +0.000752 to -0.000777 and -0.001543 cubic meters per second cubed respectively. The fixed 1 m archive lacks a w-cubed median; this is not a fidelity ranking. Both time windows appear in the figures.",
    "At the physical face 12.5 m, 32-cubed one-face and 64-cubed two-face have different transport partitions even though support height matches. Mean 64-cubed two-face viscosity is 0.09525 square meters per second, resolved u-w is -0.04946, SGS u-w is -0.00776, and separate WENO correction is -0.01178 square meters per second squared. The corresponding 32-cubed viscosity is 0.52303. One-face at 64-cubed acts at only 6.25 m, so its support height is different. All comparisons retain the same wall law and physical forcing.",
    "Validation: immutable 64-cubed source-manifest SHA-256 19f41d02f5bd249fe32a5edf2d8956e9886b1f58347a98907ec83b1c23d0fbd7. H100 gate 7627 passed CUDA parity and 15/15, 32/32, 38/38 case checks. Science array 7640 tasks 1-3 ended with durable exit zero and CASE_DONE at 32400 s. Independent frozen Julia audits verified source, paired initial state, native 64/65 levels, exact schedules, finite fields, evolving wall filter, density-consistent surface flux, and SLD flux identities. Both SLD cases passed 55 saved local 1/L and similarity records through nine hours. Compact exports and scripts accompany this chapter. A paired 128-cubed extension follows; current SLD supports at most two faces, so it cannot retain 12.5 m support at 128-cubed without additional code."
]

work = joinpath(D, "../../../../work/sld/n64/report")
pages = textpages("GABLS1: 64³ resolution study", paragraphs, "n64", work;
                  footer="Breeze LES evaluation | Julia | paired resolution sensitivity")
append!(pages, [joinpath(D, "figures", name * ".pdf") for name in
                ("n64_common_shear", "n64_native_shear", "n64_profiles", "n64_wall_transport")])
run(`pdfunite $pages $(joinpath(D, "results_section.pdf"))`)

md = read(joinpath(D, "results.md"), String)
css = "body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}"
write(joinpath(D, "results.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>GABLS1 64-cubed resolution study</title><style>$css</style>" *
      Markdown.html(Markdown.parse(md)))
println("N64_REPORT_COMPLETE pages=", length(pages))
