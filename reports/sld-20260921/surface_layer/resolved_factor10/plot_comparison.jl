using CairoMakie, JSON
include("analysis_v2/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const S=SurfaceLayerScientificPlots
const D=@__DIR__
const pair=[S.SurfaceLayerAnalysisData.load_case_export(joinpath(D,"../resolved_factor/exports_v2",id)) for id in ("gabls1_n032_weno9_surface_layer_t300_s1_rf1p0","gabls1_n032_weno9_surface_layer_t300_s1_rf2p0")]
const ten=S.SurfaceLayerAnalysisData.load_case_export(joinpath(D,"exports_v2/gabls1_n032_weno9_surface_layer_t300_s1_rf10p0"))
const control=S.SurfaceLayerAnalysisData.load_case_export(joinpath(D,"../gabls1/exports_e0655cf/gabls1_n032_weno9_control"))
@assert pair[1].manifest["provenance"]["source_freeze_manifest_sha256"]==pair[2].manifest["provenance"]["source_freeze_manifest_sha256"]
const cases=[pair;ten;control]
const colors=["#0072B2","#009E73","#D55E00","#777777"]
const styles=[:dash,:dashdot,:solid,:dot]
const labels=["Factor 1","Factor 2","Factor 10","No closure (earlier source)"]
const markers=[:circle,:rect,:utriangle,:diamond]
const times=[30600.,32400.]
const ref=JSON.parsefile(joinpath(D,"../../gabls/reference_data/fixed_1m_medians.json"))
mkpath(joinpath(D,"figures"))
function drawprofile!(ax,var,refvar;maximum_height=250.,skipwall=false)
 for (i,c) in enumerate(cases)
  p=comparison_profile(c,var,times); ix=findall(z->(skipwall ? z>0 : z>=0)&&z<=maximum_height,p.z_m)
  if var==:w_skewness_ratio_of_means
   variance=comparison_profile(c,"w_variance",times)
   ix=filter(j->variance.value[j]>=1e-6,ix)
  end
  lines!(ax,p.value[ix],p.z_m[ix];color=colors[i],linestyle=styles[i],linewidth=i==3 ? 4.2 : 2.5,label=labels[i])
  scatter!(ax,p.value[ix],p.z_m[ix];color=colors[i],marker=markers[i],markersize=8)
 end
 r=S.reference_curve(ref,refvar;maximum_height)
 if !isnothing(r)
  lines!(ax,r.value,r.z_m;color=:black,linestyle=:dashdot,linewidth=2.5,label="Fixed 1 m median")
 end
 ylims!(ax,0,maximum_height)
end
f=Figure(size=(1450,1080),fontsize=19)
Label(f[0,1:3],"Factor 10: mean profiles and resolved turbulence",fontsize=28,font=:bold)
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
Label(f[5,1:3],"Factor 10 is vermilion, solid, triangles. Reference medians shown where available.\nNative heights and physical moments retained; the added numerical-flux credit is an assumption.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/factor_profiles.pdf"),f);save(joinpath(D,"figures/factor_profiles.png"),f)
f=Figure(size=(1450,1050),fontsize=19)
Label(f[0,1:3],"Covariance and SGS transport near the surface",fontsize=28,font=:bold)
Label(f[1,1:3],"Same final-hour average · native flux faces · physical fluxes remain unscaled",fontsize=19)
for (r,(suffix,rv,units)) in enumerate((("u_w_flux","uw","m² s⁻²"),("w_theta_flux","wtheta","K m s⁻¹")))
 for (c,part) in enumerate(("resolved","sgs","total"))
  parttitle=part=="sgs" ? "SGS" : part=="total" ? "Covariance + SGS" : "Covariance"
  ax=Axis(f[r+1,c];xlabel="Upward flux ($units)",ylabel="Height (m)",title=(r==1 ? "Momentum" : "Heat")*": "*parttitle,titlesize=20,xticks=WilkinsonTicks(4))
  r==1&&c==1&&(global firstax=ax)
  drawprofile!(ax,part*"_"*suffix,rv*"_"*part;maximum_height=60.,skipwall=part=="sgs")
 end
end
Legend(f[4,1:3],firstax;orientation=:horizontal,nbanks=2,labelsize=18)
Label(f[5,1:3],"Interior total = covariance + actual SGS. This is NOT scheme-native WENO transport: its numerical correction is missing.\nWall total is prescribed; artificial SGS wall zeros omitted. Fixed 1 m medians shown where available.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/factor_fluxes.pdf"),f);save(joinpath(D,"figures/factor_fluxes.png"),f)

f=Figure(size=(1500,1130),fontsize=19)
Label(f[0,1:2],"What the factor changes: coefficients and local switch-off",fontsize=27,font=:bold)
Label(f[1,1:2],"One supported face at 12.5 m · coefficients from all three factors · switch-off fractions saved only for factor 10",fontsize=18)
for (col,(variable,title)) in enumerate((("surface_layer_face1_viscosity","Momentum viscosity (m² s⁻¹)"),("surface_layer_face1_ρθ_diffusivity","Heat diffusivity (m² s⁻¹)")))
 ax=Axis(f[2,col];xlabel="Time (h)",ylabel=title,title=title,titlesize=21)
 for (i,c) in enumerate(cases[1:3])
  lines!(ax,c.series.time_s./3600,c.series.values[variable];color=colors[i],linestyle=styles[i],linewidth=i==3 ? 3.5 : 2,label=labels[i])
 end
 vspan!(ax,7,8;color=(:black,0.045));vspan!(ax,8,9;color=(colors[3],0.05));xlims!(ax,0,9)
 col==1 && (global coefficient_axis=ax)
end
fractioncolors=["#0072B2","#D55E00","#009E73"]
fractionstyles=[:solid,:dash,:dot]
fractionlabels=["Clipped deficit = 0","Guard valid AND deficit = 0","Actual coefficient = 0"]
for (col,(prefix,coefficient,title)) in enumerate((("momentum","viscosity","Momentum: factor 10"),("ρθ","ρθ_diffusivity","Heat: factor 10")))
 ax=Axis(f[3,col];xlabel="Time (h)",ylabel="Fraction of horizontal points",title,titlesize=21)
 names=("surface_layer_face1_$(prefix)_deficit_zero_fraction","surface_layer_face1_$(prefix)_valid_zero_deficit_fraction","surface_layer_face1_$(coefficient)_zero_fraction")
 for i in 1:3
  lines!(ax,ten.series.time_s./3600,ten.series.values[names[i]];color=fractioncolors[i],linestyle=fractionstyles[i],linewidth=3,label=fractionlabels[i])
 end
 xlims!(ax,0,9);ylims!(ax,0,1)
 col==1 && (global fraction_axis=ax)
end
Legend(f[4,1:2],coefficient_axis;orientation=:horizontal,labelsize=18)
Legend(f[5,1:2],fraction_axis;orientation=:horizontal,nbanks=1,labelsize=17)
Label(f[6,1:2],"All fraction denominators include every horizontal point. Exact overlap is meaningful; quantitative values are in the report.\nActive/guard validity is separate from positive mixing. These six fractions were not saved for factors 1 and 2.",fontsize=17,tellwidth=false)
save(joinpath(D,"figures/factor_activity.pdf"),f);save(joinpath(D,"figures/factor_activity.png"),f)
