using JSON, CairoMakie, Markdown, Printf
include("../../report_layout.jl")
using .ReportLayout
const D=@__DIR__
const R=JSON.parsefile(joinpath(D,"physical_response_summary.json"))
paragraphs=[
"First physical comparison | 21 September 2026 | preliminary, diagnostic exclusions apply.",
"Question: can transport confined to one or two near-wall faces improve coarse LES? Four paired GABLS1 runs use WENO9 at 12.5 m resolution (32³ cells), a 400 m cube, the same frozen source, and 9 h of integration.",
"Finding: all three SurfaceLayerDiffusivity variants move the mean u, mean theta and w² profiles farther from the fixed 1 m LES median by RMS error over native levels below 200 m. This result applies to this grid and these settings; it is not a general verdict on the closure.",
"Near-wall response: at 12.5 m, final-hour w² falls by 85–93%. Skewness changes from +0.56 in the control to -0.21, -0.25 and -0.42. Domain-integrated resolved TKE falls by 15–20%. The first-face variance is suppressed much more strongly than the integrated energy.",
"Surface exchange: final-hour u* rises from 0.279 m/s to 0.292, 0.289 and 0.301 m/s, versus a reference mean of 0.262 m/s. Surface cooling also strengthens, moving farther from the reference. One-face 100 and 300 s responses are similar; two-face support increases local suppression.",
"Sensitivity: the preceding hour shows the same direction of near-wall variance, skewness, surface-drag and resolved-energy changes. These are single-seed comparisons, not uncertainty estimates. The LES reference median is not observational truth; w³ has no direct archive reference.",
"Diagnostic exclusion: SGS flux was incorrectly reported as zero because the generic diagnostic omits the implicit contribution. Combined flux, stress-based depth and dependent budgets are withheld. Mean fields, resolved moments/energy and direct wall exchange remain usable. The model does apply implicit transport. Correct transport diagnostics are the next validation step.",
"Reading the figures: native-height profiles are true 8–9 h means; timelines use instantaneous output. Colors, line styles and markers distinguish cases. Exact data, Julia source, reference hashes and diagnostic exclusions accompany this brief; all original DYCOMS/GABLS1 report material is retained."]
pages=textpages("SurfaceLayerDiffusivity: first results",paragraphs,"sld_results",joinpath(D,"../../../work/sld/brief");footer="GABLS1 | Julia analysis | Four completed cases; usable diagnostics only")
append!(pages,[joinpath(D,"figures/sld_physical_response.pdf"),joinpath(D,"figures/sld_exchange_and_skewness.pdf")])
run(`pdfunite $pages $(joinpath(D,"sld_results_section.pdf"))`)
run(`pdfunite $(joinpath(D,"sld_results_section.pdf")) $(joinpath(D,"../surface_layer_story.pdf")) $(joinpath(D,"../surface_layer_results.pdf"))`)
md=read(joinpath(D,"results.md"),String)
css="body{font:17px/1.65 -apple-system,sans-serif;background:#f5f7f8;color:#203340}main{max-width:1200px;margin:30px auto;padding:40px;background:white;border-top:6px solid #0072B2}img{max-width:100%}table{border-collapse:collapse}td,th{padding:10px;border-bottom:1px solid #ddd}h2,h3{color:#173e56}a{color:#0072B2}"
write(joinpath(D,"results.html"),"<!doctype html><meta charset=\"utf-8\"><title>SurfaceLayerDiffusivity results</title><style>$css</style><main>"*Markdown.html(Markdown.parse(md))*"</main>")
println("SLD_BRIEF_COMPLETE ",length(pages)," result pages plus three mechanism pages")
