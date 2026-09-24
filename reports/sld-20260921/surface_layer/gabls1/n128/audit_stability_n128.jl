# Independent audit of local SLD stability state at 128³, including face two when active.
# Recomputes 1/L and φ from the saved filtered wall fluxes, checks the stored values, and
# exports horizontal statistics of local quantities (never φ of a mean L).
using JLD2, TOML, Statistics, Printf

length(ARGS) == 3 || error("usage: julia audit_stability.jl RUN_DIRECTORY OUTPUT_DIRECTORY CASE_ID")
run_dir, out_dir, case_id = ARGS
support = occursin("_s2_", case_id) ? 2 : 1
path = joinpath(run_dir, case_id * "_sld_stability.jld2")
isfile(path) || error("missing $path")

const κ, g, θ₀ = 0.4, 9.81, 263.5          # closure default, Breeze constant, GABLS1 reference θ
const λ, βᵐ, βʰ, z₁ = 2.0, 4.8, 7.8, 3.125
const minimum_stress, heat_guard = 1e-8, 1e-8  # (1e-4 m/s)², ρθ guard of the case
interior_xy(a) = size(a, 1) == 128 ? a[:, :, 1] : a[6:133, 6:133, 1]

rows = NamedTuple[]
jldopen(path, "r") do f
    keys_t = sort(collect(keys(f["timeseries/t"])); by=k -> f["timeseries/t/$k"])
    # STABILITY_STOP_SECONDS exists only to exercise this audit on bounded gate output.
    expected = collect(0.0:600.0:parse(Float64, get(ENV, "STABILITY_STOP_SECONDS", "32400")))
    length(keys_t) == length(expected) || error("record count $(length(keys_t))")
    for (n, k) in enumerate(keys_t)
        t = Float64(f["timeseries/t/$k"])
        isapprox(t, expected[n]; atol=1e-5) || error("record time $t")
        get(name) = Float64.(interior_xy(f["timeseries/$name/$k"]))
        inverse_length = get("inverse_obukhov_length")
        state = get("stability_state")
        φᵐ = get("face1_momentum_stability_function")
        φʰ = get("face1_scalar_stability_function")
        τx, τy, Fθ = get("filtered_surface_u_flux"), get("filtered_surface_v_flux"),
                     get("filtered_surface_theta_flux")
        all(isfinite, inverse_length) && all(isfinite, φᵐ) && all(isfinite, φʰ) ||
            error("nonfinite stability state at $t")
        stress = hypot.(τx, τy)
        valid = (stress .> minimum_stress) .& (abs.(Fθ) .> heat_guard)
        reference = ifelse.(valid, -κ * g .* Fθ ./ (θ₀ .* sqrt.(stress) .^ 3), 0.0)
        maximum(abs.(reference .- inverse_length) ./ max.(abs.(reference), 1e-6)) < 1e-3 ||
            error("stored 1/L differs from saved filtered fluxes at $t")
        all(state .== sign.(inverse_length)) || error("state/sign mismatch at $t")
        ζ = z₁ .* max.(0, inverse_length)
        maximum(abs.(φᵐ .- (1 .+ λ * βᵐ .* ζ))) < 1e-4 * maximum(φᵐ) || error("φm identity at $t")
        maximum(abs.(φʰ .- (1 .+ λ * βʰ .* ζ))) < 1e-4 * maximum(φʰ) || error("φh identity at $t")
        if support == 2
            φᵐ₂ = get("face2_momentum_stability_function")
            φʰ₂ = get("face2_scalar_stability_function")
            # Face two is at 2Δz = 6.25 m here; do not reuse the 64³ 12.5 m height.
            ζ₂ = (2z₁) .* max.(0, inverse_length)
            maximum(abs.(φᵐ₂ .- (1 .+ λ * βᵐ .* ζ₂))) < 1e-4 * maximum(φᵐ₂) || error("face2 φm identity at $t")
            maximum(abs.(φʰ₂ .- (1 .+ λ * βʰ .* ζ₂))) < 1e-4 * maximum(φʰ₂) || error("face2 φh identity at $t")
        end
        stable = state .== 1
        push!(rows, (; time_s=t,
            stable_fraction=mean(stable), neutral_fraction=mean(state .== 0),
            upward_fraction=mean(state .== -1),
            mean_inverse_length=mean(inverse_length),
            median_stable_L=any(stable) ? median(1 ./ inverse_length[stable]) : NaN,
            mean_zeta=mean(ζ), max_zeta=maximum(ζ),
            mean_phi_m=mean(φᵐ), mean_phi_h=mean(φʰ),
            mean_inverse_phi_m=mean(1 ./ φᵐ), mean_inverse_phi_h=mean(1 ./ φʰ)))
    end
end

mkpath(out_dir)
columns = keys(first(rows))
open(joinpath(out_dir, "stability_series.csv"), "w") do io
    println(io, join(columns, ','))
    for r in rows
        println(io, join([@sprintf("%.10g", getproperty(r, c)) for c in columns], ','))
    end
end
window(a, b) = filter(r -> a < r.time_s <= b, rows)
summary = Dict{String, Any}("case_id" => case_id, "records" => length(rows),
    "support" => support, "stored_inverse_length_matches_saved_fluxes" => true,
    "phi_identities_pass" => true, "face2_phi_identities_pass" => support == 2)
for (label, a, b) in (("7-8h", 25200.0, 28800.0), ("8-9h", 28800.0, 32400.0))
    w = window(a, b)
    isempty(w) && continue
    summary[label] = Dict(string(c) => mean(getproperty.(w, c)) for c in columns if c != :time_s)
end
summary["max_upward_fraction_after_1h"] =
    maximum((r.upward_fraction for r in rows if r.time_s >= 3600); init=0.0)
open(io -> TOML.print(io, summary), joinpath(out_dir, "stability_audit.toml"), "w")
last_row = rows[end]
@printf("STABILITY_ADMITTED records=%d final t=%.0f s stable=%.4f upward=%.4f mean φm=%.4f φh=%.4f median L=%.1f m\n",
        length(rows), last_row.time_s, last_row.stable_fraction, last_row.upward_fraction,
        last_row.mean_phi_m, last_row.mean_phi_h, last_row.median_stable_L)
