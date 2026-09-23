using CairoMakie, JSON, Statistics, Printf

const D = @__DIR__
const ROOT = normpath(joinpath(D, "../../.."))
const CASES = (
    ("Unfiltered · no closure", joinpath(ROOT, "surface_layer/gabls1/exports_e0655cf/gabls1_n032_weno9_control"), "#0072B2"),
    ("Filtered · no closure", joinpath(D, "export/control"), "#009E73"),
    ("Unfiltered · SLD", joinpath(ROOT, "surface_layer/gabls1/native_flux/export"), "#D55E00"),
    ("Filtered · SLD", joinpath(D, "export/sld"), "#CC79A7"))
const REF = JSON.parsefile(joinpath(ROOT, "gabls/reference_data/fixed_1m_medians.json"))["curves"]

function rows(path)
    lines = readlines(path)
    header = String.(split(first(lines), ','))
    [Dict(k => String(v) for (k,v) in zip(header, split(line, ','))) for line in lines[2:end]]
end
num(r,k) = parse(Float64, r[k])
function profile(path, window, variable)
    rs = filter(r -> r["variable"] == variable, rows(joinpath(path, "profiles_$(window)_long.csv")))
    isempty(rs) && error("missing $variable at $path")
    sort!(rs; by=r -> num(r,"z_m"))
    (; z=[num(r,"z_m") for r in rs], v=[num(r,"value") for r in rs])
end
function series(path)
    rs=rows(joinpath(path,"series.csv"))
    Dict(k => [num(r,k) for r in rs] for k in keys(first(rs)))
end
const SERIES = Dict(name => series(path) for (name,path,_) in CASES)

function refprofile(name)
    r=REF["profile/"*name]
    ix=findall(i -> r["coordinates"][i] !== nothing && r["median"][i] !== nothing, eachindex(r["coordinates"]))
    (; z=Float64.(r["coordinates"][ix]), v=Float64.(r["median"][ix]))
end
function sample(p, z)
    [begin
        j=searchsortedlast(p.z,zz)
        1 <= j < length(p.z) || error("reference does not cover $zz m")
        a=(zz-p.z[j])/(p.z[j+1]-p.z[j]); (1-a)*p.v[j]+a*p.v[j+1]
    end for zz in z]
end
shear(u,v) = (; z=(u.z[1:end-1].+u.z[2:end])./2,
                 v=hypot.(diff(u.v)./diff(u.z),diff(v.v)./diff(v.z)))

mkpath(joinpath(D,"figures"))
f=Figure(size=(1800,1160),fontsize=20)
Label(f[0,1:3],"GABLS1: filtering the rough-wall bulk drag",fontsize=30,font=:bold)
Label(f[1,1:3],"32³ · 12.5 m · WENO9 · 300 s filtered wall state · same seed · dashed 7–8 h, solid 8–9 h",fontsize=19)
panels=(("u_mean","u_mean","Mean u (m s⁻¹)"), ("theta_mean","theta_mean","Potential temperature (K)"),
        ("w_variance","w_variance","w² (m² s⁻²)"), ("w_third_central_moment","w_third_central_moment","w³ (m³ s⁻³)"),
        ("total_u_w_flux","uw_total","Total u–w flux (m² s⁻²)"), ("total_w_theta_flux","wtheta_total","Total w–θ flux (K m s⁻¹)"))
for (i,(var,refvar,xlab)) in enumerate(panels)
    ax=Axis(f[2+div(i-1,3),1+mod(i-1,3)];xlabel=xlab,ylabel="Height (m)")
    for (name,path,color) in CASES, (window,style) in (("penultimate_hour",:dash),("final_hour",:solid))
        p=profile(path,window,var); ix=findall(<=(var in ("total_u_w_flux","total_w_theta_flux") ? 125 : 250),p.z)
        lines!(ax,p.v[ix],p.z[ix];color,linestyle=style,linewidth=style==:solid ? 3.2 : 2.0,
               label=window=="final_hour" ? name : nothing)
    end
    if haskey(REF,"profile/"*refvar)
        p=refprofile(refvar); ix=findall(<=(var in ("total_u_w_flux","total_w_theta_flux") ? 125 : 250),p.z)
        isempty(ix) || lines!(ax,p.v[ix],p.z[ix];color=:black,linestyle=:dashdot,linewidth=2.5,label="Fixed 1 m LES median")
    end
    ylims!(ax,0,var in ("total_u_w_flux","total_w_theta_flux") ? 125 : 250)
    i==1 && (global profile_legend=ax)
end
Legend(f[4,1:3],profile_legend;orientation=:horizontal,nbanks=2,labelsize=18)
save(joinpath(D,"figures/filtered_profiles.pdf"),f)
save(joinpath(D,"figures/filtered_profiles.png"),f)

f=Figure(size=(1700,1060),fontsize=20)
Label(f[0,1:2],"Mean-wind shear and wall flux",fontsize=30,font=:bold)
Label(f[1,1:2],"Shear between adjacent 12.5 m cell centers; fixed 1 m median sampled at the same heights",fontsize=19)
for (row,window) in enumerate(("penultimate_hour","final_hour"))
    ax=Axis(f[1+row,1];xlabel="Vector shear (s⁻¹)",ylabel="Height (m)",title=window=="final_hour" ? "8–9 h" : "7–8 h")
    for (name,path,color) in CASES
        sh=shear(profile(path,window,"u_mean"),profile(path,window,"v_mean"))
        ix=findall(<=(125),sh.z)
        lines!(ax,sh.v[ix],sh.z[ix];color,linewidth=3,label=name)
        scatter!(ax,sh.v[ix],sh.z[ix];color,markersize=4)
    end
    if window=="final_hour"
        z=profile(CASES[1][2],window,"u_mean").z
        sh=shear((;z,v=sample(refprofile("u_mean"),z)),(;z,v=sample(refprofile("v_mean"),z)))
        ix=findall(<=(125),sh.z)
        lines!(ax,sh.v[ix],sh.z[ix];color=:black,linestyle=:dashdot,linewidth=2.7,label="Fixed 1 m LES median")
    end
    ylims!(ax,0,125)
    row==2 && (global shear_legend=ax)
end
for (i,(key,title)) in enumerate((("friction_velocity","Surface friction velocity (m s⁻¹)"),
                                  ("surface_theta_kinematic_flux","Surface heat flux (K m s⁻¹)")))
    ax=Axis(f[1+i,2];xlabel="Time (h)",ylabel=title)
    for (name,_,color) in CASES
        s=SERIES[name]; lines!(ax,s["time_s"]./3600,s[key];color,linewidth=2.4,label=name)
    end
    xlims!(ax,0,9)
end
Legend(f[4,1:2],shear_legend;orientation=:horizontal,nbanks=2)
save(joinpath(D,"figures/filtered_shear_flux.pdf"),f)
save(joinpath(D,"figures/filtered_shear_flux.png"),f)

f=Figure(size=(1600,1050),fontsize=20)
Label(f[0,1:2],"Scheme-native SLD: first-face transport partition",fontsize=29,font=:bold)
Label(f[1,1:2],"Filtering changes the wall state; reconstructed = covariance + numerical correction",fontsize=19)
for (row,(stem,unit)) in enumerate((("u","m² s⁻²"),("ρθ","K m s⁻¹")))
    ax=Axis(f[1+row,1];xlabel="Time (h)",ylabel="Flux ($unit)",title=stem=="u" ? "Momentum" : "Heat")
    for (name,_,color) in CASES[3:4]
        s=SERIES[name]; pref="surface_layer_face1_"
        names=stem=="u" ? (pref*"resolved_u_flux",pref*"numerical_u_correction",pref*"reconstructed_u_flux") :
                          (pref*"ρθ_resolved_flux",pref*"ρθ_numerical_correction",pref*"ρθ_reconstructed_flux")
        for (j,style) in enumerate((:solid,:dash,:dot))
            lines!(ax,s["time_s"]./3600,s[names[j]];color,linestyle=style,linewidth=2.4,label=name*" "*("covariance","correction","reconstructed")[j])
        end
    end
    xlims!(ax,7,9)
    row==1 && (global partition_legend=ax)
    ax2=Axis(f[1+row,2];xlabel="Time (h)",ylabel="Numerical correction ($unit)")
    key=stem=="u" ? "surface_layer_face1_numerical_u_correction" : "surface_layer_face1_ρθ_numerical_correction"
    for (name,_,color) in CASES[3:4]
        s=SERIES[name];lines!(ax2,s["time_s"]./3600,s[key];color,linewidth=2.5,label=name)
    end
    xlims!(ax2,7,9)
end
Legend(f[4,1:2],partition_legend;orientation=:horizontal,nbanks=2,labelsize=15)
save(joinpath(D,"figures/filtered_partition.pdf"),f)
save(joinpath(D,"figures/filtered_partition.png"),f)

f=Figure(size=(1600,900),fontsize=20)
Label(f[0,1:3],"Saved filtered wall state",fontsize=29,font=:bold)
Label(f[1,1:3],"Horizontal mean of the actual 300 s filtered fields, sampled every 600 s",fontsize=19)
for (col,(key,title)) in enumerate((("filtered_u","Filtered u (m s⁻¹)"),
                                    ("filtered_v","Filtered v (m s⁻¹)"),
                                    ("filtered_Δθ","Filtered air–surface Δθ (K)")))
    ax=Axis(f[2,col];xlabel="Time (h)",ylabel=title)
    for (name,path,color) in (CASES[2],CASES[4])
        rs=rows(joinpath(path,"wall_filter_means.csv"))
        lines!(ax,[num(r,"time_s")/3600 for r in rs],[num(r,key) for r in rs];color,linewidth=3,label=name)
    end
    xlims!(ax,0,9)
    col==1 && (global filter_legend=ax)
end
Legend(f[3,1:3],filter_legend;orientation=:horizontal)
save(joinpath(D,"figures/filtered_state.pdf"),f)
save(joinpath(D,"figures/filtered_state.png"),f)

open(joinpath(D,"metrics.md"),"w") do io
    println(io,"# Filtered-wall GABLS1 metrics\n")
    println(io,"The 7–8 and 8–9 h windows are independent half-hour-bin averages. One seed per condition; differences are descriptive. The fixed 1 m reference is an LES intercomparison median, not observations.\n")
    println(io,"| Case | Window | First-layer vector shear (s⁻¹) | Mean u* (m s⁻¹) | Mean surface heat flux (K m s⁻¹) | Peak w² (m² s⁻²) |")
    println(io,"|---|---|---:|---:|---:|---:|")
    for (name,path,_) in CASES, (window,a,b) in (("7–8 h",25200.0,28800.0),("8–9 h",28800.0,32400.0))
        prof=window=="7–8 h" ? "penultimate_hour" : "final_hour"
        sh=shear(profile(path,prof,"u_mean"),profile(path,prof,"v_mean"))
        w=profile(path,prof,"w_variance")
        s=SERIES[name]; ix=findall(t -> a<=t<=b,s["time_s"])
        @printf(io,"| %s | %s | %.5f | %.5f | %.6f | %.5f |\n",name,window,sh.v[1],mean(s["friction_velocity"][ix]),mean(s["surface_theta_kinematic_flux"][ix]),maximum(w.v))
    end
    z=profile(CASES[1][2],"final_hour","u_mean").z
    sh=shear((;z,v=sample(refprofile("u_mean"),z)),(;z,v=sample(refprofile("v_mean"),z)))
    @printf(io,"| Fixed 1 m LES median | 8–9 h | %.5f | — | — | — |\n",sh.v[1])
    println(io,"\n## First-face SLD transport, 8–9 h\n")
    println(io,"| Case | Momentum viscosity (m² s⁻¹) | Heat diffusivity (m² s⁻¹) | u covariance flux (m² s⁻²) | u numerical correction (m² s⁻²) | Heat covariance flux (K m s⁻¹) | Heat numerical correction (K m s⁻¹) |")
    println(io,"|---|---:|---:|---:|---:|---:|---:|")
    for (name,_,_) in CASES[3:4]
        s=SERIES[name]; ix=findall(t -> 28800<=t<=32400,s["time_s"])
        m(k)=mean(s[k][ix]); p="surface_layer_face1_"
        @printf(io,"| %s | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n",name,
                m(p*"viscosity"),m(p*"ρθ_diffusivity"),m(p*"resolved_u_flux"),
                m(p*"numerical_u_correction"),m(p*"ρθ_resolved_flux"),m(p*"ρθ_numerical_correction"))
    end
end
println(read(joinpath(D,"metrics.md"),String))
