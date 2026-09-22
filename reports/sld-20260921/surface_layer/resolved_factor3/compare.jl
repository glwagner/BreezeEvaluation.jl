#!/usr/bin/env julia
using SHA, TOML, JSON, Statistics, Printf
include("analysis_v1/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots: comparison_profile
const Data = SurfaceLayerScientificPlots.SurfaceLayerAnalysisData
const D = @__DIR__
hashfile(path) = bytes2hex(open(sha256, path))
const SOURCE_SHA = "818b06d6ed93968232d8ea3049e2098b3fbbbd2c2b1764f1cdc8f3103769709b"
const TEN_SOURCE_SHA = "32ebced6c54266ce5f9d7300759635e51d599bc1b090ced070eaa6111e540b0f"
const OLD_SOURCE_SHA = "395f7a42b5cdc7dfd688d1e0b0d0d2767f11d4cb186748070d517f507b74c1c4"
const OLD_REGISTRY_SHA = "6dcd5c7f597a80a64beaa7b021df57891bbd6599eae9e66db38d968e76cb1832"
const TEN_GPU_SHA = "4d9e203c5c25f8f98d9ea6fe89419f9a647556996e009fdee30f2490fe738b01"
const GPU_SHA = "e2023069d0527ad7efa2a490a6765e18392ff29fdfd263923c8e7b240bfc0c98"
const OLD_GPU_SHA = "facbd8488192443eb41c2a7dc8e269759429039a9c3ec0fd08e0a0e58bb140ae"
const INITIAL_SHA = "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
const source_manifest = joinpath(D, "analysis_v1/source_sha256.txt")
@assert hashfile(source_manifest) == SOURCE_SHA
@assert hashfile(joinpath(D,"evidence_v1/gpu/validation_evidence.toml")) == GPU_SHA
const gpu_evidence = TOML.parsefile(joinpath(D,"evidence_v1/gpu/validation_evidence.toml"))
@assert gpu_evidence["all_passed"] && gpu_evidence["observers_are_read_only"]
for name in ("SurfaceLayerAnalysisData.jl", "SurfaceLayerScientificPlots.jl")
    suffix = "source/BreezeEvaluation.jl/cases/surface_layer/analysis/$name"
    line = only(filter(line -> endswith(line, suffix), readlines(source_manifest)))
    @assert hashfile(joinpath(D, "analysis_v1", name)) == first(split(line))
end
const collection = TOML.parsefile(joinpath(D, "collection_v1/manifest.toml"))
@assert collection["admitted_count"] == 1 && collection["rejected_count"] == 0
@assert hashfile(joinpath(D, "analysis_v1/attempts.toml")) == collection["attempt_registry_sha256"]
@assert collection["attempt_registry_sha256"] == "4b8627478204afcaf50360a90aac27ac36268f8c3bb9404c57897a468204a3ca"
const ten_collection = TOML.parsefile(joinpath(D,"../resolved_factor10/collection_v2/manifest.toml"))
@assert ten_collection["admitted_count"] == 1 && ten_collection["rejected_count"] == 0
@assert ten_collection["attempt_registry_sha256"] == "d92a62ac01b2fa45165c4a6c1c086758e6dc5289c846437e4ab9a92542a4c12b"
@assert hashfile(joinpath(D,"../resolved_factor10/analysis_v2/attempts.toml")) == ten_collection["attempt_registry_sha256"]
const old_collection = TOML.parsefile(joinpath(D, "../resolved_factor/collection_v2/manifest.toml"))
@assert old_collection["admitted_count"] == 2 && old_collection["rejected_count"] == 0
@assert hashfile(joinpath(D,"../resolved_factor/analysis_v2/attempts.toml")) == old_collection["attempt_registry_sha256"]
const cases = Dict{String, Any}()
const ids = Dict{String, String}()
const roles = Dict("factor1"=>"Admitted factor 1 from array7331", "factor2"=>"Admitted factor 2 from array7331",
                   "factor3"=>"Factor3, same Breeze physics and switch-off diagnostics as factor10",
                   "factor10"=>"Factor10, same Breeze physics, diagnostic-only evaluation revision",
                   "historical_oneface300"=>"7293 earlier-source one-face 300 s context",
                   "historical_control"=>"7293 earlier-source no-closure context")
for factor in (1, 2, 3, 10)
    id = "gabls1_n032_weno9_surface_layer_t300_s1_rf$(factor)p0"
    this_collection = factor == 3 ? collection : factor == 10 ? ten_collection : old_collection
    entry = only(filter(e -> e["case_id"] == id, this_collection["admitted"]))
    directory = joinpath(D, factor == 3 ? "exports_v1" : factor == 10 ? "../resolved_factor10/exports_v2" : "../resolved_factor/exports_v2", id)
    @assert hashfile(joinpath(directory, "manifest.toml")) == entry["manifest_sha256"]
    c = Data.load_case_export(directory)
    p = c.manifest["provenance"]
    @assert p["source_freeze_manifest_sha256"] == p["analysis_freeze"]["manifest_sha256"] == (factor == 3 ? SOURCE_SHA : factor == 10 ? TEN_SOURCE_SHA : OLD_SOURCE_SHA)
    registry_sha = factor == 3 ? "e6afbb08e7af4995df8611578121d3304d81986c0b809ffe9938c2bb958f154a" : factor == 10 ? "d1f4e56ed705ce035207d9900e8da441cb8f4d3a06a283acaa4958e08f314519" : OLD_REGISTRY_SHA
    @assert p["scientific_registry_sha256"] == registry_sha
    @assert p["gpu_validation"]["evidence_sha256"] == (factor == 3 ? GPU_SHA : factor == 10 ? TEN_GPU_SHA : OLD_GPU_SHA)
    @assert p["scientific_case_settings"]["resolved_flux_factor"] == factor
    @assert p["scientific_case_settings"]["support"] == 1
    @assert p["scientific_case_settings"]["filter_seconds"] == 300
    @assert p["completion"]["final_time_s"] == 32400
    for kind in ("initial", "profiles", "series")
        @assert c.manifest["raw_metadata"][kind]["resolved_flux_factor"] == factor
    end
    cases["factor$factor"] = c
    ids["factor$factor"] = id
end
const attempts = TOML.parsefile(joinpath(D, "analysis_v1/attempts.toml"))
@assert attempts["source_evaluation_commit"] == "b9c31029929650c61040a5a20f9699de9a457978"
@assert attempts["source_breeze_commit"] == "1df78f2bb94db159e3a296f7439e1a5e90286014"
for attempt in attempts["attempts"]
    @assert attempt["batch_child_exit_code"] == 0
    exitpath = joinpath(D, "logs_v1", basename(attempt["batch_exit_record_path"]))
    @assert hashfile(exitpath) == attempt["batch_exit_record_sha256"]
end
historical_collection = TOML.parsefile(joinpath(D, "../gabls1/collection_e0655cf/manifest.toml"))
for (label, id) in (("historical_oneface300", "gabls1_n032_weno9_surface_layer_t300_s1"),
                    ("historical_control", "gabls1_n032_weno9_control"))
    directory = joinpath(D, "../gabls1/exports_e0655cf", id)
    entry = only(filter(e -> e["case_id"] == id, historical_collection["admitted"]))
    @assert hashfile(joinpath(directory, "manifest.toml")) == entry["manifest_sha256"]
    c = Data.load_case_export(directory)
    @assert c.manifest["provenance"]["source_freeze_manifest_sha256"] == "d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
    cases[label] = c
    ids[label] = id
end
audit = Dict{String, Any}()
for (label, c) in cases
    @assert c.manifest["grid"] == cases["factor1"].manifest["grid"]
    @assert c.series.time_s == collect(0.0:60.0:32400.0)
    @assert sort(unique(r.time_s for r in c.profiles)) == collect(0.0:1800.0:32400.0)
    @assert all(isfinite(r.value) for r in c.profiles)
    @assert all(all(isfinite, values) for values in values(c.series.values))
    @assert c.manifest["provenance"]["provenance_audit"]["paired_initial_digests_checked"] == 1
    rows = Dict((r.variable, r.time_s, r.z_m) => r.value for r in c.profiles)
    residuals = Float64[]
    for stem in ("u_w_flux", "v_w_flux", "w_theta_flux"), t in 0.0:1800.0:32400.0, z in 12.5:12.5:387.5
        resolved, sgs, total = (rows[(part * "_" * stem, t, z)] for part in ("resolved", "sgs", "total"))
        @assert isapprox(total, resolved + sgs; atol=2e-7, rtol=2e-5)
        z > 12.5 && @assert sgs == 0
        push!(residuals, abs(total - resolved - sgs))
    end
    audit[label] = Dict("maximum_interior_flux_partition_residual" => maximum(residuals),
                        "profile_records" => 19, "series_records" => 541,
                        "native_grid_and_times_verified" => true)
end
initial(c) = Dict((r.variable, r.z_m) => r.value for r in c.profiles if r.time_s == 0)
@assert initial(cases["factor1"]) == initial(cases["factor2"])
@assert initial(cases["factor1"]) == initial(cases["factor3"])
@assert initial(cases["factor1"]) == initial(cases["factor10"])
@assert initial(cases["factor1"]) == initial(cases["historical_oneface300"])

const WINDOWS = (("penultimate_hour", [27000.0, 28800.0], 25200, 28800),
                 ("final_hour", [30600.0, 32400.0], 28800, 32400))
const reference_path = joinpath(D, "../../gabls/reference_data/fixed_1m_medians.json")
const reference = JSON.parsefile(reference_path)
function interpolate(x, y, z)
    j = searchsortedlast(x, z)
    j == 0 && return NaN
    j == length(x) && return z == x[end] ? y[end] : NaN
    return y[j] + (y[j+1]-y[j]) * (z-x[j]) / (x[j+1]-x[j])
end
metrics = Dict{String, Any}()
open(joinpath(D, "comparison_profiles.csv"), "w") do io
    println(io, "case,window,z_m,variable,value,location,units")
    for label in ("factor1", "factor2", "factor3", "factor10", "historical_oneface300", "historical_control")
        c = cases[label]
        result = Dict{String, Any}("case_id" => ids[label], "role" => roles[label])
        for (window, times, lower, upper) in WINDOWS
            indices = findall(t -> lower < t <= upper, c.series.time_s)
            @assert length(indices) == 60
            values = Dict{String, Any}()
            # Include all closure activity/filter series with physical names unchanged.
            for (name, series) in c.series.values
                if startswith(name, "surface_layer_") || name in (
                    "friction_velocity", "surface_sensible_heat_flux", "surface_theta_kinematic_flux",
                    "resolved_tke_vertical_integral", "boundary_layer_height", "low_level_jet_height",
                    "low_level_jet_speed", "surface_stability_cap_fraction")
                    values[name] = mean(series[indices])
                end
            end
            for variable in sort(unique(r.variable for r in c.profiles))
                p = comparison_profile(c, variable, times)
                for j in eachindex(p.z_m)
                    println(io, join((label, window, p.z_m[j], variable, p.value[j], p.location, p.units), ','))
                end
            end
            w2 = comparison_profile(c, "w_variance", times)
            w3 = comparison_profile(c, "w_third_central_moment", times)
            for z in (12.5, 25.0, 50.0, 100.0)
                j = only(findall(==(z), w2.z_m))
                suffix = replace(string(z), "." => "p") * "m"
                values["w2_at_$suffix"] = w2.value[j]
                values["w3_at_$suffix"] = w3.value[j]
                values["skewness_at_$suffix"] = w2.value[j] >= 1e-6 ? w3.value[j]/w2.value[j]^1.5 : nothing
            end
            values["peak_w2"] = maximum(w2.value)
            values["peak_w2_height_m"] = w2.z_m[argmax(w2.value)]
            for j in eachindex(w2.z_m)
                w2.value[j] >= 1e-6 || continue
                println(io, join((label, window, w2.z_m[j], "w_skewness_ratio_of_means", w3.value[j]/w2.value[j]^1.5, "Face", "1"), ','))
            end
            for stem in ("u_w_flux", "v_w_flux", "w_theta_flux"), component in ("resolved", "sgs", "total")
                p = comparison_profile(c, component * "_" * stem, times)
                values[component * "_" * stem * "_at_12p5m"] = p.value[2]
            end
            for stem in ("u_w_flux", "v_w_flux", "w_theta_flux")
                values["sgs_signed_fraction_$(stem)_at_12p5m"] = values["sgs_$(stem)_at_12p5m"] / values["total_$(stem)_at_12p5m"]
            end
            for variable in ("u_mean", "v_mean", "theta_mean", "w_variance")
                p = comparison_profile(c, variable, times)
                r = SurfaceLayerScientificPlots.reference_curve(reference, variable)
                if r !== nothing
                    indices = findall(z -> 0 < z <= 200, p.z_m)
                    errors = [p.value[j] - interpolate(r.z_m, r.value, p.z_m[j]) for j in indices]
                    @assert all(isfinite, errors)
                    values[variable * "_rmse_0_200m"] = sqrt(mean(abs2, errors))
                end
            end
            result[window] = values
        end
        metrics[label] = result
    end
end
equivalence = Dict{String, Any}()
a, b = cases["factor1"], cases["historical_oneface300"]
amap, bmap = (Dict((r.variable,r.time_s,r.z_m)=>r.value for r in c.profiles) for c in (a,b))
@assert Set(keys(amap)) == Set(keys(bmap))
equivalence["all_profile_values_bitwise_equal"] = amap == bmap
equivalence["maximum_profile_absolute_difference"] = maximum(abs(amap[k]-bmap[k]) for k in keys(amap))
equivalence["all_series_values_bitwise_equal"] = a.series.values == b.series.values
equivalence["maximum_series_absolute_difference"] = maximum(abs(a.series.values[k][i]-b.series.values[k][i]) for k in keys(a.series.values) for i in eachindex(a.series.time_s))
differences = Dict{String, Any}()
for factor in (2,3,10)
    windows = Dict{String, Any}()
    for (window, times, lower, upper) in WINDOWS
        diff = Dict{String, Any}()
        for key in intersect(keys(metrics["factor1"][window]), keys(metrics["factor$factor"][window]))
            x, y = metrics["factor1"][window][key], metrics["factor$factor"][window][key]
            (x isa Number && y isa Number) || continue
            diff[key] = Dict("absolute" => y-x, "relative_percent" => x == 0 ? nothing : 100*(y-x)/abs(x))
        end
        windows[window] = diff
    end
    differences["factor$(factor)_minus_factor1"] = windows
end
fractions = sort(filter(k->occursin("zero_",k), collect(keys(cases["factor10"].series.values))))
@assert length(fractions) == 6
for name in fractions
    @assert all(x -> 0 <= x <= 1, cases["factor3"].series.values[name])
    @assert all(x -> 0 <= x <= 1, cases["factor10"].series.values[name])
    @assert !haskey(cases["factor1"].series.values,name) && !haskey(cases["factor2"].series.values,name)
end
hourly=Dict{String,Any}()
for factor in (3,10)
    ten_series=cases["factor$factor"].series
    for prefix in ("momentum","ρθ")
    active=ten_series.values["surface_layer_face1_$(prefix)_active_fraction"]
    raw=ten_series.values["surface_layer_face1_$(prefix)_deficit_zero_fraction"]
    valid=ten_series.values["surface_layer_face1_$(prefix)_valid_zero_deficit_fraction"]
    coefficient=prefix=="momentum" ? "viscosity" : "ρθ_diffusivity"
    zero=ten_series.values["surface_layer_face1_$(coefficient)_zero_fraction"]
    @assert all(valid .<= raw) && all(valid .<= active) && all(valid .<= zero)
    end
    windows=Dict{String,Any}()
    for hour in 1:9
    ix=findall(t->3600(hour-1)<t<=3600hour,ten_series.time_s)
    @assert length(ix)==60
    names=[fractions;["surface_layer_face1_viscosity","surface_layer_face1_ρθ_diffusivity"]]
        windows[string(hour)]=Dict(name=>mean(ten_series.values[name][ix]) for name in names)
    end
    hourly["factor$factor"]=windows
end
summary = Dict("cases"=>metrics, "differences"=>differences,
    "switch_off_series"=>fractions,
    "hourly_switch_off"=>hourly,
    "historical_factor1_reproducibility"=>equivalence, "audit"=>audit,
    "source_manifest_sha256"=>SOURCE_SHA, "registry_sha256"=>cases["factor3"].manifest["provenance"]["scientific_registry_sha256"],
    "gpu_evidence_sha256"=>GPU_SHA, "paired_initial_theta_sha256"=>INITIAL_SHA,
    "reference_sha256"=>hashfile(reference_path), "comparison_script_sha256"=>hashfile(@__FILE__),
    "definitions"=>Dict("profiles"=>"Equal average of the two true 1800s averages per hour; native model heights retained",
      "series"=>"Arithmetic mean of 60 instantaneous samples strictly after hour start and through hour end",
      "skewness"=>"Ratio of hourly mean third moment to hourly mean variance^(3/2); omitted for variance<1e-6; not mean instantaneous skewness",
      "rmse"=>"Unweighted at native levels0<z<=200m; interpolate only fixed1m median; descriptive single realization",
      "factor"=>"Factor multiplies local time-filtered covariance in closure deficit; all diagnostic fluxes remain physical and unscaled",
      "flux_partition"=>"Covariance + actual constitutive SGS interior flux. NOT scheme-native WENO transport: the discrete advective flux and its numerical correction are absent.",
      "switch_off_fractions"=>"Factors3/10 only. Six saved horizontal fractions distinguish raw zero deficit, guard-valid zero deficit and actual zero coefficient for momentum/heat; denominator is every horizontal point. Factors1/2 unavailable, not zero.",
      "historical"=>"7293 data from earlier source, same grid/seed/setup; equivalence tested explicitly for oneface300",
      "scheduler"=>"Factor3 job7348 used a non-login wrapper and its durable child record verifies exit0. Older factor2 job7331 had batchNonZeroExitCode despite child0 and verified complete output; the older discrepancy remains documented separately."))
open(io -> JSON.print(io, summary, 2), joinpath(D, "comparison.json"), "w")
open(joinpath(D, "comparison.md"), "w") do io
    println(io, "Factors 1/2 retain their original strict admission (2 admitted, 0 rejected); factors 3 and 10 each passed separate source-specific admission (1 admitted, 0 rejected). Same Breeze physics, grid and initial profiles. Exact schedules, covariance-plus-SGS partition and support rechecked locally.")
    println(io, "\nSkewness is the ratio of hourly mean moments. Fluxes remain unscaled; numerical transport is not measured. The earlier control is context from another source revision.")
    println(io, "\n| Window | Case | u* m/s | Heat W/m² | ∫TKE m³/s² | w²12.5m | w³12.5m | Skew12.5m | ν12.5m m²/s | SGS/total uw |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for (window, _, _, _) in WINDOWS, label in ("factor1", "factor2", "factor3", "factor10", "historical_oneface300", "historical_control")
        m = metrics[label][window]
        @printf(io, "| %s | %s | %.5f | %.3f | %.4f | %.7f | %+.7f | %+.4f | %.4f | %.4f |\n", window, label,
            m["friction_velocity"], m["surface_sensible_heat_flux"], m["resolved_tke_vertical_integral"],
            m["w2_at_12p5m"], m["w3_at_12p5m"], m["skewness_at_12p5m"],
            get(m, "surface_layer_face1_viscosity", 0.0), m["sgs_signed_fraction_u_w_flux_at_12p5m"])
    end
    println(io, "\nFresh factor1 versus old7293 oneface300: all profile values identical = ", equivalence["all_profile_values_bitwise_equal"], "; all series values identical = ", equivalence["all_series_values_bitwise_equal"], ".")
    println(io,"\n| Case | Saved fraction | 7-8 h | 8-9 h |\n|---|---|---:|---:|")
    for factor in (3,10), name in fractions
        @printf(io,"| Factor%d | %s | %.7f | %.7f |\n",factor,name,metrics["factor$factor"]["penultimate_hour"][name],metrics["factor$factor"]["final_hour"][name])
    end
    println(io, "\nFactor 3 job 7348 used the corrected non-login wrapper; its durable child record verifies exit zero. The older factor-2 scheduler discrepancy remains preserved separately; do not infer a batch exit status solely from a child exit.")
end
println(JSON.json(Dict("final_factor3"=>metrics["factor3"]["final_hour"], "equivalence"=>equivalence)))
