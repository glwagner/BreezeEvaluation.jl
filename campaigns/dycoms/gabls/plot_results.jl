#!/usr/bin/env julia
using CairoMakie, JSON, Statistics, Dates, Printf, SHA
include("../dycoms_data.jl")
using .DYCOMSData: table, num, interp, writecsv
const ROOT=@__DIR__
const OUT=joinpath(ROOT,"figures")
mkpath(OUT)
const STYLE=Dict(("none",9)=>("#0072B2",:solid,:circle), ("none",5)=>("#D55E00",:dash,:rect), ("smagorinsky",9)=>("#009E73",:dashdot,:utriangle), ("smagorinsky",5)=>("#CC79A7",:dot,:diamond), ("smagorinsky",2)=>("#000000",:dashdotdot,:star5))
const ORDER=[("none",9),("none",5),("smagorinsky",9)]
const REF=JSON.parsefile(joinpath(ROOT,"reference_data","final_hour_profiles.json"))
const REFSER=JSON.parsefile(joinpath(ROOT,"reference_data","series.json"))
const PLAN=JSON.parsefile(joinpath(ROOT,"experiment_matrix.json"))
const MATRIX=PLAN["cases"]
const FIXED_STYLE=(color=:black,linestyle=:dot,linewidth=3)
const FIXED_EXPORT=Dict{String,Any}()
const COSTFILE=joinpath(ROOT,"cluster","completion_metrics.json")
const COSTS=isfile(COSTFILE) ? JSON.parsefile(COSTFILE)["cases"] : Dict()
set_theme!(Theme(fontsize=16,Axis=(topspinevisible=false,rightspinevisible=false,xgridcolor=(:black,.08),ygridcolor=(:black,.08))))
function load_cases()
 statusfile=joinpath(ROOT,"cluster","export_status.json")
 status=isfile(statusfile) ? JSON.parsefile(statusfile) : Dict("cases"=>[])
 accepted=Set(get(c,"case_id",get(c,"case","")) for c in get(status,"cases",[]) if get(c,"export_verified",false)===true && get(c,"source_hashes_checked",get(status,"source_hashes_checked",false))===true)
 cases=[];rejected=[]
 for c in MATRIX
  id=c["case_id"];id in accepted || continue
  try
   dir=joinpath(ROOT,"simulation_data",id)
   m=JSON.parsefile(joinpath(dir,"manifest.json"))
@assert m["case_id"]==id && m["export_verified"]===true && m["source_hashes_checked"]===true
@assert m["completion"]["both_sentinels"]===true && m["completion"]["queue_absent"]===true
@assert m["slurm_job_spec"]==c["job_id"] && m["completion"]["log_path"]==c["log"]
if haskey(c,"source_revision")
 @assert m["source_revision"]==c["source_revision"]
 @assert m["registry_source_hashes_checked"]===true
end
for (role,key) in [("diagnostics","gabls_diagnostics.jl"),("runner","gabls_case.jl"),("surface","gabls_rough_wall_coefficient.jl"),("manifest","root_Manifest.toml")]
 @assert m["source_hashes"][role]["checked"]===true
 @assert m["source_hashes"][role]["sha256"]==get(c,"source_hashes",PLAN["cluster_source_hashes"])[key]
end
for (file,expected) in m["output_sha256"]
 @assert basename(file)==file
 @assert bytes2hex(open(sha256,joinpath(dir,file)))==expected
end
@assert m["grid"]["Nx"]==c["nx"] && m["grid"]["Lz_m"]==400
   @assert m["profile_record_semantics"]["final_hour_source_times_s"]==[30600,32400]
   @assert m["profile_record_semantics"]["penultimate_hour_source_times_s"]==[27000,28800]
   @assert m["record_audit"]["profiles"]["all_finite"] && m["record_audit"]["series"]["all_finite"]
   rows=table(joinpath(dir,"series.csv"));ss=Dict(string(k)=>num.(getproperty.(rows,k)) for k in keys(first(rows)))
   @assert length(rows)==541 && ss["time_s"]==collect(0.:60.:32400.)
   @assert all(v->all(isfinite,v),values(ss))
   raw=table(joinpath(dir,"profiles.csv"))
   @assert sort(unique(num(r.time_s) for r in raw))==collect(0.:1800.:32400.)
   allp=Dict{Int,Dict{String,Tuple{Vector{Float64},Vector{Float64}}}}()
   for (hour,ends) in [(8,(27000.,28800.)),(9,(30600.,32400.))]
    p=Dict{String,Tuple{Vector{Float64},Vector{Float64}}}()
    for name in unique(r.variable for r in raw)
     a=sort([r for r in raw if r.variable==name && num(r.time_s)==ends[1]],by=r->num(r.z_m))
     b=sort([r for r in raw if r.variable==name && num(r.time_s)==ends[2]],by=r->num(r.z_m))
     z=num.(getproperty.(a,:z_m));@assert z==num.(getproperty.(b,:z_m)) && !isempty(z)
     v=(num.(getproperty.(a,:value)).+num.(getproperty.(b,:value)))./2
     @assert all(isfinite,v)
     p[name]=(z,v)
    end
    z,w2=p["w_variance"];zw,w3=p["w_third_central_moment"]
    @assert z==zw==collect(0.:c["dx_m"]:400.)
    p["w_skewness_ratio_of_means"]=(z,[a>1e-8 ? b/a^1.5 : NaN for (a,b) in zip(w2,w3)])
if haskey(p,"w_skewness_instantaneous_ratio")
 zs,vs=p["w_skewness_instantaneous_ratio"];@assert zs==z
 p["w_skewness_instantaneous_ratio"]=(zs,[a>1e-8 ? b : NaN for (a,b) in zip(w2,vs)])
end
    allp[hour]=p
   end
   push!(cases,(id=id,nx=c["nx"],dx=num(c["dx_m"]),closure=c["closure"],order=c["advection_order"],s=ss,p=allp[9],p8=allp[8],manifest=m))
  catch err
   push!(rejected,Dict("case_id"=>id,"reason"=>sprint(showerror,err)))
  end
 end
 cases,rejected
end
function reference_profiles(dx,var)
 g="res_$(dx)m"
 # Archive uses integer names for 1 and 2 m.
 gs=Set([g,"res_$(Int(round(dx)))m"])
 [r for r in REF if r["grid"] in gs && r["variable"]==var]
end
# Linear combinations are formed within each model before taking ensemble medians.
# In particular, sum of medians is not used as a median of the total flux.
for (target,terms,weights) in [
 ("resolved_tke",["u_variance","v_variance","w_variance"],[.5,.5,.5]),
 ("uw_total",["uw_resolved","uw_sgs"],[1.,1.]),
 ("vw_total",["vw_resolved","vw_sgs"],[1.,1.]),
 ("wtheta_total",["wtheta_resolved","wtheta_sgs"],[1.,1.]),
 ("shear_production_total",["shear_production_resolved","shear_production_sgs"],[1.,1.])]
 for r in copy(REF)
  r["variable"]==first(terms)||continue
  rr=[findfirst(q->q["grid"]==r["grid"] && q["model"]==r["model"] && q["variable"]==v,REF) for v in terms]
  any(isnothing,rr)&&continue
  parts=REF[Int.(rr)]
  all(q->q["z_m"]==r["z_m"] && q["source_file"]==r["source_file"],parts)||continue
  values=[any(q->q["value"][j]===nothing,parts) ? nothing : sum(w*q["value"][j] for (w,q) in zip(weights,parts)) for j in eachindex(r["z_m"])]
  derived=copy(r);derived["variable"]=target;derived["value"]=values
  derived["derivation"]="model-wise linear combination: "*join(["$w × $v" for (w,v) in zip(weights,terms)]," + ")
  push!(REF,derived)
 end
end
function ensemble_samples(rr,coord,xx;nonnegative=false)
 samples=[Float64[] for x in xx]
 for r in rr
  z=Float64.(r[coord]);v=[x===nothing ? NaN : Float64(x) for x in r["value"]]
  order=sortperm(z);z=z[order];v=v[order]
  for (j,x) in enumerate(xx)
   length(z)>=2 && first(z)<=x<=last(z) || continue
   q=interp(z,v,x);isfinite(q) && !(nonnegative && q<0) && push!(samples[j],q)
  end
 end
 samples
end
function missing_reference!(ax)
 text!(ax,.98,.98,text="1.0 m reference unavailable",space=:relative,align=(:right,:top),fontsize=10,color="#666666")
end
function fixed_reference!(ax,var;series=false,positive=false)
 coord=series ? "time_s" : "z_m"
 xx=series ? collect(0.:60.:32400.) : collect(0.:2.:400.)
 rr=series ? [r for r in REFSER if r["grid"] in ("res_1m","res_1.0m") && r["variable"]==var] : reference_profiles(1.,var)
 samples=ensemble_samples(rr,coord,xx;nonnegative=var=="boundary_layer_height")
 med=[isempty(v) ? NaN : median(v) for v in samples]
 FIXED_EXPORT[(series ? "series/" : "profile/")*var]=Dict("variable"=>var,"coordinate"=>coord,"coordinates"=>xx,"median"=>[isfinite(v) ? v : nothing for v in med],"member_count"=>length.(samples),"sources"=>[Dict(k=>r[k] for k in ("model","source_file","source_header","derivation") if haskey(r,k)) for r in rr])
 if !any(isfinite,med)
  missing_reference!(ax);return false
 end
 positive && (med[med.<=0].=NaN)
 series ? lines!(ax,xx./3600,med;FIXED_STYLE...) : lines!(ax,med,xx;FIXED_STYLE...)
 true
end
function reference_band!(ax,dx,var)
 rr=reference_profiles(dx,var);isempty(rr)&&return
 zz=collect(0.:2.:400.);samples=ensemble_samples(rr,"z_m",zz)
 lo=[length(v)>=2 ? minimum(v) : NaN for v in samples]
 hi=[length(v)>=2 ? maximum(v) : NaN for v in samples]
 med=[!isempty(v) ? median(v) : NaN for v in samples]
 band!(ax,zz,lo,hi,direction=:y,color=(:gray,.23))
 lines!(ax,med,zz,color="#666666",linestyle=:dash,linewidth=1.5)
end
function reference_series_band!(ax,dx,var)
 gs=Set(["res_$(dx)m","res_$(Int(round(dx)))m"])
 rr=[r for r in REFSER if r["grid"] in gs && r["variable"]==var]
 tt=collect(0.:60.:32400.);samples=ensemble_samples(rr,"time_s",tt;nonnegative=var=="boundary_layer_height")
 lo=[length(v)>=2 ? minimum(v) : NaN for v in samples];hi=[length(v)>=2 ? maximum(v) : NaN for v in samples]
 med=[!isempty(v) ? median(v) : NaN for v in samples]
 band!(ax,tt./3600,lo,hi;color=(:gray,.23))
 lines!(ax,tt./3600,med;color="#666666",linestyle=:dash,linewidth=1.5)
end
function curve!(ax,c,x,y)
 col,ls,marker=STYLE[(c.closure,c.order)]
 lines!(ax,x,y;color=col,linestyle=ls,linewidth=2.5)
 idx=1:max(1,cld(length(x),12)):length(x)
 scatter!(ax,x[idx],y[idx];color=:white,strokecolor=col,strokewidth=1.4,marker,markersize=7)
end
function finish(f,name,title,caption,cols,lastrow,cases;paper=true,fixed=false)
 Label(f[0,1:cols],title,fontsize=23,font=:bold,tellwidth=false)
 elements=Any[];labels=String[]
 for key in ORDER
  any(c->(c.closure,c.order)==key,cases)||continue
  col,ls,mk=STYLE[key]
  push!(elements,[LineElement(color=col,linestyle=ls,linewidth=2.5),MarkerElement(color=:white,strokecolor=col,marker=mk,markersize=8)])
  push!(labels,(key[2]==2 ? "Centered2" : "WENO$(key[2])")*" / "*(key[1]=="none" ? "no SGS" : "Smagorinsky"))
 end
 if paper
  append!(elements,[PolyElement(color=(:gray,.23)),LineElement(color="#666666",linestyle=:dash)])
  append!(labels,["Same-grid archive min–max (≥2 members)","Same-grid archive median"])
 end
 if fixed
  push!(elements,LineElement(;FIXED_STYLE...));push!(labels,"1.0 m archive median (fixed reference)")
 end
 isempty(elements)||Legend(f[lastrow+1,1:cols],elements,labels;orientation=:horizontal,nbanks=2,framevisible=false,tellwidth=false,patchsize=(38,14))
 Label(f[lastrow+2,1:cols],caption,fontsize=12,tellwidth=false,halign=:left,justification=:left)
 for ext in ("png","pdf")
  save(joinpath(OUT,name*"."*ext),f;px_per_unit=ext=="png" ? 1.4 : 1)
 end
 "gabls/figures/"*name
end
function profileplot(cases,grids,variables,name,title;paper=true)
 f=Figure(size=(1200,300length(grids)+220));cols=length(variables); axs=[Axis[] for _ in 1:cols]
 fixed=false
 for (i,dx) in enumerate(grids),(j,(key,ref,label)) in enumerate(variables)
  ax=Axis(f[i,j],xlabel=label,ylabel=j==1 ? "Height (m)" : "",title="Δ = $dx m")
  push!(axs[j],ax)
  paper && !isempty(ref) && reference_band!(ax,dx,ref)
  for c in cases
   c.dx==dx && haskey(c.p,key)||continue
   z,v=c.p[key];curve!(ax,c,v,z)
  end
  fixed = fixed_reference!(ax,isempty(ref) ? key : ref) || fixed
  ylims!(ax,0,400)
 end
 foreach(a->length(a)>1 && linkxaxes!(a...),axs)
 caption=paper ? "Archive: nominal final-hour profiles, including some NERSC windows of 474–534 min. Breeze curves, when present: 8–9 h means.\nNative heights interpolated without extrapolation; model membership varies with height and grid. The spread is not observational uncertainty." : "Breeze: 8–9 h means; only fully completed and audited exports. Shown budget terms do not form a closed budget.
A budget residual must not be interpreted as numerical dissipation; unavailable terms are not replaced by zero."
 caption *= "\nBlack dots: fixed 1.0 m ensemble median; interpolation precedes the median. Unavailable references are labeled."
 name in ("tke_terms","momentum_flux","crosswind_flux","heat_flux") && (caption *= "\nArchive caution: 1.0 m IMUK SGS data contain upper-level anomalies; retained as supplied and flagged in the report.")
 finish(f,name,title,caption,cols,length(grids),cases;paper,fixed)
end
function timeaverage(c,key,lo=28800,hi=32400)
 t=c.s["time_s"];v=c.s[key];idx=findall(x->lo<=x<=hi,t)
 sum(diff(t[idx]).*(v[idx[1:end-1]].+v[idx[2:end]])./2)/(hi-lo)
end
cases,rejected=load_cases();figures=String[];findings=String[];metrics=[];admitted=[]
# This reference page is useful before the first GPU result arrives.
push!(figures,profileplot([], [12.5,6.25,3.125,2.,1.],[("u_mean","u_mean","u (m/s)"),("theta_mean","theta_mean","θ (K)"),("w_variance","w_variance","w′² (m²/s²)")],"reference_overview","GABLS1 reference archive: final-hour model spread"))
rf=Figure(size=(1200,1700));rax=[Axis[] for _ in 1:3]
for (i,dx) in enumerate([12.5,6.25,3.125,2.,1.]),(j,(key,label)) in enumerate([("boundary_layer_height","h (m)"),("ustar","u★ (m/s)"),("surface_theta_flux","Surface w′θ′ (K m/s)")])
 ax=Axis(rf[i,j],xlabel="Time (h)",ylabel=label,title="Δ = $dx m");push!(rax[j],ax)
 reference_series_band!(ax,dx,key);fixed_reference!(ax,key;series=true);xlims!(ax,0,9)
end
foreach(a->linkyaxes!(a...),rax)
push!(figures,finish(rf,"reference_evolution","GABLS1 reference archive: evolution","Archive series interpolated to common times without extrapolation; missing values omitted.
Membership varies with grid and time. Black dots: the same 1.0 m ensemble median in every row. Heat flux is upward positive.",3,5,[];paper=true,fixed=true))
if !isempty(cases)
 grids=sort(unique(c.dx for c in cases),rev=true)
 for (vars,name,title,paper) in [
  ([("u_mean","u_mean","u (m/s)"),("v_mean","v_mean","v (m/s)"),("theta_mean","theta_mean","θ (K)")],"mean_profiles","GABLS1: mean wind and temperature",true),
  ([("w_variance","w_variance","w′² (m²/s²)"),("w_third_central_moment","","w′³ (m³/s³)"),("w_skewness_ratio_of_means","w_skewness","Skewness (ratio of means)")],"vertical_moments","GABLS1: vertical velocity moments",true),
  ([("resolved_u_w_flux","uw_resolved","Resolved u′w′ (m²/s²)"),("sgs_u_w_flux","uw_sgs","SGS u′w′ (m²/s²)"),("total_u_w_flux","uw_total","Total u′w′ (m²/s²)")],"momentum_flux","GABLS1: streamwise momentum transport",true),
  ([("resolved_w_theta_flux","wtheta_resolved","Resolved w′θ′ (K m/s)"),("sgs_w_theta_flux","wtheta_sgs","SGS w′θ′ (K m/s)"),("total_w_theta_flux","wtheta_total","Total w′θ′ (K m/s)")],"heat_flux","GABLS1: vertical heat transport",true)]
  push!(figures,profileplot(cases,grids,vars,name,title;paper))
 end
 push!(figures,profileplot(cases,grids,[("resolved_tke","resolved_tke","Resolved TKE (m²/s²)"),("w_skewness_instantaneous_ratio","w_skewness","Mean instantaneous skewness"),("total_stress_magnitude","","Total stress magnitude (m²/s²)")],"tke_skewness_stress","GABLS1: turbulence intensity, asymmetry and stress";paper=true))
 push!(figures,profileplot(cases,grids,[("total_tke_shear_production","shear_production_total","Shear production (m²/s³)"),("total_tke_buoyancy_production","","Buoyancy production (m²/s³)"),("resolved_tke_transport","","Resolved TKE transport (m²/s³)")],"tke_terms","GABLS1: selected TKE budget terms";paper=false))
 push!(figures,profileplot(cases,grids,[("resolved_v_w_flux","vw_resolved","Resolved v′w′ (m²/s²)"),("sgs_v_w_flux","vw_sgs","SGS v′w′ (m²/s²)"),("total_v_w_flux","vw_total","Total v′w′ (m²/s²)")],"crosswind_flux","GABLS1: crosswind momentum transport";paper=true))
 if all(c->haskey(c.s,"surface_stability_cap_fraction"),cases)
  sf=Figure(size=(1200,290length(grids)+220))
  for (i,dx) in enumerate(grids),(j,(key,label)) in enumerate([("surface_stability_cap_fraction","Area fraction at stability cap"),("surface_neutral_fallback_fraction","Area fraction using neutral fallback"),("w_variance_maximum","Peak instantaneous w′² (m²/s²)")])
   ax=Axis(sf[i,j],xlabel="Time (h)",ylabel=label,title="Δ = $dx m")
   for c in cases
    c.dx==dx||continue
    curve!(ax,c,c.s["time_s"]./3600,c.s[key])
   end
   xlims!(ax,0,9); j<=2 && ylims!(ax,0,1)
   missing_reference!(ax)
  end
  push!(figures,finish(sf,"surface_regimes","GABLS1: wall-model regimes and resolved turbulence","Instantaneous 60 s samples. The wall law caps ζ at 10 and uses neutral exchange for nonpositive bulk Richardson number.\nThese fractions identify when wall-model limits participate in the result. No matching archive regime or peak-variance series is available.",3,length(grids),cases;paper=false))
 end
 lf=Figure(size=(1000,320length(grids)+220))
 for (i,dx) in enumerate(grids)
  ax=Axis(lf[i,1],xlabel="Time (h)",ylabel="Peak instantaneous w′² (m²/s²)",yscale=log10,title="Δ = $dx m")
  ap=Axis(lf[i,2],xlabel="Final-hour w′² (m²/s²)",ylabel="Height (m)",xscale=log10,title="Δ = $dx m")
  for c in cases
   c.dx==dx||continue
   v=copy(c.s["w_variance_maximum"]);v[v.<=0].=NaN
   curve!(ax,c,c.s["time_s"]./3600,v)
   z,p=c.p["w_variance"];p=copy(p);p[p.<=0].=NaN
   curve!(ap,c,p,z)
  end
  missing_reference!(ax)
  fixed_reference!(ap,"w_variance";positive=true)
  xlims!(ax,0,9);ylims!(ap,0,400)
 end
 push!(figures,finish(lf,"resolved_turbulence_decay","GABLS1: resolved vertical-velocity variance","Logarithmic variance axes distinguish weak resolved motions from sustained turbulence. Left: instantaneous profile maxima; right: 8–9 h means.\nBlack dots: fixed 1.0 m median (right only). No archived peak-variance time series. Nonpositive values omitted without a substituted floor.",2,length(grids),cases;paper=false,fixed=true))
 f=Figure(size=(1200,290length(grids)+220))
 for (i,dx) in enumerate(grids),(j,(key,label)) in enumerate([("boundary_layer_height","Boundary-layer height (m)"),("friction_velocity","u★ (m/s)"),("surface_theta_kinematic_flux","Surface w′θ′ (K m/s)")])
  ax=Axis(f[i,j],xlabel="Time (h)",ylabel=label,title="Δ = $dx m")
  refkey=key=="friction_velocity" ? "ustar" : key=="surface_theta_kinematic_flux" ? "surface_theta_flux" : key
  reference_series_band!(ax,dx,refkey)
  fixed_reference!(ax,refkey;series=true)
  for c in cases
   c.dx==dx||continue
   y=copy(c.s[key]);key=="boundary_layer_height" && (y[c.s["boundary_layer_height_valid"].==0].=NaN)
   curve!(ax,c,c.s["time_s"]./3600,y)
  end
  xlims!(ax,0,9)
 end
 push!(figures,finish(f,"evolution","GABLS1: evolution","Breeze: instantaneous 60 s samples. Archive series interpolated to common times without extrapolation; model membership varies.\nh = height of 5% total surface stress / 0.95; invalid crossings omitted. Black dots: fixed 1.0 m median. Heat flux is upward positive.",3,length(grids),cases;paper=true,fixed=true))
 jf=Figure(size=(1200,290length(grids)+220))
 for (i,dx) in enumerate(grids),(j,(key,label)) in enumerate([("low_level_jet_height","Jet height (m)"),("low_level_jet_speed","Jet speed (m/s)"),("low_level_jet_turning_from_geostrophic","Jet direction (degrees)")])
  ax=Axis(jf[i,j],xlabel="Time (h)",ylabel=label,title="Δ = $dx m")
  missing_reference!(ax)
  for c in cases
   c.dx==dx||continue
   y=copy(c.s[key]);y[c.s["low_level_jet_valid"].==0].=NaN
   j==3 && (y .*= 180/pi)
   curve!(ax,c,c.s["time_s"]./3600,y)
  end
  xlims!(ax,0,9)
 end
 push!(figures,finish(jf,"jet_evolution","GABLS1: low-level jet evolution","Instantaneous 60 s samples of the maximum horizontal-mean wind speed. Direction is atan(v, u) relative to eastward geostrophic wind.\nInvalid jet diagnostics are omitted; a changing peak height can jump between adjacent grid levels. No archived jet time series is available.",3,length(grids),cases;paper=false))
 for c in cases
  hvalid=all(c.s["boundary_layer_height_valid"][c.s["time_s"].>=28800].==1)
  h=hvalid ? timeaverage(c,"boundary_layer_height") : NaN
  h8valid=all(c.s["boundary_layer_height_valid"][(25200 .<= c.s["time_s"]).&(c.s["time_s"].<=28800)].==1)
h8=h8valid ? timeaverage(c,"boundary_layer_height",25200,28800) : NaN
w2drift=sqrt(mean(abs2,c.p["w_variance"][2].-c.p8["w_variance"][2]))
thetadrift=sqrt(mean(abs2,c.p["theta_mean"][2].-c.p8["theta_mean"][2]))
metric=(case_id=c.id,dx_m=c.dx,boundary_layer_height_m=h,ustar_m_s=timeaverage(c,"friction_velocity"),surface_heat_flux_W_m2=timeaverage(c,"surface_sensible_heat_flux"),peak_final_hour_w2=maximum(c.p["w_variance"][2]),minimum_theta_K=minimum(c.s["theta_minimum"]),maximum_abs_w_m_s=maximum(c.s["w_absolute_maximum"]),delta_h_last_two_hours_m=h-h8,w2_profile_last_hour_change_rms=w2drift,theta_profile_last_hour_change_rms=thetadrift,delta_heat_flux_last_two_hours_W_m2=timeaverage(c,"surface_sensible_heat_flux")-timeaverage(c,"surface_sensible_heat_flux",25200,28800))
 cost=get(COSTS,c.id,Dict())
 isempty(cost) || @assert cost["job_id"]==c.manifest["slurm_job_spec"]
 jetvalid=all(c.s["low_level_jet_valid"][c.s["time_s"].>=28800].==1)
 metric=merge(metric,(solver_wall_s=get(cost,"solver_wall_s",NaN),iterations=get(cost,"iterations",0),
                      mean_jet_height_m=jetvalid ? timeaverage(c,"low_level_jet_height") : NaN,
                      mean_jet_speed_m_s=jetvalid ? timeaverage(c,"low_level_jet_speed") : NaN,
                      h_final_hour_sample_std_m=hvalid ? std(c.s["boundary_layer_height"][c.s["time_s"].>=28800];corrected=false) : NaN,
                      max_resolved_momentum_flux_m2_s2=maximum(hypot.(c.p["resolved_u_w_flux"][2],c.p["resolved_v_w_flux"][2])),
                      max_sgs_momentum_flux_m2_s2=maximum(hypot.(c.p["sgs_u_w_flux"][2],c.p["sgs_v_w_flux"][2]))))
  push!(metrics,metric)
  desc=@sprintf("%s: final-hour h = %.1f m; ustar = %.3f m/s; surface heat flux = %.2f W/m²; peak mean w2 = %.4g m²/s².",c.id,h,metric.ustar_m_s,metric.surface_heat_flux_W_m2,metric.peak_final_hour_w2)
  desc *= @sprintf(" Between 7–8 and 8–9 h, h changed by %.1f m and the w2 profile changed by %.3g m²/s² RMS.",h-h8,w2drift)
 isfinite(metric.solver_wall_s) && (desc *= @sprintf(" Simulation wall time %.1f s (%d iterations), excluding preceding compilation/startup.",metric.solver_wall_s,metric.iterations))
  push!(admitted,Dict("case_id"=>c.id,"summary"=>desc))
audit=get(c.manifest,"physics_audit",Dict())
get(audit,"final_surface_theta_kinematic_flux_negative",true)===false && push!(findings,c.id*": final surface heat flux is not downward. This completed case is retained and flagged for physical diagnosis.")
 end
 writecsv(joinpath(ROOT,"simulation_data","final_hour_metrics.csv"),metrics)
 for dx in grids
  smag=findfirst(m->m.dx_m==dx && endswith(m.case_id,"weno9_smagorinsky"),metrics)
  none=findfirst(m->m.dx_m==dx && endswith(m.case_id,"weno9_none"),metrics)
  if smag!==nothing && none!==nothing
   sm,nn=metrics[smag],metrics[none]
   if sm.peak_final_hour_w2 < 0.001nn.peak_final_hour_w2
    push!(findings,@sprintf("At Δ=%.3g m, WENO9/Smagorinsky has strongly suppressed resolved turbulence: peak final-hour w2 is %.3g m²/s², %.3g times the no-closure value. Maximum magnitudes of the final-hour mean resolved and SGS momentum-flux vectors are %.3g and %.3g m²/s². Its h is %.1f m with only %.3g m standard deviation across final-hour 60 s samples. Similar h or mean wind can therefore coexist with very different resolved turbulence and transport partition; h alone cannot establish fidelity. Skewness in this weak-variance regime must not be interpreted as evidence of vigorous turbulent motions.",dx,sm.peak_final_hour_w2,sm.peak_final_hour_w2/nn.peak_final_hour_w2,sm.max_resolved_momentum_flux_m2_s2,sm.max_sgs_momentum_flux_m2_s2,sm.boundary_layer_height_m,sm.h_final_hour_sample_std_m))
   end
  end
  a=findfirst(m->m.dx_m==dx && endswith(m.case_id,"weno9_none"),metrics)
  b=findfirst(m->m.dx_m==dx && endswith(m.case_id,"weno5_none"),metrics)
  if a!==nothing && b!==nothing
   a,b=metrics[a],metrics[b]
   push!(findings,@sprintf("At Δ=%.3g m without interior closure, WENO9 versus WENO5 gives final-hour h %.1f versus %.1f m and peak resolved w2 %.4f versus %.4f m²/s². This is a scheme sensitivity at fixed grid and seed, not evidence of resolution convergence.",dx,a.boundary_layer_height_m,b.boundary_layer_height_m,a.peak_final_hour_w2,b.peak_final_hour_w2))
  end
 end
 for m in metrics
  rr=reference_profiles(m.dx_m,"w_variance")
  peaks=[maximum(Float64(x) for x in r["value"] if x!==nothing && isfinite(Float64(x))) for r in rr if any(x->x!==nothing && isfinite(Float64(x)),r["value"])]
  !isempty(peaks) && m.peak_final_hour_w2>maximum(peaks) && push!(findings,@sprintf("%s: peak final-hour resolved w2 (%.4f m²/s²) exceeds the largest archived model peak at the same spacing (%.4f m²/s²). Model spread is a comparison baseline, not observational truth; stronger resolved turbulence alone does not establish better fidelity.",m.case_id,m.peak_final_hour_w2,maximum(peaks)))
 end
 for (closure,order) in ORDER
  suffix="weno$(order)_$(closure)"
  mm=sort([m for m in metrics if endswith(m.case_id,suffix)],by=m->m.dx_m,rev=true)
  length(mm)>=2 || continue
  coarse,fine=first(mm),last(mm)
  push!(findings,@sprintf("Resolution comparison for WENO%d/%s: reducing spacing from %.3g to %.3g m changes final-hour h from %.1f to %.1f m and peak resolved w2 from %.4g to %.4g m²/s². Surface heat flux changes from %.2f to %.2f W/m². These compare the coarsest and finest completed grids for this configuration; similarity of selected quantities alone is not a convergence or fidelity test.",order,closure,coarse.dx_m,fine.dx_m,coarse.boundary_layer_height_m,fine.boundary_layer_height_m,coarse.peak_final_hour_w2,fine.peak_final_hour_w2,coarse.surface_heat_flux_W_m2,fine.surface_heat_flux_W_m2))
  if closure=="smagorinsky"
   push!(findings,@sprintf("For WENO9/Smagorinsky, the finest completed grid has %.3g times the coarsest-grid peak final-hour resolved w2. At Δ=%.3g m, maximum magnitudes of final-hour mean resolved and SGS momentum-flux vectors are %.4g and %.4g m²/s²; these maxima can occur at different heights and should not be treated as fractions of a common total. Final-hour h sample standard deviation is %.2f m, and mean h changed by %.2f m between 7–8 and 8–9 h. Read the variance evolution and flux profiles together: this resolution sensitivity does not establish statistical stationarity or identify a unique cause.",fine.peak_final_hour_w2/coarse.peak_final_hour_w2,fine.dx_m,fine.max_resolved_momentum_flux_m2_s2,fine.max_sgs_momentum_flux_m2_s2,fine.h_final_hour_sample_std_m,fine.delta_h_last_two_hours_m))
  end
 end
 push!(findings,"Final-hour values are descriptive results, not a fidelity ranking. Resolution comparisons must keep the scheme and closure fixed; archive ensemble membership changes with resolution.")
 push!(findings,"The archive reports skewness directly; its averaging convention is not assumed identical to our ratio of time-averaged central moments. No archive third moment is reconstructed from independently averaged variance and skewness. Both Breeze skewness plots mask levels with final-hour variance at or below 1e-8 m²/s²; the raw diagnostics remain available.")
end
!isempty(rejected)&&push!(findings,"$(length(rejected)) remotely verified cases failed local admission; see local_audit.json. They are excluded from plots.")
write(joinpath(ROOT,"reference_data","fixed_1m_medians.json"),JSON.json(Dict("grid_spacing_m"=>1.0,"description"=>"Pointwise median after interpolating each available 1 m archive model to common coordinates without extrapolation. Model-wise linear combinations precede interpolation and median. Missing values stay missing; no w3, time-mean stress magnitude or jet series synthesized.","curves"=>FIXED_EXPORT)))
push!(findings,"A fixed 1.0 m archive ensemble median (black dotted line) is repeated across resolution panels wherever a matching quantity is available, alongside same-grid archive spread. The 1.0 m archive has two models; pointwise member counts and source files are saved in reference_data/fixed_1m_medians.json. Linear totals and resolved TKE are computed per model before taking medians. No matching reference is fabricated for w3, time-mean stress magnitude, unmatched budget terms, wall-regime fractions, peak-variance time series or jet time series. The fixed reference aids resolution comparisons but is not an exact solution.")
push!(findings,"The 1.0 m IMUK archive contains conspicuously large upper-level SGS values, confirmed in the original files: SGS uw spans -0.872 to 0.869 m²/s² and SGS shear production spans -0.283 to 0.793 m²/s³. Tiny values approaching 1e-100 abruptly become order-one values above roughly 330 m. This pattern suggests an archive exponent-format problem, but the intended values have not been established. Raw values and resulting median curves are retained, with affected flux/budget panels flagged. Do not interpret those upper-level excursions as a convergence target.")
write(joinpath(ROOT,"local_audit.json"),JSON.json(Dict("checked_utc"=>string(now(UTC))*"Z","accepted"=>[c.id for c in cases],"rejected"=>rejected)))
write(joinpath(ROOT,"results_summary.json"),JSON.json(Dict("verified_cases"=>admitted,"figures"=>figures,"findings"=>findings,"language"=>"Julia","updated_utc"=>string(now(UTC))*"Z")))
println("GABLS_PLOTS_COMPLETE verified=$(length(cases)) rejected=$(length(rejected)) figures=$(length(figures))")
