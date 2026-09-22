using JLD2, SHA, TOML, Statistics, Printf

length(ARGS) == 2 || error("usage: julia audit_export.jl RUN_DIRECTORY OUTPUT_DIRECTORY")
run_dir, out_dir = ARGS
case_id = "gabls1_n032_weno9_surface_layer_t300_s1_rf1p0_native"
isdir(run_dir) || error("missing run directory")
!ispath(joinpath(run_dir, "CASE_FAILED")) || error("CASE_FAILED exists")
occursin("exit=0", read(joinpath(dirname(dirname(run_dir)), "logs/science_7497.exit"), String)) || error("nonzero science exit")
done = read(joinpath(run_dir, "CASE_DONE"), String)
occursin("case_id=$case_id", done) || error("case mismatch")
occursin("final_time_s=32400.0", done) || error("final time mismatch")

paths = Dict(kind => joinpath(run_dir, case_id * "_diag_" * kind * ".jld2") for kind in ("initial", "statistics", "series"))
all(isfile, values(paths)) || error("missing diagnostic file")
expected = Dict("initial" => [0.0], "statistics" => collect(0.0:1800.0:32400.0),
                "series" => collect(0.0:60.0:32400.0))
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
        kind == "statistics" && (String(f["metadata/resolved_transport"]) == "scheme_native" || error("profile metadata transport"))
        for name in names(f)
            shape = nothing
            if kind == "statistics"
                data = Dict{Float64, Vector{Float64}}()
                for (key, t) in rs
                    raw = f["timeseries/$name/$key"]
                    size(raw)[1:2] == (1, 1) || error("$name horizontal shape")
                    length(raw) in (32, 33) || error("$name native vertical levels")
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

for face in 1:2, (label, stem) in (("u", "u"), ("v", "v"), ("ρθ", "ρθ"), ("ρqᵛ", "ρqᵛ"))
    prefix = "surface_layer_face$(face)_"
    base = stem in ("u", "v") ? prefix * "resolved_$(stem)_flux" : prefix * stem * "_resolved_flux"
    correction = stem in ("u", "v") ? prefix * "numerical_$(stem)_correction" : prefix * stem * "_numerical_correction"
    reconstructed = stem in ("u", "v") ? prefix * "reconstructed_$(stem)_flux" : prefix * stem * "_reconstructed_flux"
    all(haskey(series_data, x) for x in (base, correction, reconstructed)) || error("missing $face $label decomposition")
    mismatch = maximum(abs.(series_data[base] .+ series_data[correction] .- series_data[reconstructed]))
    mismatch <= 5e-5 || error("$face $label decomposition mismatch: $mismatch")
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
            location = length(a) == 32 ? "Center" : "Face"
            for i in eachindex(a)
                z = location == "Center" ? (i - 0.5) * 12.5 : (i - 1) * 12.5
                println(io, "$(source_times[2]),$z,$name,$(a[i]),$location")
            end
        end
    end
end

manifest = Dict("case_id" => case_id, "final_time_s" => 32400.0,
                "source_manifest_sha256" => "72f1bc031503f0833a1b6969e29e2078ceef04e495b8e27cc3885a9843e35a25",
                "raw_sha256" => Dict(k => sha(v) for (k, v) in paths),
                "records" => Dict(k => length(v) for (k, v) in times_audited),
                "variables" => Dict("profiles" => length(profile_data), "series" => length(series_data)),
                "shapes" => shapes, "all_finite" => true, "flux_decomposition_pass" => true)
open(joinpath(out_dir, "audit.toml"), "w") do io
    TOML.print(io, manifest)
end
println("ADMITTED: $(length(profile_data)) profiles, $(length(series_data)) series; times/heights/finite/flux passed")
