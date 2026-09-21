#!/usr/bin/env julia
using CairoMakie, JSON, Statistics, SHA, Printf
include("../analysis/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const D=@__DIR__
const FIG=joinpath(D,"figures")
const REF=normpath(joinpath(D,"../../gabls/reference_data/fixed_1m_medians.json"))
const dirs=sort(readdir(joinpath(D,"exports_e0655cf");join=true))
const comp=load_comparison_cases(dirs)
# The historical run is contextual evidence, not a fifth same-source SLD treatment.
const HD=joinpath(D,"historical_smagorinsky")
const hm=JSON.parsefile(joinpath(HD,"manifest.json"))
@assert hm["export_verified"] && hm["source_hashes_checked"]
for (name,hash) in hm["output_sha256"]
 @assert bytes2hex(open(sha256,joinpath(HD,name)))==hash "Historical export hash mismatch: $name"
end
const Data=SurfaceLayerScientificPlots.SurfaceLayerAnalysisData
const historical=(manifest=hm, profiles=Data.read_long_profiles(joinpath(HD,"profiles.csv")),series=Data.read_wide_series(joinpath(HD,"series.csv")))
@assert historical.series.time_s==collect(0.:60.:32400.)
@assert sort(unique(r.time_s for r in historical.profiles))==collect(0.:1800.:32400.)
@assert all(hm["grid"][k]==12.5 for k in ("dx_m","dy_m","dz_m"))
const plot_cases=[comp.cases; historical]
const ref=JSON.parsefile(REF)
const S=SurfaceLayerScientificPlots
const final=[30600.,32400.]
const penult=[27000.,28800.]
const colors=["#202020","#0072B2","#D55E00","#AA4499","#009E73"]
const styles=[:solid,:dash,:dot,:dashdot,:solid]
const markers=[:circle,:rect,:utriangle,:diamond,:star5]
const labels=["Matched control","One face · 100 s","One face · 300 s","Two faces · 300 s","Smagorinsky (earlier run)"]
# Interpolate the reference only; simulation values retain native locations.
function interp(x,y,z)
 j=searchsortedlast(x,z)
 j==0 && return NaN
 j==length(x) && return z==x[end] ? y[end] : NaN
 return y[j]+(y[j+1]-y[j])*(z-x[j])/(x[j+1]-x[j])
end
metrics=Dict{String,Any}()
for (i,c) in enumerate(plot_cases)
 m=Dict{String,Any}("label"=>labels[i],"comparison_role"=>i==5 ? "Historical context; different source" : "Same-source matched treatment")
 for (name,times,lo,hi) in (("final_hour",final,28800,32400),("penultimate_hour",penult,25200,28800))
  ix=findall(t->lo<t<=hi,c.series.time_s)
  vals=Dict(v=>mean(c.series.values[v][ix]) for v in ("friction_velocity","surface_sensible_heat_flux","surface_theta_kinematic_flux","resolved_tke_vertical_integral"))
  w2=comparison_profile(c,"w_variance",times);w3=comparison_profile(c,"w_third_central_moment",times)
  vals["w2_at_12_5m"]=w2.value[2];vals["w3_at_12_5m"]=w3.value[2]
  vals["skewness_at_12_5m"]=w3.value[2]/w2.value[2]^1.5
  vals["peak_w2"]=maximum(w2.value)
  for variable in ("u_mean","theta_mean","w_variance")
   p=comparison_profile(c,variable,times);r=S.reference_curve(ref,variable)
   ixp=findall(z->0<z<=200,p.z_m)
   errors=[p.value[j]-interp(r.z_m,r.value,p.z_m[j]) for j in ixp]
   vals[variable*"_rmse_0_200m"]=sqrt(mean(abs2,errors))
  end
  m[name]=vals
 end
 metrics[c.manifest["case_id"]]=m
end
reference_means=Dict{String,Any}()
for variable in ("ustar","surface_theta_flux")
 r=S.reference_series(ref,variable)
 reference_means[variable]=mean(interp(r.time_s,r.value,t) for t in 28860:60:32400)
end
r=S.reference_curve(ref,"w_variance")
reference_means["w2_at_12_5m"]=interp(r.z_m,r.value,12.5)
reference_means["peak_w2"]=maximum(r.value)
evidence=Dict("cases"=>metrics,"reference"=>reference_means,"scope"=>"Four corrected-source GABLS1 reruns, array7293; native implicit SGS/total flux verified. Historical7156 flux exclusions remain in force.","profile_window"=>"8-9 h: equal mean of 30600 and 32400 s half-hour averages; sensitivity uses 7-8 h", "series_window"=>"60 instantaneous samples: 28860:60:32400 s", "rmse_definition"=>"Unweighted RMS at native model levels 0<z<=200 m, linearly interpolating fixed 1 m reference median only; descriptive, not uncertainty", "sha256"=>Dict("reference"=>bytes2hex(open(sha256,REF)), "plot_source"=>bytes2hex(open(sha256,@__FILE__)), (basename(d)*"/manifest.toml"=>bytes2hex(open(sha256,joinpath(d,"manifest.toml"))) for d in dirs)...))
evidence["historical_smagorinsky"]=Dict("manifest_sha256"=>bytes2hex(open(sha256,joinpath(HD,"manifest.json"))),"source_hashes"=>hm["source_hashes"],"relationship"=>"Same 12.5 m grid and WENO9; earlier source, not a fifth same-revision matched treatment")
open(io->JSON.print(io,evidence,2),joinpath(D,"physical_response_summary.json"),"w")
function profiles!(ax,variable;threshold=false)
 for (i,c) in enumerate(plot_cases)
  p=comparison_profile(c,variable,final);v=copy(p.value)
  if threshold
   w2=comparison_profile(c,"w_variance",final); v[w2.value.<1e-6].=NaN
  end
  lines!(ax,v,p.z_m;color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
  scatter!(ax,v,p.z_m;color=colors[i],marker=markers[i],markersize=7)
 end
 ylims!(ax,0,250)
end
function reference!(ax,var)
 r=S.reference_curve(ref,var)
 if isnothing(r)
  text!(ax,.96,.96;text="1 m reference unavailable",space=:relative,align=(:right,:top),fontsize=14,color=:gray40)
 else
  lines!(ax,r.value,r.z_m;color=:black,linestyle=:dot,linewidth=2.3,label="Fixed 1 m archive median")
 end
end
f=Figure(size=(1300,1050),fontsize=18)
Label(f[0,1:2],"Surface-layer mixing versus coarse-grid Smagorinsky",fontsize=29,font=:bold,color="#173e56")
Label(f[1,1:2],"GABLS1 · WENO9 · 12.5 m grid (32³) · final hour, 8–9 h · four matched runs + earlier Smagorinsky",fontsize=16)
axes=Axis[]
for (i,(var,xlabel,title)) in enumerate((("u_mean","u (m s⁻¹)","Wind: added near-wall mixing changes the profile"),("theta_mean","θ (K)","Temperature: smaller changes above the first levels"),("w_variance","w² (m² s⁻²)","Vertical variance: strongest suppression near the wall"),("w_third_central_moment","w³ (m³ s⁻³)","Third moment: the near-wall sign changes")))
 ax=Axis(f[2+(i-1)÷2,1+(i-1)%2];xlabel,ylabel="Height (m)",title,titlesize=17)
 profiles!(ax,var);reference!(ax,var);push!(axes,ax)
end
Legend(f[4,1:2],axes[1];orientation=:horizontal,nbanks=2,labelsize=16)
Label(f[5,1:2],"Teal stars: earlier Smagorinsky source; its w² and w³ nearly coincide with zero on these linear axes.\nBlack dotted: fixed 1 m LES median. Matched runs use the corrected, GPU-validated flux diagnostics.",fontsize=15,tellwidth=false)
save(joinpath(FIG,"sld_physical_response.pdf"),f);save(joinpath(FIG,"sld_physical_response.png"),f)
f=Figure(size=(1300,1050),fontsize=18)
Label(f[0,1:2],"Follow the response beyond the mean profile",fontsize=29,font=:bold,color="#173e56")
Label(f[1,1:2],"Surface exchange through 9 h; skewness from the final-hour native-face moments",fontsize=17)
axes=Axis[]
for (i,(var,ylabel,refvar)) in enumerate((("friction_velocity","u* (m s⁻¹)","ustar"),("surface_theta_kinematic_flux","Surface wθ (K m s⁻¹)","surface_theta_flux"),("resolved_tke_vertical_integral","∫ resolved TKE dz (m³ s⁻²)","")))
 ax=Axis(f[2+(i-1)÷2,1+(i-1)%2];xlabel="Elapsed time (h)",ylabel)
 for (j,c) in enumerate(plot_cases)
  lines!(ax,c.series.time_s./3600,c.series.values[var];color=colors[j],linestyle=styles[j],linewidth=2.5,label=labels[j])
 end
 if !isempty(refvar)
  rc=S.reference_series(ref,refvar); lines!(ax,rc.time_s./3600,rc.value;color=:black,linestyle=:dot,linewidth=2.3,label="Fixed 1 m archive median")
 else
  text!(ax,.97,.95;text="1 m integral reference unavailable",space=:relative,align=(:right,:top),fontsize=14,color=:gray40)
 end
 xlims!(ax,0,9);push!(axes,ax)
end
ax=Axis(f[3,2];xlabel="w³ / (w²)³ᐟ²",ylabel="Height (m)",title="Final-hour skewness",titlesize=17)
profiles!(ax,:w_skewness_ratio_of_means;threshold=true);reference!(ax,"w_skewness");xlims!(ax,-1.5,1.5)
Legend(f[4,1:2],axes[1];orientation=:horizontal,nbanks=2,labelsize=16)
Label(f[5,1:2],"Wall flux remains usable; resolved TKE excludes SGS energy. Teal: earlier Smagorinsky source.\nSkewness omits w² < 10⁻⁶ m² s⁻², masking most Smagorinsky levels; a ratio of tiny moments is not robust.",fontsize=15,tellwidth=false)
save(joinpath(FIG,"sld_exchange_and_skewness.pdf"),f);save(joinpath(FIG,"sld_exchange_and_skewness.png"),f)
f=Figure(size=(1300,850),fontsize=18)
Label(f[0,1:2],"Smagorinsky nearly eliminates resolved vertical turbulence",fontsize=27,font=:bold,color="#173e56")
Label(f[1,1:2],"12.5 m GABLS1 · WENO9 · log axes expose the difference hidden by linear scales",fontsize=17)
ax=Axis(f[2,1];xlabel="Final-hour w² (m² s⁻²; log scale)",ylabel="Height (m)",xscale=log10,xticks=(10.0.^(-10:2:-2),["10⁻¹⁰","10⁻⁸","10⁻⁶","10⁻⁴","10⁻²"]),title="8–9 h mean variance profile",titlesize=19)
for (i,c) in enumerate(plot_cases)
 p=comparison_profile(c,"w_variance",final);v=copy(p.value);v[v.<=0].=NaN
 lines!(ax,v,p.z_m;color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
 scatter!(ax,v,p.z_m;color=colors[i],marker=markers[i],markersize=8)
end
rc=S.reference_curve(ref,"w_variance");ix=findall(>(0),rc.value)
lines!(ax,rc.value[ix],rc.z_m[ix];color=:black,linestyle=:dot,linewidth=2.3,label="Fixed 1 m archive median")
ylims!(ax,0,250);xlims!(ax,1e-11,0.2)
ax2=Axis(f[2,2];xlabel="Elapsed time (h)",ylabel="Peak w² over height (m² s⁻²; log scale)",yscale=log10,yticks=(10.0.^(-8:2:-2),["10⁻⁸","10⁻⁶","10⁻⁴","10⁻²"]),title="Instantaneous horizontal variance",titlesize=19)
for (i,c) in enumerate(plot_cases)
 v=copy(c.series.values["w_variance_maximum"]);v[v.<=0].=NaN
 lines!(ax2,c.series.time_s./3600,v;color=colors[i],linestyle=styles[i],linewidth=3)
end
xlims!(ax2,0,9);ylims!(ax2,1e-9,0.3)
text!(ax2,.97,.70;text="Earlier Smagorinsky run:\nfinal-hour profile peak ≈ 1.12 × 10⁻⁶",space=:relative,align=(:right,:top),fontsize=16,color=colors[5])
Legend(f[3,1:2],ax;orientation=:horizontal,nbanks=2,labelsize=16)
Label(f[4,1:2],"Same grid and advection; Smagorinsky is historical context, not a same-revision controlled treatment.\nZeros are omitted on log axes. The left panel averages first; the right panel takes each instantaneous maximum.",fontsize=15,tellwidth=false)
save(joinpath(FIG,"sld_smagorinsky_variance.pdf"),f);save(joinpath(FIG,"sld_smagorinsky_variance.png"),f)
open(joinpath(D,"physical_response_table.md"),"w") do io
 println(io,"| Configuration | u* (m/s) | Surface heat (W/m²) | ∫ resolved TKE dz (m³/s²) | w² at 12.5 m (m²/s²) | w³ at 12.5 m (m³/s³) |")
 println(io,"|---|---:|---:|---:|---:|---:|")
 for c in plot_cases
  m=metrics[c.manifest["case_id"]];v=m["final_hour"]
  @printf(io,"| %s | %.3f | %.2f | %.3g | %.3g | %+.3g |\n",m["label"],v["friction_velocity"],v["surface_sensible_heat_flux"],v["resolved_tke_vertical_integral"],v["w2_at_12_5m"],v["w3_at_12_5m"])
 end
end
println(JSON.json(evidence))
