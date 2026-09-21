#!/usr/bin/env julia
using CairoMakie, JSON, SHA, Statistics
include("../analysis/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const D=@__DIR__
const S=SurfaceLayerScientificPlots
const Data=S.SurfaceLayerAnalysisData
const cases=load_comparison_cases(sort(readdir(joinpath(D,"exports_e0655cf");join=true))).cases
const hd=joinpath(D,"historical_smagorinsky")
const hm=JSON.parsefile(joinpath(hd,"manifest.json"))
for (name,hash) in hm["output_sha256"]
 @assert bytes2hex(open(sha256,joinpath(hd,name)))==hash
end
historical=(manifest=hm,profiles=Data.read_long_profiles(joinpath(hd,"profiles.csv")),series=Data.read_wide_series(joinpath(hd,"series.csv")))
@assert historical.series.time_s==collect(0.:60.:32400.)
allcases=[cases;historical]
colors=["#202020","#0072B2","#D55E00","#AA4499","#009E73"]
styles=[:solid,:dash,:dot,:dashdot,:solid]
markers=[:circle,:rect,:utriangle,:diamond,:star5]
labels=["Matched control","One face · 100 s","One face · 300 s","Two faces · 300 s","Smagorinsky (earlier run)"]
ref=JSON.parsefile(joinpath(D,"../../gabls/reference_data/fixed_1m_medians.json"))
times=[30600.,32400.]
f=Figure(size=(1600,1050),fontsize=19)
Label(f[0,1:3],"SGS transport replaces most of the resolved near-wall flux",fontsize=30,font=:bold,color="#173e56")
Label(f[1,1:3],"GABLS1 · 12.5 m · 8–9 h means · native faces in the lowest 60 m · corrected diagnostics",fontsize=19)
firstaxis=nothing
for (row,(suffix,reference_suffix,units)) in enumerate((("u_w_flux","uw","m² s⁻²"),("w_theta_flux","wtheta","K m s⁻¹")))
 for (col,component) in enumerate(("resolved","sgs","total"))
  variable=component*"_"*suffix
  title=(row==1 ? "u-momentum" : "Potential temperature")*": "*(component=="sgs" ? "SGS" : uppercasefirst(component))
  ax=Axis(f[row+1,col];xlabel="Upward flux ($units)",ylabel=col==1 ? "Height (m)" : "",title,titlesize=20)
  row==1&&col==1&&(global firstaxis=ax)
  for (i,c) in enumerate(allcases)
   p=comparison_profile(c,variable,times)
   @assert p.location=="Face"
   ix=findall(z->0<=z<=75,p.z_m)
   # At the wall, resolved=0 and SGS=0 are diagnostic conventions; prescribed
   # boundary flux is represented only in total. Omit the artificial SGS wall zero.
   component=="sgs"&&(ix=filter(j->p.z_m[j]>0,ix))
   lines!(ax,p.value[ix],p.z_m[ix];color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
   scatter!(ax,p.value[ix],p.z_m[ix];color=colors[i],marker=markers[i],markersize=9)
  end
  r=S.reference_curve(ref,reference_suffix*"_"*component)
  if !isnothing(r)
   lines!(ax,r.value,r.z_m;color=:black,linestyle=:dot,linewidth=2.5,label="Fixed 1 m archive median")
  end
  ylims!(ax,0,60)
  xlims!(ax,row==1 ? (-0.10,0.005) : (-0.015,0.0005))
 end
end
Legend(f[4,1:3],firstaxis;orientation=:horizontal,nbanks=2,labelsize=18)
Label(f[5,1:3],"Colors, line styles and markers identify cases. SGS wall zeros are omitted; total uses the prescribed wall flux.\nInterior total = resolved + SGS. This split does not quantify WENO numerical mixing. Teal is historical context.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/sld_flux_partition.pdf"),f)
save(joinpath(D,"figures/sld_flux_partition.png"),f)
println("CORRECTED_FLUX_FIGURE_COMPLETE")
