# Julia-only, physical-height comparison of the admitted 32³ and 64³ GABLS1 cases.
# Run after the three 64³ exports have passed their independent raw-output audits.
#
# julia --project=cases/surface_layer/gabls1/stability/julia compare_n64.jl OUTPUT_DIR
using CairoMakie, JSON, Statistics, Printf

length(ARGS) == 1 || error("usage: compare_n64.jl OUTPUT_DIR")
const OUT = abspath(only(ARGS))
const COORD = "/shared/home/greg/review-coordination"
const N64 = joinpath(COORD, "sld-gabls1-n64-20260923", "export")
const N32_CONTROL = joinpath(COORD, "sld-filtered-wall-20260923-v2", "export", "control")
const N32_SLD = joinpath(COORD, "sld-stability-gamma2-20260923", "export", "sld_gamma2")
const REF_JSON = get(ENV, "REFERENCE_JSON",
    "/shared/home/greg/Projects/BreezeEvaluation-sld-results/reports/sld-20260921/gabls/reference_data/fixed_1m_medians.json")

# Paths can be overridden to test against copied, audited exports.
const CASES = (
    (name="32³ no closure", path=get(ENV, "N32_CONTROL_EXPORT", N32_CONTROL), color="#009E73", style=:solid, n=32, sld=false, support=0),
    (name="64³ no closure", path=get(ENV, "N64_CONTROL_EXPORT", joinpath(N64, "control")), color="#0072B2", style=:solid, n=64, sld=false, support=0),
    (name="32³ γ=2, one face", path=get(ENV, "N32_SLD_EXPORT", N32_SLD), color="#D55E00", style=:solid, n=32, sld=true, support=1),
    (name="64³ γ=2, one face", path=get(ENV, "N64_S1_EXPORT", joinpath(N64, "sld_s1")), color="#CC79A7", style=:solid, n=64, sld=true, support=1),
    (name="64³ γ=2, two faces", path=get(ENV, "N64_S2_EXPORT", joinpath(N64, "sld_s2")), color="#E69F00", style=:solid, n=64, sld=true, support=2))
const WINDOWS = ((label="7–8 h", tag="penultimate_hour", t0=25200.0, t1=28800.0),
                 (label="8–9 h", tag="final_hour", t0=28800.0, t1=32400.0))
const REF = JSON.parsefile(REF_JSON)["curves"]

function rows(path)
    lines = readlines(path)
    h = String.(split(first(lines), ','))
    [Dict(k => String(v) for (k, v) in zip(h, split(line, ','))) for line in lines[2:end]]
end
num(r, k) = parse(Float64, r[k])
function profile(path, tag, variable)
    rs = filter(r -> r["variable"] == variable,
                rows(joinpath(path, "profiles_$(tag)_long.csv")))
    isempty(rs) && error("missing $variable in $path")
    sort!(rs; by=r -> num(r, "z_m"))
    (; z=[num(r, "z_m") for r in rs], v=[num(r, "value") for r in rs])
end
function series(path)
    rs = rows(joinpath(path, "series.csv"))
    Dict(k => [num(r, k) for r in rs] for k in keys(first(rs)))
end
function reference(name)
    r = REF["profile/" * name]
    ix = findall(i -> r["coordinates"][i] !== nothing && r["median"][i] !== nothing,
                 eachindex(r["coordinates"]))
    (; z=Float64.(r["coordinates"][ix]), v=Float64.(r["median"][ix]))
end
function sample(p, z)
    [begin
        j = searchsortedlast(p.z, zz)
        1 <= j < length(p.z) || error("profile does not cover $zz m")
        α = (zz - p.z[j]) / (p.z[j+1] - p.z[j])
        (1 - α) * p.v[j] + α * p.v[j+1]
    end for zz in z]
end
shear(z, u, v) = (; z=(z[1:end-1] .+ z[2:end]) ./ 2,
                    v=hypot.(diff(u) ./ diff(z), diff(v) ./ diff(z)))
mean_window(s, key, w) = mean(s[key][findall(t -> w.t0 <= t <= w.t1, s["time_s"])])
function face(p, tag, variable, z)
    q = profile(p, tag, variable)
    i = findfirst(x -> isapprox(x, z; atol=1e-5), q.z)
    isnothing(i) && error("no $variable at $z m in $p")
    q.v[i]
end

mkpath(OUT)
for c in CASES
    isfile(joinpath(c.path, "audit.toml")) || error("missing admitted audit: $(c.path)")
    length(profile(c.path, "final_hour", "u_mean").z) == c.n ||
        error("wrong native vertical level count: $(c.name)")
end

# Common-interval shear: interpolate each wind component to 32³ cell centers before
# differencing. The 64³ native finite difference is shown separately so a thin feature
# is not hidden by interpolation.
const ZC = profile(CASES[1].path, "final_hour", "u_mean").z
function common_shear(path, tag)
    u, v = profile(path, tag, "u_mean"), profile(path, tag, "v_mean")
    shear(ZC, sample(u, ZC), sample(v, ZC))
end
function native_shear(path, tag)
    u, v = profile(path, tag, "u_mean"), profile(path, tag, "v_mean")
    shear(u.z, u.v, v.v)
end
ref_shear() = shear(ZC, sample(reference("u_mean"), ZC),
                          sample(reference("v_mean"), ZC))

# Scientific profiles: dashed 7–8 h and solid 8–9 h. All reference curves are
# the fixed 1 m LES median; this is not an observation or a universal truth.
fig = Figure(size=(1850, 1280), fontsize=20)
Label(fig[0, 1:3], "GABLS1 32³ → 64³: matched stability-corrected SLD", fontsize=31, font=:bold)
Label(fig[1, 1:3], "400 m cube · WENO9 · γ=2 · 300 s wall/SLD filters · dashed 7–8 h, solid 8–9 h", fontsize=19)
panels = (("u_mean", "u_mean", "Mean u (m s⁻¹)", 250),
          ("theta_mean", "theta_mean", "Potential temperature (K)", 250),
          ("w_variance", "w_variance", "w² (m² s⁻²)", 250),
          ("w_third_central_moment", "w_third_central_moment", "w³ (m³ s⁻³)", 250),
          ("total_u_w_flux", "uw_total", "Total u–w flux (m² s⁻²)", 125),
          ("total_w_theta_flux", "wtheta_total", "Total w–θ flux (K m s⁻¹)", 125))
legend_axis = nothing
for (i, (var, refvar, label, top)) in enumerate(panels)
    ax = Axis(fig[2+div(i-1, 3), 1+mod(i-1, 3)]; xlabel=label, ylabel="Height (m)")
    for c in CASES, w in WINDOWS
        p = profile(c.path, w.tag, var)
        ix = findall(<=(top), p.z)
        lines!(ax, p.v[ix], p.z[ix]; color=c.color,
               linestyle=w.tag == "final_hour" ? :solid : :dash,
               linewidth=w.tag == "final_hour" ? 3.2 : 1.8,
               label=w.tag == "final_hour" ? c.name : nothing)
    end
    if haskey(REF, "profile/" * refvar)
        p = reference(refvar)
        ix = findall(<=(top), p.z)
        lines!(ax, p.v[ix], p.z[ix]; color=:black, linestyle=:dashdot,
               linewidth=2.6, label="Fixed 1 m LES median")
    end
    ylims!(ax, 0, top)
    i == 1 && (global legend_axis = ax)
end
Legend(fig[4, 1:3], legend_axis; orientation=:horizontal, nbanks=2, labelsize=16)
save(joinpath(OUT, "n64_profiles.pdf"), fig)
save(joinpath(OUT, "n64_profiles.png"), fig)

fig = Figure(size=(1700, 1100), fontsize=20)
Label(fig[0, 1:2], "Vector shear at matched physical heights", fontsize=30, font=:bold)
Label(fig[1, 1:2], "u and v interpolated to 32³ cell centers (6.25, 18.75, … m), then differenced", fontsize=19)
for (row, w) in enumerate(WINDOWS)
    ax = Axis(fig[1+row, 1]; xlabel="Vector shear (s⁻¹)", ylabel="Height (m)", title=w.label)
    for c in CASES
        p = common_shear(c.path, w.tag); ix = findall(<=(125), p.z)
        lines!(ax, p.v[ix], p.z[ix]; color=c.color, linewidth=3, label=c.name)
        scatter!(ax, p.v[ix], p.z[ix]; color=c.color, markersize=5)
    end
    r = ref_shear(); ix = findall(<=(125), r.z)
    lines!(ax, r.v[ix], r.z[ix]; color=:black, linestyle=:dashdot, linewidth=2.6,
           label="Fixed 1 m LES median")
    ylims!(ax, 0, 125)
    row == 2 && Legend(fig[3, 1:2], ax; orientation=:horizontal, nbanks=2, labelsize=16)
end
save(joinpath(OUT, "n64_common_shear.pdf"), fig)
save(joinpath(OUT, "n64_common_shear.png"), fig)

fig = Figure(size=(1650, 1000), fontsize=20)
Label(fig[0, 1:2], "Native-grid vector shear", fontsize=30, font=:bold)
Label(fig[1, 1:2], "64³ shear spans 6.25 m; 32³ shear spans 12.5 m. Compare with matched-height figure.", fontsize=18)
for (row, w) in enumerate(WINDOWS)
    ax = Axis(fig[1+row, 1]; xlabel="Native vector shear (s⁻¹)", ylabel="Height (m)", title=w.label)
    for c in CASES
        p = native_shear(c.path, w.tag); ix = findall(<=(125), p.z)
        lines!(ax, p.v[ix], p.z[ix]; color=c.color, linewidth=2.8, label=c.name)
        scatter!(ax, p.v[ix], p.z[ix]; color=c.color, markersize=4)
    end
    ylims!(ax, 0, 125)
    row == 2 && Legend(fig[3, 1:2], ax; orientation=:horizontal, nbanks=2, labelsize=16)
end
save(joinpath(OUT, "n64_native_shear.pdf"), fig)
save(joinpath(OUT, "n64_native_shear.png"), fig)

# Wall time histories and the resolved/SGS transport partition at the common
# physical face z=12.5 m. WENO correction is separately tabulated below.
fig = Figure(size=(1750, 1150), fontsize=19)
Label(fig[0, 1:2], "Wall response and vertical-transport partition", fontsize=30, font=:bold)
wall_legend = nothing
for (row, (key, unit, title)) in enumerate((("friction_velocity", "m s⁻¹", "Friction velocity"),
                                              ("surface_theta_kinematic_flux", "K m s⁻¹", "Surface heat flux")))
    ax = Axis(fig[1+row, 1]; xlabel="Time (h)", ylabel=unit, title=title)
    for c in CASES
        s = series(c.path)
        lines!(ax, s["time_s"] ./ 3600, s[key]; color=c.color, linewidth=2.2, label=c.name)
    end
    xlims!(ax, 7, 9)
    row == 1 && (global wall_legend = ax)
end
for (row, (vars, unit, title)) in enumerate((
    (("resolved_u_w_flux", "sgs_u_w_flux", "total_u_w_flux"), "m² s⁻²", "u–w at z=12.5 m"),
    (("resolved_w_theta_flux", "sgs_w_theta_flux", "total_w_theta_flux"), "K m s⁻¹", "w–θ at z=12.5 m")))
    ax = Axis(fig[1+row, 2]; xlabel="Flux ($unit)", title=title,
              yticks=(1:15, [c.name * " " * part for c in CASES for part in ("resolved", "SGS", "total")]))
    values = [face(c.path, "final_hour", var, 12.5) for c in CASES for var in vars]
    colors = [c.color for c in CASES for _ in vars]
    barplot!(ax, 1:15, values; direction=:x, color=colors)
end
Legend(fig[4, 1:2], wall_legend; orientation=:horizontal, nbanks=2, labelsize=16)
save(joinpath(OUT, "n64_wall_transport.pdf"), fig)
save(joinpath(OUT, "n64_wall_transport.png"), fig)

# Face comparisons use physical z=12.5 m: face1 on 32³ and face2 on 64³.
# The 64³ face1 at 6.25 m is listed separately, never conflated with z=12.5 m.
open(joinpath(OUT, "n64_metrics.md"), "w") do io
    println(io, "# Matched GABLS1 32³–64³ metrics")
    println(io, "\nAll shear values below use common 12.5 m height intervals. Native-grid shear is in the figures. Two grids show a trend, not formal convergence.\n")
    println(io, "| Case | Window | Shear 12.5 m | Shear 25 m | Shear 37.5 m | Peak w² | w³ at 18.75 m | u* | Surface heat flux |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for c in CASES
        s = series(c.path)
        for w in WINDOWS
            sh = common_shear(c.path, w.tag)
            w2 = profile(c.path, w.tag, "w_variance")
            w3 = profile(c.path, w.tag, "w_third_central_moment")
            w3at = sample(w3, [18.75])[1]
            @printf(io, "| %s | %s | %.5f | %.5f | %.5f | %.5f | %.5g | %.5f | %.5f |\n",
                    c.name, w.label, sh.v[1], sh.v[2], sh.v[3],
                    maximum(w2.v), w3at, mean_window(s, "friction_velocity", w),
                    mean_window(s, "surface_theta_kinematic_flux", w))
        end
    end
    r = ref_shear()
    @printf(io, "| Fixed 1 m LES median | 8–9 h | %.5f | %.5f | %.5f | — | — | — | — |\n",
            r.v[1], r.v[2], r.v[3])
    println(io, "\n## Face-specific transport and coefficients, 8–9 h\n")
    println(io, "| Case | Physical face height (m) | Viscosity | Heat diffusivity | Resolved u–w | SGS u–w | WENO u correction | Resolved w–θ | SGS w–θ |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for c in CASES
        c.sld || continue
        heights = c.n == 32 ? (12.5,) : c.support == 2 ? (6.25, 12.5) : (6.25,)
        for z in heights
            slot = Int(round(z / (400 / c.n)))
            ss = series(c.path)
            prefix = "surface_layer_face$(slot)_"
            w = WINDOWS[2]
            ν = mean_window(ss, prefix * "viscosity", w)
            κθ = mean_window(ss, prefix * "ρθ_diffusivity", w)
            nc = mean_window(ss, prefix * "numerical_u_correction", w)
            @printf(io, "| %s | %.2f | %.5f | %.5f | %.5f | %.5f | %.5f | %.5f | %.5f |\n",
                    c.name, z, ν, κθ,
                    face(c.path, w.tag, "resolved_u_w_flux", z),
                    face(c.path, w.tag, "sgs_u_w_flux", z), nc,
                    face(c.path, w.tag, "resolved_w_theta_flux", z),
                    face(c.path, w.tag, "sgs_w_theta_flux", z))
        end
    end
end
println(read(joinpath(OUT, "n64_metrics.md"), String))
