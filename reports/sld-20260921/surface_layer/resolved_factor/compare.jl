#!/usr/bin/env julia
using SHA, TOML, JSON, Statistics, Printf
include("analysis_v2/SurfaceLayerScientificPlots.jl")
using .SurfaceLayerScientificPlots: comparison_profile
const Data = SurfaceLayerScientificPlots.SurfaceLayerAnalysisData
const D = @__DIR__
hashfile(path) = bytes2hex(open(sha256, path))
const SOURCE_SHA = "395f7a42b5cdc7dfd688d1e0b0d0d2767f11d4cb186748070d517f507b74c1c4"
const REGISTRY_SHA = "6dcd5c7f597a80a64beaa7b021df57891bbd6599eae9e66db38d968e76cb1832"
const GPU_SHA = "facbd8488192443eb41c2a7dc8e269759429039a9c3ec0fd08e0a0e58bb140ae"
const INITIAL_SHA = "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b"
const source_manifest = joinpath(D, "analysis_v2/source_sha256.txt")
@assert hashfile(source_manifest) == SOURCE_SHA
for name in ("SurfaceLayerAnalysisData.jl", "SurfaceLayerScientificPlots.jl")
    suffix = "source/BreezeEvaluation.jl/cases/surface_layer/analysis/$name"
    line = only(filter(line -> endswith(line, suffix), readlines(source_manifest)))
    @assert hashfile(joinpath(D, "analysis_v2", name)) == first(split(line))
end
const collection = TOML.parsefile(joinpath(D, "collection_v2/manifest.toml"))
@assert collection["admitted_count"] == 2 && collection["rejected_count"] == 0
@assert hashfile(joinpath(D, "analysis_v2/attempts.toml")) == collection["attempt_registry_sha256"]
const cases = Dict{String, Any}()
const ids = Dict{String, String}()
const roles = Dict("factor1"=>"Fresh matched factor 1", "factor2"=>"Fresh matched factor 2",
                   "historical_oneface300"=>"7293 earlier-source one-face 300 s context",
                   "historical_control"=>"7293 earlier-source no-closure context")
for factor in (1, 2)
    id = "gabls1_n032_weno9_surface_layer_t300_s1_rf$(factor)p0"
    entry = only(filter(e -> e["case_id"] == id, collection["admitted"]))
    directory = joinpath(D, "exports_v2", id)
    @assert hashfile(joinpath(directory, "manifest.toml")) == entry["manifest_sha256"]
    c = Data.load_case_export(directory)
    p = c.manifest["provenance"]
    @assert p["source_freeze_manifest_sha256"] == p["analysis_freeze"]["manifest_sha256"] == SOURCE_SHA
    @assert p["scientific_registry_sha256"] == REGISTRY_SHA
    @assert p["gpu_validation"]["evidence_sha256"] == GPU_SHA
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
const attempts = TOML.parsefile(joinpath(D, "analysis_v2/attempts.toml"))
@assert attempts["source_evaluation_commit"] == "ec714e57615d888a9976f501c87f02fc5bb4e77f"
@assert attempts["source_breeze_commit"] == "1df78f2bb94db159e3a296f7439e1a5e90286014"
for attempt in attempts["attempts"]
    @assert attempt["batch_child_exit_code"] == 0
    exitpath = joinpath(D, "analysis_v2", basename(attempt["batch_exit_record_path"]))
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
    for label in ("factor1", "factor2", "historical_oneface300", "historical_control")
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
for (window, times, lower, upper) in WINDOWS
    diff = Dict{String, Any}()
    for key in intersect(keys(metrics["factor1"][window]), keys(metrics["factor2"][window]))
        x, y = metrics["factor1"][window][key], metrics["factor2"][window][key]
        (x isa Number && y isa Number) || continue
        diff[key] = Dict("absolute" => y-x, "relative_percent" => x == 0 ? nothing : 100*(y-x)/abs(x))
    end
    differences[window] = diff
end
summary = Dict("cases"=>metrics, "factor2_minus_factor1"=>differences,
    "historical_factor1_reproducibility"=>equivalence, "audit"=>audit,
    "source_manifest_sha256"=>SOURCE_SHA, "registry_sha256"=>REGISTRY_SHA,
    "gpu_evidence_sha256"=>GPU_SHA, "paired_initial_theta_sha256"=>INITIAL_SHA,
    "reference_sha256"=>hashfile(reference_path), "comparison_script_sha256"=>hashfile(@__FILE__),
    "definitions"=>Dict("profiles"=>"Equal average of the two true 1800s averages per hour; native model heights retained",
      "series"=>"Arithmetic mean of 60 instantaneous samples strictly after hour start and through hour end",
      "skewness"=>"Ratio of hourly mean third moment to hourly mean variance^(3/2); omitted for variance<1e-6; not mean instantaneous skewness",
      "rmse"=>"Unweighted at native levels0<z<=200m; interpolate only fixed1m median; descriptive single realization",
      "factor"=>"Factor multiplies local time-filtered covariance in closure deficit; all diagnostic fluxes remain physical and unscaled",
      "flux_partition"=>"Actual resolved+constitutiveSGS interior flux; excludes unmeasured numerical transport",
      "historical"=>"7293 data from earlier source, same grid/seed/setup; equivalence tested explicitly for oneface300",
      "scheduler"=>"7331 child processes and scientific outputs verified complete despite reported batch NonZeroExitCode; login-shell clear_console teardown reproduces exit0->1 separately; actual batchSHLVL was not logged"))
open(io -> JSON.print(io, summary, 2), joinpath(D, "comparison.json"), "w")
open(joinpath(D, "comparison.md"), "w") do io
    println(io, "Both cases passed strict scientific admission (2 admitted, 0 rejected), with matching source, registry, grid, seed, and exact scheduled outputs. Physical flux partition and one-face support were independently rechecked locally.")
    println(io, "\nSkewness is the ratio of hourly mean moments. Fluxes remain unscaled; numerical transport is not measured. The earlier control is context from another source revision.")
    println(io, "\n| Window | Case | u* m/s | Heat W/m² | ∫TKE m³/s² | w²12.5m | w³12.5m | Skew12.5m | ν12.5m m²/s | SGS/total uw |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for (window, _, _, _) in WINDOWS, label in ("factor1", "factor2", "historical_oneface300", "historical_control")
        m = metrics[label][window]
        @printf(io, "| %s | %s | %.5f | %.3f | %.4f | %.7f | %+.7f | %+.4f | %.4f | %.4f |\n", window, label,
            m["friction_velocity"], m["surface_sensible_heat_flux"], m["resolved_tke_vertical_integral"],
            m["w2_at_12p5m"], m["w3_at_12p5m"], m["skewness_at_12p5m"],
            get(m, "surface_layer_face1_viscosity", 0.0), m["sgs_signed_fraction_u_w_flux_at_12p5m"])
    end
    println(io, "\nFresh factor1 versus old7293 oneface300: all profile values identical = ", equivalence["all_profile_values_bitwise_equal"], "; all series values identical = ", equivalence["all_series_values_bitwise_equal"], ".")
    println(io, "\nBatch status is separate: child exit0,CASE_DONE32400 and complete validated output support scientific admission. A login-shell teardown probe reproduces explicitexit0 becoming exit1 through ~/.bash_logout clear_console under set-e. Actual batchSHLVL was not recorded.")
end
println(JSON.json(Dict("final_factor1"=>metrics["factor1"]["final_hour"], "final_factor2"=>metrics["factor2"]["final_hour"], "equivalence"=>equivalence)))
