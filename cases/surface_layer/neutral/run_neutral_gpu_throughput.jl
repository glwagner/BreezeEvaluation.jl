using JLD2
using Oceananigans
using SHA
using TOML
import Dates

get(ENV, "SLD_NEUTRAL_GPU_ACK", "") == "ADMITTED_CORE_GPU_CONTRACT" ||
    error("neutral GPU throughput requires SLD_NEUTRAL_GPU_ACK=ADMITTED_CORE_GPU_CONTRACT")

const OUTPUT_ROOT = abspath(get(ENV, "SLD_NEUTRAL_OUTPUT", ""))
isempty(OUTPUT_ROOT) && error("SLD_NEUTRAL_OUTPUT must name a new output directory")
ispath(OUTPUT_ROOT) && error("refusing to overwrite $OUTPUT_ROOT")
mkpath(OUTPUT_ROOT)

module NeutralThroughputRunner
    include(joinpath(@__DIR__, "neutral_abl_case.jl"))
end

file_sha256(path) = bytes2hex(open(sha256, path))

function configure!(closure; stop_time, profile_interval, series_interval)
    ENV["NEUTRAL_ABL_FIXTURE"] = "1"
    ENV["NEUTRAL_ABL_ARCH"] = "gpu"
    ENV["NEUTRAL_ABL_NX"] = "96"
    ENV["NEUTRAL_ABL_NY"] = "96"
    ENV["NEUTRAL_ABL_NZ"] = "96"
    ENV["NEUTRAL_ABL_CLOSURE"] = closure
    ENV["NEUTRAL_ABL_FILTER_SECONDS"] = "300"
    ENV["NEUTRAL_ABL_SUPPORT"] = "1"
    ENV["NEUTRAL_ABL_STOP_SECONDS"] = string(stop_time)
    ENV["NEUTRAL_ABL_SEED"] = "1994"
    ENV["NEUTRAL_ABL_DIAGNOSTICS"] = "1"
    ENV["NEUTRAL_ABL_PROFILE_INTERVAL"] = string(profile_interval)
    ENV["NEUTRAL_ABL_SERIES_INTERVAL"] = string(series_interval)
    ENV["NEUTRAL_ABL_CHECKPOINT_INTERVAL"] = "1000"
    ENV["NEUTRAL_ABL_PROGRESS_INTERVAL"] = "1000"
    return nothing
end

function record_times(file, variable="t")
    group = file["timeseries/$variable"]
    record_keys = filter(!=("serialized"), String.(keys(group)))
    if variable == "t"
        return sort(Float64[group[key] for key in record_keys])
    end
    return sort(Float64[file["timeseries/t/$key"] for key in record_keys])
end

function audit_numeric_records(file)
    checked = 0
    for variable in String.(keys(file["timeseries"]))
        variable in ("t", "serialized") && continue
        group = file["timeseries/$variable"]
        for key in filter(!=("serialized"), String.(keys(group)))
            values = group[key]
            all(isfinite, values) || error("nonfinite $variable record $key")
            checked += length(values)
        end
    end
    return checked
end

function unique_output(directory, suffix)
    paths = filter(path -> endswith(path, suffix), readdir(directory; join=true))
    length(paths) == 1 || error("expected one *$suffix in $directory, found $(length(paths))")
    return only(paths)
end

function audit_run(setup, directory, profile_times, series_times)
    statistics = unique_output(directory, "_statistics.jld2")
    initial = unique_output(directory, "_initial.jld2")
    series = unique_output(directory, "_series.jld2")
    state_bounds = unique_output(directory, "_state_bounds.jld2")
    numeric_values = 0
    jldopen(statistics, "r") do file
        record_times(file) == profile_times || error("profile times do not match")
        length(file["coordinates/z_center_m"]) == 96 || error("center coordinates")
        length(file["coordinates/z_face_m"]) == 97 || error("face coordinates")
        file["coordinates/native_w_moment_location"] == "Face" || error("native w metadata")
        for variable in ("w_mean", "w_variance", "w_third_central_moment",
                         "resolved_u_w_flux", "total_u_w_flux")
            group = file["timeseries/$variable"]
            for key in filter(!=("serialized"), String.(keys(group)))
                size(group[key], ndims(group[key])) == 97 ||
                    error("$variable is not on 97 native faces")
            end
        end
        numeric_values += audit_numeric_records(file)
    end
    jldopen(initial, "r") do file
        record_times(file) == [0.0] || error("separate initial record is not exactly t=0")
        numeric_values += audit_numeric_records(file)
    end
    for path in (series, state_bounds)
        jldopen(path, "r") do file
            record_times(file) == series_times || error("series times do not match in $path")
            numeric_values += audit_numeric_records(file)
        end
    end
    return (;
        statistics_sha256=file_sha256(statistics),
        initial_sha256=file_sha256(initial),
        series_sha256=file_sha256(series),
        state_bounds_sha256=file_sha256(state_bounds),
        numeric_values_checked=numeric_values,
        final_time_seconds=Float64(time(setup.simulation)),
        iterations=iteration(setup.simulation))
end

function run_fixture(closure, directory; stop_time, profile_interval, series_interval)
    configure!(closure; stop_time, profile_interval, series_interval)
    mkpath(directory)
    setup = NeutralThroughputRunner.build_simulation(; run_directory=directory)
    time_steps = Float64[]
    add_callback!(setup.simulation,
        simulation -> push!(time_steps, Float64(simulation.Δt)),
        IterationInterval(1))
    elapsed = @elapsed run!(setup.simulation)
    open(joinpath(directory, "FIXTURE_CASE_DONE"), "w") do io
        println(io, "case_id=", setup.case_id)
        println(io, "fixture_non_scientific=true")
        println(io, "final_time_s=", time(setup.simulation))
    end
    profile_times = collect(profile_interval:profile_interval:stop_time)
    series_times = collect(0.0:series_interval:stop_time)
    audit = audit_run(setup, directory, profile_times, series_times)
    return merge(audit, (;
        case_id=setup.case_id,
        fixture_non_scientific=true,
        initial_state_sha256=Dict(string(name) => value
            for (name, value) in pairs(setup.settings.initial_state_sha256)),
        elapsed_seconds=elapsed,
        seconds_per_step=elapsed / audit.iterations,
        simulated_seconds_per_wall_second=stop_time / elapsed,
        projected_five_hour_wall_seconds=elapsed * 18000 / stop_time,
        minimum_time_step_seconds=minimum(time_steps),
        maximum_time_step_seconds=maximum(time_steps),
        last_time_step_seconds=last(time_steps)))
end

function main()
    registry = TOML.parsefile(joinpath(@__DIR__, "neutral_sld_2case.toml"))
    expected_digests = registry["paired_initial_state_sha256"]

    # Compile both 96-cubed model variants and their full writers before timing.
    warm_results = Dict{String, Any}()
    for closure in ("none", "surface_layer")
        warm = run_fixture(closure, joinpath(OUTPUT_ROOT, "warmup", closure);
            stop_time=1.0, profile_interval=1.0, series_interval=1.0)
        warm.initial_state_sha256 == expected_digests ||
            error("warm-up initial digest mismatch for $closure")
        warm_results[closure] = Dict(
            string(name) => value for (name, value) in pairs(warm))
        NeutralThroughputRunner.CUDA.reclaim()
        GC.gc(true)
    end

    results = Dict{String, Any}()
    for closure in ("none", "surface_layer")
        directory = joinpath(OUTPUT_ROOT, closure)
        result = run_fixture(closure, directory;
            stop_time=120.0, profile_interval=60.0, series_interval=10.0)
        result.initial_state_sha256 == expected_digests ||
            error("paired initial digest mismatch for $closure")
        results[closure] = Dict(string(name) => value for (name, value) in pairs(result))
        NeutralThroughputRunner.CUDA.reclaim()
        GC.gc(true)
    end

    evidence = Dict{String, Any}(
        "schema_version" => 1,
        "mode" => "gpu_neutral_throughput_fixture",
        "fixture_non_scientific" => true,
        "all_passed" => true,
        "created_utc" => string(Dates.now(Dates.UTC)),
        "architecture" => "CUDAGPU",
        "cuda_scalar_indexing_disabled" => true,
        "grid" => [96, 96, 96],
        "domain_m" => [3000.0, 3000.0, 1000.0],
        "authorized_scientific_duration_s" => 18000.0,
        "measured_fixture_duration_s" => 120.0,
        "paired_initial_state_sha256" => expected_digests,
        "warmup" => warm_results,
        "results" => results)
    evidence_path = joinpath(OUTPUT_ROOT, "neutral_throughput_evidence.toml")
    open(evidence_path, "w") do io
        TOML.print(io, evidence; sorted=true)
    end
    evidence_hash = file_sha256(evidence_path)
    open(joinpath(OUTPUT_ROOT, "NEUTRAL_THROUGHPUT_DONE"), "w") do io
        println(io, "mode=gpu_neutral_throughput_fixture")
        println(io, "fixture_non_scientific=true")
        println(io, "evidence_sha256=", evidence_hash)
    end
    println("NEUTRAL_GPU_THROUGHPUT_PASSED evidence_sha256=", evidence_hash)
    return nothing
end

try
    main()
catch error
    open(joinpath(OUTPUT_ROOT, "NEUTRAL_THROUGHPUT_FAILED"), "w") do io
        println(io, "failed_utc=", Dates.now(Dates.UTC))
        println(io, "error=", sprint(showerror, error))
    end
    rethrow()
end
