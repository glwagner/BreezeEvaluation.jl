# Compare λ=2 with the admitted λ=0, 1, and 4 filtered-SLD cases, filtered no closure,
# and the fixed 1 m LES median. Inputs are audited exports; nothing is rerun.
#
#   julia --project=julia compare_gamma2.jl OUTPUT_DIRECTORY
#
# Paths default to the admitted filtered-wall campaign and may be overridden by environment.
using CairoMakie, JSON, Statistics, Printf

const COORDINATION = "/shared/home/greg/review-coordination"
const FILTERED = joinpath(COORDINATION, "sld-filtered-wall-20260923-v2", "export")
const STABILITY = joinpath(COORDINATION, "sld-stability-20260923", "export")
const GAMMA2 = joinpath(COORDINATION, "sld-stability-gamma2-20260923", "export")
const GAMMA4 = joinpath(COORDINATION, "sld-stability-gamma4-20260923", "export")
const REFERENCE_JSON = get(ENV, "REFERENCE_JSON",
    "/shared/home/greg/Projects/BreezeEvaluation-sld-results/reports/sld-20260921/gabls/reference_data/fixed_1m_medians.json")

length(ARGS) == 1 || error("usage: compare_gamma2.jl OUTPUT_DIRECTORY")
const OUT = abspath(ARGS[1])

const CASES = (
    ("Filtered · no closure", get(ENV, "CONTROL_EXPORT", joinpath(FILTERED, "control")), "#009E73"),
    ("Filtered · SLD λ=0", get(ENV, "LAMBDA0_EXPORT", joinpath(FILTERED, "sld")), "#CC79A7"),
    ("Filtered · SLD λ=1", get(ENV, "LAMBDA1_EXPORT", joinpath(STABILITY, "sld_lambda1")), "#E69F00"),
    ("Filtered · SLD λ=2", get(ENV, "GAMMA2_EXPORT", joinpath(GAMMA2, "sld_gamma2")), "#D55E00"),
    ("Filtered · SLD λ=4", get(ENV, "GAMMA4_EXPORT", joinpath(GAMMA4, "sld_gamma4")), "#0072B2"))
const SLD_CASES = CASES[2:5]
const REF = JSON.parsefile(REFERENCE_JSON)["curves"]
const WINDOWS = (("7–8 h", "penultimate_hour", 25200.0, 28800.0),
                 ("8–9 h", "final_hour", 28800.0, 32400.0))

function rows(path)
    lines = readlines(path)
    header = String.(split(first(lines), ','))
    [Dict(k => String(v) for (k, v) in zip(header, split(line, ','))) for line in lines[2:end]]
end
num(r, k) = parse(Float64, r[k])
function profile(path, window, variable)
    rs = filter(r -> r["variable"] == variable, rows(joinpath(path, "profiles_$(window)_long.csv")))
    isempty(rs) && error("missing $variable at $path")
    sort!(rs; by=r -> num(r, "z_m"))
    (; z=[num(r, "z_m") for r in rs], v=[num(r, "value") for r in rs])
end
function series(path)
    rs = rows(joinpath(path, "series.csv"))
    Dict(k => [num(r, k) for r in rs] for k in keys(first(rs)))
end
const SERIES = Dict(name => series(path) for (name, path, _) in CASES)

function refprofile(name)
    r = REF["profile/" * name]
    ix = findall(i -> r["coordinates"][i] !== nothing && r["median"][i] !== nothing,
                 eachindex(r["coordinates"]))
    (; z=Float64.(r["coordinates"][ix]), v=Float64.(r["median"][ix]))
end
function sample(p, z)
    [begin
        j = searchsortedlast(p.z, zz)
        1 <= j < length(p.z) || error("reference does not cover $zz m")
        a = (zz - p.z[j]) / (p.z[j+1] - p.z[j]); (1 - a) * p.v[j] + a * p.v[j+1]
    end for zz in z]
end
shear(u, v) = (; z=(u.z[1:end-1] .+ u.z[2:end]) ./ 2,
                 v=hypot.(diff(u.v) ./ diff(u.z), diff(v.v) ./ diff(v.z)))
window_mean(s, key, a, b) = mean(s[key][findall(t -> a <= t <= b, s["time_s"])])
face_value(path, window, variable, z) = (p = profile(path, window, variable);
                                          p.v[findfirst(≈(z), p.z)])

mkpath(OUT)

# Profiles: dashed 7–8 h, solid 8–9 h, fixed 1 m median dash-dot.
f = Figure(size=(1800, 1160), fontsize=20)
Label(f[0, 1:3], "GABLS1: stable Monin–Obukhov correction of SLD", fontsize=30, font=:bold)
Label(f[1, 1:3], "32³ · 12.5 m · WENO9 · filtered wall · scheme-native one-face SLD · λ=0, 1, 2, 4 · dashed 7–8 h, solid 8–9 h", fontsize=19)
panels = (("u_mean", "u_mean", "Mean u (m s⁻¹)"), ("theta_mean", "theta_mean", "Potential temperature (K)"),
          ("w_variance", "w_variance", "w² (m² s⁻²)"), ("w_third_central_moment", "w_third_central_moment", "w³ (m³ s⁻³)"),
          ("total_u_w_flux", "uw_total", "Total u–w flux (m² s⁻²)"), ("total_w_theta_flux", "wtheta_total", "Total w–θ flux (K m s⁻¹)"))
profile_legend = nothing
for (i, (var, refvar, xlab)) in enumerate(panels)
    top = var in ("total_u_w_flux", "total_w_theta_flux") ? 125 : 250
    ax = Axis(f[2+div(i-1, 3), 1+mod(i-1, 3)]; xlabel=xlab, ylabel="Height (m)")
    for (name, path, color) in CASES, (_, window, _, _) in WINDOWS
        style = window == "final_hour" ? :solid : :dash
        p = profile(path, window, var); ix = findall(<=(top), p.z)
        lines!(ax, p.v[ix], p.z[ix]; color, linestyle=style, linewidth=style == :solid ? 3.2 : 2.0,
               label=window == "final_hour" ? name : nothing)
    end
    if haskey(REF, "profile/" * refvar)
        p = refprofile(refvar); ix = findall(<=(top), p.z)
        isempty(ix) || lines!(ax, p.v[ix], p.z[ix]; color=:black, linestyle=:dashdot, linewidth=2.5,
                              label="Fixed 1 m LES median")
    end
    ylims!(ax, 0, top)
    i == 1 && (global profile_legend = ax)
end
Legend(f[4, 1:3], profile_legend; orientation=:horizontal, nbanks=1, labelsize=18)
save(joinpath(OUT, "stability_profiles.pdf"), f)
save(joinpath(OUT, "stability_profiles.png"), f)

# Shear and wall fluxes.
f = Figure(size=(1700, 1060), fontsize=20)
Label(f[0, 1:2], "Mean-wind shear and wall flux", fontsize=30, font=:bold)
Label(f[1, 1:2], "Shear between adjacent 12.5 m cell centers; fixed 1 m median sampled at the same heights", fontsize=19)
shear_legend = nothing
for (row, (label, window, _, _)) in enumerate(WINDOWS)
    ax = Axis(f[1+row, 1]; xlabel="Vector shear (s⁻¹)", ylabel="Height (m)", title=label)
    for (name, path, color) in CASES
        sh = shear(profile(path, window, "u_mean"), profile(path, window, "v_mean"))
        ix = findall(<=(125), sh.z)
        lines!(ax, sh.v[ix], sh.z[ix]; color, linewidth=3, label=name)
        scatter!(ax, sh.v[ix], sh.z[ix]; color, markersize=5)
    end
    z = profile(CASES[1][2], window, "u_mean").z
    sh = shear((; z, v=sample(refprofile("u_mean"), z)), (; z, v=sample(refprofile("v_mean"), z)))
    ix = findall(<=(125), sh.z)
    lines!(ax, sh.v[ix], sh.z[ix]; color=:black, linestyle=:dashdot, linewidth=2.7,
           label="Fixed 1 m LES median (8–9 h)")
    ylims!(ax, 0, 125)
    row == 2 && (global shear_legend = ax)
end
for (i, (key, title)) in enumerate((("friction_velocity", "Surface friction velocity (m s⁻¹)"),
                                    ("surface_theta_kinematic_flux", "Surface heat flux (K m s⁻¹)")))
    ax = Axis(f[1+i, 2]; xlabel="Time (h)", ylabel=title)
    for (name, _, color) in CASES
        s = SERIES[name]; lines!(ax, s["time_s"] ./ 3600, s[key]; color, linewidth=2.4, label=name)
    end
    xlims!(ax, 0, 9)
end
Legend(f[4, 1:2], shear_legend; orientation=:horizontal, nbanks=2)
save(joinpath(OUT, "stability_shear_flux.pdf"), f)
save(joinpath(OUT, "stability_shear_flux.png"), f)

# First-face SLD coefficients and the local stability state of the λ=2 run.
stability_rows = rows(joinpath(CASES[4][2], "stability_series.csv"))
st(k) = [num(r, k) for r in stability_rows]
f = Figure(size=(1700, 1060), fontsize=20)
Label(f[0, 1:2], "First-face SLD coefficients and local stability", fontsize=30, font=:bold)
Label(f[1, 1:2], "Horizontal means of local quantities at z = 12.5 m; φ is never evaluated from a mean L", fontsize=19)
coefficient_legend = nothing
for (col, (key, title)) in enumerate((("surface_layer_face1_viscosity", "SLD viscosity (m² s⁻¹)"),
                                      ("surface_layer_face1_ρθ_diffusivity", "SLD heat diffusivity (m² s⁻¹)")))
    ax = Axis(f[2, col]; xlabel="Time (h)", ylabel=title)
    for (name, _, color) in SLD_CASES
        s = SERIES[name]; lines!(ax, s["time_s"] ./ 3600, s[key]; color, linewidth=2.4, label=name)
    end
    xlims!(ax, 0, 9)
    col == 1 && (global coefficient_legend = ax)
end
φ_axis = Axis(f[3, 1]; xlabel="Time (h)", ylabel="Mean φ at 12.5 m")
lines!(φ_axis, st("time_s") ./ 3600, st("mean_phi_m"); color="#D55E00", linewidth=2.6, label="φₘ")
lines!(φ_axis, st("time_s") ./ 3600, st("mean_phi_h"); color="#D55E00", linestyle=:dash, linewidth=2.6, label="φₕ")
axislegend(φ_axis; position=:rb); xlims!(φ_axis, 0, 9)
fraction_axis = Axis(f[3, 2]; xlabel="Time (h)", ylabel="Column fraction")
lines!(fraction_axis, st("time_s") ./ 3600, st("stable_fraction"); color="#D55E00", linewidth=2.6, label="stable (corrected)")
lines!(fraction_axis, st("time_s") ./ 3600, st("upward_fraction"); color="#56B4E9", linewidth=2.6, label="upward flux (φ = 1)")
lines!(fraction_axis, st("time_s") ./ 3600, st("neutral_fraction"); color=:gray40, linewidth=2.0, label="guarded (φ = 1)")
axislegend(fraction_axis; position=:rc); xlims!(fraction_axis, 0, 9); ylims!(fraction_axis, -0.02, 1.02)
Legend(f[4, 1:2], coefficient_legend; orientation=:horizontal)
save(joinpath(OUT, "stability_coefficients.pdf"), f)
save(joinpath(OUT, "stability_coefficients.png"), f)

# First-face momentum and heat partition: covariance, numerical correction, and SGS.
f = Figure(size=(1600, 1050), fontsize=20)
Label(f[0, 1:2], "Scheme-native SLD: first-face transport partition", fontsize=29, font=:bold)
Label(f[1, 1:2], "Reconstructed resolved = covariance + numerical correction; SGS is the SLD constitutive flux", fontsize=19)
partition_legend = nothing
for (row, (stem, unit)) in enumerate((("u", "m² s⁻²"), ("ρθ", "K m s⁻¹")))
    ax = Axis(f[1+row, 1]; xlabel="Time (h)", ylabel="Flux ($unit)", title=stem == "u" ? "Momentum" : "Heat")
    for (name, _, color) in SLD_CASES
        s = SERIES[name]; pref = "surface_layer_face1_"
        names = stem == "u" ? (pref * "resolved_u_flux", pref * "numerical_u_correction", pref * "reconstructed_u_flux") :
                              (pref * "ρθ_resolved_flux", pref * "ρθ_numerical_correction", pref * "ρθ_reconstructed_flux")
        for (j, style) in enumerate((:solid, :dash, :dot))
            lines!(ax, s["time_s"] ./ 3600, s[names[j]]; color, linestyle=style, linewidth=2.4,
                   label=name * " " * ("covariance", "correction", "reconstructed")[j])
        end
    end
    xlims!(ax, 7, 9)
    row == 1 && (global partition_legend = ax)
    ax2 = Axis(f[1+row, 2]; xlabel="Flux at 12.5 m ($unit)", ylabel="",
               title=(stem == "u" ? "u–w" : "w–θ") * " partition, 8–9 h",
               yticks=(1:12, vcat([[n * " resolved", n * " SGS", n * " total"] for n in ("λ=0", "λ=1", "λ=2", "λ=4")]...)))
    variables = stem == "u" ? ("resolved_u_w_flux", "sgs_u_w_flux", "total_u_w_flux") :
                              ("resolved_w_theta_flux", "sgs_w_theta_flux", "total_w_theta_flux")
    values = [face_value(path, "final_hour", v, 12.5) for (_, path, _) in SLD_CASES for v in variables]
    colors = [color for (_, _, color) in SLD_CASES for _ in variables]
    barplot!(ax2, 1:12, values; direction=:x, color=colors)
end
Legend(f[4, 1:2], partition_legend; orientation=:horizontal, nbanks=2, labelsize=15)
save(joinpath(OUT, "stability_partition.pdf"), f)
save(joinpath(OUT, "stability_partition.png"), f)

open(joinpath(OUT, "metrics.md"), "w") do io
    println(io, "# GABLS1 SLD stability-correction metrics\n")
    println(io, "One seed per condition; half-hour-bin window averages; differences are descriptive. The fixed 1 m reference is an LES intercomparison median, not observations, and λ was not tuned against it.\n")
    println(io, "| Case | Window | First-layer vector shear (s⁻¹) | Mean u* (m s⁻¹) | Mean surface heat flux (K m s⁻¹) | Peak w² (m² s⁻²) | w³ at 18.75 m (m³ s⁻³) | Domain L (m) |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|")
    for (name, path, _) in CASES, (label, window, a, b) in WINDOWS
        sh = shear(profile(path, window, "u_mean"), profile(path, window, "v_mean"))
        w2 = profile(path, window, "w_variance")
        w3 = profile(path, window, "w_third_central_moment")
        w3_18 = w3.v[findfirst(≈(18.75), w3.z) === nothing ? findfirst(≈(12.5), w3.z) : findfirst(≈(18.75), w3.z)]
        s = SERIES[name]
        @printf(io, "| %s | %s | %.5f | %.5f | %.6f | %.5f | %.3e | %.1f |\n", name, label, sh.v[1],
                window_mean(s, "friction_velocity", a, b), window_mean(s, "surface_theta_kinematic_flux", a, b),
                maximum(w2.v), w3_18, window_mean(s, "obukhov_length", a, b))
    end
    z = profile(CASES[1][2], "final_hour", "u_mean").z
    sh = shear((; z, v=sample(refprofile("u_mean"), z)), (; z, v=sample(refprofile("v_mean"), z)))
    @printf(io, "| Fixed 1 m LES median | 8–9 h | %.5f | — | — | — | — | — |\n", sh.v[1])
    println(io, "\n## First-face (12.5 m) SLD transport\n")
    println(io, "| Case | Window | Viscosity (m² s⁻¹) | Heat diffusivity (m² s⁻¹) | u covariance (m² s⁻²) | u numerical correction | u–w resolved (profile) | u–w SGS (profile) | w–θ resolved (K m s⁻¹) | w–θ SGS (K m s⁻¹) |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for (name, path, _) in SLD_CASES, (label, window, a, b) in WINDOWS
        s = SERIES[name]; p = "surface_layer_face1_"; m(k) = window_mean(s, k, a, b)
        @printf(io, "| %s | %s | %.5g | %.5g | %.5g | %.5g | %.5g | %.5g | %.5g | %.5g |\n", name, label,
                m(p * "viscosity"), m(p * "ρθ_diffusivity"), m(p * "resolved_u_flux"), m(p * "numerical_u_correction"),
                face_value(path, window, "resolved_u_w_flux", 12.5), face_value(path, window, "sgs_u_w_flux", 12.5),
                face_value(path, window, "resolved_w_theta_flux", 12.5), face_value(path, window, "sgs_w_theta_flux", 12.5))
    end
    println(io, "\n## λ=2 local stability state (horizontal means of local values)\n")
    println(io, "| Window | Stable fraction | Upward-flux fraction | Mean φₘ | Mean φₕ | Mean 1/φₘ | Mean 1/φₕ | Median stable local L (m) |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|---:|")
    for (label, _, a, b) in WINDOWS
        ix = findall(r -> a < num(r, "time_s") <= b, stability_rows)
        m(k) = mean(num(stability_rows[i], k) for i in ix)
        @printf(io, "| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.1f |\n", label, m("stable_fraction"),
                m("upward_fraction"), m("mean_phi_m"), m("mean_phi_h"), m("mean_inverse_phi_m"),
                m("mean_inverse_phi_h"), m("median_stable_L"))
    end
end
println(read(joinpath(OUT, "metrics.md"), String))
