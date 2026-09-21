#!/usr/bin/env julia
# Julia-only presentation. Analytic/synthetic figures are never LES evidence.
using CairoMakie, JSON, TOML, SHA, Printf
const DIR = @__DIR__
const INK = "#173e56"
const BLUE = "#0072B2"
const ORANGE = "#D55E00"
const PURPLE = "#AA4499"
const GRAY = "#606C76"
const paths = String[]
function page(k, eyebrow, title, subtitle)
    f = Figure(size=(850,1100), figure_padding=0, backgroundcolor=:white)
    a = Axis(f[1,1], limits=(0,850,0,1100))
    hidedecorations!(a); hidespines!(a)
    text!(a,45,1060; text=eyebrow, fontsize=13, color=BLUE, font=:bold)
    text!(a,45,1023; text=title, fontsize=29, color=INK, font=:bold, align=(:left,:top))
    text!(a,45,933; text=subtitle, fontsize=16, color=GRAY, align=(:left,:top))
    text!(a,45,27; text="Breeze evaluation | SurfaceLayerDiffusivity | Julia | $(k)/3", fontsize=11, color=GRAY)
    return f,a
end
function paragraph(a,y,heading,body; color=INK)
    text!(a,45,y; text=heading, fontsize=20, font=:bold, color, align=(:left,:top))
    text!(a,45,y-34; text=body, fontsize=16, color=INK, align=(:left,:top), lineheight=1.25)
end
function finish(f,stem)
    p=joinpath(DIR,stem*".pdf"); save(p,f); save(joinpath(DIR,stem*".png"),f; px_per_unit=1.5)
    push!(paths,p)
end

# Matched input samples: both references receive exactly the same Float32 inputs.
# This is a standalone arithmetic reproducer, not execution of a model kernel.
function arithmetic()
    α32=-expm1(-0.1f0/300f0); α64=-expm1(-0.1/300)
    mx,my,mp=300f0,0.05f0,300f0*0.05f0
    sx,sy,sc=mx,my,0f0
    rx,ry,rc=Float64(mx),Float64(my),0.0
    history=Tuple{Float64,Float64,Float64,Float64}[]
    for n in 1:90000
        t=0.1n
        x=Float32(300+0.1sin(2pi*t/37)); y=Float32(0.05+0.02sin(2pi*t/37+0.4))
        mx=(1-α32)*mx+α32*x; my=(1-α32)*my+α32*y; mp=(1-α32)*mp+α32*x*y
        dx,dy=x-sx,y-sy
        sc=(1-α32)*(sc+α32*dx*dy); sx+=α32*dx; sy+=α32*dy
        dx64,dy64=Float64(x)-rx,Float64(y)-ry
        rc=(1-α64)*(rc+α64*dx64*dy64); rx+=α64*dx64; ry+=α64*dy64
        n%100==0 && push!(history,(t,Float64(mp-mx*my),Float64(sc),rc))
    end
    return history
end
history=arithmetic(); t,raw,stable,ref=last(history)
open(joinpath(DIR,"covariance_arithmetic.csv"),"w") do io
    println(io,"time_s,naive_float32_K_m_s,centered_float32_K_m_s,quantized_input_float64_K_m_s")
    for row in history; println(io,join(row,',')); end
end
relative_error=abs((stable-ref)/ref)
feature=JSON.parsefile(joinpath(DIR,"cpu_validation.json"))
harness=TOML.parsefile(joinpath(DIR,"gpu_harness_cpu_contract.toml"))
exporter=TOML.parsefile(joinpath(DIR,"analysis_export_evidence.toml"))
@assert feature["tests"]["feature"]["failed"]==0 && harness["all_passed"] && exporter["tests_failed"]==0

f,a=page(1,"THE QUESTION", "Can a thin surface closure\nimprove coarse LES?",
    "Supply unresolved near-wall transport while preserving resolved turbulence.\nFour coarse GABLS1 comparisons admitted; transfer tests ongoing.")
paragraph(a,852,"A local estimate of missing transport",
    "Filter velocity, scalar, and wall-flux samples in physical time. Use their\ncentered covariance to estimate the resolved share of the surface flux.")
ax=Axis(f; bbox=BBox(85,445,420,720), xlabel="Resolved along-stress fraction r", ylabel="Viscosity / (W κ u* z)",
    title="Constitutive response (analytic)", titlesize=18, xlabelsize=15,ylabelsize=15)
r=range(-0.5,1.5,length=401)
lines!(ax,r,max.(1 .- r,0); color=BLUE,linewidth=4)
scatter!(ax,[0,0.5,1],[1,0.5,0];color=BLUE,marker=:circle,markersize=11)
vlines!(ax,[1];color=GRAY,linestyle=:dot); ylims!(ax,-.08,1.65)
text!(a,497,739;text="Shallow vertical support",fontsize=18,font=:bold,color=INK)
for (z,label) in ((465,"surface"),(535,"first face"),(605,"second face"),(675,"above"))
    lines!(a,[495,780],[z,z];color=z==465 ? INK : "#DCE3E7",linewidth=z==465 ? 3 : 1)
    text!(a,500,z+8;text=label,fontsize=13,color=GRAY)
end
lines!(a,[653,653],[465,675];color=GRAY,linestyle=:dot)
scatter!(a,[627,627,627],[535,605,675];markersize=[18,7,7],color=[BLUE,GRAY,GRAY],marker=:circle)
scatter!(a,[723,723,723],[535,605,675];markersize=[18,13,7],color=[PURPLE,PURPLE,GRAY],marker=:diamond)
text!(a,590,431;text="One face     Two faces",fontsize=15,color=INK)
text!(a,492,398;text="Weights: 1       1, 0.5\nSame applied surface flux",fontsize=15,color=INK)
paragraph(a,340,"What this formula does",
    "No resolved stress: full neutral similarity viscosity. Half resolved:\nhalf the viscosity. Fully resolved or more: the correction turns off.\nOpposite-sign transport can give a factor greater than one.")
paragraph(a,210,"What it does not establish",
    "The added flux still depends on the instantaneous vertical gradient.\nThe formula does not force exact flux balance, include stability functions,\nor measure the numerical transport produced by WENO.")
text!(a,45,77;text="One-face height: 12.5 m in both planned GABLS comparisons.\nScalar correction uses signed flux ratios; zero/tiny wall flux disables it.",fontsize=13,color=GRAY,align=(:left,:top))
finish(f,"01_mechanism")

f,a=page(2,"EVIDENCE AVAILABLE NOW", "A small covariance can get\nthe wrong sign in Float32",
    "Synthetic arithmetic test: 90,000 samples, Δt = 0.1 s, filter time = 300 s.\nIdentical Float32 input samples are used in the Float64 reference.")
ax=Axis(f; bbox=BBox(100,765,520,835),xlabel="Time (hours)",ylabel="Filtered covariance (10⁻³ K m s⁻¹)",
    xlabelsize=16,ylabelsize=16)
tt=first.(history)./3600
lines!(ax,tt,1000 .* getindex.(history,2);color=ORANGE,linewidth=2,label="Naive Float32 subtraction")
lines!(ax,tt,1000 .* getindex.(history,3);color=BLUE,linewidth=3,label="Centered Float32 recurrence")
lines!(ax,tt,1000 .* getindex.(history,4);color=:black,linewidth=2,linestyle=:dot,label="Float64 reference")
hlines!(ax,[0];color=GRAY,linewidth=1)
axislegend(ax;position=:lb,labelsize=13,framevisible=true)
text!(a,45,443;text=@sprintf("Final covariance: naive %.3f  |  centered %.3f  |  reference %.3f",1000raw,1000stable,1000ref),fontsize=17,font=:bold,color=INK)
text!(a,45,411;text=@sprintf("Units: 10⁻³ K m s⁻¹. Centered recurrence relative error: %.3f%%.",100relative_error),fontsize=15,color=GRAY)
paragraph(a,357,"Why this matters for the closure",
    "Subtracting two much larger filtered products loses the small turbulent\nflux. Here it reverses its sign. A centered covariance update retains the\nsignal that controls the added diffusivity.")
paragraph(a,226,"Implementation checks support the arithmetic result",
    "The original 119-check CPU suite covers filtering, signs, guards and\nconservation. Later halo/restart checks and the 1,678-check GPU suite\nsupport the admitted run source. Their evidence files retain each revision.")
text!(a,45,92;text="Boundary of the evidence: this arithmetic example is synthetic.\nPhysical fidelity is assessed separately using the completed GABLS1 runs.\nReproducer, exact plotted CSV, and source hashes accompany this section.",fontsize=13,color=GRAY,align=(:left,:top))
finish(f,"02_arithmetic")

f,a=page(3,"HOW TO READ THE COMPARISON", "Judge transport, turbulence,\nand the mean state together",
    "One controlled intervention, three complementary tests of physical behavior.\nSee the accompanying GABLS1 results for the first completed comparison.")
paragraph(a,850,"01  Did the near-wall transport change as intended?",
    "Lead with resolved, added, and combined momentum/heat flux profiles.\nZoom the lowest four levels; mark every active face. Pair flux mismatch\nwith viscosity, diffusivity, guard activity, and mean vertical transport.")
paragraph(a,696,"02  Did the boundary layer improve without losing turbulence?",
    "Place mean wind and temperature beside w², w³ and skewness. Show\nsurface flux through time; withhold invalid depth diagnostics. Retain the\nfixed 1 m GABLS1 median; missing reference quantities remain explicit.")
paragraph(a,542,"03  Is the result robust to filter time and support?",
    "Use the same four styles in every GABLS panel. Compare with a freshly\nrun, same-revision control, then examine 7-8 h versus 8-9 h. Report\nchanges in physical units; avoid a composite score that hides tradeoffs.")
for (i,(label,col,style,marker)) in enumerate([
    ("Matched WENO9 control",INK,:solid,:circle),
    ("One face / 100 s",BLUE,:dash,:rect),
    ("One face / 300 s",ORANGE,:dot,:utriangle),
    ("Two faces / 300 s",PURPLE,:dashdot,:diamond)])
    yy=373-(i-1)*36
    lines!(a,[55,140],[yy,yy];color=col,linestyle=style,linewidth=3)
    scatter!(a,[98],[yy];color=col,marker,markersize=10)
    text!(a,158,yy;text=label,fontsize=16,color=INK,align=(:left,:center))
end
paragraph(a,204,"Independent challenges strengthen the conclusion",
    "GABLS3: moist nocturnal evolution and the sunrise flux sign change.\nNeutral ABL: fixed-stress transport, without a surface-drag prediction.\nBoth add evidence; neither substitutes for the GABLS1 reference comparison.")
text!(a,45,75;text="Main result layout: mean state | flux partition | w² / w³ / skewness.\nCompanion timeline: surface exchange | boundary-layer depth | closure activity.",fontsize=13,color=GRAY,align=(:left,:top))
finish(f,"03_readout")

run(`pdfunite $paths $(joinpath(DIR,"surface_layer_story.pdf"))`)
evidence=Dict("artifact_kind"=>"analytic_and_synthetic_presentation", "scientific_les_cases"=>0,
    "arithmetic"=>Dict("sample_count"=>90000,"dt_s"=>0.1,"filter_s"=>300,
        "naive_float32"=>raw,"centered_float32"=>stable,"quantized_input_float64"=>ref,"relative_error"=>relative_error,
        "scope"=>"standalone reproducer; not a model-kernel run"),
    "breeze_feature_commit"=>feature["breeze"]["feature_commit"],
    "source_sha256"=>Dict(name=>bytes2hex(open(sha256,joinpath(DIR,name))) for name in
        ("presentation.jl","cpu_validation.json","gpu_harness_cpu_contract.toml","analysis_export_evidence.toml","covariance_arithmetic.csv")))
open(io->JSON.print(io,evidence,2),joinpath(DIR,"presentation_evidence.json"),"w")
println("SLD_PRESENTATION_COMPLETE pages=3 scientific_les_cases=0 covariance_relative_error=",relative_error)
