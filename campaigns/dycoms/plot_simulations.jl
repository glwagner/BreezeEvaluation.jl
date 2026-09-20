#!/usr/bin/env julia
using CairoMakie, Statistics, JSON, Printf
include("dycoms_data.jl")
using .DYCOMSData
CairoMakie.activate!()
set_theme!(Theme(fontsize=16, Axis=(xgridcolor=(:black,.09),ygridcolor=(:black,.09), topspinevisible=false,rightspinevisible=false), Legend=(labelsize=15,)))
const OUT=joinpath(ROOT,"report_figures")
mkpath(OUT)
const STYLE=Dict(("none",9)=>("#0072B2",:solid,:circle), ("none",5)=>("#D55E00",:dash,:rect), ("smagorinsky",9)=>("#009E73",:dashdot,:utriangle), ("smagorinsky",5)=>("#CC79A7",:dot,:diamond), ("smagorinsky",2)=>("#000000",:dashdotdot,:star5))
const ORDER=[("none",9),("none",5),("smagorinsky",9),("smagorinsky",5),("smagorinsky",2)]
const GRID=["coarse","canonical","fine"]
const GLABEL=Dict("coarse"=>"Coarse: Δx = 80 m, Δz = 20 m", "canonical"=>"Canonical: Δx = 35 m, Δz = 5 m", "fine"=>"Fine: Δx = 10 m, Δz = 5 m")
const cases=load_cases()
const stats=metrics!(cases)
const groups=[(g,filter(c->c.grid==g,cases)) for g in GRID if any(c->c.grid==g,cases)]
const N=length(groups)
const obs4=table(joinpath(ROOT,"data","figure4_observation_centers.csv"))
const obs5=table(joinpath(ROOT,"data","figure5_observation_centers.csv"))
const ref=table(joinpath(ROOT,"data","figure2_ensemble_means.csv"))
const env=table(joinpath(ROOT,"data","figure2_ensemble_envelope.csv"))
short(key)=(key[2]==2 ? "Centered2" : "WENO$(key[2])")*" / "*(key[1]=="none" ? "no SGS" : "Smagorinsky")
function curve!(ax,c,x,y)
    color,ls,marker=STYLE[(c.closure,c.order)]
    lines!(ax,x,y,color=color,linewidth=2.6,linestyle=ls)
    step=max(1,round(Int,length(x)/13));offset=findfirst(==((c.closure,c.order)),ORDER)
    ii=collect(offset:step:length(x))
    scatter!(ax,x[ii],y[ii],color=:white,strokecolor=color,strokewidth=1.6,marker=marker,markersize=8)
end
function caselegend!(f,row,ncol;paper=false)
    elems=Any[];labels=String[]
    for key in ORDER
        any(c->(c.closure,c.order)==key,cases) || continue
        color,ls,marker=STYLE[key]
        push!(elems,[LineElement(color=color,linestyle=ls,linewidth=2.6),MarkerElement(color=:white,strokecolor=color,strokewidth=1.5,marker=marker,markersize=9)])
        push!(labels,short(key))
    end
    if paper
        append!(elems,[PolyElement(color="#E1E1E1"),PolyElement(color="#B3B3B3"),LineElement(color=:black,linestyle=:dot,linewidth=1.8)])
        append!(labels,["Paper model min–max","Paper model interquartile range","Paper model mean"])
    end
    Legend(f[row,1:ncol],elems,labels,orientation=:horizontal,nbanks=paper ? 3 : 2,framevisible=false,patchsize=(42,15),colgap=22,tellwidth=false)
end
function wrap(s,n=120)
    lines=String[];line=""
    for word in split(s)
        if length(line)+length(word)+1>n;push!(lines,line);line=word
        else;line=isempty(line) ? word : line*" "*word;end
    end
    isempty(line)||push!(lines,line);join(lines,"\n")
end
function finish(f,name,title,caption;lastrow,ncol,paper=false)
    Label(f[0,1:ncol],title,fontsize=23,font=:bold,tellwidth=false)
    caselegend!(f,lastrow+1,ncol;paper)
    Label(f[lastrow+2,1:ncol],wrap(caption,N>1 ? 160 : 125),fontsize=13,halign=:left,justification=:left,tellwidth=false)
    rowgap!(f.layout,16)
    for ext in ("png","svg","pdf");save(joinpath(OUT,name*"."*ext),f;px_per_unit=ext=="png" ? 1.6 : 1);end
    println("JULIA_FIGURE ",name)
end
function bandsegments!(ax,x,lo,hi;color)
    ok=isfinite.(lo).&isfinite.(hi);start=0
    for i in 1:length(x)+1
        if i<=length(x) && ok[i]
            start==0 && (start=i)
        elseif start>0
            i-start>=2 && band!(ax,x[start:i-1],lo[start:i-1],hi[start:i-1],color=color)
            start=0
        end
    end
end
function paper!(ax,var)
    r=filter(r->r.variable==var,env);x=num.(getproperty.(r,:time_h))
    low=num.(getproperty.(r,:minimum));hi=num.(getproperty.(r,:maximum));q1=num.(getproperty.(r,:q25));q3=num.(getproperty.(r,:q75))
    if var=="cloud_fraction";low=clamp.(low,0,1);hi=clamp.(hi,0,1);q1=clamp.(q1,0,1);q3=clamp.(q3,0,1);end
    bandsegments!(ax,x,low,hi;color="#E1E1E1")
    bandsegments!(ax,x,q1,q3;color="#B3B3B3")
    r=filter(r->r.variable==var,ref)
    lines!(ax,num.(getproperty.(r,:time_h)),num.(getproperty.(r,:value)),color=:black,linewidth=1.6,linestyle=:dot)
end

# Zoomed cloud-fraction row AND full-range context: no hidden model-envelope tails.
f=Figure(size=(max(1100,650N),1160))
axs=Matrix{Axis}(undef,4,N)
cfmin=minimum(minimum(c.s["cloud_fraction"]) for c in cases)
zoomlo=max(0,min(.975,floor((cfmin-.003)*200)/200))
for (col,(g,cs)) in enumerate(groups)
    for (row,(key,scale,label,rv)) in enumerate([
        ("lwp_mean",1000.,"LWP (g m⁻²)","LWP"),
        ("cloud_fraction",1.,"Cloud fraction (zoom)","cloud_fraction"),
        ("cloud_fraction",1.,"Cloud fraction (full range)","cloud_fraction"),
        ("resolved_tke_vertical_integral",1.,"Resolved TKE integral (m³ s⁻²)","vertically_integrated_TKE")])
        ax=Axis(f[row,col],title=row==1 ? GLABEL[g] : "",ylabel=col==1 ? label : "",xlabel=row==4 ? "Simulation time (h)" : "")
        axs[row,col]=ax
        row==2 || paper!(ax,rv) # Zoom is for Breeze: do not magnify raster-band edge uncertainty.
        vspan!(ax,3,4,color=(:black,.025))
        for c in cs;curve!(ax,c,c.s["time_s"]./3600,c.s[key].*scale);end
        xlims!(ax,0,4)
        if row==2;ylims!(ax,zoomlo,1.002);hlines!(ax,[.99],color="#666666",linestyle=:dash,linewidth=1)
        elseif row==3;ylims!(ax,0,1.02);end
    end
end
for row in 1:4;linkyaxes!(axs[row,:]...);end
finish(f,"evolution","Cloud persistence and turbulence evolution",
 "Gray bands: digitized MODEL spread (Stevens et al. 2005, Fig. 2), not observational uncertainty. Cloud-fraction zoom shows Breeze curves; the full-range row shows the paper envelope. Unresolved early shading is omitted. TKE is resolved only. All plots: Julia/CairoMakie.",lastrow=4,ncol=N,paper=true)

function profilefigure(name,title,defs;observations=nothing,ylim=(0,1100))
    nc=length(defs);f=Figure(size=(nc==2 ? 1100 : 1250,560N+200));axes=Matrix{Axis}(undef,N,nc)
    for (row,(g,cs)) in enumerate(groups), (col,(key,scale,label,ov)) in enumerate(defs)
        ax=Axis(f[row,col],ylabel=col==1 ? GLABEL[g]*"\nHeight (m)" : "",xlabel=label)
        axes[row,col]=ax
        for c in cs
            z,v=prof(c,key);curve!(ax,c,v.*scale,z)
        end
        if observations===obs4
            r=filter(r->r.variable==ov,obs4)
            scatter!(ax,num.(getproperty.(r,:value)),num.(getproperty.(r,:height_m)),color=:black,marker=:rect,markersize=10)
        elseif observations===obs5
            for (instrument,marker) in (("in_situ",:rect),("radar",:circle))
                r=filter(r->r.variable==ov && r.instrument==instrument,obs5)
                scatter!(ax,num.(getproperty.(r,:value)),num.(getproperty.(r,:height_m)),color=instrument=="in_situ" ? :black : :white,strokecolor=:black,strokewidth=1.5,marker=marker,markersize=10)
            end
        end
        ylims!(ax,ylim...)
    end
    for col in 1:nc;linkxaxes!(axes[:,col]...);end
    caption=observations===obs5 ? "Fourth-hour means on native w faces. Black squares: retained in-situ observations; black open circles: radar (paper Fig. 5). Error bars were not digitized. Colors, line patterns and marker shapes identify numerical configurations; rows identify resolutions." : "Fourth-hour means combine the two half-hour profile averages ending at 12600 and 14400 s. Black squares: retained paper Fig. 4 observations; measurement error bars were not digitized. Shared axis scales across resolutions."
    finish(f,name,title,caption,lastrow=N,ncol=nc)
end
profilefigure("mean_profiles","Fourth-hour thermodynamic structure",[("theta_li_mean",1.,"θₗ (K)","theta_l"),("q_t_mean",1000.,"qₜ (g kg⁻¹)","q_t"),("q_l_mean",1000.,"qₗ (g kg⁻¹)","q_l")];observations=obs4)
profilefigure("vertical_velocity_moments","Fourth-hour vertical-velocity moments",[("w_variance",1.,"⟨w′²⟩ (m² s⁻²)","variance"),("w_third_central_moment",1.,"⟨w′³⟩ (m³ s⁻³)","third_moment")];observations=obs5,ylim=(0,1000))

f=Figure(size=(1250,560N+200));axes=Matrix{Axis}(undef,N,3)
for (row,(g,cs)) in enumerate(groups),col in 1:3
    ax=Axis(f[row,col],ylabel=col==1 ? GLABEL[g]*"\nHeight (m)" : "",xlabel=["Resolved + SGS w′θₗ′ (K m s⁻¹)","Resolved + SGS w′qₜ′ (g kg⁻¹ m s⁻¹)","Resolved w′b′ (cm² s⁻³)"][col]);axes[row,col]=ax
    for c in cs
        z,h=prof(c,"resolved_w_theta_li_flux");_,hs=prof(c,"sgs_theta_li_flux");_,q=prof(c,"resolved_w_q_t_flux");_,qs=prof(c,"sgs_q_t_flux");_,b=prof(c,"resolved_buoyancy_flux")
        v=(h.+hs,1000 .* (q.+qs),1e4 .*b)[col];curve!(ax,c,v,z)
    end
    vlines!(ax,[0],color=(:black,.3),linewidth=1);ylims!(ax,0,1100)
end
for col in 1:3;linkxaxes!(axes[:,col]...);end
finish(f,"flux_profiles","Fourth-hour scalar transport and buoyancy production","Scalar panels add resolved covariance and explicit SGS flux; buoyancy production is resolved only. Numerical transport is not separately measured, so resolved + SGS is not a complete discrete flux budget.",lastrow=N,ncol=3)

f=Figure(size=(max(1100,650N),950));axes=Matrix{Axis}(undef,3,N)
for (col,(g,cs)) in enumerate(groups), (row,(key,scale,label)) in enumerate([("q_t_8gkg_inversion_height_mean",1.,"Inversion qₜ = 8 g/kg (m)"),("cloud_base_mean",1.,"Cloud base (m)"),("decoupling_delta_q_t",1000.,"Δqₜ lower − upper (g/kg)")])
    ax=Axis(f[row,col],title=row==1 ? GLABEL[g] : "",ylabel=col==1 ? label : "",xlabel=row==3 ? "Simulation time (h)" : "");axes[row,col]=ax
    for c in cs;curve!(ax,c,c.s["time_s"]./3600,c.s[key].*scale);end
    vspan!(ax,3,4,color=(:black,.04));xlims!(ax,0,4)
end
for row in 1:3;linkyaxes!(axes[row,:]...);end
finish(f,"boundaries_decoupling","Cloud boundaries and decoupling","Cloud-base height is conditional on cloudy columns. Inversion height uses the interpolated qₜ contour. Δqₜ = mean(100–200 m) − mean(700–800 m), using exact geometric layer overlap.",lastrow=3,ncol=N)

f=Figure(size=(1100,680));axs=[Axis(f[1,k],xlabel="Resolution / horizontal domain",ylabel=k==1 ? "Fourth-hour LWP (g m⁻²)" : "Descriptive w² marker RMSE (m² s⁻²)",xticks=(1:3,["80 × 20 m\n7.68 km","35 × 5 m\n3.36 km","10 × 5 m\n3.36 km"])) for k in 1:2]
for r in stats
    key=(r.closure,r.advection_order);color,ls,marker=STYLE[key]
    x=findfirst(==(r.grid),GRID)+.12*(findfirst(==(key),ORDER)-3)
    rangebars!(axs[1],[x],[min(r.LWP_first_half_g_m2,r.LWP_second_half_g_m2)],[max(r.LWP_first_half_g_m2,r.LWP_second_half_g_m2)],color=color,linewidth=2)
    for (ax,v) in zip(axs,(r.LWP_g_m2,r.w2_insitu_marker_RMSE));scatter!(ax,[x],[v],marker=marker,color=:white,strokecolor=color,strokewidth=2,markersize=13);end
end
for ax in axs;xlims!(ax,.5,3.5);end
finish(f,"factorial_summary","Resolution and numerical choices","Only completed cases appear. LWP bars span two half-hour means, not confidence intervals. Marker RMSE is an unweighted descriptive distance to retained in-situ observations, not an uncertainty-normalized validation score.",lastrow=1,ncol=2)
write(joinpath(OUT,"plot_provenance.json"),JSON.json(Dict("language"=>"Julia","julia"=>string(VERSION),"CairoMakie"=>string(pkgversion(CairoMakie)),"cases"=>[c.id for c in cases],"cloud_fraction_zoom_limits"=>[zoomlo,1.002],"ensemble_source"=>"data/figure2_ensemble_envelope.csv","styles"=>"Okabe-Ito colors + dash patterns + marker shapes; resolution panels share scales")))
println("ALL_JULIA_PLOTS_COMPLETE cases=",length(cases))
if any(c->c.scheme=="Centered",cases)
    mf=Figure(size=(1450,730));ma=Axis[]
    for (j,g) in enumerate(GRID)
        ax=Axis(mf[1,j],title=GLABEL[g],xlabel="Simulation time (h)",ylabel="Global qₜ extrema (g/kg)");push!(ma,ax)
        hlines!(ax,[0],color="#D55E00",linestyle=:dot,linewidth=1.5)
        cc=filter(c->c.grid==g && c.scheme=="Centered",cases)
        if isempty(cc)
            text!(ax,2,0,text="Awaiting completed export",align=(:center,:bottom),fontsize=15,color=:gray)
        else
            c=only(cc);rr=table(joinpath(ROOT,"simulation_data",c.id,"moisture_extrema.csv"))
            t=num.(getproperty.(rr,:time_s))./3600;lo=1000num.(getproperty.(rr,:q_t_min));hi=1000num.(getproperty.(rr,:q_t_max))
            @assert minimum(lo)==1000c.moisture.minimum && maximum(hi)==1000c.moisture.maximum
            lines!(ax,t,lo,color=:black,linestyle=:dashdotdot,linewidth=2.5)
            scatter!(ax,t[1:20:end],lo[1:20:end],marker=:star5,color=:black,markersize=9)
            lines!(ax,t,hi,color="#777777",linestyle=:dash,linewidth=2.5)
        end
        xlims!(ax,0,4)
    end
    linkyaxes!(ma...)
    Label(mf[0,1:3],"Unbounded Centered2 + Smagorinsky: moisture extrema",fontsize=24)
    Legend(mf[2,1:3],[LineElement(color=:black,linestyle=:dashdotdot),LineElement(color="#777777",linestyle=:dash),LineElement(color="#D55E00",linestyle=:dot)],["Minimum qₜ (star markers)","Maximum qₜ","Zero total water"],orientation=:horizontal,framevisible=false,tellwidth=false)
    Label(mf[3,1:3],"Global spatial extrema sampled every 60 s; excursions between samples are not bounded by these curves.\nNegative total water is physically inadmissible. Finite output does not establish physical validity; no clipping or WENO fallback was applied.",fontsize=14)
    for ext in ("png","svg","pdf");save(joinpath(OUT,"moisture_extrema.$ext"),mf,px_per_unit=ext=="png" ? 1.6 : 1);end
    println("JULIA_FIGURE moisture_extrema")
end
