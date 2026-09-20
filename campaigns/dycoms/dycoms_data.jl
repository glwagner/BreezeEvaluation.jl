module DYCOMSData
using JSON, Statistics, Printf
export ROOT, table, num, load_cases, prof, avg, metrics!, interp, writecsv
const ROOT=@__DIR__
num(x)=x isa Number ? Float64(x) : parse(Float64,x)
function csvfields(s)
    out=String[];buf=IOBuffer();quoted=false;i=firstindex(s)
    while i<=lastindex(s)
        c=s[i]
        if c=='"'
            ni=nextind(s,i)
            if quoted && ni<=lastindex(s) && s[ni]=='"';write(buf,'"');i=ni
            else;quoted=!quoted;end
        elseif c==',' && !quoted;push!(out,String(take!(buf)))
        else;write(buf,c);end
        i=nextind(s,i)
    end
    push!(out,String(take!(buf)));out
end
function table(path)
    lines=readlines(path);names=Tuple(Symbol.(csvfields(first(lines))))
    [NamedTuple{names}(Tuple(csvfields(line))) for line in lines[2:end] if !isempty(line)]
end
escape_csv(x)=occursin(r"[,\"\n]",string(x)) ? "\""*replace(string(x),'"'=>"\"\"")*"\"" : string(x)
function writecsv(path,rows)
    isempty(rows) && return
    open(path,"w") do io
        println(io,join(keys(first(rows)),','))
        for r in rows;println(io,join(escape_csv.(values(r)),','));end
    end
end
function load_cases()
    configs=JSON.parsefile(joinpath(ROOT,"experiment_matrix.json"))["cases"]
    cases=[]
    for c in configs
        id=c["remote_case_id"];dir=joinpath(ROOT,"simulation_data",id)
        isfile(joinpath(dir,"series.csv")) || continue
        meta=JSON.parsefile(joinpath(dir,"manifest.json"))
        @assert meta["record_audit"]["profiles"]["all_finite"] && meta["record_audit"]["series"]["all_finite"]
        @assert meta["profile_record_semantics"]["fourth_hour_source_times_s"]==[12600,14400]
        rows=table(joinpath(dir,"series.csv"));ss=Dict(string(k)=>num.(getproperty.(rows,k)) for k in keys(first(rows)))
        @assert length(rows)==241 && ss["time_s"]==collect(0.:60.:14400.)
        @assert length(ss)==33 && all(v->all(isfinite,v),values(ss))
        @assert all(==(15),ss["surface_sensible_heat_flux"]) && all(==(115),ss["surface_latent_heat_flux"])
        raw=table(joinpath(dir,"profiles.csv"));names=unique(r.variable for r in raw)
        @assert length(names)==46 && sort(unique(num(r.time_s) for r in raw))==collect(0.:1800.:14400.)
        profiles=Dict{String,Tuple{Vector{Float64},Vector{Float64}}}()
        for name in names
            records=[r for r in raw if r.variable==name && num(r.time_s) in (12600,14400)]
            a=sort([r for r in records if num(r.time_s)==12600],by=r->num(r.z_m))
            b=sort([r for r in records if num(r.time_s)==14400],by=r->num(r.z_m))
            z=num.(getproperty.(a,:z_m));@assert z==num.(getproperty.(b,:z_m))
            v=(num.(getproperty.(a,:value)).+num.(getproperty.(b,:value)))./2
            @assert all(isfinite,v)
            profiles[name]=(z,v)
        end
        dz=c["dz_m"];nz=c["nz"]
        @assert profiles["w_variance"][1]==collect(0.:dz:nz*dz)
        @assert profiles["w_third_central_moment"][1]==collect(0.:dz:nz*dz)
        @assert profiles["q_l_mean"][1]==collect(dz/2:dz:(nz-.5)*dz)
        scheme=get(c,"advection_scheme","WENO")
        moisture=nothing
        if scheme=="Centered"
            extrema=table(joinpath(dir,"moisture_extrema.csv"))
            @assert length(extrema)==241 && num.(getproperty.(extrema,:time_s))==collect(0.:60.:14400.)
            lo=num.(getproperty.(extrema,:q_t_min));hi=num.(getproperty.(extrema,:q_t_max))
            @assert all(isfinite,lo) && all(isfinite,hi) && all(lo.<=hi)
            moisture=(minimum=minimum(lo),maximum=maximum(hi),negative_samples=count(<(0),lo))
        end
        push!(cases,(id=id,grid=c["name"],scheme=scheme,order=c["advection_order"],closure=c["closure"]=="none" ? "none" : "smagorinsky",s=ss,p=profiles,moisture=moisture))
    end
    sort!(cases,by=c->(findfirst(==(c.grid),["coarse","canonical","fine"]),c.closure!="none",-c.order))
end
prof(c,k)=c.p[k]
function interp(t,v,x)
    i=clamp(searchsortedlast(t,x),1,length(t)-1)
    v[i]+(v[i+1]-v[i])*(x-t[i])/(t[i+1]-t[i])
end
function avg(c,key,lo=10800.,hi=14400.)
    t=c.s["time_s"];v=c.s[key];idx=findall(x->lo<x<hi,t)
    tt=vcat(lo,t[idx],hi);vv=vcat(interp(t,v,lo),v[idx],interp(t,v,hi))
    sum(diff(tt).*(vv[1:end-1].+vv[2:end])./2)/(hi-lo)
end
function metrics!(cases)
    obs=table(joinpath(ROOT,"data","figure5_observation_centers.csv"));rows=[]
    for c in cases
        z,w2=prof(c,"w_variance");_,w3=prof(c,"w_third_central_moment");h="q_t_8gkg_inversion_height_mean";t=c.s["time_s"]
        @assert minimum(c.s["q_t_8gkg_inversion_valid_fraction"])>.999
        growth=(interp(t,c.s[h],14400)-interp(t,c.s[h],10800))/3600
        ow2=filter(r->r.variable=="variance" && r.instrument=="in_situ",obs)
        ow3=filter(r->r.variable=="third_moment" && r.instrument=="in_situ",obs)
        e2=[interp(z,w2,num(r.height_m))-num(r.value) for r in ow2]
        e3=[interp(z,w3,num(r.height_m))-num(r.value) for r in ow3]
        cloud=(600 .<= z).&(z.<=760)
        push!(rows,(case_id=c.id,grid=c.grid,advection_scheme=c.scheme,advection_order=c.order,weno=c.scheme=="WENO" ? string(c.order) : "",closure=c.closure,
         q_t_min_kg_kg=c.moisture===nothing ? "" : c.moisture.minimum,q_t_max_kg_kg=c.moisture===nothing ? "" : c.moisture.maximum,q_t_negative_samples=c.moisture===nothing ? "" : c.moisture.negative_samples,
         LWP_g_m2=1000avg(c,"lwp_mean"),LWP_first_half_g_m2=1000avg(c,"lwp_mean",10800,12600),LWP_second_half_g_m2=1000avg(c,"lwp_mean",12600,14400),
         cloud_fraction=avg(c,"cloud_fraction"),cloud_base_m=avg(c,"cloud_base_mean"),inversion_qt_m=avg(c,h),entrainment_mm_s=1000*(growth+3.75e-6avg(c,h)),
         decoupling_g_kg=1000avg(c,"decoupling_delta_q_t"),integrated_resolved_TKE_m3_s2=avg(c,"resolved_tke_vertical_integral"),peak_hour4_w2_m2_s2=maximum(w2),min_hour4_w3_m3_s3=minimum(w3),
         min_hour4_w3_600_760_m3_s3=minimum(w3[cloud]),max_hour4_w3_600_760_m3_s3=maximum(w3[cloud]),
         w2_insitu_marker_RMSE=sqrt(mean(abs2,e2)),w2_insitu_marker_bias=mean(e2),w3_insitu_marker_RMSE=sqrt(mean(abs2,e3)),w3_insitu_marker_bias=mean(e3)))
    end
    writecsv(joinpath(ROOT,"simulation_data","fourth_hour_metrics.csv"),rows)
    pairs=[]
    for a in rows,b in rows
        a.grid==b.grid || continue
        label=if a.advection_scheme==b.advection_scheme=="WENO" && a.closure==b.closure && a.advection_order==9 && b.advection_order==5
            "WENO9 minus WENO5"
        elseif a.advection_scheme==b.advection_scheme && a.advection_order==b.advection_order && a.closure=="smagorinsky" && b.closure=="none"
            "Smagorinsky minus no closure"
        elseif a.advection_scheme=="Centered" && b.advection_scheme=="WENO" && a.closure==b.closure=="smagorinsky"
            "Centered2 minus WENO$(b.advection_order), both Smagorinsky"
        else
            ""
        end
        isempty(label) && continue
        push!(pairs,(grid=a.grid,contrast=label,case_a=a.case_id,case_b=b.case_id,LWP_g_m2=a.LWP_g_m2-b.LWP_g_m2,cloud_fraction=a.cloud_fraction-b.cloud_fraction,decoupling_g_kg=a.decoupling_g_kg-b.decoupling_g_kg,peak_hour4_w2_m2_s2=a.peak_hour4_w2_m2_s2-b.peak_hour4_w2_m2_s2,w2_insitu_marker_RMSE=a.w2_insitu_marker_RMSE-b.w2_insitu_marker_RMSE,w3_insitu_marker_RMSE=a.w3_insitu_marker_RMSE-b.w3_insitu_marker_RMSE))
    end
    writecsv(joinpath(ROOT,"simulation_data","paired_effects.csv"),pairs)
    rows
end
end
