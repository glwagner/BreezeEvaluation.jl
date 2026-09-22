using CairoMakie, JSON, Statistics, Printf

length(ARGS) == 1 || error("usage: julia compare_plot.jl COMPARISON_DIRECTORY")
root = only(ARGS)
function csv(path)
    lines = readlines(path)
    header = split(first(lines), ',')
    return [Dict(String(k) => String(v) for (k, v) in zip(header, split(line, ','))) for line in lines[2:end]]
end
number(row, key) = parse(Float64, row[key])
function profile(case, window, variable)
    rows = csv(joinpath(root, case, "profiles_$(window)_long.csv"))
    points = filter(r -> r["variable"] == variable, rows)
    isempty(points) && error("missing $case $window $variable")
    sort!(points; by=r -> number(r, "z_m"))
    return (; z=[number(r,"z_m") for r in points], v=[number(r,"value") for r in points])
end
function series(case)
    rows = csv(joinpath(root,case,"series.csv"))
    return Dict(k => [number(r,k) for r in rows] for k in keys(first(rows)))
end
const cases = ("control", "native")
const color = Dict("control" => "#0072B2", "native" => "#D55E00")
const label = Dict("control" => "Covariance control", "native" => "Scheme-native")
const window_style = Dict("penultimate_hour" => :dash, "final_hour" => :solid)
const reference = JSON.parsefile(joinpath(root,"reference/fixed_1m_medians.json"))["curves"]

function add_profile!(ax, variable, refvar; ymax=250, xlimits=nothing)
    for case in cases, window in ("penultimate_hour", "final_hour")
        p=profile(case,window,variable)
        ix=findall(z -> z <= ymax, p.z)
        lines!(ax,p.v[ix],p.z[ix];color=color[case],linestyle=window_style[window],linewidth=window=="final_hour" ? 3.4 : 2.1,
               label=label[case]*" "*(window=="final_hour" ? "8–9 h" : "7–8 h"))
    end
    key="profile/"*refvar
    if haskey(reference,key)
        r=reference[key]
        ix=findall(i -> r["coordinates"][i] !== nothing && r["median"][i] !== nothing && r["coordinates"][i] <= ymax, eachindex(r["coordinates"]))
        if !isempty(ix)
            lines!(ax,Float64.(r["median"][ix]),Float64.(r["coordinates"][ix]); color=:black,linestyle=:dashdot,linewidth=2.4,label="Fixed 1 m LES median")
        end
    end
    ylims!(ax,0,ymax)
    xlimits === nothing || xlims!(ax,xlimits...)
end

mkpath(joinpath(root,"figures"))
f=Figure(size=(1600,1120),fontsize=19)
Label(f[0,1:3],"GABLS1: scheme-native transport versus covariance",fontsize=29,font=:bold)
Label(f[1,1:3],"12.5 m · WENO9 · one face · 300 s · factor 1 · same seed; dashed 7–8 h, solid 8–9 h",fontsize=19)
panels=(("u_mean","u_mean","Wind u (m s⁻¹)"), ("theta_mean","theta_mean","Potential temperature (K)"),
        ("w_variance","w_variance","w² (m² s⁻²)"), ("w_third_central_moment","w_third_central_moment","w³ (m³ s⁻³)"),
        ("resolved_tke","resolved_tke","Resolved TKE (m² s⁻²)"), ("total_u_w_flux","uw_total","Total u–w flux (m² s⁻²)"))
for (i,(variable,refvar,xlab)) in enumerate(panels)
    ax=Axis(f[2+div(i-1,3),1+mod(i-1,3)];xlabel=xlab,ylabel="Height (m)",title=variable)
    add_profile!(ax,variable,refvar; ymax=variable=="total_u_w_flux" ? 100 : 250)
    i==1 && (global legend_ax=ax)
end
Legend(f[4,1:3],legend_ax;orientation=:horizontal,nbanks=2,labelsize=17)
save(joinpath(root,"figures/native_profiles.pdf"),f)
save(joinpath(root,"figures/native_profiles.png"),f)

const s=Dict(case => series(case) for case in cases)
@assert all(s["native"]["time_s"] .== s["control"]["time_s"])
f=Figure(size=(1550,1050),fontsize=19)
Label(f[0,1:2],"What the transport estimator changes at the first interior face",fontsize=28,font=:bold)
Label(f[1,1:2],"Same nine-hour forcing and discretization · 12.5 m supported face · shaded final two hours",fontsize=19)
sp=(("surface_layer_face1_viscosity","Momentum viscosity (m² s⁻¹)"),
    ("surface_layer_face1_ρθ_diffusivity","Heat diffusivity (m² s⁻¹)"),
    ("surface_layer_face1_momentum_deficit","Momentum flux deficit (m² s⁻²)"),
    ("surface_layer_face1_ρθ_deficit","Heat flux deficit (K m s⁻¹)"))
for (i,(v,title)) in enumerate(sp)
    ax=Axis(f[2+div(i-1,2),1+mod(i-1,2)];xlabel="Time (h)",ylabel=title,title)
    vspan!(ax,7,8;color=(:gray,0.08));vspan!(ax,8,9;color=(:gray,0.14))
    for case in cases
        lines!(ax,s[case]["time_s"]./3600,s[case][v];color=color[case],linewidth=case=="native" ? 3 : 2.4,label=label[case])
    end
    xlims!(ax,0,9)
    i==1 && (global series_legend_ax=ax)
end
Legend(f[4,1:2],series_legend_ax;orientation=:horizontal)
save(joinpath(root,"figures/native_activity.pdf"),f)
save(joinpath(root,"figures/native_activity.png"),f)

f=Figure(size=(1550,1050),fontsize=19)
Label(f[0,1:2],"Measured WENO transport correction",fontsize=29,font=:bold)
Label(f[1,1:2],"Scheme-native run only · covariance + numerical correction = reconstructed flux",fontsize=19)
for (i,(stem,units)) in enumerate((("u","m² s⁻²"),("ρθ","K m s⁻¹")))
    ax=Axis(f[i+1,1];xlabel="Time (h)",ylabel="Upward flux ($units)",title=stem=="u" ? "Momentum flux" : "Heat flux")
    pref="surface_layer_face1_"
    names=stem=="u" ? (pref*"resolved_u_flux",pref*"numerical_u_correction",pref*"reconstructed_u_flux") :
                      (pref*"ρθ_resolved_flux",pref*"ρθ_numerical_correction",pref*"ρθ_reconstructed_flux")
    cols=("#0072B2","#D55E00","#009E73")
    labs=("Covariance","Numerical correction","Reconstructed")
    for j in 1:3
        lines!(ax,s["native"]["time_s"]./3600,s["native"][names[j]];color=cols[j],linewidth=2.5,label=labs[j])
    end
    xlims!(ax,0,9);i==1&&(global partition_ax=ax)
    correction_ax=Axis(f[i+1,2];xlabel="Time (h)",ylabel="Correction ($units)",title=stem=="u" ? "Momentum numerical correction" : "Heat numerical correction")
    lines!(correction_ax,s["native"]["time_s"]./3600,s["native"][names[2]];color="#D55E00",linewidth=2.8)
    hlines!(correction_ax,[0.0];color=:black,linestyle=:dash)
    xlims!(correction_ax,0,9)
end
Legend(f[4,1:2],partition_ax;orientation=:horizontal)
save(joinpath(root,"figures/native_partition.pdf"),f)
save(joinpath(root,"figures/native_partition.png"),f)

open(joinpath(root,"comparison_metrics.md"),"w") do io
    println(io,"# Matched GABLS1 native-flux comparison\n")
    println(io,"One matched seed and realization. Source and raw schedule audited separately. Values below are descriptive; they do not establish convergence or general calibration.\n")
    println(io,"| Metric | Covariance factor 1 | Scheme-native factor 1 | Change |")
    println(io,"|---|---:|---:|---:|")
    for (v,title) in (("surface_layer_face1_viscosity","Mean 8–9 h momentum viscosity (m² s⁻¹)"),
                      ("surface_layer_face1_ρθ_diffusivity","Mean 8–9 h heat diffusivity (m² s⁻¹)"),
                      ("surface_layer_face1_momentum_deficit","Mean 8–9 h momentum deficit (m² s⁻²)"),
                      ("surface_layer_face1_ρθ_deficit","Mean 8–9 h heat deficit (K m s⁻¹)"),
                      ("resolved_tke_vertical_integral","Mean 8–9 h integrated resolved TKE (m³ s⁻²)"),
                      ("w_variance_maximum","Mean 8–9 h maximum w² (m² s⁻²)"),
                      ("boundary_layer_height","Mean 8–9 h diagnosed boundary layer height (m)"))
        ix=findall(t -> 28800 <= t <= 32400,s["native"]["time_s"])
        a=mean(s["control"][v][ix]); b=mean(s["native"][v][ix]); d=b-a
        println(io,@sprintf("| %s | %.5g | %.5g | %+.5g (%.1f%%) |",title,a,b,d,100*d/abs(a)))
    end
    for (correction,resolved,title) in (("surface_layer_face1_numerical_u_correction","surface_layer_face1_resolved_u_flux","Momentum"),
                                        ("surface_layer_face1_ρθ_numerical_correction","surface_layer_face1_ρθ_resolved_flux","Heat"))
        ix=findall(t -> 28800 <= t <= 32400,s["native"]["time_s"])
        c=mean(s["native"][correction][ix]); r=mean(s["native"][resolved][ix])
        println(io,@sprintf("\n%s 8–9 h numerical correction: %.6g; covariance %.6g; ratio %.3f%%.",title,c,r,100*c/r))
    end
    for window in ("penultimate_hour","final_hour")
        for v in ("w_variance","w_third_central_moment")
            a=profile("control",window,v); b=profile("native",window,v)
            println(io,@sprintf("\n%s %s peak: control %.5g, native %.5g",window,v,maximum(a.v),maximum(b.v)))
        end
    end
end
println(read(joinpath(root,"comparison_metrics.md"),String))
