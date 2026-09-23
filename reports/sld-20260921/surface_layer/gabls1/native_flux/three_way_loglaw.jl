using CairoMakie, JSON, Statistics, Printf, LinearAlgebra

const D = @__DIR__
const ROOT = normpath(joinpath(D, "../../.."))
const KAPPA = 0.4
const BETA_M = 4.8
const Z0 = 0.1
const CASES = [
    (name="No closure", path=joinpath(ROOT,"surface_layer/gabls1/exports_e0655cf/gabls1_n032_weno9_control"), color="#009E73"),
    (name="Scheme-native SLD", path=joinpath(D,"export"), color="#D55E00"),
    (name="Smagorinsky", path=joinpath(ROOT,"surface_layer/gabls1/historical_smagorinsky"), color="#CC79A7")]

function table(path)
    ls=readlines(path)
    names=String.(split(first(ls),','))
    return [Dict(k=>String(v) for (k,v) in zip(names,split(line,','))) for line in ls[2:end]]
end
function profile(path, variable, window="final_hour")
    rs=filter(r->r["variable"]==variable,table(joinpath(path,"profiles_$(window)_long.csv")))
    sort!(rs;by=r->parse(Float64,r["z_m"]))
    z=parse.(Float64,getindex.(rs,"z_m"))
    v=parse.(Float64,getindex.(rs,"value"))
    length(z)==32 || error("$variable: expected 32 center levels")
    return (;z,v)
end
function mean_series(path,variable)
    rs=table(joinpath(path,"series.csv"))
    vals=[parse(Float64,r[variable]) for r in rs if 28800 < parse(Float64,r["time_s"]) <= 32400]
    length(vals)==60 || error("series final-hour schedule")
    return mean(vals)
end
function slope(z,u,v)
    return (;z=(z[1:end-1].+z[2:end])./2,
             du=diff(u)./diff(z),dv=diff(v)./diff(z),
             magnitude=hypot.(diff(u)./diff(z),diff(v)./diff(z)))
end
function refcurve(variable)
    r=JSON.parsefile(joinpath(ROOT,"gabls/reference_data/fixed_1m_medians.json"))["curves"]["profile/"*variable]
    ix=[i for i in eachindex(r["coordinates"]) if r["coordinates"][i]!==nothing && r["median"][i]!==nothing]
    z=Float64.(r["coordinates"][ix]);v=Float64.(r["median"][ix])
    p=sortperm(z)
    return (;z=z[p],v=v[p])
end
function interp(z,v,targets)
    out=Float64[]
    for t in targets
        j=searchsortedlast(z,t)
        1<=j<length(z) || error("reference missing z=$t")
        λ=(t-z[j])/(z[j+1]-z[j])
        push!(out,(1-λ)*v[j]+λ*v[j+1])
    end
    return out
end
function reference_series_mean(variable)
    curves=JSON.parsefile(joinpath(ROOT,"gabls/reference_data/fixed_1m_medians.json"))["curves"]
    r=curves["series/"*variable]
    ix=[i for i in eachindex(r["coordinates"]) if r["coordinates"][i]!==nothing &&
        r["median"][i]!==nothing && 28800<r["coordinates"][i]<=32400]
    return mean(Float64.(r["median"][ix]))
end
const C = Dict{String,Any}()
for c in CASES
    u=profile(c.path,"u_mean");v=profile(c.path,"v_mean")
    u.z==v.z || error("u-v level mismatch")
    C[c.name]=(;z=u.z,u=u.v,v=v.v,U=hypot.(u.v,v.v),shear=slope(u.z,u.v,v.v),
                ustar=mean_series(c.path,"friction_velocity"),
                L=mean_series(c.path,"obukhov_length"),color=c.color)
end
ru=refcurve("u_mean");rv=refcurve("v_mean")
refz=C["No closure"].z
ref_u=interp(ru.z,ru.v,refz);ref_v=interp(rv.z,rv.v,refz)
ref_ustar=reference_series_mean("ustar")
ref_flux=reference_series_mean("surface_theta_flux")
ref_L=-ref_ustar^3*263.5/(KAPPA*9.81*ref_flux)
C["Fixed 1 m median"]= (;z=refz,u=ref_u,v=ref_v,U=hypot.(ref_u,ref_v),
                            shear=slope(refz,ref_u,ref_v),ustar=ref_ustar,L=ref_L,color="#343434")

f=Figure(size=(1580,680),fontsize=19)
Label(f[0,1:3],"GABLS1 mean wind and shear: three requested treatments",fontsize=28,font=:bold)
Label(f[1,1:3],"8–9 h · 12.5 m WENO9 · 32³ · same 400 m cube; fixed 1 m LES median for context",fontsize=18)
for (j,(what,xlab,title)) in enumerate((("U","Horizontal speed (m s⁻¹)","Wind speed"),
                                        ("du","∂u/∂z (s⁻¹)","u shear"),
                                        ("magnitude","|∂(u,v)/∂z| (s⁻¹)","Vector shear")))
    ax=Axis(f[2,j];xlabel=xlab,ylabel="Height (m)",title)
    for name in ("No closure","Scheme-native SLD","Smagorinsky","Fixed 1 m median")
        c=C[name]
        z=what=="U" ? c.z : c.shear.z
        x=what=="U" ? c.U : getproperty(c.shear,Symbol(what))
        ix=findall(h->0<=h<=125,z)
        lines!(ax,x[ix],z[ix];color=c.color,linewidth=name=="Scheme-native SLD" ? 3.7 : 2.8,
               linestyle=name=="Fixed 1 m median" ? :dashdot : :solid,label=name)
        name=="Fixed 1 m median" || scatter!(ax,x[ix],z[ix];color=c.color,markersize=6)
    end
    ylims!(ax,0,125)
    j==1&&(global legend_ax=ax)
end
Legend(f[3,1:3],legend_ax;orientation=:horizontal,nbanks=1)
Label(f[4,1:3],"Reference componentwise median u/v sampled at 12.5 m centers before differentiation. Shear at 12.5 m spans 6.25–18.75 m; it is not a wall gradient.\nSmagorinsky used an earlier source revision and is contextual rather than an exact same-revision treatment.",fontsize=16,tellwidth=false)
save(joinpath(D,"figures/gabls1_shear_requested.png"),f)
save(joinpath(D,"figures/gabls1_shear_requested.pdf"),f)

function law_residual(z,U,ustar,L)
    neutral=(ustar/KAPPA).*log.(z./first(z))
    stable=neutral .+ (ustar/KAPPA)*(BETA_M/L).*(z.-first(z))
    residual=U.-first(U).-neutral
    return (;neutral,stable,residual,stable_excess=stable.-neutral,
            neutral_rms=sqrt(mean(abs2,(U.-first(U)).-neutral)),
            stable_rms=sqrt(mean(abs2,(U.-first(U)).-stable)))
end
ref_ix=findall(z->2<=z<=30,ru.z)
ref_z=ru.z[ref_ix]
ref_U=hypot.(ru.v[ref_ix],interp(rv.z,rv.v,ref_z))
ref_law=law_residual(ref_z,ref_U,ref_ustar,ref_L)
model=C["Scheme-native SLD"]
model_ix=findall(z->6.25<=z<=43.75,model.z)
model_z=model.z[model_ix];model_U=model.U[model_ix]
model_law=law_residual(model_z,model_U,model.ustar,model.L)

f=Figure(size=(1320,650),fontsize=19)
Label(f[0,1:2],"Neutral log-law versus stable surface-layer scaling",fontsize=28,font=:bold)
Label(f[1,1:2],"Residual from a neutral log profile anchored at the first plotted level; zero would be neutral-log behavior",fontsize=18)
for (j,(title,z,law,c)) in enumerate((("Fixed 1 m LES median · 2–30 m",ref_z,ref_law,"#343434"),
                                      ("Scheme-native SLD · 6.25–43.75 m",model_z,model_law,"#D55E00")))
    ax=Axis(f[2,j];xlabel="Height (m)",ylabel="Departure from neutral log profile (m s⁻¹)",title)
    hlines!(ax,[0.0];color=:gray,linestyle=:dot,linewidth=2,label="Neutral log-law")
    lines!(ax,z,law.residual;color=c,linewidth=3.5,label="Saved wind profile")
    scatter!(ax,z,law.residual;color=c,markersize=9)
    lines!(ax,z,law.stable_excess;color="#0072B2",linestyle=:dash,linewidth=2.8,label="Stable MOST term")
    j==1&&(global law_legend_ax=ax)
end
Legend(f[3,1:2],law_legend_ax;orientation=:horizontal)
Label(f[4,1:2],"MOST term = (u*/κ) βₘ(z−z₁)/L, βₘ=4.8; each curve uses its mean 8–9 h u* and L. Reference L is derived from median u* and heat flux.\nAveraged profiles and fluxes need not satisfy pointwise MOST exactly; the law is a surface-layer expectation, not a constraint imposed through the column.",fontsize=16,tellwidth=false)
save(joinpath(D,"figures/gabls1_loglaw.png"),f)
save(joinpath(D,"figures/gabls1_loglaw.pdf"),f)

open(joinpath(D,"loglaw_comparison.md"),"w") do io
    println(io,"# GABLS1 shear and log-law diagnostic\n")
    println(io,"This view shows only no closure, scheme-native SLD, Smagorinsky, and the fixed 1 m LES median. The first three use 12.5 m WENO9 on a 32³ grid; Smagorinsky has a different source revision. The reference is an LES intercomparison median, not an observation.\n")
    println(io,"| 8–9 h case | u* (m/s) | L (m) | 6.25–18.75 m vector shear (s⁻¹) |")
    println(io,"|---|---:|---:|---:|")
    for name in ("No closure","Scheme-native SLD","Smagorinsky","Fixed 1 m median")
        c=C[name]
        @printf(io,"| %s | %.4f | %.1f | %.5f |\n",name,c.ustar,c.L,c.shear.magnitude[1])
    end
    println(io,"\nThe fixed 1 m reference shear is computed from separately median u and v profiles sampled at the same 12.5 m centers; it is not the median of member shears. All plotted shear values are finite differences across cell-center levels, not wall derivatives.\n")
    println(io,"A neutral log-law would require U(z)-U(z₁)=(u*/κ)ln(z/z₁), with κ=0.4 and horizontal wind speed U. GABLS1 is stably stratified. The wall model instead uses a linear stable MOST correction, giving an expected additional (u*/κ)βₘ(z−z₁)/L with βₘ=4.8 when local fluxes are approximately constant. It computes a transfer coefficient between the surface and the first velocity level; SLD acts at one interior face. Neither enforces a log profile across the column.\n")
    @printf(io,"For the fixed 1 m median, a neutral-log fit over 2–30 m has slope %.3f m/s per log-height, versus mean u*/κ=%.3f. Its neutral anchored residual RMS is %.3f m/s; including the stable term with L≈%.1f m gives %.3f m/s. The reference therefore is not a pure neutral log-law. The median u/v profiles, u*, and heat flux come from separately aggregated archive curves, so the derived L and comparison are diagnostic rather than an exact MOST identity.\n\n",
            (hcat(ones(length(ref_z)),log.(ref_z./Z0))\ref_U)[2],ref_ustar/KAPPA,
            ref_law.neutral_rms,ref_L,ref_law.stable_rms)
    @printf(io,"For scheme-native SLD over 6.25–43.75 m, the anchored neutral-log residual RMS is %.3f m/s; the stable-MOST residual RMS is %.3f m/s using mean u*=%.3f m/s and L=%.1f m. These are only four coarse levels.\n\n",
            model_law.neutral_rms,model_law.stable_rms,model.ustar,model.L)
    println(io,"![Requested three-treatment wind and shear plot](figures/gabls1_shear_requested.png)\n")
    println(io,"![Neutral log-law residual and stable correction](figures/gabls1_loglaw.png)")
end
println(read(joinpath(D,"loglaw_comparison.md"),String))
