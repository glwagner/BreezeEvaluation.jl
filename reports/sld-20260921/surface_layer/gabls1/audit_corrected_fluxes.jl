using TOML, SHA, Statistics, JSON
include(joinpath(@__DIR__,"../analysis/SurfaceLayerAnalysisData.jl"))
using .SurfaceLayerAnalysisData
base=@__DIR__
col=TOML.parsefile(joinpath(base,"collection_e0655cf/manifest.toml"))
@assert col["admitted_count"]==4 && col["rejected_count"]==0
summary=Dict{String,Any}()
for e in col["admitted"]
 id=e["case_id"];dir=joinpath(base,"exports_e0655cf",id)
 @assert bytes2hex(open(sha256,joinpath(dir,"manifest.toml")))==e["manifest_sha256"]
 c=load_case_export(dir)
 @assert c.manifest["provenance"]["source_freeze_manifest_sha256"]=="d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
 @assert c.manifest["provenance"]["analysis_freeze"]["manifest_sha256"]=="c8e83cef2f51a392f5a154f3e3d295f2554a65241cf9f721bbe9c8ee1e3fd7a1"
 @assert c.series.time_s==collect(0.:60.:32400.)
 @assert sort(unique(r.time_s for r in c.profiles))==collect(0.:1800.:32400.)
 support=endswith(id,"_s2") ? 2 : endswith(id,"_control") ? 0 : 1
 rows=Dict((r.variable,r.time_s,r.z_m)=>r.value for r in c.profiles)
 residuals=Float64[]
 for part in ("u_w_flux","v_w_flux","w_theta_flux"), t in 0.:1800.:32400., z in 12.5:12.5:387.5
  a=rows[("total_"*part,t,z)];b=rows[("resolved_"*part,t,z)];s=rows[("sgs_"*part,t,z)]
  push!(residuals,abs(a-b-s))
  @assert isapprox(a,b+s;atol=2e-7,rtol=2e-5)
  z>12.5support && @assert s==0
 end
 vals=Dict{String,Any}("max_interior_flux_split_residual"=>maximum(residuals),"support_faces"=>support)
 for part in ("u_w_flux","v_w_flux","w_theta_flux"), component in ("resolved","sgs","total")
  v=component*"_"*part
  vals[v*"_at_12_5m"]=mean(rows[(v,t,12.5)] for t in (30600.,32400.))
  if support>0 && component=="sgs"
   @assert maximum(abs(r.value) for r in c.profiles if r.variable==v && r.time_s>0)>0
  end
 end
 ix=findall(t->28800<t<=32400,c.series.time_s)
 for v in ("surface_layer_face1_viscosity","surface_layer_face1_ρθ_diffusivity","friction_velocity","surface_theta_kinematic_flux")
  haskey(c.series.values,v) || continue
  vals[v]=mean(c.series.values[v][ix])
 end
 summary[id]=vals
end
open(joinpath(base,"corrected_flux_audit.json"),"w") do io
 JSON.print(io,summary,2)
end
println(JSON.json(summary))
