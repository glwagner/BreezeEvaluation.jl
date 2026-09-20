#!/usr/bin/env julia
using CairoMakie, JSON, Markdown, Dates, Printf
include("dycoms_data.jl")
using .DYCOMSData
const WORK=joinpath(dirname(ROOT),"work","julia-report")
mkpath(WORK)
const status=JSON.parsefile(joinpath(ROOT,"cluster","run_status.json"))
const rows=table(joinpath(ROOT,"simulation_data","fourth_hour_metrics.csv"))
const n=length(rows)
const title="Breeze DYCOMS-II RF01: resolution and numerics"
const total=length(JSON.parsefile(joinpath(ROOT,"experiment_matrix.json"))["cases"])
const state=n==total ? "Complete: $total cases analyzed" : "Preliminary: $n of $total cases analyzed"
const stamp=status["checked_utc"]
# Keep the checked scientific methods as Markdown source, independent of the renderer.
methodfile=joinpath(ROOT,"report_methods.md")
if !isfile(methodfile)
    previous=read(joinpath(ROOT,"dycoms_report.md"),String)
    found=match(r"## Experiment and interpretation\n(.*?)\n## Run state"s,previous)
    found===nothing && error("Checked scientific methods missing")
    write(methodfile,strip(found[1])*"\n")
end
const methods=read(methodfile,String)
name(r)=uppercasefirst(r.grid)*" / "*r.advection_scheme*r.advection_order*" / "*(r.closure=="none" ? "no SGS" : "Smagorinsky")
f(x,d=2)=@sprintf("%.*f",d,num(x))
findings=String[]
negative_centered=filter(r->r.advection_scheme=="Centered" && num(r.q_t_min_kg_kg)<0,rows)
if !isempty(negative_centered)
    badmoisture=join([r.grid*": "*f(1000num(r.q_t_min_kg_kg),3)*" g/kg" for r in negative_centered],"; ")
    push!(findings,"Completed Centered2 runs contain physically inadmissible negative total water (sampled minima: $badmoisture). Their cloud and turbulence statistics are retained as diagnostics of this unbounded numerical configuration, not evidence of a physically faithful solution. The production extrema figure shows the full sampled time history; verification here means complete finite output, not physical validity.")
end
smokeaudit=[]
smokelog=joinpath(ROOT,"cluster","centered2","c2-smoke-7073.log")
if isfile(smokelog)
    smoketext=read(smokelog,String)
    for m in eachmatch(r"SMOKE_AUDIT grid=(\w+)\s+records=\s*(\d+) t=\[0\.\.600\] q_t_min=([\deE+.\-]+) q_t_max=([\deE+.\-]+) finite=(true|false) negative=(true|false)",smoketext)
        push!(smokeaudit,(grid=m[1],sample_count=parse(Int,m[2]),window_start_s=0,window_end_s=600,
              q_t_min_kg_kg=parse(Float64,m[3]),q_t_max_kg_kg=parse(Float64,m[4]),all_finite=m[5]=="true",negative=m[6]=="true",source="c2-smoke-7073.log; rounded audit values"))
    end
    @assert length(smokeaudit)==3 && all(r->r.sample_count==11 && r.all_finite,smokeaudit) && occursin("SMOKE_AUDIT_PASSED",smoketext)
    writecsv(joinpath(ROOT,"cluster","centered2","smoke_audit.csv"),smokeaudit)
    smokemintext=join([r.grid*": "*f(1000r.q_t_min_kg_kg,4)*" g/kg" for r in smokeaudit],"; ")
    push!(findings,"Centered2 smoke audit: all three grids stayed finite over the first 600 simulated seconds, but canonical and fine cases produced negative total water. Across the 11 one-minute samples, minimum qₜ was $smokemintext. Passing the finite-value gate establishes neither moisture positivity nor physical validity. Production retains unbounded centered moisture; full-run extrema are reported separately in the production audit. These are smoke-test results, not completed four-hour Centered2 statistics.")
end
costrows=[(case_id=c["case_id"],grid=c["grid"],advection_scheme=c["advection_scheme"],advection_order=c["advection_order"],closure=c["closure"],solver_wall_s=c["solver_wall_s"],iterations=c["iterations"],wall_s_per_iteration=c["solver_wall_s"]/c["iterations"]) for c in status["cases"] if c["state"]=="COMPLETED" && haskey(c,"solver_wall_s") && any(r->r.case_id==c["case_id"],rows)]
@assert all(c->c.solver_wall_s>0 && c.iterations>0,costrows)
writecsv(joinpath(ROOT,"simulation_data","solver_costs.csv"),costrows)
fine5=findfirst(r->r.grid=="fine" && r.closure=="none" && r.weno=="5",rows)
fine9=findfirst(r->r.grid=="fine" && r.closure=="none" && r.weno=="9",rows)
fine9sgs=findfirst(r->r.grid=="fine" && r.closure=="smagorinsky" && r.weno=="9",rows)
if fine9!==nothing && fine9sgs!==nothing
    let base=rows[fine9], smag=rows[fine9sgs]
        cb=only(filter(c->c.case_id==base.case_id,costrows));cs=only(filter(c->c.case_id==smag.case_id,costrows))
        push!(findings,"At 10 m horizontal / 5 m vertical spacing with WENO9, adding Smagorinsky changes fourth-hour minimum w′³ over 600–760 m from $(f(base.min_hour4_w3_600_760_m3_s3,4)) to $(f(smag.min_hour4_w3_600_760_m3_s3,4)) m³/s³, third-moment marker RMSE from $(f(base.w3_insitu_marker_RMSE,4)) to $(f(smag.w3_insitu_marker_RMSE,4)) m³/s³, and variance-marker RMSE from $(f(base.w2_insitu_marker_RMSE,4)) to $(f(smag.w2_insitu_marker_RMSE,4)) m²/s². LWP changes from $(f(base.LWP_g_m2)) to $(f(smag.LWP_g_m2)) g/m². Solver wall increases by $(f(100*(cs.solver_wall_s/cb.solver_wall_s-1),1))%. This closure weakens the negative third moment and increases both marker errors in this paired single-realization comparison; it is not evidence against every possible closure or coefficient choice.")
    end
end
if fine5!==nothing && fine9!==nothing
    let low=rows[fine5], high=rows[fine9]
        c5=only(filter(c->c.case_id==low.case_id,costrows));c9=only(filter(c->c.case_id==high.case_id,costrows))
        push!(findings,"At 10 m horizontal / 5 m vertical resolution without SGS, WENO5 uses $(f(c5.solver_wall_s/60,1)) solver wall minutes versus $(f(c9.solver_wall_s/60,1)) for WENO9 ($(f(100*(1-c5.solver_wall_s/c9.solver_wall_s),1))% less). However, its fourth-hour third-moment RMSE against digitized in-situ markers is $(f(low.w3_insitu_marker_RMSE,4)) rather than $(f(high.w3_insitu_marker_RMSE,4)) m³/s³. Its minimum w′³ in 600–760 m is $(f(low.min_hour4_w3_600_760_m3_s3,4)) versus $(f(high.min_hour4_w3_600_760_m3_s3,4)) m³/s³. Lower advection order saves wall time but weakens the negative third moment in this realization. Timings include output within the solve and exclude startup/compilation before the solve; they are not isolated kernel benchmarks.")
    end
end
finecenter=findfirst(r->r.grid=="fine" && r.advection_scheme=="Centered",rows)
if finecenter!==nothing && fine9sgs!==nothing
    let centered=rows[finecenter], weno=rows[fine9sgs]
        cc=only(filter(c->c.case_id==centered.case_id,costrows));cw=only(filter(c->c.case_id==weno.case_id,costrows))
        push!(findings,"Fine Centered2 with Smagorinsky completes in $(f(cc.solver_wall_s/60,1)) solver wall minutes, $(f(100*(1-cc.solver_wall_s/cw.solver_wall_s),1))% less than fine WENO9 with Smagorinsky. Its fourth-hour LWP is $(f(centered.LWP_g_m2)) versus $(f(weno.LWP_g_m2)) g/m², and third-moment marker RMSE is $(f(centered.w3_insitu_marker_RMSE,4)) versus $(f(weno.w3_insitu_marker_RMSE,4)) m³/s³. Negative total water prevents interpreting this cheaper run as an acceptable physical solution. Timing includes diagnostics and differing timestep counts; no GPU profiling was performed to identify the cost mechanism.")
    end
end
canonical9=findfirst(r->r.grid=="canonical" && r.closure=="none" && r.weno=="9",rows)
if fine9!==nothing && canonical9!==nothing
    let a=rows[fine9], b=rows[canonical9]
    signnote=num(a.max_hour4_w3_600_760_m3_s3)<0 ? "The fine case is negative throughout 600–760 m, agreeing with the sign of the retained in-situ observations there." : "The fine case does not remain negative throughout 600–760 m."
    push!(findings,"At fixed 5 m vertical spacing and fixed horizontal domain, changing WENO9/no-SGS from 35 m to 10 m horizontal spacing changes the fourth-hour minimum w′³ over 600–760 m from $(f(b.min_hour4_w3_600_760_m3_s3,4)) to $(f(a.min_hour4_w3_600_760_m3_s3,4)) m³/s³. $signnote")
    push!(findings,"For this same 35 m to 10 m comparison, unweighted RMSE against the digitized in-situ third-moment markers changes from $(f(b.w3_insitu_marker_RMSE,4)) to $(f(a.w3_insitu_marker_RMSE,4)) m³/s³; variance-marker RMSE changes from $(f(b.w2_insitu_marker_RMSE,4)) to $(f(a.w2_insitu_marker_RMSE,4)) m²/s². The third moment improves substantially, while variance does not improve by this metric. These are single realizations without observational error-bar weighting, not a convergence demonstration.")
end
end
coarse=filter(r->r.grid=="coarse" && r.advection_scheme=="WENO",rows)
if !isempty(coarse) && all(r->num(r.min_hour4_w3_600_760_m3_s3)>0,coarse)
    push!(findings,"All $(length(coarse)) completed coarse WENO cases have positive fourth-hour w′³ throughout 600–760 m, while the retained in-situ observations there are negative. Cloud persistence therefore does not establish faithful coarse-grid turbulence.")
end
for grid in ("coarse","canonical","fine")
    r=findfirst(r->r.grid==grid && r.closure=="none" && r.weno=="9",rows)
    if r!==nothing
        a=rows[r]
        push!(findings,"$(uppercasefirst(grid)), WENO9 without closure: fourth-hour LWP $(f(a.LWP_g_m2)) g/m², cloud fraction $(f(100num(a.cloud_fraction)))%, peak w² $(f(a.peak_hour4_w2_m2_s2,3)) m²/s², and Δqₜ $(f(a.decoupling_g_kg,3)) g/kg.")
        b=findfirst(r->r.grid==grid && r.closure=="none" && r.weno=="5",rows)
        if b!==nothing
            b=rows[b]
            push!(findings,"At $grid resolution without closure, WENO9 minus WENO5 changes fourth-hour LWP by $(f(num(a.LWP_g_m2)-num(b.LWP_g_m2))) g/m² and peak w² by $(f(num(a.peak_hour4_w2_m2_s2)-num(b.peak_hour4_w2_m2_s2),3)) m²/s². These are paired single-realization differences, not statistically established scheme effects.")
        end
        b=findfirst(r->r.grid==grid && r.closure=="smagorinsky" && r.weno=="9",rows)
        if b!==nothing
            b=rows[b]
            push!(findings,"At $grid resolution with WENO9, adding Smagorinsky changes fourth-hour LWP by $(f(num(b.LWP_g_m2)-num(a.LWP_g_m2))) g/m² and peak w² by $(f(num(b.peak_hour4_w2_m2_s2)-num(a.peak_hour4_w2_m2_s2),3)) m²/s². Third-moment marker RMSE changes from $(f(a.w3_insitu_marker_RMSE,4)) to $(f(b.w3_insitu_marker_RMSE,4)) m³/s³.")
        end
    end
end
for grid in ("coarse","canonical","fine")
    i=findfirst(r->r.grid==grid && r.advection_scheme=="Centered",rows)
    i===nothing && continue
    a=rows[i]
    push!(findings,"$(uppercasefirst(grid)), Centered2 with Smagorinsky: sampled global qₜ extrema over 0–4 h were $(f(1000num(a.q_t_min_kg_kg),4)) to $(f(1000num(a.q_t_max_kg_kg),4)) g/kg; $(a.q_t_negative_samples) of 241 samples contained negative moisture. These are 60-second samples, not bounds on every timestep.")
    for order in ("9","5")
        j=findfirst(r->r.grid==grid && r.advection_scheme=="WENO" && r.advection_order==order && r.closure=="smagorinsky",rows)
        j===nothing && continue
        b=rows[j]
        push!(findings,"At $grid resolution with Smagorinsky, Centered2 minus WENO$order changes fourth-hour LWP by $(f(num(a.LWP_g_m2)-num(b.LWP_g_m2))) g/m² and peak w² by $(f(num(a.peak_hour4_w2_m2_s2)-num(b.peak_hour4_w2_m2_s2),3)) m²/s². Centered moisture is unbounded; this changes scheme family and bounding as well as formal order.")
    end
end
conclusion=n==total ? "All 15 requested four-hour cases are analyzed. This matrix does not establish faithful low-resolution DYCOMS turbulence: the four coarse WENO cases retain the wrong third-moment sign in the 600–760 m layer, and refining WENO9/no-SGS from 35 m to 10 m horizontal spacing substantially improves the third moment despite little improvement in variance-marker error. Fine WENO9/no-SGS has the smallest third-moment marker RMSE among the tested WENO cases. All three unbounded Centered2 cases develop negative total water and cannot establish physical fidelity. Cloud persistence alone is therefore insufficient. These are single-seed comparisons; the fine grid is not a proven converged solution, and the larger coarse domain confounds the resolution comparison." : "$n completed four-hour cases are analyzed. The remaining cases are in preparation, queued, running or awaiting audited exports; see the run-state table. Pending cases are absent from the scientific curves and metrics. The cross-resolution conclusion remains preliminary."
plotnote="All scientific figures are generated in Julia with CairoMakie. Numerical configurations use fixed Okabe-Ito colors, distinct dashes and marker shapes; different resolutions occupy panels with shared scales. The cloud-fraction zoom follows the simulated range, while a separate full-range panel preserves the paper ensemble spread."
envnote="Light gray is the paper’s model-ensemble minimum–maximum; darker gray is its interquartile range. These are not observational uncertainty bands or validation tolerances. The mean and envelope were digitized from Figure 2 at approximately 0.2–3.9 h. Original pixel coordinates, calibration, extraction settings and an overlay are retained. Subpixel early cloud-fraction bands are left missing. Only rendered cloud-fraction band edges are clipped to the physical 0–1 range; CSV values preserve raw digitization. The zoom panel omits the paper bands to avoid magnifying raster-edge uncertainty."
const figures=[("evolution","Cloud persistence and ensemble context"),("mean_profiles","Fourth-hour thermodynamic structure"),("vertical_velocity_moments","Fourth-hour vertical-velocity moments"),("flux_profiles","Scalar fluxes and buoyancy production"),("boundaries_decoupling","Cloud boundaries and decoupling"),("factorial_summary","Resolution and numerical choices")]
isfile(joinpath(ROOT,"report_figures","moisture_extrema.png")) && push!(figures,("moisture_extrema","Centered2 moisture validity"))
md=IOBuffer()
println(md,"# $title\n\n**$state** · Data checked $stamp\n\n## Current result\n\n$conclusion\n")
foreach(x->println(md,"- ",x),findings)
println(md,"\n## Fourth-hour metrics\n\n| Case | LWP (g/m²) | Cloud (%) | Peak w² (m²/s²) | Δqₜ (g/kg) | E (mm/s) |\n|---|---:|---:|---:|---:|---:|")
metriclines=String[]
for r in rows
    println(md,"| $(name(r)) | $(f(r.LWP_g_m2)) | $(f(100num(r.cloud_fraction))) | $(f(r.peak_hour4_w2_m2_s2,3)) | $(f(r.decoupling_g_kg,3)) | $(f(r.entrainment_mm_s)) |")
    push!(metriclines,"$(name(r)): LWP $(f(r.LWP_g_m2)) g/m²; cloud $(f(100num(r.cloud_fraction)))%; peak w² $(f(r.peak_hour4_w2_m2_s2,3)) m²/s²; Δqₜ $(f(r.decoupling_g_kg,3)) g/kg; E $(f(r.entrainment_mm_s)) mm/s.")
end
println(md,"\nPeak w² is the maximum of the fourth-hour mean native-face profile; E includes subsidence. [Full metrics](simulation_data/fourth_hour_metrics.csv) · [Paired contrasts](simulation_data/paired_effects.csv).\n\n## Plot conventions and envelope\n\n$plotnote\n\n$envnote\n\n[Envelope CSV](data/figure2_ensemble_envelope.csv) · [Extraction audit overlay](data/figure2_envelope_overlay.png) · [Envelope provenance](data/figure2_envelope_provenance.json).\n")
for (file,heading) in figures
    if file=="evolution"
        println(md,"## Measured solver cost\n\n| Case | Solver wall (min) | Iterations |\n|---|---:|---:|")
        for c in costrows
            println(md,"| $(c.case_id) | $(f(c.solver_wall_s/60,2)) | $(c.iterations) |")
        end
        println(md,"\nMeasured per-run solver wall includes output during time integration and excludes earlier Julia startup/compilation and queue waiting. Differences in timestep counts and diagnostic overhead contribute. These single-run timings are not isolated advection-kernel benchmarks. [Cost CSV](simulation_data/solver_costs.csv).\n")
    end
    println(md,"## $heading\n\n![$heading](report_figures/$file.png)\n\n[Vector SVG](report_figures/$file.svg) · [Vector PDF](report_figures/$file.pdf).\n")
end
if isfile(joinpath(ROOT,"pressel2017","figures","breeze_comparison.png"))
    windowfile=joinpath(ROOT,"pressel2017","data","velocity_window_comparison.csv")
    if isfile(windowfile)
        println(md,"## Averaging-window comparison for the fine grid\n\nCompare the same statistic across windows: changing from dimensional third moment to skewness also changes normalization. Both effects must be kept separate. Values below are minima over 600–760 m; skewness is the ratio of time-averaged central moments.\n\n| Fine case | Window | Minimum w′³ (m³/s³) | Minimum skewness |\n|---|---|---:|---:|")
        for r in filter(r->r.grid=="fine",table(windowfile))
            println(md,"| $(r.case_id) | $(r.window) | $(f(r.min_w3_600_760_m3_s3,4)) | $(f(r.min_skewness_600_760,4)) |")
        end
        println(md,"\n[All-resolution window-comparison CSV](pressel2017/data/velocity_window_comparison.csv). These minima may occur at different heights; they do not describe a single fixed-height plume.\n")
    end
    println(md,"## Skewness and the Pressel comparison\n\n![Skewness compared with Pressel](pressel2017/figures/breeze_skewness_comparison.png)\n\nColored solid curves and symbols are completed canonical Breeze cases; gray dashed curves are Pressel Figure 7 model results, not observations. Both use hours 2–4. Breeze is the ratio of time-averaged central moments, mean_t(w′³)/mean_t(w′²)^(3/2), formed from four half-hour bins. It is not the time average of instantaneous skewness. Pressel's normalization versus time-averaging order is not unambiguously specified, so that part of the comparison remains provisional. Variance ≤ 10⁻⁶ m²/s² is masked.\n\n![Skewness across resolutions](pressel2017/figures/breeze_skewness_resolutions.png)\n\nOnly completed exports are shown; the coarse domain is larger. The displayed height range is 0–1000 m. [Full-height skewness and moment CSV](pressel2017/data/breeze_skewness_2_4h.csv) · [Normalization sensitivity audit](pressel2017/data/breeze_skewness_audit.csv) · [Definitions and provenance](pressel2017/data/skewness_provenance.json).\n")
    println(md,"## Pressel et al. (2017): separate 2–4 h comparison\n\nThis paper revisits RF01 with the same canonical grid and domain. The comparison below uses its 2–4 h window, separate from the fourth-hour Stevens plots above. Its SGS coefficients, CFL, thermodynamics, surface treatment and moisture handling differ from the current Breeze setup. Dashed curves are published model results, not observations.\n\n![Breeze and Pressel](pressel2017/figures/breeze_comparison.png)\n\n[Paper reference and all seven figures](pressel2017/reference.md) · [Extracted data and audit](pressel2017/data/provenance.json) · [Exact 2–4 h bulk comparison](pressel2017/data/breeze_bulk_comparison_2_4h.csv).\n")
end
println(md,"## Experiment and interpretation\n\n$methods\n## Run state\n\n| Case | State | Analyzed |\n|---|---|---|")
for c in status["cases"];println(md,"| ",c["case_id"]," | ",c["state"]," | ",any(r->r.case_id==c["case_id"],rows) ? "yes" : "no"," |");end
println(md,"\n## Reproducibility\n\nAll active collection, analysis, digitization, plotting and report scripts are Julia. From the task workspace:\n\n```sh\njulia --project=outputs/julia outputs/collect_simulations.jl\njulia --project=outputs/julia outputs/digitize_figure2_envelope.jl\njulia --project=outputs/julia outputs/plot_simulations.jl\njulia --project=outputs/julia outputs/pressel2017/plot_reference.jl\njulia --project=outputs/julia outputs/pressel2017/build_reference.jl\njulia --project=outputs/julia outputs/build_simulation_report.jl\njulia --project=outputs/julia outputs/package_report.jl --sync\n```\n\nThe pinned plotting environment is in `julia/`. PDF assembly uses Poppler's `pdfunite`; packaging uses `zip` and `tar`. Historical Python scripts are retained only as an audit trail and are not used. Original JLD2 files and checkpoints remain on pcluster; reduced CSVs, metadata and all figure formats accompany this report.\n\n[Paper reference](paper_reference.md) · [Figures and extracted data](figure_data.md) · [Source provenance](cluster/source_provenance.json) · [Exact matrix](experiment_matrix.json) · [Workflow](report_workflow.md).\n\nStevens et al. (2005), Monthly Weather Review 133, 1443–1462. DOI: https://doi.org/10.1175/MWR2930.1.")
text=String(take!(md));write(joinpath(ROOT,"dycoms_report.md"),text)
body=Markdown.html(Markdown.parse(text))
css="body{font:17px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;color:#203340;background:#f5f7f8;margin:0}main{max-width:1200px;margin:25px auto;padding:45px;background:white;border-top:6px solid #0072B2}h1{font-size:32px}h2{margin-top:2em;color:#176d9c}img{max-width:100%;height:auto}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:8px;border-bottom:1px solid #dce3e7;text-align:left}th{background:#eef3f6}a{color:#176d9c}pre{background:#f4f6f8;padding:12px;overflow:auto}code{font-size:13px}"
write(joinpath(ROOT,"dycoms_report.html"),"<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>$title</title><style>$css</style><main>$body</main></html>")

# Text pages and scientific plots are both rendered by CairoMakie; Poppler only joins PDFs.
function wraplines(text,width=87)
    out=String[];line=""
    for word in split(text)
        if length(line)+length(word)+1>width;push!(out,line);line=String(word)
        else;line=isempty(line) ? String(word) : line*" "*word;end
    end
    isempty(line)||push!(out,line);out
end
function textpages(heading,paragraphs,prefix)
    paths=String[];page=0;fig=nothing;ax=nothing;y=0.
    function newpage()
        page+=1
        fig=Figure(size=(850,1100),figure_padding=0)
        ax=Axis(fig[1,1],limits=(0,850,0,1100));hidedecorations!(ax);hidespines!(ax)
        text!(ax,44,1050,text=join(wraplines(heading,49),"\n"),fontsize=25,font=:bold,align=(:left,:top),color="#173e56")
        text!(ax,44,29,text="Breeze / DYCOMS-II RF01 | Julia report | $state",fontsize=11,color="#607080")
        y=970.
    end
    function flushpage()
        path=joinpath(WORK,"$(prefix)_$(lpad(page,2,'0')).pdf");save(path,fig);push!(paths,path)
    end
    newpage()
    for (index,paragraph) in enumerate(paragraphs)
        ishead=startswith(paragraph,"### ");clean=replace(paragraph,r"^### "=>"",r"\*\*"=>"",r"`"=>"")
        lines=wraplines(clean,ishead ? 67 : 87);height=length(lines)*(ishead ? 25 : 22)+16
        reserve=height
        if ishead && index<length(paragraphs)
            reserve+=22length(wraplines(paragraphs[index+1],87))+16
        end
        if y-reserve<68;flushpage();newpage();end
        for line in lines
            text!(ax,44,y,text=line,fontsize=ishead ? 19 : 16,font=ishead ? :bold : :regular,align=(:left,:top))
            y-=ishead ? 25 : 22
        end
        y-=16
    end
    flushpage();paths
end
pages=textpages(title,vcat([state,"Data checked: "*stamp,conclusion],findings),"summary")
append!(pages,textpages("Fourth-hour metrics",vcat(metriclines,["Peak w² is the maximum of the fourth-hour mean native-face profile; entrainment includes subsidence. These are single-seed results."]),"metrics"))
windowfile=joinpath(ROOT,"pressel2017","data","velocity_window_comparison.csv")
if isfile(windowfile)
    windowlines=["Compare the same statistic across averaging windows. Dimensional third moment and skewness differ in normalization as well as the windows used in the two papers. All minima below are over 600–760 m and may occur at different heights. Skewness is the ratio of time-averaged moments."]
    for r in filter(r->r.grid=="fine",table(windowfile))
        push!(windowlines,"$(r.case_id), $(r.window): minimum w′³ $(f(r.min_w3_600_760_m3_s3,4)) m³/s³; minimum skewness $(f(r.min_skewness_600_760,4)).")
    end
    append!(pages,textpages("Fine-grid averaging-window comparison",windowlines,"windows"))
end
append!(pages,textpages("How to read these comparisons",[plotnote,envnote,"Paper observations are black markers in profile plots. Measurement error bars were not digitized. Numerical configurations use redundant color, line and symbol cues; resolution panels share scales."],"conventions"))
append!(pages,[joinpath(ROOT,"report_figures",file*".pdf") for (file,_) in figures])
presselplot=joinpath(ROOT,"pressel2017","figures","breeze_comparison.pdf")
isfile(presselplot) && push!(pages,presselplot)
for name in ("breeze_skewness_comparison","breeze_skewness_resolutions")
    path=joinpath(ROOT,"pressel2017","figures",name*".pdf")
    isfile(path) && push!(pages,path)
end
paragraphs=filter(!isempty,strip.(split(methods,"\n\n")))
append!(pages,textpages("Methods and limitations",paragraphs,"methods"))
append!(pages,textpages("Reproducibility and current run state",vcat(["All active processing and figures use Julia. CairoMakie version $(pkgversion(CairoMakie)); Julia $(VERSION). The companion Markdown/HTML report links to all CSVs, source hashes, digitization provenance and exact rebuild commands. Original restart checkpoints and JLD2 files remain on pcluster."],[c["case_id"]*": "*c["state"] for c in status["cases"]],["Reference: Stevens et al. (2005), Monthly Weather Review 133, 1443–1462. DOI 10.1175/MWR2930.1."]),"status"))
run(`pdfunite $pages $(joinpath(ROOT,"dycoms_report.pdf"))`)
println("JULIA_REPORT_COMPLETE analyzed=$n pdf_pages=",length(pages))
