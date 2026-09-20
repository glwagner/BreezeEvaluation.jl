#!/usr/bin/env julia
# Can run alone or from plot_reference.jl; module isolates names from its caller.
module SkewnessComparison
using CairoMakie, Statistics, JSON
include("../dycoms_data.jl")
using .DYCOMSData
const D=@__DIR__
const TIMES=(9000.,10800.,12600.,14400.)
const VAR_FLOOR=1e-6 # m²/s²; ratios near zero turbulence are not meaningful.
const configs=[("none",9,"99NN","#0072B2",:circle,:solid),
 ("none",5,"55NN","#D55E00",:rect,:dash),
 ("smagorinsky",9,"99MS","#009E73",:utriangle,:dashdot),
 ("smagorinsky",5,"55MS","#CC79A7",:diamond,:dot),
 ("smagorinsky",2,"22MS","#000000",:star5,:dashdotdot)]
label(cl,o)=(o==2 ? "Centered2" : "WENO$o")*" / "*(cl=="none" ? "no SGS" : "Smagorinsky")
safe_skew(m2,m3)=m2>VAR_FLOOR ? m3/m2^1.5 : NaN
function derive(c)
 raw=table(joinpath(ROOT,"simulation_data",c.id,"profiles.csv"))
 fields=Dict{String,Matrix{Float64}}();zref=Float64[]
 for key in ("w_variance","w_third_central_moment")
  cols=Vector{Float64}[]
  for t in TIMES
   rows=sort(filter(r->r.variable==key && num(r.time_s)==t,raw),by=r->num(r.z_m))
   @assert !isempty(rows)
   @assert all(r->r.record_kind=="preceding_1800s_average" && num(r.window_start_s)==t-1800 && num(r.window_end_s)==t,rows)
   z=num.(getproperty.(rows,:z_m))
   isempty(zref) ? (zref=z) : (@assert z==zref)
   push!(cols,num.(getproperty.(rows,:value)))
  end
  fields[key]=hcat(cols...)
 end
 m2=fields["w_variance"];m3=fields["w_third_central_moment"]
 @assert all(isfinite,m2) && all(isfinite,m3) && minimum(m2)>=0
 v2=vec(mean(m2,dims=2));v3=vec(mean(m3,dims=2))
 sw=safe_skew.(v2,v3)
 # This is only a sensitivity diagnostic, not the unrecoverable mean of instantaneous skewness.
 binmean=vec(mean(safe_skew.(m2,m3),dims=2))
 (z=zref,m2=v2,m3=v3,sw=sw,binmean=binmean)
end
function drawcurve!(ax,x,z,col,mark;style=:solid)
 lines!(ax,x,z,color=col,linewidth=2.6,linestyle=style)
 ii=findall(i->isfinite(x[i]) && 0<z[i]<1000,eachindex(z))[1:12:end]
 scatter!(ax,x[ii],z[ii],marker=mark,color=:white,strokecolor=col,strokewidth=1.5,markersize=9)
end
function savefig(name,f)
 for ext in ("png","svg","pdf")
  save(joinpath(D,"figures","$name.$ext"),f,px_per_unit=ext=="png" ? 1.5 : 1)
 end
end
CairoMakie.activate!();set_theme!(fontsize=17)
cases=load_cases();profiles=Dict(c.id=>derive(c) for c in cases)
rows=[];checks=[];windows=[]
for c in cases
 p=profiles[c.id]
 z4,m24=prof(c,"w_variance");z34,m34=prof(c,"w_third_central_moment");@assert z4==z34
 for (window,z,m2,m3) in (("2-4 h",p.z,p.m2,p.m3),("3-4 h",z4,m24,m34))
  sw=safe_skew.(m2,m3);ii=findall(i->600<=z[i]<=760 && isfinite(sw[i]),eachindex(z))
  push!(windows,(case_id=c.id,grid=c.grid,window=window,min_w3_600_760_m3_s3=minimum(m3[ii]),
   max_w3_600_760_m3_s3=maximum(m3[ii]),min_skewness_600_760=minimum(sw[ii]),max_skewness_600_760=maximum(sw[ii])))
 end
 for i in eachindex(p.z)
  push!(rows,(case_id=c.id,grid=c.grid,window_start_s=7200,window_end_s=14400,z_m=p.z[i],
   w_variance_m2_s2=p.m2[i],w_third_central_moment_m3_s3=p.m3[i],
   skewness_ratio_of_time_averaged_moments=p.sw[i],
   mean_of_four_halfhour_skewness_ratios=p.binmean[i],valid=p.m2[i]>VAR_FLOOR))
 end
 idx=findall(i->600<=p.z[i]<=760 && isfinite(p.sw[i]) && isfinite(p.binmean[i]),eachindex(p.z))
 push!(checks,(case_id=c.id,min_skewness_600_760m=minimum(p.sw[idx]),max_skewness_600_760m=maximum(p.sw[idx]),
  max_normalization_order_difference_600_760m=maximum(abs.(p.sw[idx].-p.binmean[idx])),
  excluded_low_variance_levels=count(!isfinite,p.sw)))
end
writecsv(joinpath(D,"data","breeze_skewness_2_4h.csv"),rows)
writecsv(joinpath(D,"data","breeze_skewness_audit.csv"),checks)
writecsv(joinpath(D,"data","velocity_window_comparison.csv"),windows)
paper=table(joinpath(D,"data","figure7_w_skewness.csv"))
matched=[(conf,c) for conf in configs for c in cases if c.grid=="canonical" && c.closure==conf[1] && c.order==conf[2]]
@assert !isempty(matched)
nc=min(3,length(matched));nr=cld(length(matched),nc)
f=Figure(size=(440nc,800nr+160))
for (j,(conf,c)) in enumerate(matched)
 cl,o,id,col,mark,style=conf;r,k=divrem(j-1,nc);p=profiles[c.id]
 a=Axis(f[2r+1,k+1],title=label(cl,o)*"\nPressel $id",xlabel="Vertical-velocity skewness",ylabel="Height (m)")
 vlines!(a,[0],color=(:black,.25),linewidth=1)
 rr=sort(filter(x->x.case_id==id,paper),by=x->num(x.coordinate_value))
 lines!(a,num.(getproperty.(rr,:value)),num.(getproperty.(rr,:coordinate_value)),color="#6B6B6B",linestyle=:dash,linewidth=2.7)
 drawcurve!(a,p.sw,p.z,col,mark)
 xlims!(a,-.75,4.2);ylims!(a,0,1000)
 b=Axis(f[2r+2,k+1],title="Cloud-base detail",xlabel="Vertical-velocity skewness",ylabel="Height (m)")
 vlines!(b,[0],color=(:black,.3),linewidth=1)
 lines!(b,num.(getproperty.(rr,:value)),num.(getproperty.(rr,:coordinate_value)),color="#6B6B6B",linestyle=:dash,linewidth=2.7)
 drawcurve!(b,p.sw,p.z,col,mark)
 xlims!(b,-.5,.5);ylims!(b,500,800)
end
Label(f[0,1:nc],"Breeze and Pressel Figure 7: skewness, hours 2–4",fontsize=24)
Legend(f[2nr+1,1:nc],[LineElement(color="#0072B2",linewidth=2.6),LineElement(color="#6B6B6B",linestyle=:dash,linewidth=2.7)],
 ["Breeze: colored solid + symbols","Pressel model: gray dashed"],orientation=:horizontal,framevisible=false)
Label(f[2nr+2,1:nc],"Canonical grid: Δx = 35 m, Δz = 5 m. Breeze uses the ratio of time-averaged central moments.\nPressel normalization/averaging order is unverified; these are model curves, not observations.\nTop: 0–1000 m. Bottom: magnified 500–800 m. Low-variance levels masked. Model settings differ.",fontsize=14)
savefig("breeze_skewness_comparison",f)
g=Figure(size=(1400,780));els=Any[];labels=String[]
for (j,grid) in enumerate(("coarse","canonical","fine"))
 title=Dict("coarse"=>"Coarse: 80 m / 20 m","canonical"=>"Canonical: 35 m / 5 m","fine"=>"Fine: 10 m / 5 m")[grid]
 a=Axis(g[1,j],title=title,xlabel="Vertical-velocity skewness",ylabel="Height (m)")
 vlines!(a,[0],color=(:black,.25),linewidth=1)
 cc=filter(c->c.grid==grid,cases)
 for (cl,o,id,col,mark,style) in configs
  found=filter(c->c.closure==cl && c.order==o,cc);isempty(found)&&continue
  p=profiles[only(found).id];drawcurve!(a,p.sw,p.z,col,mark;style)
 end
 isempty(cc) && text!(a,1.7,500,text="No completed exports",align=(:center,:center),color=:gray)
 xlims!(a,-.75,4.2);ylims!(a,0,1000)
end
for (cl,o,id,col,mark,style) in configs
 any(c->c.closure==cl && c.order==o,cases)||continue
 push!(els,[LineElement(color=col,linestyle=style),MarkerElement(marker=mark,color=:white,strokecolor=col)])
 push!(labels,label(cl,o))
end
Label(g[0,1:3],"Breeze skewness across resolutions: hours 2–4",fontsize=25)
Legend(g[2,1:3],els,labels,orientation=:horizontal,nbanks=2,framevisible=false,tellwidth=false)
Label(g[3,1:3],"Ratio of 2–4 h averaged central moments; not the time average of instantaneous skewness.\nOnly completed exports shown. Coarse horizontal domain is larger. Variance ≤ 10⁻⁶ m²/s² is masked; full-height values are in CSV.",fontsize=15)
savefig("breeze_skewness_resolutions",g)
open(joinpath(D,"data","skewness_provenance.json"),"w") do io
 JSON.print(io,Dict("definition"=>"mean_t(w_third_central_moment) / mean_t(w_variance)^1.5",
  "window_s"=>[7200,14400],"half_hour_record_end_times_s"=>collect(TIMES),"variance_floor_m2_s2"=>VAR_FLOOR,
  "vertical_location"=>"native w faces","instantaneous_skewness_time_average_available"=>false,
  "paper_time_normalization_order"=>"Not unambiguously specified in paper; raw 60 s output unavailable",
  "normalization_sensitivity"=>"Mean of four half-hour ratios is retained as a sensitivity check, not an exact instantaneous-skewness average",
  "paper_curves"=>"Figure 7 model curves from PDF vector extraction, not observations",
  "cases"=>[c.id for c in cases]),2)
end
println("SKEWNESS_COMPLETE cases=",length(cases)," canonical_matches=",length(matched))
foreach(println,checks)
end
