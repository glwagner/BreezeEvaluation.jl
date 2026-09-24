# Copied from glwagner/BreezeEvaluation.jl@33cc9da (reports/sld-20260921/surface_layer/gabls1/
# filtered_wall/audit_export.jl). Only change: the immutable source-manifest digest is supplied
# by SOURCE_MANIFEST_SHA256 instead of the filtered-wall campaign's hard-coded value, and the
# Adapted for 128³ GABLS1 with a paired 32³ initial perturbation field and optional γ=2 SLD.
using JLD2, SHA, TOML, Statistics, Printf

const SOURCE_MANIFEST_SHA256 = ENV["SOURCE_MANIFEST_SHA256"]

length(ARGS) == 4 || error("usage: julia audit_export.jl RUN_DIRECTORY OUTPUT_DIRECTORY CASE_ID EXIT_FILE")
run_dir, out_dir, case_id, exit_file = ARGS
is_sld = occursin("surface_layer", case_id)
isdir(run_dir) || error("missing run directory")
!ispath(joinpath(run_dir, "CASE_FAILED")) || error("CASE_FAILED exists")
occursin("exit=0", read(exit_file, String)) || error("nonzero science exit")
done = read(joinpath(run_dir, "CASE_DONE"), String)
occursin("case_id=$case_id", done) || error("case mismatch")
occursin("final_time_s=32400.0", done) || error("final time mismatch")
provenance = read(joinpath(run_dir, "provenance/run.txt"), String)
for required in ("case_id: $case_id", "nx: 128", "spacing: 3.125", "filter_seconds: 300.0",
                 "wall_filter_seconds: 300.0", "stop_time: 32400.0", "seed: 123",
                 "theta_initial_sha256: 177e9b12560bf668690ecb0eb9aa57488c385d48f54fd2084218188d98bbc3c5")
    occursin(required, provenance) || error("provenance mismatch: $required")
end
occursin("paired_coarse_theta_sha256: 1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b", provenance) ||
    error("paired coarse initial digest mismatch")
occursin(is_sld ? "resolved_transport: scheme_native" : "resolved_transport: covariance", provenance) || error("transport mismatch")
is_sld && !occursin("stability_strength: 2.0", provenance) && error("stability strength mismatch")

paths = Dict(kind => joinpath(run_dir, case_id * "_diag_" * kind * ".jld2") for kind in ("initial", "statistics", "series"))
all(isfile, values(paths)) || error("missing diagnostic file")
expected = Dict("initial" => [0.0], "statistics" => collect(0.0:1800.0:32400.0),
                "series" => collect(0.0:60.0:32400.0),
                "wall_filter" => collect(0.0:600.0:32400.0))
sha(path) = bytes2hex(open(sha256, path))
records(f) = sort([(String(k), Float64(f["timeseries/t/$k"])) for k in keys(f["timeseries/t"])]; by=last)
names(f) = sort!(filter(!=("t"), String.(collect(keys(f["timeseries"])))))
value(x) = x isa Number ? Float64(x) : (length(x) == 1 ? Float64(only(x)) : error("non-scalar series output"))

mkpath(out_dir)
profile_data = Dict{String, Dict{Float64, Vector{Float64}}}()
series_data = Dict{String, Vector{Float64}}()
shapes = Dict{String, Any}()
times_audited = Dict{String, Any}()
for kind in ("initial", "statistics", "series")
    jldopen(paths[kind], "r") do f
        rs = records(f)
        length(rs) == length(expected[kind]) || error("$kind record count")
        all(isapprox(last(rs[i]), expected[kind][i]; atol=1e-5, rtol=0) for i in eachindex(rs)) || error("$kind times")
        times_audited[kind] = last.(rs)
        kind == "initial" && return
        kind == "statistics" && (String(f["metadata/resolved_transport"]) == (is_sld ? "scheme_native" : "none") || error("profile metadata transport"))
        for name in names(f)
            shape = nothing
            if kind == "statistics"
                data = Dict{Float64, Vector{Float64}}()
                for (key, t) in rs
                    raw = f["timeseries/$name/$key"]
                    size(raw)[1:2] == (1, 1) || error("$name horizontal shape")
                    length(raw) in (128, 129) || error("$name native vertical levels")
                    shape === nothing && (shape = size(raw))
                    size(raw) == shape || error("$name shape changes")
                    a = Float64.(vec(raw))
                    all(isfinite, a) || error("$name nonfinite at $t")
                    data[t] = a
                end
                profile_data[name] = data
            else
                data = Float64[]
                for (key, t) in rs
                    raw = f["timeseries/$name/$key"]
                    shape === nothing && (shape = size(raw))
                    size(raw) == shape || error("$name shape changes")
                    v = value(raw)
                    isfinite(v) || error("$name nonfinite at $t")
                    push!(data, v)
                end
                series_data[name] = data
            end
            shapes["$kind/$name"] = collect(shape)
        end
    end
end

for stem in ("surface_drag_u", "surface_drag_v", "surface_theta")
    dynamic = series_data[stem * "_dynamic_flux"]
    kinematic = series_data[stem * "_kinematic_flux"]
    density = series_data["surface_density"]
    mismatch = maximum(abs.(dynamic .- kinematic .* density))
    mismatch <= 5e-5 || error("$stem density/flux mismatch: $mismatch")
end

if is_sld
for face in 1:2, (label, stem) in (("u", "u"), ("v", "v"), ("ρθ", "ρθ"), ("ρqᵛ", "ρqᵛ"))
    prefix = "surface_layer_face$(face)_"
    base = stem in ("u", "v") ? prefix * "resolved_$(stem)_flux" : prefix * stem * "_resolved_flux"
    correction = stem in ("u", "v") ? prefix * "numerical_$(stem)_correction" : prefix * stem * "_numerical_correction"
    reconstructed = stem in ("u", "v") ? prefix * "reconstructed_$(stem)_flux" : prefix * stem * "_reconstructed_flux"
    all(haskey(series_data, x) for x in (base, correction, reconstructed)) || error("missing $face $label decomposition")
    mismatch = maximum(abs.(series_data[base] .+ series_data[correction] .- series_data[reconstructed]))
    mismatch <= 5e-5 || error("$face $label decomposition mismatch: $mismatch")
end
end

wall_path = joinpath(run_dir, case_id * "_wall_filter.jld2")
isfile(wall_path) || error("missing wall filter")
wall_means = Dict{String, Vector{Float64}}()
wall_change = Dict{String, Float64}()
jldopen(wall_path, "r") do f
    rs = records(f)
    length(rs) == length(expected["wall_filter"]) || error("wall record count")
    all(isapprox(last(rs[i]), expected["wall_filter"][i]; atol=1e-5, rtol=0) for i in eachindex(rs)) || error("wall times")
    times_audited["wall_filter"] = last.(rs)
    for name in ("filtered_u", "filtered_v", "filtered_Δθ")
        means = Float64[]
        shape = nothing
        first_field = nothing
        last_field = nothing
        for (key, t) in rs
            a = f["timeseries/$name/$key"]
            shape === nothing && (shape = size(a))
            size(a) == shape || error("$name wall shape changes")
            size(a)[1:2] == (138, 138) || error("$name wall halo shape")
            all(isfinite, a) || error("$name wall nonfinite at $t")
            push!(means, mean(a[6:69, 6:69, 1]))
            t == 600.0 && (first_field = copy(a))
            t == 32400.0 && (last_field = copy(a))
        end
        wall_means[name] = means
        wall_change[name] = maximum(abs.(last_field .- first_field))
        wall_change[name] > 0 || error("$name filtered state did not evolve")
        shapes["wall_filter/$name"] = collect(shape)
    end
end

open(joinpath(out_dir, "wall_filter_means.csv"), "w") do io
    vars = sort!(collect(keys(wall_means)))
    println(io, join(["time_s"; vars], ','))
    for i in eachindex(expected["wall_filter"])
        println(io, join([@sprintf("%.8g", expected["wall_filter"][i]);
                          [@sprintf("%.12g", wall_means[v][i]) for v in vars]], ','))
    end
end

open(joinpath(out_dir, "series.csv"), "w") do io
    vars = sort!(collect(keys(series_data)))
    println(io, join(["time_s"; vars], ','))
    for i in eachindex(expected["series"])
        println(io, join([@sprintf("%.8g", expected["series"][i]);
                          [@sprintf("%.12g", series_data[v][i]) for v in vars]], ','))
    end
end

for (window, source_times) in (("final_hour", (30600.0, 32400.0)),
                               ("penultimate_hour", (27000.0, 28800.0)))
    open(joinpath(out_dir, "profiles_$(window)_long.csv"), "w") do io
        println(io, "time_s,z_m,variable,value,location")
        for name in sort!(collect(keys(profile_data)))
            a = (profile_data[name][source_times[1]] .+ profile_data[name][source_times[2]]) ./ 2
            location = length(a) == 128 ? "Center" : "Face"
            for i in eachindex(a)
                z = location == "Center" ? (i - 0.5) * 3.125 : (i - 1) * 3.125
                println(io, "$(source_times[2]),$z,$name,$(a[i]),$location")
            end
        end
    end
end

manifest = Dict("case_id" => case_id, "final_time_s" => 32400.0,
                "source_manifest_sha256" => SOURCE_MANIFEST_SHA256,
                "raw_sha256" => Dict(k => sha(v) for (k, v) in merge(paths, Dict("wall_filter" => wall_path))),
                "records" => Dict(k => length(v) for (k, v) in times_audited),
                "variables" => Dict("profiles" => length(profile_data), "series" => length(series_data)),
                "shapes" => shapes, "all_finite" => true, "surface_flux_density_consistency_pass" => true,
                "flux_decomposition_pass" => is_sld,
                "wall_filter_max_change_after_600s" => wall_change)
open(joinpath(out_dir, "audit.toml"), "w") do io
    TOML.print(io, manifest)
end
println("ADMITTED: $(length(profile_data)) profiles, $(length(series_data)) series; times/heights/finite/flux passed")
