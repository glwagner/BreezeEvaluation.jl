using CairoMakie
include("analysis_b144835/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const S=SurfaceLayerScientificPlots
const D=@__DIR__
ids=["n064_weno9_none","n064_weno9_surface_layer_t100_s1","n064_weno9_surface_layer_t300_s1","n064_weno9_surface_layer_t300_s2"]
cases=load_comparison_cases([joinpath(D,"exports_b144835",id) for id in ids]).cases
fig=Figure(size=(1500,1050),fontsize=18)
Label(fig[0,1:3],"GABLS3: from nocturnal cooling to morning convection",fontsize=27)
axs=[]
for (row,(a,b,label)) in enumerate(((10800.,14400.,"03–04 UTC"),(28800.,32400.,"08–09 UTC")))
 for (col,(var,xlabel)) in enumerate((("w_variance","w² (m² s⁻²)"),("w_third_central_moment","w³ (m³ s⁻³)"),(:w_skewness_ratio_of_means,"w³ / (w²)³ᐟ²")))
  ax=Axis(fig[row,col];xlabel,ylabel=col==1 ? "Height (m)" : "",title=label)
  push!(axs,ax)
  for c in cases
   ts=collect(a+300.:300.:b);p=comparison_profile(c,var,ts);v=comparison_profile(c,"w_variance",ts);st=S.STYLES[S.variant(c.manifest["case_id"])]
   values=copy(p.value)
   for j in eachindex(values)
    (p.z_m[j]>400 || p.z_m[j]<=0 || (var isa Symbol && v.value[j]<1e-5)) && (values[j]=NaN)
   end
   lines!(ax,values,p.z_m;color=st.color,linestyle=st.linestyle,linewidth=3,label=st.label)
   ix=1:3:length(values);scatter!(ax,values[ix],p.z_m[ix];color=st.color,marker=st.marker,markersize=7)
  end
  ylims!(ax,0,400)
 end
end
Label(fig[3,1:3],"Native-face moments; 12 instantaneous profiles per hour. Skewness omitted where w² < 10⁻⁵ m² s⁻².\nMatched 12.5 m WENO9 cases, one seed. This comparison has no observational reference overlay.",fontsize=16,tellwidth=false)
Legend(fig[4,1:3],first(axs),orientation=:horizontal,nbanks=2)
for ext in ("pdf","png");save(joinpath(D,"figures/gabls3_transition."*ext),fig);end
