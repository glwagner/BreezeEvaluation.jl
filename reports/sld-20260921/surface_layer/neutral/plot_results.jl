using CairoMakie, TOML, SHA, JSON, Statistics
include("analysis_c9220b1/cases/surface_layer/analysis/SurfaceLayerAnalysisData.jl")
using .SurfaceLayerAnalysisData
const D=@__DIR__
sha(p)=bytes2hex(open(SHA.sha256,p))
@assert sha(joinpath(D,"collection_v2/manifest.toml"))=="f926dcd0aafae50d384af0dca8f8d21c90f2e324f507e86ebbadb8da88b27cc8"
collection=TOML.parsefile(joinpath(D,"collection_v2/manifest.toml"))
@assert collection["admitted_count"]==2 && collection["rejected_count"]==0
ids=["neutral_n096_weno9_control","neutral_n096_weno9_surface_layer_t300_s1"]
cases=map(ids) do id
 path=joinpath(D,"exports_v2",id)
 record=only(filter(x->x["case_id"]==id,collection["admitted"]))
 @assert sha(joinpath(path,"manifest.toml"))==record["manifest_sha256"]
 c=load_case_export(path)
 @assert c.manifest["scientific_admission"]=="passed_root_accepted_saved_output"
 @assert c.series.time_s==collect(0.:60.:18000.)
 @assert all(isfinite,Iterators.flatten(values(c.series.values)))
 @assert sort(unique(p.time_s for p in c.profiles))==collect(0.:600.:18000.)
 @assert all(p->isfinite(p.value),c.profiles)
 c
end
function prof(c,name,ts=collect(15000.:600.:18000.))
 rows=filter(p->p.variable==name && p.time_s in ts,c.profiles)
 z=sort(unique(p.z_m for p in rows))
 @assert !isempty(z) && length(rows)==length(z)*length(ts)
 v=[mean(p.value for p in rows if p.z_m==zz) for zz in z]
 (;z,v)
end
colors=["#0072B2","#D55E00"];styles=[:dash,:solid];labels=["WENO9 control","WENO9 + SLD (one face, 300 s)"]
mkpath(joinpath(D,"figures"))
f=Figure(size=(1450,1050),fontsize=18);axes=[]
Label(f[0,1:3],"Neutral ABL: matched five-hour comparison",fontsize=28)
Label(f[1,1:3],"96³ · Δx = 31.25 m · Δz = 10.42 m · fixed local u* = 0.5 m/s · 4–5 h means",fontsize=18)
for (k,(var,label)) in enumerate((("u_mean","u (m/s)"),("theta_mean","θ (K)"),("resolved_tke","Resolved TKE (m²/s²)"),("w_variance","w² (m²/s²)"),("w_third_central_moment","w³ (m³/s³)"),("skew","w³ / (w²)³ᐟ²")))
 ax=Axis(f[2+div(k-1,3),1+mod(k-1,3)],xlabel=label,ylabel="Height (m)");push!(axes,ax)
 for (i,c) in enumerate(cases)
  p=prof(c,var=="skew" ? "w_third_central_moment" : var);v=copy(p.v)
  if var=="skew"
   w=prof(c,"w_variance");v=[w.v[j]>1e-5 ? v[j]/w.v[j]^1.5 : NaN for j in eachindex(v)]
  end
  lines!(ax,v,p.z,color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
 end
 ylims!(ax,0,600)
end
Legend(f[4,1:3],axes[1],orientation=:horizontal)
Label(f[5,1:3],"Six true 600 s mean profiles per hour. Native-face moments; skewness masked for w² ≤ 10⁻⁵ m²/s².\nOne seed, no observational or LES reference: this tests response, not accuracy.",fontsize=16,tellwidth=false)
for ext in ("pdf","png");save(joinpath(D,"figures/neutral_profiles."*ext),f);end
f=Figure(size=(1450,1020),fontsize=18);axes=[]
Label(f[0,1:3],"Neutral ABL: momentum transport and evolution",fontsize=28)
for (k,var) in enumerate(("resolved_u_w_flux","sgs_u_w_flux","total_u_w_flux"))
 ax=Axis(f[1,k],xlabel="Upward u-momentum flux (m²/s²)",ylabel="Height (m)",title=["Resolved covariance","SGS","Covariance + SGS"][k]);push!(axes,ax)
 for (i,c) in enumerate(cases)
  p=prof(c,var);ix=findall(z->z>0 && z<=150,p.z)
  lines!(ax,p.v[ix],p.z[ix],color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
 end
 ylims!(ax,0,150)
end
for (k,var) in enumerate(("friction_velocity","resolved_tke_vertical_integral","surface_layer_face1_viscosity"))
 ax=Axis(f[2,k],xlabel="Time (h)",ylabel=["u* from mean stress (m/s)","Integrated resolved TKE (m³/s²)","First-face viscosity (m²/s)"][k])
 for (i,c) in enumerate(cases)
  haskey(c.series.values,var)||continue
  lines!(ax,c.series.time_s/3600,c.series.values[var],color=colors[i],linestyle=styles[i],linewidth=3)
 end
 xlims!(ax,0,5)
end
Legend(f[3,1:3],axes[1],orientation=:horizontal)
Label(f[4,1:3],"Interior fluxes exclude unmeasured WENO numerical transport. Wall values omitted from these flux panels.\nLocal prescribed stress magnitude is 0.25 m²/s²; averaging stress directions can reduce the mean-vector magnitude.",fontsize=16,tellwidth=false)
for ext in ("pdf","png");save(joinpath(D,"figures/neutral_transport."*ext),f);end
summary=Dict{String,Any}()
for (id,c) in zip(ids,cases)
 m=Dict{String,Any}()
 for (window,ts) in (("final_hour",collect(15000.:600.:18000.)),("penultimate_hour",collect(11400.:600.:14400.)))
  w=prof(c,"w_variance",ts);third=prof(c,"w_third_central_moment",ts);tke=prof(c,"resolved_tke",ts)
  m[window]=Dict("first_face_w2"=>w.v[2],"first_face_w3"=>third.v[2],"first_face_skewness"=>third.v[2]/w.v[2]^1.5,"peak_w2"=>maximum(w.v),"integrated_tke"=>sum(tke.v)*1000/96)
 end
 summary[id]=m
end
open(joinpath(D,"summary.json"),"w") do io;JSON.print(io,summary,2);end
println(JSON.json(summary));println("LOCAL_NEUTRAL_ADMISSION_2_0")
