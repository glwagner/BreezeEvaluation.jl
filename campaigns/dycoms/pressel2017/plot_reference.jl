#!/usr/bin/env julia
using CairoMakie, Statistics, JSON
include("../dycoms_data.jl");using .DYCOMSData
const D=@__DIR__
CairoMakie.activate!();set_theme!(fontsize=16)
const groups=["Mixed-SGS","Paired-SGS","Mixed-NSGS","Paired-NSGS"]
const palette=["#0072B2","#D55E00","#009E73","#CC79A7","#E69F00","#000000"]
const marks=[:circle,:rect,:utriangle,:diamond,:dtriangle,:star5]
const styles=[:solid,:dash,:dashdot,:dot,:dashdotdot,:solid]
const defs=[(1,"q_l","qₗ (kg/kg)",true),(2,"cloud_fraction","Cloud fraction",false),(3,"LWP","LWP (g/m²)",false),(4,"q_t","qₜ (kg/kg)",true),(5,"theta_l","θₗ (K)",true),(6,"w_variance","⟨w′²⟩ (m²/s²)",true),(7,"w_skewness","w skewness",true)]
for (fig,var,label,profile) in defs
 rows=table(joinpath(D,"data","figure$(fig)_$var.csv"));f=Figure(size=(1150,1050));axes=[]
 for (j,g) in enumerate(groups)
  rr=filter(r->r.experiment==g,rows);i,k=divrem(j-1,2);a=Axis(f[2i+1,k+1],title=g,xlabel=profile ? label : "Time (h)",ylabel=profile ? "Height (m)" : label);push!(axes,a)
  for (ci,id) in enumerate(unique(r.case_id for r in rr))
   cc=filter(r->r.case_id==id,rr);v=num.(getproperty.(cc,:value));q=num.(getproperty.(cc,:coordinate_value));x,y=profile ? (v,q) : (q,v)
   lines!(a,x,y,color=palette[ci],linestyle=styles[ci],linewidth=2.2,label=id)
   ii=ci:15:length(x);scatter!(a,x[ii],y[ii],marker=marks[ci],color=:white,strokecolor=palette[ci],strokewidth=1.2,markersize=7)
  end
  profile ? ylims!(a,0,1200) : xlims!(a,0,4)
  var=="cloud_fraction" && ylims!(a,.1,1.03)
  Legend(f[2i+2,k+1],a,orientation=:horizontal,nbanks=2,framevisible=false,tellwidth=false)
 end
 profile ? linkxaxes!(axes...) : linkyaxes!(axes...)
 Label(f[0,1:2],"Pressel et al. (2017), Figure $fig: recovered model curves",fontsize=22)
 Label(f[5,1:2],profile ? "Profiles: hours 2–4. Reconstructed in Julia from PDF vector geometry; these are model curves, not observations." : "Resampled PDF curves, not original LES output. Published bulk means independently check the extraction.",fontsize=13)
 save(joinpath(D,"figures","reconstructed_figure$fig.png"),f,px_per_unit=1.4)
end
# A separate comparison uses the paper's 2–4h window; the Stevens 3–4h plots remain separate.
cs=filter(c->c.grid=="canonical",load_cases());f=Figure(size=(1550,1180));summary=[]
configs=[("none",9,"99NN","#0072B2",:circle),("none",5,"55NN","#D55E00",:rect),("smagorinsky",9,"99MS","#009E73",:utriangle),("smagorinsky",5,"55MS","#CC79A7",:diamond),("smagorinsky",2,"22MS","#000000",:star5)]
paperbulk=table(joinpath(D,"data","case_configuration_and_bulk_results.csv"))
function profile24(c,key)
 raw=table(joinpath(ROOT,"simulation_data",c.id,"profiles.csv"));rs=filter(r->r.variable==key && num(r.time_s) in (9000,10800,12600,14400),raw)
 zs=sort(unique(num(r.z_m) for r in rs));v=[mean(num(r.value) for r in rs if num(r.z_m)==z) for z in zs]
 @assert all(z->count(r->num(r.z_m)==z,rs)==4,zs)
 zs,v
end
panels=[("LWP",3,"LWP (g/m²)",false),("cloud_fraction",2,"Cloud fraction",false),("q_l",1,"qₗ (g/kg)",true),("q_t",4,"qₜ (g/kg)",true),("theta_l",5,"θₗ (K)",true),("w_variance",6,"⟨w′²⟩ (m²/s²)",true)]
for (j,(var,fig,label,profile)) in enumerate(panels)
 i,k=divrem(j-1,3);a=Axis(f[i+1,k+1],xlabel=profile ? label : "Time (h)",ylabel=profile ? "Height (m)" : label)
 data=table(joinpath(D,"data","figure$(fig)_$var.csv"))
 cfmin=1.0
 for (closure,order,id,col,marker) in configs
  cc=filter(c->c.closure==closure && c.order==order,cs);isempty(cc)&&continue;c=only(cc)
  r=filter(r->r.case_id==id,data);q=num.(getproperty.(r,:coordinate_value));v=num.(getproperty.(r,:value));scale=var in ("q_l","q_t") ? 1000 : 1
  px,py=profile ? (scale.*v,q) : (q,v)
  lines!(a,px,py,color=col,linestyle=:dash,linewidth=2)
  if profile
   key=Dict("q_l"=>"q_l_mean","q_t"=>"q_t_mean","theta_l"=>"theta_li_mean","w_variance"=>"w_variance")[var]
   z,b=profile24(c,key);bx,by=scale.*b,z
  else
   key=var=="LWP" ? "lwp_mean" : "cloud_fraction";bx=c.s["time_s"]./3600;by=c.s[key].*(var=="LWP" ? 1000 : 1)
   var=="cloud_fraction" && (cfmin=min(cfmin,minimum(v),minimum(by)))
  end
  lines!(a,bx,by,color=col,linewidth=2.5)
  ii=5:20:length(bx);scatter!(a,bx[ii],by[ii],marker=marker,color=:white,strokecolor=col,strokewidth=1.2,markersize=8)
 end
 profile ? ylims!(a,0,1100) : xlims!(a,0,4)
 var=="cloud_fraction"&&ylims!(a,max(0,min(.975,floor((cfmin-.003)*200)/200)),1.002)
end
els=Any[];labels=String[]
for (cl,o,id,col,m) in configs
 any(c->c.closure==cl&&c.order==o,cs)||continue
 push!(els,[LineElement(color=col),MarkerElement(marker=m,color=:white,strokecolor=col)]);push!(labels,(o==2 ? "Centered2" : "WENO$o")*" / "*(cl=="none" ? "no SGS" : "Smagorinsky")*" ($id)")
 c=only(filter(c->c.closure==cl&&c.order==o,cs));pb=only(filter(r->r.case_id==id,paperbulk))
 push!(summary,(breeze_case_id=c.id,pressel_case_id=id,averaging="2-4 h",breeze_LWP_g_m2=1000avg(c,"lwp_mean",7200,14400),pressel_LWP_g_m2=num(pb.LWP_g_m2_2_4h),breeze_cloud_fraction=avg(c,"cloud_fraction",7200,14400),pressel_cloud_fraction=num(pb.cloud_fraction_2_4h)))
end
append!(els,[LineElement(color=:black,linestyle=:solid),LineElement(color=:black,linestyle=:dash)]);append!(labels,["Breeze","Pressel model"])
Legend(f[3,1:3],els,labels,orientation=:horizontal,nbanks=2,framevisible=false,tellwidth=false)
Label(f[0,1:3],"Canonical grid: Breeze and Pressel et al. (2017)",fontsize=25)
Label(f[4,1:3],"35 m horizontal / 5 m vertical; same domain. Profiles average 2–4 h. Cloud-fraction axis zoomed. Only completed Breeze cases shown.\nScheme-family comparison: Cs, Pr, CFL, thermodynamics, surface treatment and moisture handling differ; this is not a replication.",fontsize=14)
for ext in ("png","svg","pdf");save(joinpath(D,"figures","breeze_comparison.$ext"),f,px_per_unit=ext=="png" ? 1.5 : 1);end
writecsv(joinpath(D,"data","breeze_bulk_comparison_2_4h.csv"),summary)
println("PRESSEL_REFERENCE_PLOTS_COMPLETE; matched completed cases=",length(summary))
include("plot_skewness.jl")
