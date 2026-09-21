module SurfaceLayerScientificExport

export collect_admitted_exports, export_fixture, export_scientific_case,
       file_sha256, load_attempt_registry, verify_completion,
       verify_hash_manifest, GABLS1_PROFILE_TIMES, GABLS1_INITIAL_TIMES,
       GABLS1_SERIES_TIMES, GABLS3_PROFILE_TIMES, GABLS3_SERIES_TIMES

using Dates
using JLD2
using Printf
using SHA
using Statistics
using TOML

const GABLS1_PROFILE_TIMES = collect(1800.0:1800.0:32400.0)
const GABLS1_INITIAL_TIMES = [0.0]
const GABLS1_SERIES_TIMES = collect(0.0:60.0:32400.0)
const GABLS1_FINAL_HOUR_TIMES = [30600.0, 32400.0]
const GABLS1_PENULTIMATE_HOUR_TIMES = [27000.0, 28800.0]
const GABLS3_PROFILE_TIMES = collect(0.0:300.0:32400.0)
# Oceananigans writes an iteration-zero record to every output writer during
# Simulation.initialize!, even when SpecifiedTimes starts at 10 s. Preserve
# that native initial record alongside all 10 s scheduled records.
const GABLS3_SERIES_TIMES = collect(0.0:10.0:32400.0)
const GABLS3_PAPER_WINDOW_TIMES = collect(11100.0:300.0:14400.0)

const PROFILE_UNITS = Dict(
    "u_mean" => "m s^-1", "v_mean" => "m s^-1", "w_mean" => "m s^-1",
    "theta_mean" => "K", "density_mean" => "kg m^-3",
    "buoyancy_mean" => "m s^-2", "u_variance" => "m^2 s^-2",
    "v_variance" => "m^2 s^-2", "w_variance" => "m^2 s^-2",
    "w_third_central_moment" => "m^3 s^-3",
    "w_skewness_instantaneous_ratio" => "1", "w_center_mean" => "m s^-1",
    "w_center_variance" => "m^2 s^-2",
    "w_center_third_central_moment" => "m^3 s^-3",
    "theta_variance" => "K^2", "resolved_u_w_flux" => "m^2 s^-2",
    "resolved_v_w_flux" => "m^2 s^-2", "resolved_w_theta_flux" => "K m s^-1",
    "sgs_u_w_flux" => "m^2 s^-2", "sgs_v_w_flux" => "m^2 s^-2",
    "sgs_w_theta_flux" => "K m s^-1", "total_u_w_flux" => "m^2 s^-2",
    "total_v_w_flux" => "m^2 s^-2", "total_w_theta_flux" => "K m s^-1",
    "total_stress_magnitude" => "m^2 s^-2",
    "resolved_buoyancy_flux" => "m^2 s^-3",
    "sgs_buoyancy_flux" => "m^2 s^-3", "total_buoyancy_flux" => "m^2 s^-3",
    "resolved_tke" => "m^2 s^-2",
    "resolved_tke_shear_production" => "m^2 s^-3",
    "sgs_tke_shear_production" => "m^2 s^-3",
    "total_tke_shear_production" => "m^2 s^-3",
    "resolved_tke_buoyancy_production" => "m^2 s^-3",
    "sgs_tke_buoyancy_production" => "m^2 s^-3",
    "total_tke_buoyancy_production" => "m^2 s^-3",
    "turbulent_tke_flux" => "m^3 s^-3", "pressure_tke_flux" => "m^3 s^-3",
    "density_at_w_faces" => "kg m^-3",
    "density_weighted_turbulent_tke_flux" => "kg s^-3",
    "density_weighted_pressure_tke_flux" => "kg s^-3",
    "resolved_tke_turbulent_transport" => "m^2 s^-3",
    "resolved_tke_pressure_transport" => "m^2 s^-3",
    "resolved_tke_transport" => "m^2 s^-3",
    "sgs_resolved_tke_dissipation" => "m^2 s^-3",
    "sgs_tke" => "m^2 s^-2", "q_mean" => "1", "q_variance" => "1",
    "resolved_w_q_flux" => "m s^-1", "sgs_w_q_flux" => "m s^-1",
    "total_w_q_flux" => "m s^-1", "surface_layer_viscosity" => "m^2 s^-1",
    "surface_layer_diffusivity_ρθ" => "m^2 s^-1",
    "surface_layer_diffusivity_ρqᵉ" => "m^2 s^-1")

const SERIES_UNITS = Dict(
    "friction_velocity" => "m s^-1",
    "surface_drag_u_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_v_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_u_kinematic_flux" => "m^2 s^-2",
    "surface_drag_v_kinematic_flux" => "m^2 s^-2",
    "surface_theta_dynamic_flux" => "kg K m^-2 s^-1",
    "surface_theta_kinematic_flux" => "K m s^-1",
    "surface_sensible_heat_flux" => "W m^-2", "surface_buoyancy_flux" => "m^2 s^-3",
    "surface_density" => "kg m^-3", "obukhov_length" => "m",
    "obukhov_length_valid" => "1", "surface_bulk_richardson_mean" => "1",
    "surface_bulk_richardson_minimum" => "1",
    "surface_bulk_richardson_maximum" => "1",
    "surface_stability_parameter_mean" => "1",
    "surface_stability_parameter_maximum" => "1",
    "surface_stability_cap_fraction" => "1",
    "surface_neutral_fallback_fraction" => "1", "surface_temperature" => "K",
    "stress_height_0_05" => "m", "boundary_layer_height" => "m",
    "boundary_layer_height_valid" => "1", "low_level_jet_height" => "m",
    "low_level_jet_speed" => "m s^-1",
    "low_level_jet_turning_from_geostrophic" => "rad", "low_level_jet_valid" => "1",
    "theta_minimum" => "K", "theta_maximum" => "K",
    "u_absolute_maximum" => "m s^-1", "v_absolute_maximum" => "m s^-1",
    "w_absolute_maximum" => "m s^-1", "speed_maximum" => "m s^-1",
    "resolved_tke_vertical_integral" => "m^3 s^-2",
    "w_variance_maximum" => "m^2 s^-2",
    "sgs_tke_vertical_integral" => "m^3 s^-2",
    "surface_q_dynamic_flux" => "kg m^-2 s^-1",
    "surface_q_kinematic_flux" => "m s^-1", "obukhov_length_moist" => "m",
    "obukhov_length_moist_valid" => "1", "surface_zeta_mean" => "1",
    "surface_zeta_minimum" => "1", "surface_zeta_maximum" => "1",
    "surface_zeta_cap_fraction" => "1", "surface_unstable_fraction" => "1",
    "prescribed_surface_pressure" => "Pa", "prescribed_surface_theta" => "K",
    "prescribed_surface_q" => "1", "q_minimum" => "1", "q_maximum" => "1",
    "surface_layer_filtered_surface_u_flux" => "m^2 s^-2",
    "surface_layer_filtered_surface_v_flux" => "m^2 s^-2",
    "surface_layer_filtered_friction_velocity" => "m s^-1",
    "surface_layer_filtered_surface_flux_ρθ" => "K m s^-1",
    "surface_layer_filtered_surface_flux_ρqᵉ" => "m s^-1")

file_sha256(path) = bytes2hex(open(sha256, path))
require_check(condition, message) = condition || error(message)

function safe_inside(root, path)
    normalized_root = normpath(abspath(root))
    normalized_path = normpath(abspath(path))
    return normalized_path == normalized_root ||
           startswith(normalized_path, normalized_root * Base.Filesystem.path_separator)
end

function parse_fields(path)
    fields = Dict{String, String}()
    for line in readlines(path)
        occursin('=', line) || continue
        key, value = split(line, '='; limit=2)
        fields[strip(key)] = strip(value)
    end
    return fields
end

function verify_hash_manifest(root, manifest_path; expected_sha=nothing)
    root = abspath(root)
    manifest_path = abspath(manifest_path)
    expected_sha === nothing || require_check(
        file_sha256(manifest_path) == expected_sha,
        "hash-manifest SHA mismatch for $manifest_path")
    entries = 0
    for line in readlines(manifest_path)
        isempty(strip(line)) && continue
        parts = split(line; limit=2)
        require_check(length(parts) == 2, "malformed hash-manifest line")
        expected, relative = parts
        relative = strip(relative)
        startswith(relative, "*") && (relative = relative[2:end])
        path = normpath(joinpath(root, relative))
        require_check(safe_inside(root, path), "hash-manifest path escapes root: $relative")
        require_check(isfile(path), "hash-manifest file missing: $relative")
        require_check(file_sha256(path) == expected,
                      "hash-manifest mismatch: $relative")
        entries += 1
    end
    return entries
end

function verify_gpu_evidence(directory, freeze_root, expected_manifest_sha)
    done_path = joinpath(directory, "GPU_VALIDATION_DONE")
    failed_path = joinpath(directory, "GPU_VALIDATION_FAILED")
    evidence_path = joinpath(directory, "validation_evidence.toml")
    manifest_path = joinpath(freeze_root, "source_sha256.txt")
    require_check(isfile(done_path), "GPU_VALIDATION_DONE is missing")
    require_check(!ispath(failed_path), "GPU_VALIDATION_FAILED is present")
    require_check(isfile(evidence_path), "validation_evidence.toml is missing")
    done = parse_fields(done_path)
    evidence = TOML.parsefile(evidence_path)
    evidence_sha = file_sha256(evidence_path)
    require_check(get(done, "mode", "") == "gpu_full", "GPU evidence is not gpu_full")
    require_check(get(done, "evidence_sha256", "") == evidence_sha,
                  "GPU evidence sentinel hash mismatch")
    require_check(evidence["validation_mode"] == "gpu_full", "CPU evidence is inadmissible")
    require_check(evidence["all_passed"] === true, "GPU evidence reports a failed check")
    require_check(evidence["architecture"] == "CUDAGPU", "GPU evidence is not CUDAGPU")
    require_check(evidence["cuda_functional"] === true, "CUDA was not functional")
    require_check(evidence["cuda_scalar_indexing_disabled"] === true,
                  "CUDA scalar indexing was not disabled")
    require_check(abspath(evidence["freeze_root"]) == abspath(freeze_root),
                  "GPU evidence belongs to another source freeze")
    require_check(evidence["freeze_source_manifest_sha256"] == expected_manifest_sha,
                  "GPU evidence source-manifest SHA mismatch")
    entries = verify_hash_manifest(freeze_root, manifest_path;
                                   expected_sha=expected_manifest_sha)
    require_check(evidence["freeze_source_manifest_entries"] == entries,
                  "GPU evidence source-manifest entry count mismatch")
    evaluation_root = joinpath(freeze_root, "source", "BreezeEvaluation.jl")
    for (relative, expected) in evidence["source_sha256"]
        path = normpath(joinpath(evaluation_root, relative))
        require_check(safe_inside(evaluation_root, path), "GPU source path escapes freeze")
        require_check(isfile(path) && file_sha256(path) == expected,
                      "GPU evidence source mismatch: $relative")
    end
    return Dict("evidence_sha256" => evidence_sha,
                "source_manifest_entries" => entries,
                "passed_checks" => evidence["passed_checks"])
end

function load_attempt_registry(path)
    registry = TOML.parsefile(path)
    attempts = registry["attempts"]
    require_check(length(attempts) == registry["expected_case_count"],
                  "attempt registry count mismatch")
    ids = String[attempt["case_id"] for attempt in attempts]
    require_check(length(unique(ids)) == length(ids), "duplicate attempt case_id")
    return registry
end

function active_attempt(registry, case_id)
    matching = filter(attempt -> attempt["case_id"] == case_id, registry["attempts"])
    require_check(length(matching) == 1, "expected one attempt entry for $case_id")
    attempt = only(matching)
    require_check(attempt["active"] === true, "$case_id has no active attempt")
    require_check(attempt["attempt_state"] == "completed_candidate",
                  "$case_id is not a completed candidate")
    require_check(attempt["scientific_candidate"] === true,
                  "$case_id is not a scientific candidate")
    require_check(attempt["fixture_kind"] == "none", "fixture output is inadmissible")
    for key in ("active_attempt_id", "run_directory", "log_path", "job_spec",
                "log_sha256", "attempt_started_sha256", "case_done_sha256")
        require_check(attempt[key] != "UNASSIGNED", "$case_id has unassigned $key")
    end
    require_check(isabspath(attempt["run_directory"]), "run_directory must be absolute")
    require_check(isabspath(attempt["log_path"]), "log_path must be absolute")
    return attempt
end

function verify_completion(run_directory, case_id)
    started_path = joinpath(run_directory, "ATTEMPT_STARTED")
    done_path = joinpath(run_directory, "CASE_DONE")
    require_check(isfile(started_path), "ATTEMPT_STARTED is missing")
    require_check(isfile(done_path), "CASE_DONE is missing")
    require_check(!ispath(joinpath(run_directory, "CASE_FAILED")), "CASE_FAILED is present")
    started = parse_fields(started_path)
    done = parse_fields(done_path)
    require_check(get(started, "case_id", "") == case_id, "ATTEMPT_STARTED case mismatch")
    require_check(get(done, "case_id", "") == case_id, "CASE_DONE case mismatch")
    final_time = parse(Float64, get(done, "final_time_s", "NaN"))
    require_check(isfinite(final_time) && isapprox(final_time, 32400; atol=1e-5, rtol=0),
                  "CASE_DONE final_time_s is not 32400")
    return Dict("started" => started, "done" => done, "final_time_s" => final_time)
end

function exact_times(actual, expected, label)
    require_check(length(actual) == length(expected),
                  "$label record count $(length(actual)) != $(length(expected))")
    require_check(all(isapprox.(actual, expected; atol=1e-5, rtol=0)),
                  "$label saved times do not match the required schedule")
    return nothing
end

function numeric_records(file)
    group = file["timeseries/t"]
    records = [(key=String(key), time=Float64(group[key])) for key in keys(group)]
    sort!(records; by=record -> record.time)
    return records
end

function output_names(file)
    names = String.(collect(keys(file["timeseries"])))
    filter!(name -> name != "t" && name != "serialized", names)
    return sort!(names)
end

function sanitize(value)
    if value === nothing || value isa Bool || value isa Integer || value isa AbstractString
        return value
    elseif value isa AbstractFloat
        return isfinite(value) ? Float64(value) : string(value)
    elseif value isa Symbol
        return String(value)
    elseif value isa Tuple || value isa AbstractVector
        return [sanitize(item) for item in value]
    elseif value isa AbstractDict
        return Dict(string(key) => sanitize(item) for (key, item) in value)
    else
        return string(value)
    end
end

function metadata_dictionary(file)
    haskey(file, "metadata") || return Dict{String, Any}()
    return Dict(String(key) => sanitize(file["metadata/$key"])
                for key in keys(file["metadata"]))
end

function profile_unit(name)
    haskey(PROFILE_UNITS, name) && return PROFILE_UNITS[name]
    startswith(name, "surface_layer_diffusivity_") && return "m^2 s^-1"
    error("no units registered for profile $name")
end

function series_unit(name)
    haskey(SERIES_UNITS, name) && return SERIES_UNITS[name]
    startswith(name, "surface_layer_face") || error("no units registered for series $name")
    endswith(name, "_viscosity") && return "m^2 s^-1"
    endswith(name, "_diffusivity") && return "m^2 s^-1"
    (occursin("filtered_uw_product", name) || occursin("filtered_vw_product", name) ||
     occursin("momentum", name) && occursin("deficit", name) ||
     occursin("transverse_resolved_stress", name) || occursin("resolved_u_flux", name) ||
     occursin("resolved_v_flux", name) || occursin("_u_mean_w_mean_transport", name) ||
     occursin("_v_mean_w_mean_transport", name)) && return "m^2 s^-2"
    (endswith(name, "_filtered_u_mean") || endswith(name, "_filtered_v_mean") ||
     endswith(name, "_filtered_w_mean")) && return "m s^-1"
    (endswith(name, "momentum_active_fraction") || endswith(name, "viscosity_cap_fraction") ||
     endswith(name, "active_fraction") || endswith(name, "cap_fraction")) && return "1"
    if occursin("_ρθ_", name)
        endswith(name, "_filtered_scalar_mean") && return "K"
        return "K m s^-1"
    elseif occursin("_ρq", name)
        endswith(name, "_filtered_scalar_mean") && return "1"
        return "m s^-1"
    end
    error("no units registered for series $name")
end

function point_unit(name)
    startswith(name, "u_") && return "m s^-1"
    startswith(name, "v_") && return "m s^-1"
    startswith(name, "w_") && return "m s^-1"
    startswith(name, "theta_") && return "K"
    startswith(name, "q_") && return "1"
    error("no units registered for point $name")
end

function scalar_value(raw, name, time)
    value = raw isa Number ? raw : length(raw) == 1 ? only(raw) :
            error("$name at $time is not scalar; size=$(size(raw))")
    require_check(isfinite(value), "non-finite $name at $time")
    return Float64(value)
end

function profile_vector(raw, nz, name, time)
    require_check(raw isa AbstractArray, "$name at $time is not an array")
    values = Array(raw)
    require_check(all(isfinite, values), "non-finite profile $name at $time")
    vertical_length = size(values, ndims(values))
    require_check(vertical_length in (nz, nz + 1),
                  "$name at $time has vertical length $vertical_length, expected $nz or $(nz + 1)")
    reduced = false
    maximum_spread = 0.0
    if ndims(values) >= 3 && prod(size(values)[1:end-1]) != 1
        horizontal_dims = Tuple(1:ndims(values)-1)
        profile = vec(dropdims(mean(values; dims=horizontal_dims); dims=horizontal_dims))
        for k in axes(values, ndims(values))
            slice = selectdim(values, ndims(values), k)
            low, high = extrema(slice)
            maximum_spread = max(maximum_spread, Float64(high - low))
        end
        reduced = true
    else
        profile = vec(values)
    end
    return Float64.(profile), reduced, maximum_spread
end

profile_location(length, nz) = length == nz ? "Center" : length == nz + 1 ? "Face" :
                                        error("invalid profile length $length")

function z_coordinates(location, nz, vertical_extent)
    dz = vertical_extent / nz
    return location == "Center" ? [(k - 0.5) * dz for k in 1:nz] :
           [(k - 1) * dz for k in 1:nz+1]
end

function csv_number(io, value)
    require_check(isfinite(value), "refusing non-finite CSV value")
    @printf(io, "%.17g", Float64(value))
end

function write_wide_csv(path, records, names, values)
    open(path, "w") do io
        println(io, join(vcat("time_s", names), ','))
        for index in eachindex(records)
            csv_number(io, records[index].time)
            for name in names
                print(io, ',')
                csv_number(io, values[name][index])
            end
            println(io)
        end
    end
end

function read_series_file(path, expected_times, unit_function)
    information = Dict{String, Any}()
    values = Dict{String, Vector{Float64}}()
    metadata = Dict{String, Any}()
    records = NamedTuple[]
    jldopen(path, "r") do file
        records = numeric_records(file)
        exact_times([record.time for record in records], expected_times, basename(path))
        metadata = metadata_dictionary(file)
        for name in output_names(file)
            units = unit_function(name)
            series = Float64[]
            source_shape = nothing
            source_eltype = nothing
            for record in records
                raw = file["timeseries/$name/$(record.key)"]
                shape = raw isa Number ? Int[] : collect(size(raw))
                element_type = raw isa Number ? string(typeof(raw)) : string(eltype(raw))
                source_shape === nothing && (source_shape = shape)
                source_eltype === nothing && (source_eltype = element_type)
                require_check(shape == source_shape, "$name shape changes over time")
                require_check(element_type == source_eltype, "$name element type changes over time")
                push!(series, scalar_value(raw, name, record.time))
            end
            values[name] = series
            information[name] = Dict("units" => units, "records" => length(series),
                                     "all_finite" => true, "source_shape" => source_shape,
                                     "raw_element_type" => source_eltype)
        end
    end
    return (; records, values, information, metadata)
end

function read_profile_file(path, expected_times, nz)
    data = Dict{String, Dict{Float64, Vector{Float64}}}()
    information = Dict{String, Any}()
    metadata = Dict{String, Any}()
    records = NamedTuple[]
    jldopen(path, "r") do file
        records = numeric_records(file)
        exact_times([record.time for record in records], expected_times, basename(path))
        metadata = metadata_dictionary(file)
        for name in output_names(file)
            units = profile_unit(name)
            data[name] = Dict{Float64, Vector{Float64}}()
            source_shape = nothing
            source_eltype = nothing
            location = nothing
            reduced = false
            maximum_spread = 0.0
            for record in records
                raw = file["timeseries/$name/$(record.key)"]
                shape = collect(size(raw))
                element_type = string(eltype(raw))
                source_shape === nothing && (source_shape = shape)
                source_eltype === nothing && (source_eltype = element_type)
                require_check(shape == source_shape, "$name shape changes over time")
                require_check(element_type == source_eltype, "$name element type changes over time")
                profile, was_reduced, spread = profile_vector(raw, nz, name, record.time)
                record_location = profile_location(length(profile), nz)
                location === nothing && (location = record_location)
                require_check(location == record_location, "$name location changes over time")
                data[name][record.time] = profile
                reduced |= was_reduced
                maximum_spread = max(maximum_spread, spread)
            end
            information[name] = Dict("units" => units, "location" => location,
                "source_shape" => source_shape, "records" => length(records),
                "raw_element_type" => source_eltype, "all_finite" => true,
                "horizontal_mean_applied_during_export" => reduced,
                "maximum_source_xy_spread" => maximum_spread)
        end
    end
    return (; records, data, information, metadata)
end

function require_same_profile_contract(initial, averaged)
    require_check(Set(keys(initial.data)) == Set(keys(averaged.data)),
                  "GABLS1 initial and averaged profile variables differ")
    for name in keys(initial.data)
        a, b = initial.information[name], averaged.information[name]
        require_check(a["location"] == b["location"], "$name changes location")
        require_check(a["source_shape"] == b["source_shape"], "$name changes shape")
    end
end

function write_profiles(path, records, data, information, nz, vertical_extent,
                        record_kind, window_start)
    open(path, "w") do io
        println(io, "time_s,z_m,variable,value,location,units,record_kind,window_start_s,window_end_s")
        for record in records
            for name in sort!(collect(keys(data)))
                profile = data[name][record.time]
                info = information[name]
                z = z_coordinates(info["location"], nz, vertical_extent)
                for index in eachindex(profile)
                    csv_number(io, record.time); print(io, ','); csv_number(io, z[index])
                    print(io, ',', name, ','); csv_number(io, profile[index])
                    print(io, ',', info["location"], ',', info["units"], ',',
                          record_kind(record.time), ',')
                    csv_number(io, window_start(record.time)); print(io, ',')
                    csv_number(io, record.time); println(io)
                end
            end
        end
    end
end

function append_profiles(path, records, data, information, nz, vertical_extent,
                         record_kind, window_start)
    open(path, "a") do io
        for record in records
            for name in sort!(collect(keys(data)))
                profile = data[name][record.time]
                info = information[name]
                z = z_coordinates(info["location"], nz, vertical_extent)
                for index in eachindex(profile)
                    csv_number(io, record.time); print(io, ','); csv_number(io, z[index])
                    print(io, ',', name, ','); csv_number(io, profile[index])
                    print(io, ',', info["location"], ',', info["units"], ',',
                          record_kind(record.time), ',')
                    csv_number(io, window_start(record.time)); print(io, ',')
                    csv_number(io, record.time); println(io)
                end
            end
        end
    end
end

function write_mean_profile(path, source_times, data, information, nz, vertical_extent,
                            label, window_start, window_end)
    open(path, "w") do io
        println(io, "time_s,z_m,variable,value,location,units,record_kind,window_start_s,window_end_s,source_times_s")
        for name in sort!(collect(keys(data)))
            profile = reduce(+, (data[name][time] for time in source_times)) ./ length(source_times)
            info = information[name]
            z = z_coordinates(info["location"], nz, vertical_extent)
            for index in eachindex(profile)
                csv_number(io, window_end); print(io, ','); csv_number(io, z[index])
                print(io, ',', name, ','); csv_number(io, profile[index])
                print(io, ',', info["location"], ',', info["units"], ',', label, ',')
                csv_number(io, window_start); print(io, ','); csv_number(io, window_end)
                println(io, ',', join(source_times, ';'))
            end
        end
    end
end

function required_surface_layer_variables(family)
    profiles = family == "GABLS1" ? ["surface_layer_viscosity",
        "surface_layer_diffusivity_ρθ"] : ["surface_layer_viscosity",
        "surface_layer_diffusivity_ρθ", "surface_layer_diffusivity_ρqᵉ"]
    tracers = family == "GABLS1" ? ["ρθ"] : ["ρθ", "ρqᵉ"]
    series = ["surface_layer_filtered_surface_u_flux",
              "surface_layer_filtered_surface_v_flux",
              "surface_layer_filtered_friction_velocity"]
    for face in 1:2
        prefix = "surface_layer_face$(face)_"
        append!(series, prefix .* ["viscosity", "filtered_u_mean", "filtered_v_mean",
            "filtered_w_mean", "filtered_uw_product", "filtered_vw_product",
            "filtered_u_mean_w_mean_transport", "filtered_v_mean_w_mean_transport",
            "momentum_deficit", "transverse_resolved_stress", "resolved_u_flux",
            "resolved_v_flux", "momentum_active_fraction", "viscosity_cap_fraction"])
        for tracer in tracers
            scalar = prefix * tracer * "_"
            append!(series, scalar .* ["diffusivity", "filtered_scalar_mean",
                "filtered_scalar_w_product", "filtered_scalar_mean_w_mean_transport",
                "resolved_flux", "deficit", "active_fraction", "cap_fraction"])
        end
    end
    append!(series, ["surface_layer_filtered_surface_flux_$tracer" for tracer in tracers])
    return (; profiles, series)
end

function audit_closure_outputs(family, closure, profiles, series, profile_metadata)
    available = get(profile_metadata, "surface_layer_diffusivity_available", false)
    if closure == "surface_layer"
        require_check(available === true, "SLD case metadata says closure diagnostics unavailable")
        required = required_surface_layer_variables(family)
        for name in required.profiles
            require_check(haskey(profiles, name), "missing required SLD profile $name")
        end
        for name in required.series
            require_check(haskey(series, name), "missing required SLD series $name")
        end
    else
        require_check(available === false, "control metadata unexpectedly says SLD is available")
        require_check(!any(startswith(name, "surface_layer_") for name in keys(profiles)),
                      "control contains SLD profiles")
        require_check(!any(startswith(name, "surface_layer_") for name in keys(series)),
                      "control contains SLD series")
    end
end

function json_escape(value)
    return replace(string(value), '\\' => "\\\\", '"' => "\\\"",
                   '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")
end

function write_json(io, value; indent=0)
    value = sanitize(value)
    if value === nothing
        print(io, "null")
    elseif value isa Bool
        print(io, value ? "true" : "false")
    elseif value isa Integer
        print(io, value)
    elseif value isa AbstractFloat
        print(io, repr(value))
    elseif value isa AbstractString
        print(io, '"', json_escape(value), '"')
    elseif value isa AbstractDict
        entries = sort!(collect(pairs(value)); by=pair -> string(first(pair)))
        println(io, "{")
        for (index, (key, item)) in enumerate(entries)
            print(io, repeat(" ", indent + 2), '"', json_escape(key), "\": ")
            write_json(io, item; indent=indent + 2)
            print(io, index == length(entries) ? "\n" : ",\n")
        end
        print(io, repeat(" ", indent), "}")
    elseif value isa AbstractVector
        print(io, '[')
        for (index, item) in enumerate(value)
            index > 1 && print(io, ", ")
            write_json(io, item; indent)
        end
        print(io, ']')
    else
        error("unsupported JSON value $(typeof(value))")
    end
end

function write_manifests(destination, manifest)
    manifest = sanitize(manifest)
    open(joinpath(destination, "manifest.toml"), "w") do io
        TOML.print(io, manifest; sorted=true)
    end
    open(joinpath(destination, "manifest.json"), "w") do io
        write_json(io, manifest)
        println(io)
    end
end

function raw_paths(family, run_directory, case_id)
    prefix = joinpath(run_directory, "$(case_id)_diag")
    if family == "GABLS1"
        return Dict("initial" => prefix * "_initial.jld2",
                    "profiles" => prefix * "_statistics.jld2",
                    "series" => prefix * "_series.jld2")
    else
        return Dict("profiles" => prefix * "_profiles.jld2",
                    "series" => prefix * "_series.jld2",
                    "points" => prefix * "_points.jld2")
    end
end

function export_raw(family, run_directory, case_id, destination, nz, vertical_extent,
                    closure; scientific, provenance=Dict{String, Any}(),
                    grid_size=(nz, nz, nz),
                    domain_m=(vertical_extent, vertical_extent, vertical_extent))
    paths = raw_paths(family, run_directory, case_id)
    for path in values(paths)
        require_check(isfile(path), "missing raw diagnostic $path")
    end
    outputs = String[]
    source_files = Dict{String, Any}()
    for (kind, path) in paths
        source_files[kind] = Dict("path" => abspath(path), "sha256" => file_sha256(path))
    end

    if family == "GABLS1"
        initial = read_profile_file(paths["initial"], GABLS1_INITIAL_TIMES, nz)
        profiles = read_profile_file(paths["profiles"], GABLS1_PROFILE_TIMES, nz)
        require_same_profile_contract(initial, profiles)
        series = read_series_file(paths["series"], GABLS1_SERIES_TIMES, series_unit)
        audit_closure_outputs(family, closure, profiles.data, series.values, profiles.metadata)
        profile_path = joinpath(destination, "profiles.csv")
        write_profiles(profile_path, initial.records, initial.data, initial.information,
            nz, vertical_extent, time -> "instantaneous_initial", time -> 0.0)
        append_profiles(profile_path, profiles.records, profiles.data, profiles.information,
            nz, vertical_extent, time -> "preceding_1800s_average", time -> time - 1800)
        write_wide_csv(joinpath(destination, "series.csv"), series.records,
                       sort!(collect(keys(series.values))), series.values)
        write_mean_profile(joinpath(destination, "profiles_penultimate_hour_long.csv"),
            GABLS1_PENULTIMATE_HOUR_TIMES, profiles.data, profiles.information, nz,
            vertical_extent, "equal_mean_of_two_preceding_1800s_averages", 25200.0, 28800.0)
        write_mean_profile(joinpath(destination, "profiles_final_hour_long.csv"),
            GABLS1_FINAL_HOUR_TIMES, profiles.data, profiles.information, nz,
            vertical_extent, "equal_mean_of_two_preceding_1800s_averages", 28800.0, 32400.0)
        append!(outputs, ["profiles.csv", "series.csv",
                          "profiles_penultimate_hour_long.csv", "profiles_final_hour_long.csv"])
        profile_information = profiles.information
        series_information = series.information
        record_audit = Dict(
            "profiles" => Dict("initial_records" => 1, "averaged_records" => 18,
                "total_records" => 19, "initial_times_s" => GABLS1_INITIAL_TIMES,
                "averaged_times_s" => GABLS1_PROFILE_TIMES, "variables" => length(profiles.data),
                "all_finite" => true, "final_time_s" => 32400.0),
            "series" => Dict("records" => 541, "times_s" => GABLS1_SERIES_TIMES,
                "variables" => length(series.values), "all_finite" => true,
                "final_time_s" => 32400.0))
        semantics = Dict("t0" => "separate instantaneous initial profile",
            "positive_times" => "true average over the preceding 1800 seconds",
            "penultimate_hour_source_times_s" => GABLS1_PENULTIMATE_HOUR_TIMES,
            "final_hour_source_times_s" => GABLS1_FINAL_HOUR_TIMES)
        raw_metadata = Dict("initial" => initial.metadata,
                            "profiles" => profiles.metadata, "series" => series.metadata)
        point_information = Dict{String, Any}()
    elseif family == "GABLS3"
        profiles = read_profile_file(paths["profiles"], GABLS3_PROFILE_TIMES, nz)
        series = read_series_file(paths["series"], GABLS3_SERIES_TIMES, series_unit)
        points = read_series_file(paths["points"], GABLS3_SERIES_TIMES, point_unit)
        audit_closure_outputs(family, closure, profiles.data, series.values, profiles.metadata)
        write_profiles(joinpath(destination, "profiles.csv"), profiles.records,
            profiles.data, profiles.information, nz, vertical_extent,
            time -> "instantaneous_horizontal_profile", time -> time)
        write_wide_csv(joinpath(destination, "series.csv"), series.records,
                       sort!(collect(keys(series.values))), series.values)
        write_wide_csv(joinpath(destination, "points.csv"), points.records,
                       sort!(collect(keys(points.values))), points.values)
        write_mean_profile(joinpath(destination, "profiles_03_04utc_mean.csv"),
            GABLS3_PAPER_WINDOW_TIMES, profiles.data, profiles.information, nz,
            vertical_extent, "equal_mean_of_12_instantaneous_profiles", 10800.0, 14400.0)
        append!(outputs, ["profiles.csv", "series.csv", "points.csv",
                          "profiles_03_04utc_mean.csv"])
        profile_information = profiles.information
        series_information = series.information
        point_information = points.information
        record_audit = Dict(
            "profiles" => Dict("records" => 109, "times_s" => GABLS3_PROFILE_TIMES,
                "variables" => length(profiles.data), "all_finite" => true,
                "final_time_s" => 32400.0),
            "series" => Dict("records" => 3241, "times_s" => GABLS3_SERIES_TIMES,
                "variables" => length(series.values), "all_finite" => true,
                "final_time_s" => 32400.0),
            "points" => Dict("records" => 3241, "times_s" => GABLS3_SERIES_TIMES,
                "variables" => length(points.values), "all_finite" => true,
                "final_time_s" => 32400.0))
        semantics = Dict("profiles" => "instantaneous horizontal reductions",
            "series_and_points" => "instantaneous records, including Oceananigans initialization at t=0 before the 10 s SpecifiedTimes schedule",
            "paper_03_04utc_source_times_s" => GABLS3_PAPER_WINDOW_TIMES,
            "paper_03_04utc_window_s" => [10800.0, 14400.0],
            "left_boundary_10800_excluded" => true)
        raw_metadata = Dict("profiles" => profiles.metadata,
            "series" => series.metadata, "points" => points.metadata)
    else
        error("unsupported family $family")
    end

    output_sha = Dict(name => file_sha256(joinpath(destination, name)) for name in outputs)
    physics_audit = Dict{String, Any}()
    series_values = series.values
    if haskey(series_values, "surface_theta_kinematic_flux")
        physics_audit["final_surface_theta_kinematic_flux_negative"] =
            series_values["surface_theta_kinematic_flux"][end] < 0
    end
    haskey(series_values, "q_minimum") &&
        (physics_audit["q_minimum_observed"] = minimum(series_values["q_minimum"]))
    haskey(series_values, "q_maximum") &&
        (physics_audit["q_maximum_observed"] = maximum(series_values["q_maximum"]))
    for name in keys(series_values)
        endswith(name, "cap_fraction") || continue
        physics_audit["maximum_$name"] = maximum(series_values[name])
    end
    manifest = Dict{String, Any}(
        "schema_version" => 1, "generated_utc" => string(now(UTC)),
        "case_id" => case_id, "case_family" => family, "closure" => closure,
        "export_verified" => scientific, "fixture_non_scientific" => !scientific,
        "scientific_admission" => scientific ? "passed" : "not_attempted_fixture_only",
        "source_files" => source_files,
        "grid" => Dict("Nx" => grid_size[1], "Ny" => grid_size[2], "Nz" => grid_size[3],
            "Lx_m" => domain_m[1], "Ly_m" => domain_m[2], "Lz_m" => domain_m[3],
            "dx_m" => domain_m[1] / grid_size[1],
            "dy_m" => domain_m[2] / grid_size[2],
            "dz_m" => domain_m[3] / grid_size[3],
            "center_z_definition" => "(k-0.5)*dz_m, k=1:Nz",
            "face_z_definition" => "(k-1)*dz_m, k=1:Nz+1"),
        "record_audit" => record_audit, "profile_record_semantics" => semantics,
        "physics_audit" => physics_audit,
        "profile_variables" => profile_information,
        "series_variables" => series_information, "point_variables" => point_information,
        "raw_metadata" => raw_metadata, "output_sha256" => output_sha,
        "definitions" => Dict(
            "vertical_flux_sign" => "upward-positive kinematic vertical flux",
            "stable_surface_heat_flux_expectation" => "negative; audited as physics, not admission",
            "momentum_stress_sign" => "wall stress vector; resolved vertical momentum flux retains native sign",
            "surface_layer_mean_transport" => "horizontal mean of local filtered-mean products, not product of horizontal averages",
            "surface_layer_covariance" => "stable exponentially weighted centered recurrence from old means",
            "surface_layer_friction_velocity" => "local ustar from local filtered stress vector, then horizontal mean",
            "unavailable_terms" => "omitted and identified by availability metadata; never filled with physical zero"),
        "provenance" => provenance)
    write_manifests(destination, manifest)
    return manifest
end

function require_file_match(captured, frozen)
    require_check(isfile(captured), "captured provenance file missing: $captured")
    require_check(isfile(frozen), "frozen provenance source missing: $frozen")
    require_check(file_sha256(captured) == file_sha256(frozen),
                  "captured/frozen source mismatch: $(basename(captured))")
end

function verify_provenance(family, run_directory, freeze_root, registry, scientific_registry)
    provenance = joinpath(run_directory, "provenance")
    evaluation = joinpath(freeze_root, "source", "BreezeEvaluation.jl")
    breeze = joinpath(freeze_root, "source", "Breeze.jl")
    git_text = read(joinpath(provenance, "git.txt"), String)
    breeze_git = read(joinpath(provenance, "breeze_git.txt"), String)
    freeze_readme = read(joinpath(freeze_root, "README.md"), String)
    require_check(occursin(registry["source_evaluation_commit"], freeze_readme),
                  "freeze README evaluation commit mismatch")
    require_check(occursin(registry["source_breeze_commit"], freeze_readme),
                  "freeze README Breeze commit mismatch")
    evaluation_git_available = !occursin("UNAVAILABLE", git_text)
    breeze_git_available = !occursin("UNAVAILABLE", breeze_git)
    evaluation_git_available && require_check(
        occursin(registry["source_evaluation_commit"], git_text),
        "captured evaluation commit mismatch")
    breeze_git_available && require_check(
        occursin(registry["source_breeze_commit"], breeze_git),
        "captured Breeze commit mismatch")
    breeze_diff = strip(read(joinpath(provenance, "breeze_uncommitted.diff"), String))
    require_check(isempty(breeze_diff) || startswith(breeze_diff, "UNAVAILABLE"),
                  "captured Breeze dependency had an uncommitted diff")
    environment_hashes = Dict{String, String}()
    for (captured_name, frozen_path) in (
        "active.Project.toml" => joinpath(evaluation, "cases/gabls3/runner/Project.toml"),
        "active.Manifest.toml" => joinpath(evaluation, "cases/gabls3/runner/Manifest.toml"),
        "Breeze.Project.toml" => joinpath(breeze, "Project.toml"),
        "Breeze.Manifest.toml" => joinpath(breeze, "Manifest.toml"))
        require_file_match(joinpath(provenance, captured_name), frozen_path)
        environment_hashes[captured_name] = file_sha256(frozen_path)
    end
    relative_sources = family == "GABLS1" ? [
        ("gabls1_case.jl", "evaluation", "cases/surface_layer/gabls1/gabls1_case.jl"),
        ("gabls_rough_wall_coefficient.jl", "evaluation", "source_snapshots/gabls1/original/source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl"),
        ("gabls_diagnostics.jl", "evaluation", "source_snapshots/gabls1/original/source/examples/gabls_diagnostics.jl"),
        ("SurfaceLayerDiagnostics.jl", "evaluation", "cases/surface_layer/diagnostics/SurfaceLayerDiagnostics.jl"),
        ("LegacyGABLSDiagnosticsAdaptation.jl", "evaluation", "cases/surface_layer/diagnostics/LegacyGABLSDiagnosticsAdaptation.jl"),
        ("GABLS1SurfaceLayerDiagnostics.jl", "evaluation", "cases/surface_layer/diagnostics/GABLS1SurfaceLayerDiagnostics.jl")] : [
        ("gabls3_case.jl", "evaluation", "cases/gabls3/runner/gabls3_case.jl"),
        ("GABLS3ModelForcing.jl", "evaluation", "cases/gabls3/forcing/GABLS3ModelForcing.jl"),
        ("GABLS3Diagnostics.jl", "evaluation", "cases/gabls3/diagnostics/GABLS3Diagnostics.jl"),
        ("SurfaceLayerDiagnostics.jl", "evaluation", "cases/surface_layer/diagnostics/SurfaceLayerDiagnostics.jl"),
        ("LegacyGABLSDiagnosticsAdaptation.jl", "evaluation", "cases/surface_layer/diagnostics/LegacyGABLSDiagnosticsAdaptation.jl"),
        ("GABLS3Forcing.jl", "evaluation", "cases/gabls3/preparation/GABLS3Forcing.jl"),
        ("inputs.toml", "evaluation", "cases/gabls3/preparation/inputs.toml")]
    captured_source_hashes = Dict{String, String}()
    for (captured_name, source_kind, relative) in relative_sources
        root = source_kind == "evaluation" ? evaluation : breeze
        require_file_match(joinpath(provenance, captured_name), joinpath(root, relative))
        captured_source_hashes[captured_name] = file_sha256(joinpath(root, relative))
    end
    run_text = read(joinpath(provenance, "run.txt"), String)
    require_check(occursin("case_id: $(scientific_registry["case_id"])", run_text),
                  "run provenance case_id mismatch")
    digest_table = family == "GABLS1" ?
        Dict("theta_initial_sha256" => scientific_registry["paired_initial_theta_sha256"]) :
        scientific_registry["paired_initial_state_sha256"]
    for (key, digest) in digest_table
        require_check(occursin(string(key), run_text) && occursin(digest, run_text),
                      "paired initial digest missing/mismatched for $key")
    end
    return Dict("captured_source_files_checked" => length(relative_sources),
                "environment_files_checked" => 4,
                "paired_initial_digests_checked" => length(digest_table),
                "captured_evaluation_git_available" => evaluation_git_available,
                "captured_breeze_git_available" => breeze_git_available,
                "immutable_archive_manifest_is_authoritative" => true,
                "environment_sha256" => environment_hashes,
                "captured_source_sha256" => captured_source_hashes)
end

function scientific_case_settings(registry, attempt)
    freeze_root = registry["source_freeze_root"]
    evaluation = joinpath(freeze_root, "source", "BreezeEvaluation.jl")
    relative = registry["scientific_registry_relative"]
    path = normpath(joinpath(evaluation, relative))
    require_check(file_sha256(path) == registry["scientific_registry_sha256"],
                  "scientific registry SHA mismatch")
    scientific = TOML.parsefile(path)
    index = attempt["registry_index"]
    require_check(1 <= index <= length(scientific["cases"]), "registry index out of bounds")
    case = scientific["cases"][index]
    require_check(case["case_id"] == attempt["case_id"], "registry case/index mismatch")
    common = Dict{String, Any}("case_id" => case["case_id"], "closure" => case["closure"])
    if registry["case_family"] == "GABLS1"
        common["paired_initial_theta_sha256"] = scientific["paired_initial_theta_sha256"]
    else
        common["paired_initial_state_sha256"] = scientific["paired_initial_state_sha256"]
    end
    return (; path, scientific, case, common)
end

function verify_attempt_identity(attempt, completion, scientific_path)
    started = completion["started"]
    require_check(parse(Int, get(started, "registry_index", "0")) == attempt["registry_index"],
                  "ATTEMPT_STARTED registry index mismatch")
    require_check(abspath(get(started, "registry", "")) == abspath(scientific_path),
                  "ATTEMPT_STARTED registry path mismatch")
    log_path = attempt["log_path"]
    require_check(isfile(log_path), "active-attempt log is missing")
    require_check(file_sha256(log_path) == attempt["log_sha256"],
                  "active-attempt log hash mismatch")
    require_check(file_sha256(joinpath(attempt["run_directory"], "ATTEMPT_STARTED")) ==
                  attempt["attempt_started_sha256"], "ATTEMPT_STARTED hash mismatch")
    require_check(file_sha256(joinpath(attempt["run_directory"], "CASE_DONE")) ==
                  attempt["case_done_sha256"], "CASE_DONE hash mismatch")
    log = read(log_path, String)
    require_check(!occursin("CASE_FAILED", log) && !occursin("GPU_VALIDATION_FAILED", log),
                  "active-attempt log contains a failure sentinel")
    return true
end

function verify_analysis_freeze(registry, program_path)
    root = registry["analysis_freeze_root"]
    expected = registry["analysis_freeze_manifest_sha256"]
    require_check(root != "UNASSIGNED" && expected != "UNASSIGNED",
                  "analysis freeze is unassigned")
    manifest = joinpath(root, "source_sha256.txt")
    entries = verify_hash_manifest(root, manifest; expected_sha=expected)
    require_check(safe_inside(root, program_path),
                  "exporter must execute from the pinned immutable analysis freeze")
    require_check(safe_inside(root, @__FILE__),
                  "export module must load from the pinned immutable analysis freeze")
    return Dict("root" => abspath(root), "manifest_sha256" => expected,
                "manifest_entries" => entries, "program_sha256" => file_sha256(program_path))
end

function export_scientific_case(attempt_registry_path, case_id, export_root;
                                program_path=abspath(PROGRAM_FILE))
    registry = load_attempt_registry(attempt_registry_path)
    attempt = active_attempt(registry, case_id)
    freeze_root = registry["source_freeze_root"]
    manifest_path = joinpath(freeze_root, "source_sha256.txt")
    source_entries = verify_hash_manifest(freeze_root, manifest_path;
        expected_sha=registry["source_freeze_manifest_sha256"])
    require_check(source_entries == registry["source_freeze_manifest_entries"],
                  "source freeze manifest entry count does not match registry")
    gpu = verify_gpu_evidence(registry["gpu_validation_evidence_directory"], freeze_root,
                              registry["source_freeze_manifest_sha256"])
    require_check(gpu["source_manifest_entries"] ==
                  registry["source_freeze_manifest_entries"],
                  "GPU evidence entry count does not match registry")
    analysis = verify_analysis_freeze(registry, program_path)
    settings = scientific_case_settings(registry, attempt)
    run_directory = abspath(attempt["run_directory"])
    completion = verify_completion(run_directory, case_id)
    verify_attempt_identity(attempt, completion, settings.path)
    provenance_audit = verify_provenance(registry["case_family"], run_directory,
                                         freeze_root, registry, settings.common)
    nz = settings.scientific["grid"][3]
    vertical_extent = settings.scientific["domain_m"][3]
    destination = joinpath(abspath(export_root), case_id)
    require_check(!ispath(destination), "refusing to overwrite export $destination")
    mkpath(export_root)
    temporary = mktempdir(export_root; prefix=".$case_id-")
    admission = Dict{String, Any}(
        "attempt_registry_path" => abspath(attempt_registry_path),
        "attempt_registry_sha256" => file_sha256(attempt_registry_path),
        "active_attempt_id" => attempt["active_attempt_id"],
        "job_spec" => attempt["job_spec"], "run_directory" => run_directory,
        "source_freeze_root" => abspath(freeze_root),
        "source_freeze_manifest_sha256" => registry["source_freeze_manifest_sha256"],
        "source_freeze_manifest_entries" => source_entries,
        "scientific_registry_path" => settings.path,
        "scientific_registry_sha256" => registry["scientific_registry_sha256"],
        "gpu_validation" => gpu, "analysis_freeze" => analysis,
        "completion" => completion, "provenance_audit" => provenance_audit,
        "queue_state_used_for_admission" => false)
    try
        manifest = export_raw(registry["case_family"], run_directory, case_id, temporary,
            nz, vertical_extent, settings.case["closure"];
            scientific=true, provenance=admission,
            grid_size=Tuple(settings.scientific["grid"]),
            domain_m=Tuple(settings.scientific["domain_m"]))
        mv(temporary, destination)
        return manifest
    catch
        rm(temporary; recursive=true, force=true)
        rethrow()
    end
end

function export_fixture(family, run_directory, case_id, destination, nz,
                        vertical_extent, closure)
    require_check(!ispath(destination), "refusing to overwrite fixture export")
    mkpath(dirname(destination))
    temporary = mktempdir(dirname(destination); prefix=".$case_id-fixture-")
    try
        manifest = export_raw(family, run_directory, case_id, temporary, nz,
                              vertical_extent, closure; scientific=false,
                              provenance=Dict("fixture_warning" =>
                                  "synthetic plumbing fixture; never a scientific result"))
        mv(temporary, destination)
        return manifest
    catch
        rm(temporary; recursive=true, force=true)
        rethrow()
    end
end

function verify_export_manifest(directory)
    manifest_path = joinpath(directory, "manifest.toml")
    require_check(isfile(manifest_path), "manifest.toml missing")
    manifest = TOML.parsefile(manifest_path)
    require_check(manifest["export_verified"] === true, "export is not scientifically verified")
    require_check(manifest["fixture_non_scientific"] === false, "fixture cannot be collected")
    for (name, expected) in manifest["output_sha256"]
        path = joinpath(directory, name)
        require_check(isfile(path) && file_sha256(path) == expected,
                      "export output hash mismatch: $name")
    end
    return manifest
end

function collect_admitted_exports(attempt_registry_path, export_root, destination)
    registry = load_attempt_registry(attempt_registry_path)
    ispath(destination) && error("refusing to overwrite collection $destination")
    mkpath(destination)
    admitted = Dict{String, Any}[]
    rejected = Dict{String, Any}[]
    for attempt in registry["attempts"]
        case_id = attempt["case_id"]
        directory = joinpath(export_root, case_id)
        try
            active_attempt(registry, case_id)
            manifest = verify_export_manifest(directory)
            provenance = manifest["provenance"]
            require_check(provenance["active_attempt_id"] == attempt["active_attempt_id"],
                          "export active-attempt mismatch")
            require_check(provenance["attempt_registry_sha256"] ==
                          file_sha256(attempt_registry_path), "export attempt registry changed")
            require_check(provenance["source_freeze_manifest_sha256"] ==
                          registry["source_freeze_manifest_sha256"],
                          "export source freeze mismatch")
            push!(admitted, Dict("case_id" => case_id, "directory" => abspath(directory),
                                 "manifest_sha256" => file_sha256(joinpath(directory, "manifest.toml"))))
        catch error
            push!(rejected, Dict("case_id" => case_id,
                                 "reason" => sprint(showerror, error)))
        end
    end
    collection = Dict{String, Any}(
        "schema_version" => 1, "generated_utc" => string(now(UTC)),
        "attempt_registry_path" => abspath(attempt_registry_path),
        "attempt_registry_sha256" => file_sha256(attempt_registry_path),
        "case_family" => registry["case_family"], "expected_cases" => registry["expected_case_count"],
        "admitted_count" => length(admitted), "rejected_count" => length(rejected),
        "admitted" => admitted, "rejected" => rejected)
    write_manifests(destination, collection)
    return collection
end

end
