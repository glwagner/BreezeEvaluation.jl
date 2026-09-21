using CairoMakie, JSON
include("analysis_v2/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const S=SurfaceLayerScientificPlots
const D=@__DIR__
const pair=[S.SurfaceLayerAnalysisData.load_case_export(joinpath(D,"exports_v2",id)) for id in ("gabls1_n032_weno9_surface_layer_t300_s1_rf1p0","gabls1_n032_weno9_surface_layer_t300_s1_rf2p0")]
const control=S.SurfaceLayerAnalysisData.load_case_export(joinpath(D,"../gabls1/exports_e0655cf/gabls1_n032_weno9_control"))
@assert pair[1].manifest["provenance"]["source_freeze_manifest_sha256"]==pair[2].manifest["provenance"]["source_freeze_manifest_sha256"]
const cases=[pair;control]
const colors=["#0072B2","#D55E00","#555555"]
const styles=[:solid,:dash,:dot]
const labels=["Factor 1","Factor 2","No closure (earlier source)"]
const markers=[:circle,:utriangle,:rect]
const times=[30600.,32400.]
const ref=JSON.parsefile(joinpath(D,"../../gabls/reference_data/fixed_1m_medians.json"))
mkpath(joinpath(D,"figures"))
function drawprofile!(ax,var,refvar;maximum_height=250.,skipwall=false)
 for (i,c) in enumerate(cases)
  p=comparison_profile(c,var,times); ix=findall(z->(skipwall ? z>0 : z>=0)&&z<=maximum_height,p.z_m)
  lines!(ax,p.value[ix],p.z_m[ix];color=colors[i],linestyle=styles[i],linewidth=3,label=labels[i])
  scatter!(ax,p.value[ix],p.z_m[ix];color=colors[i],marker=markers[i],markersize=8)
 end
 r=S.reference_curve(ref,refvar;maximum_height)
 if !isnothing(r)
  lines!(ax,r.value,r.z_m;color=:black,linestyle=:dashdot,linewidth=2.5,label="Fixed 1 m median")
 end
 ylims!(ax,0,maximum_height)
end
f=Figure(size=(1450,1080),fontsize=19)
Label(f[0,1:3],"Crediting twice the resolved flux: does turbulence recover?",fontsize=28,font=:bold)
Label(f[1,1:3],"GABLS1 · 12.5 m · WENO9 · one face · 300 s filter · 8–9 h mean",fontsize=19)
firstax=nothing
panels=(("u_mean","u_mean","u (m s⁻¹)","Mean wind"),("theta_mean","theta_mean","θ (K)","Mean potential temperature"),("w_variance","w_variance","w² (m² s⁻²)","Vertical variance"),("w_third_central_moment","w_third_central_moment","w³ (m³ s⁻³)","Vertical third moment"),(:w_skewness_ratio_of_means,"w_skewness","w³ / (w²)³ᐟ²","Skewness of averaged moments"),("resolved_tke","tke","Resolved TKE (m² s⁻²)","Resolved turbulent energy"))
for (i,(var,rv,xlabel,title)) in enumerate(panels)
 ax=Axis(f[2+div(i-1,3),1+mod(i-1,3)];xlabel,ylabel="Height (m)",title,titlesize=20)
 i==1&&(global firstax=ax)
 drawprofile!(ax,var,rv)
 var==:w_skewness_ratio_of_means&&xlims!(ax,-2,2)
end
Legend(f[4,1:3],firstax;orientation=:horizontal,nbanks=2,labelsize=18)
Label(f[5,1:3],"Factor changes the closure deficit for momentum and heat; displayed physical fluxes are unscaled.\nEarlier no-closure run is context. This tests an assumed numerical contribution, not a measured numerical flux.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/factor_profiles.pdf"),f);save(joinpath(D,"figures/factor_profiles.png"),f)
f=Figure(size=(1450,1050),fontsize=19)
Label(f[0,1:3],"Resolved and SGS transport near the surface",fontsize=28,font=:bold)
Label(f[1,1:3],"Same final-hour average · native flux faces · physical fluxes remain unscaled",fontsize=19)
for (r,(suffix,rv,units)) in enumerate((("u_w_flux","uw","m² s⁻²"),("w_theta_flux","wtheta","K m s⁻¹")))
 for (c,part) in enumerate(("resolved","sgs","total"))
  ax=Axis(f[r+1,c];xlabel="Upward flux ($units)",ylabel="Height (m)",title=(r==1 ? "Momentum" : "Heat")*": "*(part=="sgs" ? "SGS" : uppercasefirst(part)),titlesize=20,xticks=WilkinsonTicks(4))
  r==1&&c==1&&(global firstax=ax)
  drawprofile!(ax,part*"_"*suffix,rv*"_"*part;maximum_height=60.,skipwall=part=="sgs")
 end
end
Legend(f[4,1:3],firstax;orientation=:horizontal,nbanks=2,labelsize=18)
Label(f[5,1:3],"Interior total = resolved + SGS. At the wall, total includes the prescribed flux; artificial SGS wall zeros are omitted.\nEach panel includes the fixed 1 m median wherever that reference quantity is available.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/factor_fluxes.pdf"),f);save(joinpath(D,"figures/factor_fluxes.png"),f)
