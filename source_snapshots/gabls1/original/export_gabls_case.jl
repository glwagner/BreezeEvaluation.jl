#!/usr/bin/env julia

# Read-only, transactional exporter for one admitted GABLS production case. The watcher must
# supply the exact case log and Slurm job specification; this script independently verifies both
# success sentinels, queue absence, record completeness, finiteness, coordinates, and frozen
# source hashes before publishing CSVs or a manifest.

using Oceananigans
using Dates
using Printf
using SHA
using Statistics

const JLD2 = Oceananigans.OutputReaders.JLD2

length(ARGS) == 4 || error(
    "usage: export_gabls_case.jl PRODUCTION_ROOT CASE_ID LOG_PATH SLURM_JOB_SPEC")

const PRODUCTION_ROOT = normpath(ARGS[1])
const CASE_ID = ARGS[2]
const LOG_PATH = abspath(ARGS[3])
const SLURM_JOB_SPEC = ARGS[4]
const RUN_DIR = joinpath(PRODUCTION_ROOT, "runs", CASE_ID)
const EXPORT_ROOT = joinpath(PRODUCTION_ROOT, "analysis_export")

const EXPECTED_PROFILE_TIMES = collect(0.0:1800.0:32400.0)
const EXPECTED_SERIES_TIMES = collect(0.0:60.0:32400.0)
const FINAL_HOUR_SOURCE_TIMES = [30600.0, 32400.0]
const PENULTIMATE_HOUR_SOURCE_TIMES = [27000.0, 28800.0]

const PROFILE_UNITS = Dict(
    "u_mean" => "m s^-1", "v_mean" => "m s^-1", "w_mean" => "m s^-1",
    "theta_mean" => "K", "density_mean" => "kg m^-3", "buoyancy_mean" => "m s^-2",
    "u_variance" => "m^2 s^-2", "v_variance" => "m^2 s^-2",
    "w_variance" => "m^2 s^-2", "w_third_central_moment" => "m^3 s^-3",
    "w_skewness_instantaneous_ratio" => "1", "w_center_mean" => "m s^-1",
    "w_center_variance" => "m^2 s^-2",
    "w_center_third_central_moment" => "m^3 s^-3", "theta_variance" => "K^2",
    "resolved_u_w_flux" => "m^2 s^-2", "resolved_v_w_flux" => "m^2 s^-2",
    "resolved_w_theta_flux" => "K m s^-1", "sgs_u_w_flux" => "m^2 s^-2",
    "sgs_v_w_flux" => "m^2 s^-2", "sgs_w_theta_flux" => "K m s^-1",
    "total_u_w_flux" => "m^2 s^-2", "total_v_w_flux" => "m^2 s^-2",
    "total_w_theta_flux" => "K m s^-1", "total_stress_magnitude" => "m^2 s^-2",
    "resolved_buoyancy_flux" => "m^2 s^-3", "sgs_buoyancy_flux" => "m^2 s^-3",
    "total_buoyancy_flux" => "m^2 s^-3", "resolved_tke" => "m^2 s^-2",
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
    "sgs_tke" => "m^2 s^-2",
)

const SERIES_UNITS = Dict(
    "friction_velocity" => "m s^-1",
    "surface_drag_u_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_v_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_u_kinematic_flux" => "m^2 s^-2",
    "surface_drag_v_kinematic_flux" => "m^2 s^-2",
    "surface_theta_dynamic_flux" => "kg K m^-2 s^-1",
    "surface_theta_kinematic_flux" => "K m s^-1",
    "surface_sensible_heat_flux" => "W m^-2",
    "surface_buoyancy_flux" => "m^2 s^-3", "surface_density" => "kg m^-3",
    "obukhov_length" => "m", "obukhov_length_valid" => "1",
    "surface_bulk_richardson_mean" => "1",
    "surface_bulk_richardson_maximum" => "1",
    "surface_stability_parameter_mean" => "1",
    "surface_stability_parameter_maximum" => "1",
    "surface_stability_cap_fraction" => "1",
    "surface_neutral_fallback_fraction" => "1",
    "surface_temperature" => "K", "stress_height_0_05" => "m",
    "boundary_layer_height" => "m", "boundary_layer_height_valid" => "1",
    "low_level_jet_height" => "m", "low_level_jet_speed" => "m s^-1",
    "low_level_jet_turning_from_geostrophic" => "rad", "low_level_jet_valid" => "1",
    "theta_minimum" => "K", "theta_maximum" => "K",
    "u_absolute_maximum" => "m s^-1", "v_absolute_maximum" => "m s^-1",
    "w_absolute_maximum" => "m s^-1", "speed_maximum" => "m s^-1",
    "resolved_tke_vertical_integral" => "m^3 s^-2",
    "w_variance_maximum" => "m^2 s^-2", "sgs_tke_vertical_integral" => "m^3 s^-2",
)

json_escape(value) = replace(string(value), '\\' => "\\\\", '"' => "\\\"",
                             '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")

function write_json(io, value; indent=0)
    if value === nothing
        print(io, "null")
    elseif value isa Bool
        print(io, value ? "true" : "false")
    elseif value isa Integer
        print(io, value)
    elseif value isa AbstractFloat
        isfinite(value) || error("Cannot encode non-finite JSON value")
        print(io, repr(Float64(value)))
    elseif value isa AbstractString || value isa Symbol
        print(io, '"', json_escape(value), '"')
    elseif value isa NamedTuple
        write_json(io, Dict(string(k) => v for (k, v) in pairs(value)); indent)
    elseif value isa AbstractDict
        entries = sort!(collect(pairs(value)); by=p -> string(first(p)))
        println(io, "{")
        for (n, (key, item)) in enumerate(entries)
            print(io, " "^(indent + 2), '"', json_escape(key), "\": ")
            write_json(io, item; indent=indent + 2)
            print(io, n == length(entries) ? "\n" : ",\n")
        end
        print(io, repeat(" ", indent), "}")
    elseif value isa Tuple || value isa AbstractVector
        print(io, "[")
        for (n, item) in enumerate(value)
            n > 1 && print(io, ", ")
            write_json(io, item; indent)
        end
        print(io, "]")
    else
        print(io, '"', json_escape(value), '"')
    end
end

sha256_file(path) = open(io -> bytes2hex(sha256(io)), path, "r")

function csv_number(io, value)
    isfinite(value) || error("Refusing to export non-finite value")
    @printf(io, "%.9g", Float64(value))
end

function numeric_records(file)
    time_group = file["timeseries/t"]
    records = [(key=key, time=Float64(time_group[key])) for key in keys(time_group)]
    sort!(records; by=record -> record.time)
    return records
end

output_names(file) = sort!(filter(!=("t"), String.(collect(keys(file["timeseries"])))))

function scalar_value(value, name, time)
    scalar = value isa Number ? value : length(value) == 1 ? only(value) :
             error("Series $name at $time is not scalar: size $(size(value))")
    isfinite(scalar) || error("Non-finite series value $name at $time")
    return Float64(scalar)
end

function profile_vector(value, nz, name, time)
    value isa AbstractArray || error("Profile $name at $time is not an array")
    all(isfinite, value) || error("Non-finite profile $name at $time")
    z_length = size(value, ndims(value))
    z_length in (nz, nz + 1) ||
        error("Profile $name at $time has unexpected vertical length $z_length")
    if ndims(value) == 3 && (size(value, 1) != 1 || size(value, 2) != 1)
        profile = vec(dropdims(mean(value; dims=(1, 2)); dims=(1, 2)))
        maximum_spread = maximum(k -> begin
            lo, hi = extrema(view(value, :, :, k)); Float64(hi - lo)
        end, axes(value, 3))
        return Float64.(profile), true, maximum_spread
    end
    return Float64.(vec(value)), false, 0.0
end

profile_location(length, nz) = length == nz ? "Center" :
                               length == nz + 1 ? "Face" : error("bad profile length")

function z_coordinates(location, nx)
    dz = 400.0 / nx
    return location == "Center" ? [(k - 0.5) * dz for k in 1:nx] :
           [(k - 1.0) * dz for k in 1:nx+1]
end

function require_admission()
    isfile(LOG_PATH) || error("Missing case log $LOG_PATH")
    log = read(LOG_PATH, String)
    occursin("CASE_DONE $CASE_ID ", log) || error("CASE_DONE sentinel absent")
    occursin("GABLS_CASE_EXIT_SUCCESS", log) || error("GABLS success sentinel absent")
    state = strip(read(pipeline(ignorestatus(`squeue -h -j $SLURM_JOB_SPEC -o %T`),
                                stderr=devnull), String))
    isempty(state) || error("Slurm job $SLURM_JOB_SPEC remains in queue: $state")
    return true
end

function verify_source_hashes()
    pairs = [
        ("diagnostics", joinpath(PRODUCTION_ROOT, "source/examples/gabls_diagnostics.jl"),
                        joinpath(RUN_DIR, "provenance/gabls_diagnostics.jl")),
        ("runner", joinpath(PRODUCTION_ROOT, "source/validation_output/gabls/gabls_case.jl"),
                   joinpath(RUN_DIR, "provenance/gabls_case.jl")),
        ("surface", joinpath(PRODUCTION_ROOT, "source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl"),
                    joinpath(RUN_DIR, "provenance/gabls_rough_wall_coefficient.jl")),
        ("manifest", joinpath(PRODUCTION_ROOT, "source/Manifest.toml"),
                     joinpath(RUN_DIR, "provenance/Manifest.toml")),
    ]
    result = Dict{String, Any}()
    for (name, frozen, captured) in pairs
        isfile(frozen) || error("Missing frozen source $frozen")
        isfile(captured) || error("Missing captured source $captured")
        frozen_hash = sha256_file(frozen)
        captured_hash = sha256_file(captured)
        frozen_hash == captured_hash || error("Source hash mismatch for $name")
        result[name] = Dict("frozen_path" => relpath(frozen, PRODUCTION_ROOT),
                            "run_path" => relpath(captured, PRODUCTION_ROOT),
                            "sha256" => frozen_hash, "checked" => true)
    end
    return result
end

function metadata_dictionary(file)
    result = Dict{String, Any}()
    for key in keys(file["metadata"])
        result[String(key)] = file["metadata/$key"]
    end
    return result
end

function write_hour_profile(path, label, source_times, stored_profiles,
                            profile_information, nx)
    open(path, "w") do io
        println(io, "time_s,z_m,variable,value,location,units,window_start_s,window_end_s,source_times_s")
        window_end = maximum(source_times)
        window_start = window_end - 3600
        for name in sort!(collect(keys(stored_profiles)))
            first_profile = stored_profiles[name][source_times[1]]
            second_profile = stored_profiles[name][source_times[2]]
            profile = (first_profile .+ second_profile) ./ 2
            information = profile_information[name]
            location = information["location"]
            z = z_coordinates(location, nx)
            for k in eachindex(profile)
                print(io, window_end, ','); csv_number(io, z[k]); print(io, ',', name, ',')
                csv_number(io, profile[k])
                println(io, ',', location, ',', information["units"], ',', window_start, ',',
                        window_end, ',', join(source_times, ';'))
            end
        end
    end
    return label
end

function export_case(destination)
    match_result = match(r"^n(\d{3})_", CASE_ID)
    isnothing(match_result) && error("Cannot parse grid from $CASE_ID")
    nx = parse(Int, only(match_result.captures))
    statistics_path = joinpath(RUN_DIR, "$(CASE_ID)_diag_statistics.jld2")
    series_path = joinpath(RUN_DIR, "$(CASE_ID)_diag_series.jld2")
    isfile(statistics_path) || error("Missing $statistics_path")
    isfile(series_path) || error("Missing $series_path")

    source_hashes = verify_source_hashes()
    profile_information = Dict{String, Any}()
    series_information = Dict{String, Any}()
    statistics_metadata = Dict{String, Any}()
    series_metadata = Dict{String, Any}()
    stored_profiles = Dict{String, Dict{Float64, Vector{Float64}}}()
    series_values = Dict{String, Vector{Float64}}()

    JLD2.jldopen(statistics_path, "r") do file
        records = numeric_records(file)
        times = [record.time for record in records]
        times == EXPECTED_PROFILE_TIMES || error("Unexpected profile times: $times")
        names = output_names(file)
        length(names) == 44 || error("Expected 44 profiles, found $(length(names))")
        statistics_metadata = metadata_dictionary(file)
        open(joinpath(destination, "profiles.csv"), "w") do io
            println(io, "time_s,z_m,variable,value,location,units,record_kind,window_start_s,window_end_s")
            for name in names
                haskey(PROFILE_UNITS, name) || error("No units for profile $name")
                units = PROFILE_UNITS[name]
                expected_shape = nothing
                variable_location = nothing
                horizontally_reduced = false
                maximum_spread = 0.0
                stored_profiles[name] = Dict{Float64, Vector{Float64}}()
                for record in records
                    raw = file["timeseries/$name/$(record.key)"]
                    expected_shape === nothing && (expected_shape = collect(size(raw)))
                    collect(size(raw)) == expected_shape || error("Shape changed for $name")
                    profile, reduced, spread = profile_vector(raw, nx, name, record.time)
                    location = profile_location(length(profile), nx)
                    variable_location === nothing && (variable_location = location)
                    location == variable_location || error("Location changed for $name")
                    horizontally_reduced |= reduced
                    maximum_spread = max(maximum_spread, spread)
                    stored_profiles[name][record.time] = profile
                    z = z_coordinates(location, nx)
                    record_kind = record.time == 0 ? "instantaneous_initial" : "preceding_1800s_average"
                    window_start = record.time == 0 ? 0.0 : record.time - 1800
                    for k in eachindex(profile)
                        print(io, record.time, ','); csv_number(io, z[k]); print(io, ',', name, ',')
                        csv_number(io, profile[k])
                        println(io, ',', location, ',', units, ',', record_kind, ',',
                                window_start, ',', record.time)
                    end
                end
                profile_information[name] = Dict(
                    "units" => units, "location" => variable_location,
                    "source_shape" => expected_shape, "records" => length(records),
                    "finite" => true,
                    "horizontal_mean_applied_during_export" => horizontally_reduced,
                    "maximum_source_xy_spread" => maximum_spread)
            end
        end
    end

    write_hour_profile(joinpath(destination, "profiles_penultimate_hour_long.csv"),
                       "penultimate", PENULTIMATE_HOUR_SOURCE_TIMES,
                       stored_profiles, profile_information, nx)
    write_hour_profile(joinpath(destination, "profiles_final_hour_long.csv"),
                       "final", FINAL_HOUR_SOURCE_TIMES,
                       stored_profiles, profile_information, nx)

    JLD2.jldopen(series_path, "r") do file
        records = numeric_records(file)
        times = [record.time for record in records]
        times == EXPECTED_SERIES_TIMES || error("Unexpected series times")
        names = output_names(file)
        length(names) == 34 || error("Expected 34 series, found $(length(names))")
        series_metadata = metadata_dictionary(file)
        for name in names
            haskey(SERIES_UNITS, name) || error("No units for series $name")
            values = [scalar_value(file["timeseries/$name/$(record.key)"], name, record.time)
                      for record in records]
            series_values[name] = values
            series_information[name] = Dict("units" => SERIES_UNITS[name],
                                             "records" => length(values), "finite" => true)
        end
        open(joinpath(destination, "series.csv"), "w") do io
            println(io, join(vcat("time_s", names), ','))
            for n in eachindex(records)
                print(io, records[n].time)
                for name in names
                    print(io, ','); csv_number(io, series_values[name][n])
                end
                println(io)
            end
        end
    end

    final_surface_heat_flux_negative =
        series_values["surface_theta_kinematic_flux"][end] < 0

    outputs = ("series.csv", "profiles.csv", "profiles_penultimate_hour_long.csv",
               "profiles_final_hour_long.csv")
    manifest = Dict{String, Any}(
        "schema_version" => 1,
        "generated_utc" => string(now(UTC)),
        "case_id" => CASE_ID,
        "export_verified" => true,
        "source_hashes_checked" => true,
        "slurm_job_spec" => SLURM_JOB_SPEC,
        "completion" => Dict("both_sentinels" => true, "queue_absent" => true,
                             "log_path" => LOG_PATH),
        "source_hashes" => source_hashes,
        "source_files" => Dict(
            "statistics" => relpath(statistics_path, PRODUCTION_ROOT),
            "statistics_sha256" => sha256_file(statistics_path),
            "series" => relpath(series_path, PRODUCTION_ROOT),
            "series_sha256" => sha256_file(series_path)),
        "reader" => Dict("julia_version" => string(VERSION),
                         "exporter" => abspath(PROGRAM_FILE),
                         "exporter_sha256" => sha256_file(abspath(PROGRAM_FILE)),
                         "method" => "plain numeric JLD2 leaves; no serialized GPU grids loaded"),
        "grid" => Dict("Nx" => nx, "Ny" => nx, "Nz" => nx,
                       "Lx_m" => 400.0, "Ly_m" => 400.0, "Lz_m" => 400.0,
                       "dx_m" => 400 / nx, "dy_m" => 400 / nx, "dz_m" => 400 / nx,
                       "center_z_definition" => "(k-0.5)*dz_m, k=1:Nz",
                       "face_z_definition" => "(k-1)*dz_m, k=1:Nz+1"),
        "record_audit" => Dict(
            "profiles" => Dict("variables" => length(profile_information), "records" => 19,
                               "times_s" => EXPECTED_PROFILE_TIMES, "final_time_s" => 32400.0,
                               "all_finite" => true),
            "series" => Dict("variables" => length(series_information), "records" => 541,
                             "times_s" => EXPECTED_SERIES_TIMES, "final_time_s" => 32400.0,
                             "interval_s" => 60.0, "all_finite" => true)),
        "profile_record_semantics" => Dict(
            "t0" => "instantaneous initial profile",
            "positive_times" => "true average over the preceding 1800 seconds",
            "final_hour_source_times_s" => FINAL_HOUR_SOURCE_TIMES,
            "penultimate_hour_source_times_s" => PENULTIMATE_HOUR_SOURCE_TIMES),
        "physics_audit" => Dict(
            "final_surface_theta_kinematic_flux_negative" =>
                final_surface_heat_flux_negative,
            "theta_minimum_observed_K" => minimum(series_values["theta_minimum"]),
            "theta_maximum_observed_K" => maximum(series_values["theta_maximum"]),
            "maximum_speed_observed_m_s" => maximum(series_values["speed_maximum"]),
            "maximum_surface_cap_fraction" => maximum(series_values["surface_stability_cap_fraction"]),
            "maximum_surface_neutral_fallback_fraction" => maximum(series_values["surface_neutral_fallback_fraction"])),
        "statistics_metadata" => statistics_metadata,
        "series_metadata" => series_metadata,
        "profile_variables" => profile_information,
        "series_variables" => series_information,
        "output_sha256" => Dict(name => sha256_file(joinpath(destination, name)) for name in outputs),
        "budget_caveat" => "Any later closure residual is a budget residual, not numerical dissipation.")

    open(joinpath(destination, "manifest.json"), "w") do io
        write_json(io, manifest); println(io)
    end
    return nothing
end

require_admission()
mkpath(EXPORT_ROOT)
final_destination = joinpath(EXPORT_ROOT, CASE_ID)
ispath(final_destination) && error("Destination already exists: $final_destination")
temporary_destination = mktempdir(EXPORT_ROOT; prefix=".$CASE_ID-")
try
    export_case(temporary_destination)
    mv(temporary_destination, final_destination)
    println("GABLS_EXPORT_VERIFIED $CASE_ID $final_destination")
catch
    rm(temporary_destination; recursive=true, force=true)
    rethrow()
end
