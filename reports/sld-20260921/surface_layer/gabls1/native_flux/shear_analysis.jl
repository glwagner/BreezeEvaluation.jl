using CairoMakie, JSON, Printf, Statistics

const ROOT = normpath(joinpath(@__DIR__, "../../.."))
const D = @__DIR__
const CASES = Dict(
    "No closure" => joinpath(ROOT, "surface_layer/gabls1/exports_e0655cf/gabls1_n032_weno9_control"),
    "SLD covariance" => joinpath(ROOT, "surface_layer/resolved_factor/exports_v2/gabls1_n032_weno9_surface_layer_t300_s1_rf1p0"),
    "SLD scheme-native" => joinpath(D, "export"))
const COLORS = Dict("No closure" => "#009E73", "SLD covariance" => "#0072B2",
                    "SLD scheme-native" => "#D55E00", "Fixed 1 m median" => "#343434")
const WINDOWS = ("penultimate_hour", "final_hour")

function rows(path)
    lines = readlines(path)
    header = String.(split(first(lines), ','))
    return [Dict(k => String(v) for (k, v) in zip(header, split(line, ','))) for line in lines[2:end]]
end
function profile(path, window, variable)
    rs = filter(r -> r["variable"] == variable,
                rows(joinpath(path, "profiles_$(window)_long.csv")))
    sort!(rs; by=r -> parse(Float64, r["z_m"]))
    z = parse.(Float64, getindex.(rs, "z_m"))
    v = parse.(Float64, getindex.(rs, "value"))
    length(z) == 32 && all(isapprox.(diff(z), 12.5; atol=1e-6)) ||
        error("expected native 32-level center profile for $variable")
    return (; z, v)
end
function linear_sample(x, y, targets)
    out = Float64[]
    for target in targets
        j = searchsortedlast(x, target)
        1 <= j < length(x) || error("reference does not cover z=$target")
        λ = (target - x[j]) / (x[j+1] - x[j])
        push!(out, (1-λ)*y[j] + λ*y[j+1])
    end
    return out
end
const reference = JSON.parsefile(joinpath(ROOT, "gabls/reference_data/fixed_1m_medians.json"))["curves"]
function reference_profile(variable, targets)
    r = reference["profile/" * variable]
    valid = [i for i in eachindex(r["coordinates"])
             if r["coordinates"][i] !== nothing && r["median"][i] !== nothing]
    x = Float64.(r["coordinates"][valid])
    y = Float64.(r["median"][valid])
    order = sortperm(x)
    return linear_sample(x[order], y[order], targets)
end
function gradients(z, u, v)
    zg = (z[1:end-1] .+ z[2:end]) ./ 2
    du = diff(u) ./ diff(z)
    dv = diff(v) ./ diff(z)
    return (; z=zg, du, dv, magnitude=hypot.(du, dv))
end
const curves = Dict{Tuple{String,String},Any}()
for window in WINDOWS
    for (name,path) in CASES
        u = profile(path, window, "u_mean")
        v = profile(path, window, "v_mean")
        all(u.z .== v.z) || error("u/v heights differ for $name")
        curves[(window,name)] = (; u, v, shear=gradients(u.z,u.v,v.v))
    end
end
let z = curves[("final_hour","No closure")].u.z
    u = reference_profile("u_mean",z)
    v = reference_profile("v_mean",z)
    curves[("final_hour","Fixed 1 m median")] =
        (; u=(; z,v=u), v=(; z,v), shear=gradients(z,u,v))
end

f = Figure(size=(1720,1170), fontsize=18)
Label(f[0,1:3], "GABLS1: vertical shear of the mean horizontal wind", fontsize=29, font=:bold)
Label(f[1,1:3], "12.5 m WENO9 · same 400 m cube · derivatives between adjacent cell-center heights", fontsize=18)
axes = Axis[]
for (row,window) in enumerate(WINDOWS)
    for (col,(field,xlabel,title)) in enumerate((("u", "Mean u (m s⁻¹)", "Mean wind"),
                                                  ("du", "∂u/∂z (s⁻¹)", "Along-geostrophic shear"),
                                                  ("magnitude", "|∂(u,v)/∂z| (s⁻¹)", "Vector shear magnitude")))
        ax=Axis(f[row+1,col]; xlabel, ylabel="Height (m)",
                title=(row==1 ? "7–8 h · " : "8–9 h · ")*title)
        push!(axes,ax)
        names=row==1 ? ("No closure", "SLD covariance", "SLD scheme-native") :
                       ("No closure", "SLD covariance", "SLD scheme-native", "Fixed 1 m median")
        for name in names
            c=curves[(window,name)]
            y=field=="u" ? c.u.z : c.shear.z
            x=field=="u" ? c.u.v : getproperty(c.shear,Symbol(field))
            ix=findall(z -> 0 <= z <= 125, y)
            lines!(ax,x[ix],y[ix]; color=COLORS[name], linewidth=name=="SLD scheme-native" ? 3.4 : 2.5,
                   linestyle=name=="Fixed 1 m median" ? :dashdot : :solid, label=name)
            name=="Fixed 1 m median" || scatter!(ax,x[ix],y[ix];color=COLORS[name],markersize=5)
        end
        ylims!(ax,0,125)
        col==1 && row==2 && (global legend_ax=ax)
    end
end
Legend(f[4,1:3],legend_ax;orientation=:horizontal,nbanks=1,labelsize=17)
Label(f[5,1:3],"Reference is for 8–9 h only: componentwise median u and v profiles sampled at 12.5 m cell centers, then differentiated identically.\nThe reference shear is not the median of member shears. Each curve is a layer slope at 12.5, 25, 37.5… m, not a wall gradient.",fontsize=16,tellwidth=false)
save(joinpath(D,"figures/gabls1_shear.png"),f)
save(joinpath(D,"figures/gabls1_shear.pdf"),f)

open(joinpath(D,"shear_comparison.md"),"w") do io
    println(io,"# GABLS1 mean-wind shear comparison\n")
    println(io,"The gradients use differences between adjacent 12.5 m cell-center levels. The fixed 1 m LES componentwise median u and v profiles are first sampled at those same heights and then differentiated identically; this is shear of the median profiles, not the median of member shears. The reference is available for 8–9 h only. Shear at z=12.5 m describes the 6.25–18.75 m layer, not the wall gradient.\n")
    println(io,"| Window | Case | ∂u/∂z at 12.5 m (s⁻¹) | Vector shear at 12.5 m (s⁻¹) | Mean vector shear 12.5–100 m (s⁻¹) |")
    println(io,"|---|---|---:|---:|---:|")
    for window in WINDOWS
        names=window=="final_hour" ? ("No closure", "SLD covariance", "SLD scheme-native", "Fixed 1 m median") :
                                      ("No closure", "SLD covariance", "SLD scheme-native")
        for name in names
            s=curves[(window,name)].shear
            ix=findall(z -> z <= 100, s.z)
            @printf(io,"| %s | %s | %.5f | %.5f | %.5f |\n",window=="final_hour" ? "8–9 h" : "7–8 h",name,s.du[1],s.magnitude[1],mean(s.magnitude[ix]))
        end
    end
    println(io,"\n![Mean-wind shear](figures/gabls1_shear.png)\n")
    println(io,"The no-closure and covariance-SLD cases use the earlier corrected GABLS1 exports; the scheme-native SLD case uses the later measured-flux source. All use the same grid and forcing. The 1 m median is an LES intercomparison reference, not an observation.")
end
println(read(joinpath(D,"shear_comparison.md"),String))
