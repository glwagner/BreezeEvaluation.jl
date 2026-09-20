#!/usr/bin/env julia

# Read-only exporter for completed DYCOMS production cases. This deliberately reads only
# primitive metadata and numeric timeseries leaves from JLD2; it never loads serialized
# Oceananigans grids, fields, or GPU objects.

using Oceananigans
using Dates
using Printf
using SHA
using Statistics

const JLD2 = Oceananigans.OutputReaders.JLD2
const PRODUCTION_ROOT = normpath(get(ARGS, 1, dirname(@__DIR__)))
const ARRAY_JOB_ID = get(ARGS, 2, "7064")
const EXPORT_ROOT = joinpath(PRODUCTION_ROOT, "analysis_export")

const CASES = [
    "coarse_none_weno9",
    "coarse_none_weno5",
    "coarse_smagorinsky_weno9",
    "coarse_smagorinsky_weno5",
    "canonical_none_weno9",
    "canonical_none_weno5",
    "canonical_smagorinsky_weno9",
    "canonical_smagorinsky_weno5",
    "fine_none_weno9",
    "fine_none_weno5",
    "fine_smagorinsky_weno9",
    "fine_smagorinsky_weno5",
]

const GRID_SPECS = Dict(
    "coarse" => (Nx=96, Ny=96, Nz=75, Lx=7680.0, Ly=7680.0, Lz=1500.0),
    "canonical" => (Nx=96, Ny=96, Nz=300, Lx=3360.0, Ly=3360.0, Lz=1500.0),
    "fine" => (Nx=336, Ny=336, Nz=300, Lx=3360.0, Ly=3360.0, Lz=1500.0),
)

const PROFILE_UNITS = Dict(
    "u_mean" => "m s^-1", "v_mean" => "m s^-1", "w_mean" => "m s^-1",
    "theta_li_mean" => "K", "q_t_mean" => "kg kg^-1", "q_l_mean" => "kg kg^-1",
    "density_mean" => "kg m^-3", "buoyancy_mean" => "m s^-2",
    "u_variance" => "m^2 s^-2", "v_variance" => "m^2 s^-2",
    "w_variance" => "m^2 s^-2", "w_third_central_moment" => "m^3 s^-3",
    "w_center_mean" => "m s^-1", "w_center_variance" => "m^2 s^-2",
    "w_center_third_central_moment" => "m^3 s^-3", "theta_li_variance" => "K^2",
    "q_t_variance" => "(kg kg^-1)^2", "q_l_variance" => "(kg kg^-1)^2",
    "cloud_fraction_profile" => "1", "resolved_u_w_flux" => "m^2 s^-2",
    "resolved_v_w_flux" => "m^2 s^-2", "resolved_w_theta_li_flux" => "K m s^-1",
    "resolved_w_q_t_flux" => "(kg kg^-1) m s^-1",
    "resolved_w_q_l_flux" => "(kg kg^-1) m s^-1",
    "resolved_buoyancy_flux" => "m^2 s^-3", "sgs_u_w_flux" => "m^2 s^-2",
    "sgs_v_w_flux" => "m^2 s^-2", "sgs_theta_li_flux" => "K m s^-1",
    "sgs_q_t_flux" => "(kg kg^-1) m s^-1",
    "net_upward_radiative_flux" => "W m^-2", "radiative_flux_divergence" => "W m^-3",
    "resolved_tke" => "m^2 s^-2", "resolved_tke_shear_production" => "m^2 s^-3",
    "sgs_tke_shear_production" => "m^2 s^-3",
    "total_tke_shear_production" => "m^2 s^-3",
    "resolved_tke_buoyancy_production" => "m^2 s^-3",
    "turbulent_tke_flux" => "m^3 s^-3", "pressure_tke_flux" => "m^3 s^-3",
    "density_at_w_faces" => "kg m^-3",
    "density_weighted_turbulent_tke_flux" => "kg s^-3",
    "density_weighted_pressure_tke_flux" => "kg s^-3",
    "resolved_tke_turbulent_transport" => "m^2 s^-3",
    "resolved_tke_pressure_transport" => "m^2 s^-3",
    "resolved_tke_transport" => "m^2 s^-3", "sgs_tke_dissipation" => "m^2 s^-3",
    "sgs_resolved_kinetic_energy_dissipation" => "m^2 s^-3",
    "sgs_tke" => "m^2 s^-2",
)

const SERIES_UNITS = Dict(
    "lwp_mean" => "kg m^-2", "lwp_variance" => "kg^2 m^-4",
    "cloud_fraction" => "1", "cloud_base_valid_fraction" => "1",
    "cloud_base_mean" => "m", "cloud_base_variance" => "m^2",
    "q_t_8gkg_inversion_valid_fraction" => "1",
    "q_t_8gkg_inversion_height_mean" => "m",
    "q_t_8gkg_inversion_height_variance" => "m^2",
    "theta_li_295_inversion_valid_fraction" => "1",
    "theta_li_295_inversion_height_mean" => "m",
    "theta_li_295_inversion_height_variance" => "m^2",
    "radiation_nearest_q_t_inversion_height_mean" => "m",
    "radiation_nearest_q_t_inversion_height_variance" => "m^2",
    "decoupling_delta_q_t" => "kg kg^-1",
    "resolved_tke_vertical_integral" => "m^3 s^-2",
    "resolved_tke_depth_mean" => "m^2 s^-2", "w_variance_max" => "m^2 s^-2",
    "friction_velocity" => "m s^-1", "convective_velocity_scale" => "m s^-1",
    "surface_drag_u_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_v_dynamic_flux" => "kg m^-1 s^-2",
    "surface_drag_u_kinematic_flux" => "m^2 s^-2",
    "surface_drag_v_kinematic_flux" => "m^2 s^-2",
    "surface_density_for_drag" => "kg m^-3", "surface_sgs_u_w_flux" => "m^2 s^-2",
    "surface_sgs_v_w_flux" => "m^2 s^-2",
    "surface_sgs_theta_li_flux" => "K m s^-1",
    "surface_sgs_q_t_flux" => "(kg kg^-1) m s^-1",
    "surface_sensible_heat_flux" => "W m^-2",
    "surface_latent_heat_flux" => "W m^-2", "surface_buoyancy_flux" => "m^2 s^-3",
    "sgs_tke_vertical_integral" => "m^3 s^-2",
)

const VARIABLE_DEFINITIONS = Dict(
    "w_variance" => "Horizontal second central moment of native vertical velocity on z faces.",
    "w_third_central_moment" => "Horizontal third central moment of native vertical velocity on z faces.",
    "w_center_variance" => "Horizontal second central moment after interpolating vertical velocity to centers.",
    "lwp_mean" => "Domain mean of column integral rho*q_l dz.",
    "cloud_fraction" => "Fraction of columns whose maximum q_l exceeds the configured cloud threshold.",
    "q_t_8gkg_inversion_height_mean" => "Mean linearly interpolated first downward q_t=8 g/kg crossing, conditioned on a valid crossing.",
    "theta_li_295_inversion_height_mean" => "Mean linearly interpolated first upward theta_li=295 K crossing, conditioned on a valid crossing.",
    "radiation_nearest_q_t_inversion_height_mean" => "Mean radiation-internal nearest-q_t inversion height; distinct from interpolated contours.",
    "resolved_tke" => "One half the horizontal mean of centered u, v, and center-interpolated w squared.",
    "turbulent_tke_flux" => "Raw resolved face flux <w' e'> for per-mass resolved TKE e.",
    "pressure_tke_flux" => "Raw resolved face flux <w' (p'/rho_r)'>.",
    "resolved_tke_turbulent_transport" => "Anelastic transport -rho_r^-1 d_z[rho_r <w' e'>].",
    "resolved_tke_pressure_transport" => "Anelastic pressure transport -rho_r^-1 d_z[rho_r <w' (p'/rho_r)'>].",
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
        error("Unsupported JSON value $(typeof(value))")
    end
end

function sha256_file(path)
    open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end

function csv_number(io, value)
    @printf(io, "%.9g", Float64(value))
end

function numeric_records(file)
    time_group = file["timeseries/t"]
    records = [(key=key, time=Float64(time_group[key])) for key in keys(time_group)]
    sort!(records; by=record -> record.time)
    return records
end

function output_names(file)
    return filter(!=("t"), String.(collect(keys(file["timeseries"]))))
end

function scalar_value(value, name, time)
    scalar = value isa Number ? value : length(value) == 1 ? only(value) :
             error("Series $name at $time is not scalar: size $(size(value))")
    isfinite(scalar) || error("Non-finite series value $name at $time")
    return Float64(scalar)
end

function profile_vector(value, Nz, name, time)
    value isa AbstractArray || error("Profile $name at $time is not an array")
    all(isfinite, value) || error("Non-finite profile $name at $time")
    z_length = size(value, ndims(value))
    z_length in (Nz, Nz + 1) ||
        error("Profile $name at $time has unexpected vertical length $z_length")

    horizontal_reduction = size(value, 1) != 1 || size(value, 2) != 1
    maximum_spread = 0.0
    if horizontal_reduction
        ndims(value) == 3 || error("Cannot horizontally reduce $(size(value)) for $name")
        for k in axes(value, 3)
            lo, hi = extrema(view(value, :, :, k))
            maximum_spread = max(maximum_spread, Float64(hi - lo))
        end
        profile = vec(dropdims(mean(value; dims=(1, 2)); dims=(1, 2)))
    else
        profile = vec(value)
    end
    return Float64.(profile), horizontal_reduction, maximum_spread
end

function profile_location(length, Nz)
    length == Nz && return "Center"
    length == Nz + 1 && return "Face"
    error("Cannot infer vertical location from length $length and Nz=$Nz")
end

function z_coordinates(location, grid)
    dz = grid.Lz / grid.Nz
    return location == "Center" ? [(k - 0.5) * dz for k in 1:grid.Nz] :
           [(k - 1.0) * dz for k in 1:grid.Nz+1]
end

function scheduler_finished(task)
    command = ignorestatus(`squeue -h -j $(ARRAY_JOB_ID)_$task -o %T`)
    state = try
        strip(read(pipeline(command; stderr=devnull), String))
    catch
        return false
    end
    return isempty(state)
end

function completion_ready(case, task)
    log_path = joinpath(PRODUCTION_ROOT, "dycoms-$(ARRAY_JOB_ID)_$(task).log")
    isfile(log_path) || return false, "no log"
    log = read(log_path, String)
    occursin("CASE_DONE $case ", log) || return false, "CASE_DONE absent"
    occursin("DYCOMS_CASE_EXIT_SUCCESS", log) || return false, "success sentinel absent"
    scheduler_finished(task) || return false, "scheduler task still active"
    return true, "complete"
end

function finite_difference(times, values)
    derivative = similar(values)
    derivative[1] = (values[2] - values[1]) / (times[2] - times[1])
    for n in 2:length(times)-1
        dt_previous = times[n] - times[n-1]
        dt_next = times[n+1] - times[n]
        backward = (values[n] - values[n-1]) / dt_previous
        forward = (values[n+1] - values[n]) / dt_next
        derivative[n] = (dt_next * backward + dt_previous * forward) /
                        (dt_previous + dt_next)
    end
    derivative[end] = (values[end] - values[end-1]) / (times[end] - times[end-1])
    return derivative
end

function derivative_validity(valid_fraction)
    valid = valid_fraction .> 0
    stencil_valid = similar(valid)
    stencil_valid[1] = valid[1] && valid[2]
    for n in 2:length(valid)-1
        stencil_valid[n] = valid[n-1] && valid[n] && valid[n+1]
    end
    stencil_valid[end] = valid[end-1] && valid[end]
    return stencil_valid
end

function export_case(case, task, destination)
    grid_name = first(split(case, '_'))
    grid = GRID_SPECS[grid_name]
    run_dir = joinpath(PRODUCTION_ROOT, "runs", case)
    statistics_path = joinpath(run_dir, "$(case)_diag_statistics.jld2")
    series_path = joinpath(run_dir, "$(case)_diag_series.jld2")
    isfile(statistics_path) || error("Missing $statistics_path")
    isfile(series_path) || error("Missing $series_path")

    profile_information = Dict{String, Any}()
    series_information = Dict{String, Any}()
    statistics_metadata = Dict{String, Any}()
    series_metadata = Dict{String, Any}()
    profile_times = Float64[]
    series_times = Float64[]
    series_values = Dict{String, Vector{Float64}}()

    profiles_csv = joinpath(destination, "profiles.csv")
    fourth_hour_csv = joinpath(destination, "profiles_fourth_hour_long.csv")

    JLD2.jldopen(statistics_path, "r") do file
        records = numeric_records(file)
        profile_times = [record.time for record in records]
        profile_times == collect(0.0:1800.0:14400.0) ||
            error("Unexpected profile times for $case: $profile_times")
        names = output_names(file)
        length(names) == 46 || error("Expected 46 profiles for $case, found $(length(names))")
        for key in keys(file["metadata"])
            statistics_metadata[String(key)] = file["metadata/$key"]
        end

        record_12600 = only(filter(record -> record.time == 12600.0, records))
        record_14400 = only(filter(record -> record.time == 14400.0, records))

        open(profiles_csv, "w") do profiles_io
            open(fourth_hour_csv, "w") do fourth_io
                println(profiles_io, "variable,time_s,z_m,value,location,units,record_kind,window_start_s,window_end_s")
                println(fourth_io, "variable,window_start_s,window_end_s,z_m,value,location,units,source_times_s")

                for name in names
                    haskey(PROFILE_UNITS, name) || error("No profile unit registered for $name")
                    units = PROFILE_UNITS[name]
                    expected_shape = nothing
                    location = nothing
                    reduced = false
                    maximum_spread = 0.0
                    for record in records
                        value = file["timeseries/$name/$(record.key)"]
                        expected_shape === nothing && (expected_shape = collect(size(value)))
                        collect(size(value)) == expected_shape ||
                            error("Shape changed for $name at $(record.time)")
                        profile, was_reduced, spread = profile_vector(value, grid.Nz, name, record.time)
                        this_location = profile_location(length(profile), grid.Nz)
                        location === nothing && (location = this_location)
                        this_location == location || error("Location changed for $name")
                        reduced |= was_reduced
                        maximum_spread = max(maximum_spread, spread)
                        z = z_coordinates(location, grid)
                        record_kind = record.time == 0 ? "instantaneous_initial" : "preceding_1800s_average"
                        window_start = record.time == 0 ? 0.0 : record.time - 1800.0
                        window_end = record.time
                        for k in eachindex(profile)
                            print(profiles_io, name, ',', record.time, ',')
                            csv_number(profiles_io, z[k]); print(profiles_io, ',')
                            csv_number(profiles_io, profile[k])
                            println(profiles_io, ',', location, ',', units, ',', record_kind, ',',
                                    window_start, ',', window_end)
                        end
                    end

                    first_value = file["timeseries/$name/$(record_12600.key)"]
                    second_value = file["timeseries/$name/$(record_14400.key)"]
                    first_profile, _, _ = profile_vector(first_value, grid.Nz, name, 12600.0)
                    second_profile, _, _ = profile_vector(second_value, grid.Nz, name, 14400.0)
                    fourth_hour = (first_profile .+ second_profile) ./ 2
                    z = z_coordinates(location, grid)
                    for k in eachindex(fourth_hour)
                        print(fourth_io, name, ",10800.0,14400.0,")
                        csv_number(fourth_io, z[k]); print(fourth_io, ',')
                        csv_number(fourth_io, fourth_hour[k])
                        println(fourth_io, ',', location, ',', units, ",12600.0;14400.0")
                    end

                    profile_information[name] = Dict(
                        "units" => units,
                        "location" => location,
                        "source_shape" => expected_shape,
                        "export_vertical_length" => location == "Center" ? grid.Nz : grid.Nz + 1,
                        "export_time_records" => length(records),
                        "export_time_horizontal_mean_applied" => reduced,
                        "maximum_source_xy_spread" => maximum_spread,
                        "finite" => true,
                    )
                end
            end
        end
    end

    JLD2.jldopen(series_path, "r") do file
        records = numeric_records(file)
        series_times = [record.time for record in records]
        series_times == collect(0.0:60.0:14400.0) ||
            error("Unexpected series times for $case")
        names = output_names(file)
        length(names) == 32 || error("Expected 32 series for $case, found $(length(names))")
        for key in keys(file["metadata"])
            series_metadata[String(key)] = file["metadata/$key"]
        end

        for name in names
            haskey(SERIES_UNITS, name) || error("No series unit registered for $name")
            values = [scalar_value(file["timeseries/$name/$(record.key)"], name, record.time)
                      for record in records]
            series_values[name] = values
            first_value = file["timeseries/$name/$(first(records).key)"]
            series_information[name] = Dict(
                "units" => SERIES_UNITS[name],
                "source_shape" => collect(size(first_value)),
                "records" => length(records),
                "finite" => all(isfinite, values),
            )
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

    divergence = Float64(series_metadata["divergence"])
    q_t_height = series_values["q_t_8gkg_inversion_height_mean"]
    theta_height = series_values["theta_li_295_inversion_height_mean"]
    q_t_entrainment = finite_difference(series_times, q_t_height) .+ divergence .* q_t_height
    theta_entrainment = finite_difference(series_times, theta_height) .+ divergence .* theta_height
    q_t_valid = derivative_validity(series_values["q_t_8gkg_inversion_valid_fraction"])
    theta_valid = derivative_validity(series_values["theta_li_295_inversion_valid_fraction"])
    open(joinpath(destination, "entrainment.csv"), "w") do io
        println(io, "time_s,q_t_8gkg_entrainment_m_s,q_t_derivative_valid,theta_li_295_entrainment_m_s,theta_li_derivative_valid")
        for n in eachindex(series_times)
            print(io, series_times[n], ','); csv_number(io, q_t_entrainment[n])
            print(io, ',', q_t_valid[n], ','); csv_number(io, theta_entrainment[n])
            println(io, ',', theta_valid[n])
        end
    end

    dx, dy, dz = grid.Lx / grid.Nx, grid.Ly / grid.Ny, grid.Lz / grid.Nz
    manifest = Dict{String, Any}(
        "schema_version" => 1,
        "generated_utc" => string(Dates.now(Dates.UTC)),
        "case" => case,
        "array_job_id" => ARRAY_JOB_ID,
        "array_task_id" => task,
        "source_files" => Dict(
            "statistics" => relpath(statistics_path, PRODUCTION_ROOT),
            "statistics_sha256" => sha256_file(statistics_path),
            "series" => relpath(series_path, PRODUCTION_ROOT),
            "series_sha256" => sha256_file(series_path),
        ),
        "reader" => Dict(
            "julia_version" => string(VERSION),
            "project" => joinpath(PRODUCTION_ROOT, "source", "examples"),
            "exporter" => abspath(PROGRAM_FILE),
            "exporter_sha256" => sha256_file(abspath(PROGRAM_FILE)),
            "method" => "plain numeric JLD2 leaves only; serialized GPU grids and fields were not loaded",
        ),
        "frozen_source" => Dict(
            "diagnostics_sha256" => sha256_file(joinpath(PRODUCTION_ROOT, "source", "examples", "dycoms_diagnostics.jl")),
            "root_manifest_sha256" => sha256_file(joinpath(PRODUCTION_ROOT, "source", "Manifest.toml")),
            "runner_sha256" => sha256_file(joinpath(PRODUCTION_ROOT, "source", "validation_output", "dycoms", "factorial", "dycoms_case.jl")),
        ),
        "grid" => Dict(
            "Nx" => grid.Nx, "Ny" => grid.Ny, "Nz" => grid.Nz,
            "Lx_m" => grid.Lx, "Ly_m" => grid.Ly, "Lz_m" => grid.Lz,
            "dx_m" => dx, "dy_m" => dy, "dz_m" => dz,
            "topology" => ["Periodic", "Periodic", "Bounded"],
            "center_z_definition" => "z_m=(k-0.5)*dz_m, k=1:Nz",
            "face_z_definition" => "z_m=(k-1)*dz_m, k=1:Nz+1",
        ),
        "record_audit" => Dict(
            "profiles" => Dict("variables" => length(profile_information),
                               "records" => length(profile_times),
                               "times_s" => profile_times, "final_time_s" => last(profile_times),
                               "all_finite" => all(info["finite"] for info in values(profile_information))),
            "series" => Dict("variables" => length(series_information),
                             "records" => length(series_times),
                             "first_time_s" => first(series_times), "final_time_s" => last(series_times),
                             "interval_s" => 60.0,
                             "all_finite" => all(info["finite"] for info in values(series_information))),
        ),
        "profile_record_semantics" => Dict(
            "t0" => "instantaneous initial profile",
            "positive_times" => "true average over the preceding 1800 seconds",
            "fourth_hour" => "equal mean of t=12600 and t=14400 records, representing 10800-14400 s; t=10800 excluded",
            "fourth_hour_source_times_s" => [12600.0, 14400.0],
        ),
        "export_files" => Dict(
            "series.csv" => "All 32 instantaneous reduced series; one row per minute including t=0.",
            "profiles.csv" => "All 46 profiles at all nine records with native Center/Face coordinates.",
            "profiles_fourth_hour_long.csv" => "True fourth-hour profiles from the two non-overlapping 30-minute records.",
            "entrainment.csv" => "Derived E=dz_i/dt+D*z_i for both independently diagnosed inversion heights.",
        ),
        "output_sha256" => Dict(
            "series.csv" => sha256_file(joinpath(destination, "series.csv")),
            "profiles.csv" => sha256_file(joinpath(destination, "profiles.csv")),
            "profiles_fourth_hour_long.csv" => sha256_file(joinpath(destination, "profiles_fourth_hour_long.csv")),
            "entrainment.csv" => sha256_file(joinpath(destination, "entrainment.csv")),
        ),
        "statistics_metadata" => statistics_metadata,
        "series_metadata" => series_metadata,
        "profile_variables" => profile_information,
        "series_variables" => series_information,
        "diagnostic_definitions" => VARIABLE_DEFINITIONS,
        "export_notes" => [
            "Five budget terms can be stored as horizontally replicated 3-D arrays; the exporter takes their horizontal mean and records source shape and maximum x-y spread per variable.",
            "Native w-face w_mean, w_variance, and w_third_central_moment are preserved separately from center-interpolated variants.",
            "Missing inversion contours and cloud-free columns must be interpreted using their exported valid-fraction series.",
            "TKE budget residuals are not exported or claimed as numerical dissipation.",
        ],
    )
    open(joinpath(destination, "manifest.json"), "w") do io
        write_json(io, manifest)
        println(io)
    end
    return nothing
end

mkpath(EXPORT_ROOT)
exported = String[]
skipped = String[]
for (task, case) in enumerate(CASES)
    ready, reason = completion_ready(case, task)
    if !ready
        push!(skipped, "$case ($reason)")
        continue
    end
    final_destination = joinpath(EXPORT_ROOT, case)
    if isfile(joinpath(final_destination, "manifest.json"))
        push!(skipped, "$case (already exported)")
        continue
    end
    ispath(final_destination) && error("Incomplete destination already exists: $final_destination")
    temporary_destination = mktempdir(EXPORT_ROOT; prefix=".$case-")
    try
        export_case(case, task, temporary_destination)
        mv(temporary_destination, final_destination)
        push!(exported, case)
        println("EXPORTED ", case, " -> ", final_destination)
    catch
        rm(temporary_destination; recursive=true, force=true)
        rethrow()
    end
end

println("EXPORT_SUMMARY exported=", length(exported), " skipped=", length(skipped))
for item in skipped
    println("SKIP ", item)
end
