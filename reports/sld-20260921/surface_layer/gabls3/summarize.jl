using JSON, Statistics
include("analysis_b144835/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots
const S=SurfaceLayerScientificPlots
const D=@__DIR__
ids=["n064_weno9_none","n064_weno9_surface_layer_t100_s1","n064_weno9_surface_layer_t300_s1","n064_weno9_surface_layer_t300_s2"]
cases=load_comparison_cases([joinpath(D,"exports_b144835",id) for id in ids]).cases
result=Dict{String,Any}()
for c in cases
 windows=Dict{String,Any}()
 for (label,a,b) in (("03–04 UTC",10800.,14400.),("08–09 UTC",28800.,32400.))
  times=collect(a+300.:300.:b)
  w2=comparison_profile(c,"w_variance",times);w3=comparison_profile(c,"w_third_central_moment",times)
  j=findfirst(>(0),w2.z_m)
  m=Dict{String,Any}("first_face_height_m"=>w2.z_m[j],"first_face_w2"=>w2.value[j],"first_face_w3"=>w3.value[j],"first_face_skewness"=>w3.value[j]/w2.value[j]^1.5,"peak_w2"=>maximum(w2.value))
  ix=findall(t->a<t<=b,c.series.time_s)
  for name in ("friction_velocity","surface_sensible_heat_flux","surface_q_kinematic_flux","resolved_tke_vertical_integral")
   m[name]=mean(c.series.values[name][ix])
  end
  windows[label]=m
 end
 result[c.manifest["case_id"]]=windows
end
open(joinpath(D,"summary.json"),"w") do io;JSON.print(io,result,2);end
println(JSON.json(result))
