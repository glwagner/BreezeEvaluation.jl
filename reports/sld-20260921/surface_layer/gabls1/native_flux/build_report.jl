using Markdown
include("../../../report_layout.jl")
using .ReportLayout
const D=@__DIR__
md=read(joinpath(D,"results.md"),String)
paragraphs=String[
    "GABLS1 scheme-native WENO transport | 22 September 2026. Matched 12.5 m, 32³, 400 m, WENO9, one face, 300 s filter, factor one, seed 123, nine-hour LES. The old admitted factor-one covariance run is the control.",
    "At the first interior face, the measured 8–9 h WENO numerical correction to u-momentum flux is -0.000228 m²/s², versus covariance -0.007749 m²/s² (2.95%). The heat correction is 1.4e-10 K m/s, effectively zero versus covariance -0.001472 K m/s. The saved covariance plus correction equals reconstructed flux at both diagnostic faces for momentum and scalars. These measured corrections are far below the assumed extra flux behind factors two and three in this case.",
    "Mean 8–9 h first-face momentum viscosity falls 1.3214 to 1.2958 m²/s (-1.9%); heat diffusivity rises 1.2160 to 1.2642 m²/s (+4.0%). Integrated resolved TKE rises 3.8%, peak w² rises 3.1%, diagnosed boundary-layer height falls 7.4 m. One evolving realization cannot distinguish a systematic response from trajectory divergence. The profiles remain near the covariance control and show substantial coarse-run departures from the fixed 1 m LES median in resolved turbulence.",
    "Source and data audit: immutable Breeze/Evaluation manifest SHA-256 72f1bc03 and 792 source-file hashes passed; paired initial-theta SHA-256 1f5db33f matched. H100 gate 7496 passed; science 7497 had durable exit zero and CASE_DONE at 32400 s. Raw output passed exact 1/19/541 initial/profile/series schedules, finite values, native 32/33-level heights, and flux decomposition on both faces. Figures use Julia. The reference is an LES median, not observations. Historical factor and control outputs were not rerun."
]
work=joinpath(D,"../../../../work/sld/native-flux/report")
pages=textpages("GABLS1: measured scheme-native WENO flux",paragraphs,"native_flux",work;footer="Breeze LES evaluation | Julia | matched factor-one comparison")
append!(pages,[joinpath(D,"figures",n*".pdf") for n in ("native_profiles","native_activity","native_partition")])
run(`pdfunite $pages $(joinpath(D,"results_section.pdf"))`)
html="<!doctype html><meta charset=\"utf-8\"><title>GABLS1 scheme-native transport</title><style>body{font:18px/1.6 sans-serif;max-width:1250px;margin:40px auto;padding:0 20px}img{max-width:100%}td,th{padding:8px;text-align:left}table{border-collapse:collapse}</style>"*Markdown.html(Markdown.parse(md))
write(joinpath(D,"results.html"),html)
println("NATIVE_FLUX_REPORT_COMPLETE pages=",length(pages))
