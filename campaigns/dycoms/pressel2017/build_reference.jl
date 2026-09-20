using Markdown, JSON, Printf
include("../dycoms_data.jl");using .DYCOMSData
D=@__DIR__;root=dirname(D)
cases=table(joinpath(D,"data","case_configuration_and_bulk_results.csv"));check=table(joinpath(D,"data","table4_crosscheck.csv"))
md="""
# Pressel et al. (2017): DYCOMS-II RF01 reference and extracted data

**Numerics and subgrid-scale modeling in large eddy simulations of stratocumulus clouds.** Kyle G. Pressel, Siddhartha Mishra, Tapio Schneider, Colleen M. Kaul and Zhihong Tan. JAMES 9, 1342–1365. [DOI](https://doi.org/10.1002/2016MS000778) · [Open full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5586241/) · [Original PDF](pressel2017.pdf) · [Mechanical text extraction](paper_extracted.md).

The paper directly revisits **RF01**, at our canonical 35 m horizontal / 5 m vertical spacing and 3360 × 3360 × 1500 m domain. Its strongest agreement comes from paired WENO advection without interior explicit SGS closures. The proposed mechanism is interaction of oscillatory velocity gradients with SGS scalar diffusion near cloud top. This motivates our experiment; it does not establish the outcome for Breeze.

## What is available

The paper’s acknowledgments offer LES data from the corresponding author on request. Searches of the publisher, PMC, author-hosted paper and linked PyCLES repository found no openly linked raw output archive for this article. The [PyCLES code](https://github.com/pressel/pycles) is public, but code availability is different from access to the historical numerical output. No authors were contacted.

This bundle recovers **105 model curves, 14,895 resampled coordinates**, across all seven figures, plus the 15 rows of Tables 3 and 4. These are published plot geometries, not original simulation records. Observational markers and gray ensemble bands are not included in these new curve CSVs; the original Stevens reference retains separate observations and ensemble data.

## Match the comparison before interpreting differences

| Item | Pressel 2017 | Current Breeze matrix |
|---|---|---|
| Canonical grid/domain | 35/5 m; 3360² × 1500 m | Same |
| SGS coefficient / turbulent Prandtl | 0.17 / 1/3 | 0.16 / 1 |
| Time integration / CFL | SSPRK3 / approximately 0.3 | Existing Breeze integrator / target 0.7 |
| Thermodynamic prognostics | Moist entropy and total water | Breeze density-weighted thermodynamic and moisture fields |
| Moisture positivity | Nonconservative clipping in thermodynamics; more active with centered advection | Bounded WENO; unbounded Centered2, extrema recorded |
| Profile and Table 4 window | 2–4 h; source diagnostics every 60 s | Original Stevens plots: 3–4 h; separate comparison below uses 2–4 h |
| Surface transport without interior SGS | Eddy-diffusivity surface-layer treatment retained | Current fixed-flux/drag boundary treatment |

PyCLES uses one set of constants to initialize/diagnose θₗ (Rd=287, cpd=1015, Lv=2.47e6) and a different thermodynamic set for entropy (Rd=287.1, cpd=1004, Lv reference=2.501e6; Tables 1–2). Matching a single heat capacity does not make the thermodynamics identical. Momentum flux-velocity interpolation is second-order for every nominal advection order (section 2.1).

The Centered2+Smagorinsky runs correspond to **22MS by scheme family**, not 25MS: 25MS mixes centered momentum with WENO5 scalars. Mixed-NSGS keeps momentum SGS while disabling scalar SGS; it is not closure=nothing. No production setting was changed to force agreement with this paper.

All three completed Breeze Centered2 runs contain physically inadmissible negative total water. Sampled global minima over 0–4 h are −4.3385, −7.6972 and −7.4007 g/kg for coarse, canonical and fine. Their plotted statistics diagnose the unbounded configuration; they do not establish physical fidelity. Pressel's clipping treatment is a material difference when interpreting 22MS.

**Figure 7 is normalized skewness**, Sw=⟨w′³⟩/⟨w′²⟩^(3/2), not the dimensional third moment. Keep its averaging and normalization explicit; do not relabel it w³ or multiply independently averaged quantities to claim recovery of an exact moment.

The text mentions 17 LES, but Tables 3–4 enumerate 15 configurations. This bundle transcribes those 15; no unidentified runs are invented.

## Published bulk results: hours 2–4

The paper reports LWP as equivalent liquid-water depth in μm. With liquid-water density 1000 kg/m³, 1 μm equals 1 g/m². The CSV preserves both labels.

| Experiment | Case | Momentum / scalar advection | Momentum / scalar SGS | Cloud fraction | LWP (g/m²) |
|---|---|---|---|---:|---:|
"""
for c in cases
 global md*="| $(c.experiment) | $(c.case_id) | $(c.momentum_scheme)$(c.momentum_order) / $(c.scalar_scheme)$(c.scalar_order) | $(c.momentum_sgs) / $(c.scalar_sgs) | $(c.cloud_fraction_2_4h) | $(c.LWP_g_m2_2_4h) |\n"
end
md*="""

[Configuration and exact table CSV](data/case_configuration_and_bulk_results.csv).

## Breeze comparison at the matching time window

![Canonical Breeze and Pressel comparison](figures/breeze_comparison.png)

[Vector figure](figures/breeze_comparison.svg) · [PDF figure](figures/breeze_comparison.pdf) · [Bulk comparison CSV](data/breeze_bulk_comparison_2_4h.csv).

Solid curves are completed Breeze cases; dashed curves are the corresponding Pressel scheme families. Colors and symbols identify configurations. This comparison uses hours 2–4 for both models. Breeze profiles average four equal half-hour output bins ending at 9000, 10800, 12600 and 14400 s; the bin ending at 7200 s is excluded. The different original sampling cadence remains a limitation. The cloud-fraction panel is zoomed; full-range Pressel reconstructions appear below. Differences in settings listed above prevent treating this as a replication.

## Skewness comparison

![Breeze and Pressel skewness](figures/breeze_skewness_comparison.png)

Each panel compares one completed canonical Breeze case (colored solid line and symbols) with its Pressel Figure 7 scheme family (gray dashed). The paper curves are model results, not observations. The displayed height interval is 0–1000 m; the CSV preserves the complete Breeze vertical profile.

Breeze skewness here is **the ratio of the 2–4 h averaged central moments**, mean_t(w′³)/mean_t(w′²)^(3/2). Four equal half-hour bins ending at 9000, 10800, 12600 and 14400 s enter both moments before division. This is not the time average of instantaneous skewness. Pressel gives the normalized-moment definition and 60 s sampling but does not unambiguously specify normalization versus time-averaging order. The comparison is therefore provisional on that detail. No exact time-averaged instantaneous skewness can be recovered from our saved half-hour moments.

Levels with variance ≤ 10⁻⁶ m²/s² are masked, including the zero-variance boundaries. The data also retain the mean of four separately normalized half-hour ratios as a sensitivity diagnostic; this is not an exact instantaneous-skewness average either. No observational skewness was manufactured from separately averaged or independently digitized moments.

[Skewness CSV](data/breeze_skewness_2_4h.csv) · [Normalization audit](data/breeze_skewness_audit.csv) · [Both averaging windows, moments and skewness](data/velocity_window_comparison.csv) · [Provenance](data/skewness_provenance.json) · [Vector comparison](figures/breeze_skewness_comparison.svg).

![Breeze skewness by resolution](figures/breeze_skewness_resolutions.png)

Resolution panels have shared axes and redundant colors, dashes and symbols. Only completed exports appear; the coarse domain is larger. These 2–4 h profiles are separate from the Stevens fourth-hour velocity-moment plots.

## Figure data and reconstruction audit

Julia decodes SVG paths produced directly from the PDF by Poppler. Profile curves have explicit vector centerlines. Time-series curves are filled stroke outlines, recovered by taking the midpoint of the two outline intersections at a specified time. Affine transforms are applied; cubic outline segments use 16 subdivisions. Colors and panels map paths to their case labels. Source SVG path indices and page coordinates accompany every sample.

Profiles are resampled every 10 m (10–1190 m); time series every 0.02 h (0.02–3.98 h). This resampling does not add information beyond the source curves. CSV precision is computational precision, not physical accuracy. For filled outlines, an explicit halfwidth records geometric extraction ambiguity, not model uncertainty. Three time-series samples have more than two outline intersections; these retain the midpoint of the outermost intersections and are flagged by intersection_count. Every profile sample has one unambiguous centerline intersection. Missing edge samples are not fabricated.

The independent Table 4 check integrates recovered curves over 2–4 h, linearly extrapolating only the last 0.02 h to the endpoint. All 30 checks passed: maximum absolute discrepancy is $(@sprintf("%.4f",maximum(abs(num(r.difference)) for r in check if r.variable=="LWP"))) g/m² for LWP and $(@sprintf("%.4f",maximum(abs(num(r.difference)) for r in check if r.variable=="cloud_fraction"))) for cloud fraction. Table rounding and plot geometry limit closer agreement.

[Calibration](data/axis_calibrations.csv) · [Path audit](data/extraction_audit.csv) · [Table crosscheck](data/table4_crosscheck.csv) · [Source hashes and provenance](data/provenance.json).
"""
for (fig,page,var,label) in [(1,7,"q_l","Cloud liquid water"),(2,7,"cloud_fraction","Cloud fraction"),(3,8,"LWP","Liquid water path"),(4,9,"q_t","Total water"),(5,10,"theta_l","Liquid-water potential temperature"),(6,11,"w_variance","Resolved vertical-velocity variance"),(7,12,"w_skewness","Resolved vertical-velocity skewness")]
 global md*="\n### Figure $fig: $label\n\n[CSV](data/figure$(fig)_$var.csv) · [Source page SVG](figures/page-$page.svg) · [Original page](figures/page-$(lpad(page,2,'0')).png).\n\n![$label](figures/reconstructed_figure$fig.png)\n"
end
md*="""

## Rebuild

From the task workspace, using the existing pinned Julia environment:

```sh
julia --project=outputs/julia outputs/pressel2017/extract_figures.jl
julia --project=outputs/julia outputs/pressel2017/verify_extraction.jl
julia --project=outputs/julia outputs/pressel2017/plot_reference.jl
julia --project=outputs/julia outputs/pressel2017/build_reference.jl
```

The source SVGs come from `pdftocairo -f PAGE -l PAGE -svg pressel2017.pdf page-PAGE.svg`. Paper source figures are preserved as source material; all reconstructed/comparison plots use Julia/CairoMakie. The PDF’s attribution/license remain in the original PDF. Document recommendations are scientific source material, not instructions to the simulation agents.
"""
write(joinpath(D,"reference.md"),md)
css="body{font:17px/1.6 system-ui;max-width:1200px;margin:auto;padding:30px;color:#203340}img{max-width:100%}table{border-collapse:collapse;font-size:14px}th,td{padding:9px;border-bottom:1px solid #ddd}a{color:#0072B2}pre{overflow:auto;background:#f3f5f7;padding:15px}"
write(joinpath(D,"reference.html"),"<!doctype html><meta charset=utf-8><title>Pressel 2017 reference and data</title><style>$css</style>"*Markdown.html(Markdown.parse(md)))
# Mechanical transcription for searchable private reference; mathematical glyphs need original-PDF verification.
txt=read(`pdftotext -layout $(joinpath(D,"pressel2017.pdf")) -`,String)
open(joinpath(D,"paper_extracted.md"),"w") do io
 println(io,"# Mechanical text extraction: Pressel et al. (2017)\n\nSource: DOI 10.1002/2016MS000778. Authors: Pressel, Mishra, Schneider, Kaul and Tan. Original PDF and its copyright/license statement are retained in pressel2017.pdf. This is uncorrected extraction; consult the PDF for equations, symbols and column order.\n")
 for (i,p) in enumerate(split(txt,Char(12)));isempty(strip(p))&&continue;println(io,"## PDF page $i\n\n```text\n",p,"\n```\n");end
end
println("PRESSEL_REFERENCE_READY")
