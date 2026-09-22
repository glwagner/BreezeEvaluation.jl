module NeutralScientificExport

export finalize_neutral_attempts, export_neutral_case, collect_neutral_exports,
       audit_neutral_raw, scalar_leaf

using Dates
using JLD2
using Printf
using SHA
using TOML

include("SurfaceLayerScientificExport.jl")
using .SurfaceLayerScientificExport
const Common = SurfaceLayerScientificExport

const CORE = "/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647"
const CORE_SHA = "d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c"
const REGISTRY_RELATIVE = "cases/surface_layer/neutral/neutral_sld_2case.toml"
const REGISTRY_SHA = "5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156"
const WRAPPER_V1_SHA = "3bb1dfc34e4288604aaaad1c23cd828964a7e2f5917d88297cc27b99dafbceae"
const WRAPPER_V2_SHA = "68ac700978b8c83a25b18648a7f4e74c0ef205443452f6ee6bbfa54811f5e268"
const GATE_READER = "/shared/home/greg/review-coordination/admit_neutral_saved_output_7366-v4.jl"
const GATE_READER_SHA = "f5b57980bb076f4304bc908c15e334d5acceb2e71896fdd698bc8c276bb08b36"
const SAVED_ADMISSION_READER_SHA = "8be6bf7c7409f22607ebedf49ab0caac8c6e47453a3f5528ff98cdc977895450"
const SUPPLEMENT = "/shared/home/greg/review-coordination/neutral-speed-gate-7366-saved-output-audit-v4-20260922"
const SUPPLEMENT_SHA = "c3c44a8a6c71a5b8e0166dc26477e18ab823c708d75faabe0b367ba8a13bec7c"
const COMBINED_SHA = "55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02"
const ORIGINAL_JOB_ID = "7367"
const ORIGINAL_CAMPAIGN = "/shared/home/greg/review-coordination/neutral-sld-science-20260922-0718"
const CASE_IDS = ("neutral_n096_weno9_control", "neutral_n096_weno9_surface_layer_t300_s1")
const PROFILE_TIMES = collect(600.0:600.0:18000.0)
const SERIES_TIMES = collect(0.0:60.0:18000.0)
const CHECKPOINT_TIMES = collect(0.0:3600.0:18000.0)
const FINAL_HOUR_TIMES = collect(15000.0:600.0:18000.0)
const PENULTIMATE_HOUR_TIMES = collect(11400.0:600.0:14400.0)
const SOURCE_PAIRS = (
    "neutral_abl_case.jl" => "cases/surface_layer/neutral/neutral_abl_case.jl",
    "NeutralSurfaceLayerDiagnostics.jl" => "cases/surface_layer/neutral/NeutralSurfaceLayerDiagnostics.jl",
    "SurfaceLayerDiagnostics.jl" => "cases/surface_layer/diagnostics/SurfaceLayerDiagnostics.jl",
    "LegacyGABLSDiagnosticsAdaptation.jl" => "cases/surface_layer/diagnostics/LegacyGABLSDiagnosticsAdaptation.jl",
    "gabls_diagnostics.jl" => "source_snapshots/gabls1/original/source/examples/gabls_diagnostics.jl",
    "gabls_rough_wall_coefficient.jl" => "source_snapshots/gabls1/original/source/src/BoundaryConditions/gabls_rough_wall_coefficient.jl",
    "neutral_atmospheric_boundary_layer.jl" => "Breeze:examples/neutral_atmospheric_boundary_layer.jl")

check(condition, message) = condition || error(message)
sha(path) = Common.file_sha256(path)
registry_path() = joinpath(CORE, "source", "BreezeEvaluation.jl", REGISTRY_RELATIVE)
project_path() = joinpath(CORE, "source", "BreezeEvaluation.jl", "cases/gabls3/runner")

function verify_frozen_inputs()
    check(isfile(registry_path()) && sha(registry_path()) == REGISTRY_SHA,
          "neutral canonical registry changed")
    entries = Common.verify_hash_manifest(CORE, joinpath(CORE, "source_sha256.txt");
                                          expected_sha=CORE_SHA)
    check(entries == 761, "neutral frozen source count differs")
    check(isfile(GATE_READER) && sha(GATE_READER) == GATE_READER_SHA,
          "supplemental admission reader changed")
    check(sha(joinpath(SUPPLEMENT, "neutral_saved_output_audit_evidence.toml")) ==
          SUPPLEMENT_SHA, "supplemental evidence changed")
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(project_path()) $GATE_READER`
    check(occursin("NEUTRAL_SAVED_OUTPUT_ADMITTED", read(cmd, String)),
          "saved-output GPU gate not admitted")
    return TOML.parsefile(registry_path())
end

function verify_launch_identity(campaign, job_id, wrapper_path, wrapper_sha)
    campaign = abspath(campaign)
    check(isabspath(campaign) && startswith(campaign,
          "/shared/home/greg/review-coordination/neutral-sld-science-"),
          "neutral campaign root is outside the reviewed namespace")
    check(all(isdigit, job_id) && !isempty(job_id) &&
          isfile(wrapper_path) && sha(wrapper_path) == wrapper_sha,
          "array job or launch-wrapper hash differs")
    if job_id == ORIGINAL_JOB_ID
        check(campaign == ORIGINAL_CAMPAIGN && wrapper_sha == WRAPPER_V1_SHA,
              "7367 identity differs")
    else
        check(campaign != ORIGINAL_CAMPAIGN && wrapper_sha == WRAPPER_V2_SHA,
              "replacement must use distinct campaign and portable v2 wrapper")
    end
    submission = joinpath(campaign, "metadata", "submission_job_id.txt")
    check(isfile(submission) && strip(read(submission, String)) == job_id,
          "campaign submission job ID differs")
    return true
end

function scalar_leaf(raw, name)
    raw isa Number && return Float64(raw)
    raw isa AbstractArray && length(raw) == 1 && return Float64(only(raw))
    error("$name must be a numeric scalar or singleton array")
end

function records(file, expected, label)
    actual = Common.numeric_records(file)
    Common.exact_times([record.time for record in actual], expected, label)
    return actual
end

function coordinates(file, label)
    center = Float64.(file["coordinates/z_center_m"])
    face = Float64.(file["coordinates/z_face_m"])
    check(length(center) == 96 && length(face) == 97, "$label coordinate lengths differ")
    # The frozen GPU grid stores these native coordinates in Float32.
    check(all(isapprox.(center, Common.z_coordinates("Center", 96, 1000); atol=1e-4, rtol=0)),
          "$label center heights differ")
    check(all(isapprox.(face, Common.z_coordinates("Face", 96, 1000); atol=1e-4, rtol=0)),
          "$label face heights differ")
    check(file["coordinates/native_w_moment_location"] == "Face",
          "$label native-w location differs")
    return Dict("z_center_m" => center, "z_face_m" => face)
end

function profile_unit(name)
    name == "averaging_interval_midpoint_time_seconds" && return "s"
    name in ("u_vertical_gradient", "v_vertical_gradient") && return "s^-1"
    name == "theta_vertical_gradient" && return "K m^-1"
    return Common.profile_unit(name)
end

function series_unit(name)
    name == "prescribed_friction_velocity" && return "m s^-1"
    name == "prescribed_kinematic_stress_magnitude" && return "m^2 s^-2"
    name == "prescribed_surface_heat_flux" && return "K m s^-1"
    return Common.series_unit(name)
end

function read_profiles(path, expected, kind)
    data = Dict{String, Dict{Float64, Vector{Float64}}}()
    information = Dict{String, Any}()
    midpoint = Dict{Float64, Float64}()
    metadata = Dict{String, Any}()
    native_coordinates = Dict{String, Any}()
    record_list = NamedTuple[]
    jldopen(path, "r") do file
        record_list = records(file, expected, basename(path))
        native_coordinates = coordinates(file, basename(path))
        metadata = Common.metadata_dictionary(file)
        check(metadata["diagnostic_kind"] == kind, "$kind metadata differs")
        names = Common.output_names(file)
        check("averaging_interval_midpoint_time_seconds" in names,
              "missing averaging midpoint diagnostic")
        for record in record_list
            raw = file["timeseries/averaging_interval_midpoint_time_seconds/$(record.key)"]
            midpoint[record.time] = scalar_leaf(raw, "averaging midpoint")
            check(isfinite(midpoint[record.time]), "nonfinite averaging midpoint")
        end
        for name in names
            name == "averaging_interval_midpoint_time_seconds" && continue
            units = profile_unit(name)
            series = Dict{Float64, Vector{Float64}}()
            shape = nothing
            element_type = nothing
            location = nothing
            maximum_spread = 0.0
            horizontally_reduced = false
            for record in record_list
                raw = file["timeseries/$name/$(record.key)"]
                this_shape = collect(size(raw))
                this_type = string(eltype(raw))
                shape === nothing && (shape = this_shape; element_type = this_type)
                check(this_shape == shape && this_type == element_type,
                      "$name raw shape/type changes")
                profile, reduced, spread = Common.profile_vector(raw, 96, name, record.time)
                this_location = Common.profile_location(length(profile), 96)
                location === nothing && (location = this_location)
                check(this_location == location, "$name stagger changes")
                series[record.time] = profile
                horizontally_reduced |= reduced
                maximum_spread = max(maximum_spread, spread)
            end
            data[name] = series
            information[name] = Dict("units" => units, "location" => location,
                                     "source_shape" => shape, "raw_element_type" => element_type,
                                     "records" => length(record_list), "all_finite" => true,
                                     "horizontal_mean_applied_during_export" => horizontally_reduced,
                                     "maximum_source_xy_spread" => maximum_spread)
        end
    end
    return (; records=record_list, data, information, midpoint, metadata,
            native_coordinates)
end

function read_series(path, expected)
    values = Dict{String, Vector{Float64}}()
    information = Dict{String, Any}()
    record_list = NamedTuple[]
    metadata = Dict{String, Any}()
    native_coordinates = Dict{String, Any}()
    jldopen(path, "r") do file
        record_list = records(file, expected, basename(path))
        native_coordinates = coordinates(file, basename(path))
        metadata = Common.metadata_dictionary(file)
        check(metadata["diagnostic_kind"] == "instantaneous_reduced_series",
              "series diagnostic-kind metadata differs")
        for name in Common.output_names(file)
            unit = series_unit(name)
            values[name] = Float64[]
            shape = nothing
            element_type = nothing
            for record in record_list
                raw = file["timeseries/$name/$(record.key)"]
                this_shape = raw isa Number ? Int[] : collect(size(raw))
                this_type = string(raw isa Number ? typeof(raw) : eltype(raw))
                shape === nothing && (shape = this_shape; element_type = this_type)
                check(this_shape == shape && this_type == element_type,
                      "$name series shape/type changes")
                value = scalar_leaf(raw, name)
                check(isfinite(value), "$name series has nonfinite value")
                push!(values[name], value)
            end
            information[name] = Dict("units" => unit, "records" => length(record_list),
                                     "source_shape" => shape, "raw_element_type" => element_type,
                                     "all_finite" => true)
        end
    end
    return (; records=record_list, values, information, metadata, native_coordinates)
end

function write_native_profiles(io, source, record_kind, window_seconds)
    for record in source.records
        for name in sort!(collect(keys(source.data)))
            information = source.information[name]
            coordinate_key = information["location"] == "Face" ? "z_face_m" : "z_center_m"
            heights = source.native_coordinates[coordinate_key]
            values = source.data[name][record.time]
            check(length(values) == length(heights), "$name native-height length differs")
            for index in eachindex(values)
                @printf(io, "%.17g,%.17g,%s,%.17g,%s,%s,%s,%.17g,%.17g\n",
                        record.time, heights[index], name, values[index],
                        information["location"], information["units"], record_kind,
                        record.time - window_seconds, record.time)
            end
        end
    end
end

function write_native_profiles(path, initial, averaged)
    open(path, "w") do io
        println(io, "time_s,z_m,variable,value,location,units,record_kind,window_start_s,window_end_s")
        write_native_profiles(io, initial, "instantaneous_initial", 0.0)
        write_native_profiles(io, averaged, "preceding_600s_average", 600.0)
    end
end

function write_native_hour(path, source, times, label, window_start, window_end)
    open(path, "w") do io
        println(io, "time_s,z_m,variable,value,location,units,record_kind,window_start_s,window_end_s,source_times_s")
        for name in sort!(collect(keys(source.data)))
            information = source.information[name]
            coordinate_key = information["location"] == "Face" ? "z_face_m" : "z_center_m"
            heights = source.native_coordinates[coordinate_key]
            values = reduce(+, (source.data[name][time] for time in times)) ./ length(times)
            for index in eachindex(values)
                @printf(io, "%.17g,%.17g,%s,%.17g,%s,%s,%s,%.17g,%.17g,%s\n",
                        window_end, heights[index], name, values[index],
                        information["location"], information["units"], label,
                        window_start, window_end, join(times, ';'))
            end
        end
    end
end

function compare_initial_and_statistics(initial, statistics; averaging_window=600.0)
    check(Set(keys(initial.data)) == Set(keys(statistics.data)),
          "initial/averaged variable sets differ")
    for name in keys(initial.data)
        check(initial.information[name]["location"] == statistics.information[name]["location"],
              "$name initial/average locations differ")
        check(initial.information[name]["source_shape"] == statistics.information[name]["source_shape"],
              "$name initial/average shapes differ")
    end
    check(initial.midpoint[0.0] == 0.0, "instantaneous initial midpoint differs")
    check(initial.native_coordinates == statistics.native_coordinates,
          "initial/averaged native coordinates differ")
    for time in keys(statistics.midpoint)
        # This output integrates t-Δt/2 over the same 600 s averaging window.
        check(abs(statistics.midpoint[time] - (time - averaging_window / 2)) <= 0.01,
              "averaged midpoint differs at $time")
    end
end

function check_fluxes(profiles, series, closure;
                      profile_times=PROFILE_TIMES, series_times=SERIES_TIMES)
    needed = ("resolved_u_w_flux", "resolved_v_w_flux", "resolved_w_theta_flux",
              "sgs_u_w_flux", "sgs_v_w_flux", "sgs_w_theta_flux",
              "total_u_w_flux", "total_v_w_flux", "total_w_theta_flux",
              "w_variance", "w_third_central_moment", "theta_mean", "u_mean")
    for name in needed
        check(haskey(profiles.data, name), "missing required profile $name")
    end
    for name in ("prescribed_friction_velocity", "prescribed_kinematic_stress_magnitude",
                 "prescribed_surface_heat_flux", "surface_theta_kinematic_flux")
        check(haskey(series.values, name), "missing required series $name")
    end
    max_first_sgs = 0.0
    max_viscosity = 0.0
    max_theta_sgs = 0.0
    max_guard = 0.0
    maximum_split_residual = 0.0
    wall_stress_range = [Inf, -Inf]
    for time in profile_times
        wall_squared = 0.0
        for component in ("u", "v", "theta")
            names = component == "theta" ?
                ("resolved_w_theta_flux", "sgs_w_theta_flux", "total_w_theta_flux") :
                ("resolved_$(component)_w_flux", "sgs_$(component)_w_flux",
                 "total_$(component)_w_flux")
            resolved, sgs, total = (profiles.data[name][time] for name in names)
            check(length(resolved) == length(sgs) == length(total) == 97,
                  "$component flux has non-face shape")
            residual = maximum(abs.(total[2:end] .- resolved[2:end] .- sgs[2:end]))
            scale = max(1.0, maximum(abs.(total)), maximum(abs.(resolved)), maximum(abs.(sgs)))
            check(residual <= 5e-6 * scale, "$component interior flux split differs at $time")
            maximum_split_residual = max(maximum_split_residual, residual)
            if component == "theta"
                check(abs(total[1]) <= 1e-7, "neutral bottom heat flux is nonzero")
                max_theta_sgs = max(max_theta_sgs, maximum(abs.(sgs)))
            else
                wall_squared += total[1]^2
                max_first_sgs = max(max_first_sgs, abs(sgs[2]))
                closure == "none" && check(all(iszero, sgs), "control SGS flux is nonzero")
            end
        end
        wall = sqrt(wall_squared)
        # The wall law fixes the magnitude locally. Horizontal/time averaging
        # of the vector can reduce its magnitude when stress directions differ.
        check(wall <= 0.255, "mean wall-stress vector exceeds fixed local ustar=0.5 at $time")
        wall_stress_range[1] = min(wall_stress_range[1], wall)
        wall_stress_range[2] = max(wall_stress_range[2], wall)
        if closure == "surface_layer"
            viscosity = profiles.data["surface_layer_viscosity"][time]
            max_viscosity = max(max_viscosity, viscosity[2])
            check(all(isfinite, viscosity) && all(x -> x >= 0, viscosity),
                  "SLD viscosity has invalid values")
            check(all(iszero, viscosity[3:end]),
                  "one-face SLD viscosity extends beyond its supported face")
            for tracer in ("ρθ", "ρqᵛ")
                diffusivity = profiles.data["surface_layer_diffusivity_$tracer"][time]
                check(maximum(abs.(diffusivity)) <= 1e-6,
                      "zero-flux neutral scalar diffusivity is active")
            end
        end
    end
    for (index, time) in enumerate(series_times)
        check(series.values["prescribed_friction_velocity"][index] == 0.5 &&
              series.values["prescribed_kinematic_stress_magnitude"][index] == 0.25 &&
              series.values["prescribed_surface_heat_flux"][index] == 0.0,
              "prescribed fixed-stress/zero-heat series differs at $time")
        check(abs(series.values["surface_theta_kinematic_flux"][index]) <= 1e-7,
              "actual wall heat flux differs from zero at $time")
        drag_u = series.values["surface_drag_u_kinematic_flux"][index]
        drag_v = series.values["surface_drag_v_kinematic_flux"][index]
        mean_stress = hypot(drag_u, drag_v)
        check(mean_stress <= 0.2501, "mean instantaneous stress exceeds fixed local magnitude")
        check(abs(series.values["friction_velocity"][index] - sqrt(mean_stress)) <= 1e-5,
              "diagnosed friction velocity differs from mean stress vector")
        if closure == "surface_layer"
            for face in 1:2, tracer in ("ρθ", "ρqᵛ")
                key = "surface_layer_face$(face)_$(tracer)_active_fraction"
                max_guard = max(max_guard, abs(series.values[key][index]))
            end
        end
    end
    closure == "none" && check(max_first_sgs == 0 && max_theta_sgs == 0,
                               "control has SGS flux")
    closure == "surface_layer" && check(max_first_sgs > 1e-10 && max_viscosity > 0 &&
                                         max_guard == 0 && max_theta_sgs <= 1e-6,
                                         "SLD supported momentum or zero-flux scalar guard differs")
    return Dict("wall_stress_magnitude_min_m2_s2" => wall_stress_range[1],
                "wall_stress_magnitude_max_m2_s2" => wall_stress_range[2],
                "wall_stress_is_magnitude_of_averaged_vector" => true,
                "prescribed_stress_is_local_magnitude_m2_s2" => 0.25,
                "maximum_interior_flux_split_residual" => maximum_split_residual,
                "maximum_first_supported_sgs_stress_m2_s2" => max_first_sgs,
                "maximum_first_supported_viscosity_m2_s" => max_viscosity,
                "maximum_theta_sgs_flux_K_m_s" => max_theta_sgs,
                "maximum_scalar_guard_active_fraction" => max_guard)
end

function check_state_bounds(path; expected_times=SERIES_TIMES)
    result = Dict{String, Any}()
    all_values = Dict{String, Vector{Float64}}()
    jldopen(path, "r") do file
        record_list = records(file, expected_times, basename(path))
        for name in ("theta_min", "theta_max", "max_u", "max_v", "max_w")
            check(name in Common.output_names(file), "missing state-bound $name")
            values = [scalar_leaf(file["timeseries/$name/$(record.key)"], name)
                      for record in record_list]
            check(all(isfinite, values), "nonfinite state-bound $name")
            all_values[name] = values
            result[name] = Dict("minimum" => minimum(values), "maximum" => maximum(values))
        end
    end
    check(all(all_values["theta_min"] .<= all_values["theta_max"]),
          "inverted per-record theta state bounds")
    for name in ("max_u", "max_v", "max_w")
        check(all(x -> x >= 0, all_values[name]), "$name absolute bound is negative")
    end
    return result
end

function check_checkpoints(run_directory, case_id; expected_times=CHECKPOINT_TIMES)
    prefix = case_id * "_checkpoint_iteration"
    paths = sort(filter(path -> startswith(basename(path), prefix) &&
                                 endswith(path, ".jld2"), readdir(run_directory; join=true)))
    check(length(paths) == length(expected_times),
          "checkpoint count $(length(paths)) differs from $(length(expected_times))")
    by_time = Dict{Float64, Dict{String, Any}}()
    for path in paths
        jldopen(path, "r") do file
            clock = file["simulation/model/clock"] # scalar clock only; never deserialize a GPU grid
            time = Float64(getproperty(clock, :time))
            iteration = Int(getproperty(clock, :iteration))
            check(isfinite(time) && iteration >= 0, "checkpoint clock invalid")
            check(!haskey(by_time, time), "duplicate checkpoint clock time")
            for name in ("ρu", "ρv", "ρw", "ρθ", "ρqᵛ")
                raw = file["simulation/model/fields/$name/data"]
                check(raw isa AbstractArray && all(isfinite, raw),
                      "checkpoint $name is missing/nonfinite at $time")
            end
            check(haskey(file, "simulation/model/closure_fields"),
                  "checkpoint closure state missing")
            by_time[time] = Dict("path" => abspath(path), "sha256" => sha(path),
                                 "iteration" => iteration, "time_s" => time,
                                 "prognostic_arrays_finite" => true)
        end
    end
    Common.exact_times(sort!(collect(keys(by_time))), expected_times, "checkpoints")
    return [by_time[time] for time in sort!(collect(keys(by_time)))]
end

function verify_provenance(run_directory, case_id, canonical)
    provenance = joinpath(run_directory, "provenance")
    check(isdir(provenance), "missing run provenance")
    check(sha(joinpath(provenance, "source_snapshot_sha256.txt")) == CORE_SHA,
          "captured source manifest differs")
    text = read(joinpath(provenance, "source_snapshot.txt"), String)
    check(occursin(CORE, text) && occursin(CORE_SHA, text) &&
          occursin("source_manifest_entries: 761", text), "source provenance differs")
    run = read(joinpath(provenance, "run.txt"), String)
    check(occursin("case_id: $case_id", run) && occursin("fixture: false", run) &&
          occursin("architecture: CUDAGPU", run) && occursin("stop_time: 18000.0", run) &&
          occursin("profile_interval: 600.0", run) &&
          occursin("series_interval: 60.0", run) &&
          occursin("checkpoint_interval: 3600.0", run) &&
          occursin("seed: 1994", run), "captured run settings differ")
    for digest in values(canonical["paired_initial_state_sha256"])
        check(occursin(digest, run), "paired initial digest missing from run provenance")
    end
    evaluation = joinpath(CORE, "source", "BreezeEvaluation.jl")
    checked = Dict{String, String}()
    for (captured, relative) in SOURCE_PAIRS
        frozen = startswith(relative, "Breeze:") ?
            joinpath(CORE, "source", "Breeze.jl", relative[8:end]) :
            joinpath(evaluation, relative)
        check(isfile(frozen) && sha(joinpath(provenance, captured)) == sha(frozen),
              "captured source differs: $captured")
        checked[captured] = sha(frozen)
    end
    for (captured, frozen) in (("active.Project.toml", joinpath(project_path(), "Project.toml")),
                               ("active.Manifest.toml", joinpath(project_path(), "Manifest.toml")),
                               ("Breeze.Project.toml", joinpath(CORE, "source/Breeze.jl/Project.toml")),
                               ("Breeze.Manifest.toml", joinpath(CORE, "source/Breeze.jl/Manifest.toml")))
        check(sha(joinpath(provenance, captured)) == sha(frozen),
              "captured environment differs: $captured")
        checked[captured] = sha(frozen)
    end
    return checked
end

function raw_paths(run_directory, case_id)
    prefix = joinpath(run_directory, case_id)
    return Dict("initial" => prefix * "_diag_initial.jld2",
                "profiles" => prefix * "_diag_statistics.jld2",
                "series" => prefix * "_diag_series.jld2",
                "state_bounds" => prefix * "_state_bounds.jld2")
end

function audit_neutral_raw(run_directory, case_id, closure; check_all_checkpoints=true)
    paths = raw_paths(run_directory, case_id)
    for path in values(paths)
        check(isfile(path), "missing raw neutral writer: $path")
    end
    initial = read_profiles(paths["initial"], [0.0], "instantaneous_initial_profile")
    profiles = read_profiles(paths["profiles"], PROFILE_TIMES, "true_time_averaged_profiles")
    series = read_series(paths["series"], SERIES_TIMES)
    compare_initial_and_statistics(initial, profiles)
    check(profiles.native_coordinates == series.native_coordinates,
          "profile/series native coordinates differ")
    check(profiles.metadata["averaging_window_seconds"] == 600 &&
          profiles.metadata["output_interval_seconds"] == 600 &&
          profiles.metadata["expected_profile_record_count"] == 30 &&
          Float64.(profiles.metadata["expected_profile_times_seconds"]) == PROFILE_TIMES,
          "averaged profile window metadata differs")
    check(series.metadata["output_interval_seconds"] == 60,
          "series interval metadata differs")
    closure_available = get(profiles.metadata, "surface_layer_diffusivity_available", false)
    check(closure_available === (closure == "surface_layer"),
          "SLD metadata availability differs from closure")
    if closure == "surface_layer"
        check(profiles.metadata["surface_layer_support_faces"] == 1,
              "SLD support differs from one face")
    end
    check(profiles.information["w_variance"]["location"] == "Face" &&
          profiles.information["w_third_central_moment"]["location"] == "Face",
          "native w moments are not on faces")
    physics = check_fluxes(profiles, series, closure)
    state_bounds = check_state_bounds(paths["state_bounds"])
    checkpoints = check_all_checkpoints ? check_checkpoints(run_directory, case_id) : []
    hashes = Dict(name => sha(path) for (name, path) in paths)
    return (; initial, profiles, series, physics, state_bounds, checkpoints,
            raw_paths=paths, raw_sha256=hashes)
end

function parse_fields(path)
    fields = Dict{String, String}()
    for line in eachline(path)
        key, value = split(line, '='; limit=2)
        fields[key] = value
    end
    return fields
end

function verify_completion_identity(started, done, exited, case_id, index;
                                    job_id=ORIGINAL_JOB_ID,
                                    wrapper_sha=WRAPPER_V1_SHA)
    check(started["case_id"] == case_id && started["registry"] == registry_path() &&
          started["registry_index"] == string(index) &&
          started["array_job_id"] == job_id && started["fixture"] == "false" &&
          started["source_manifest_sha256"] == CORE_SHA &&
          started["gpu_gate_combined_sha256"] == COMBINED_SHA &&
          started["supplemental_saved_output_sha256"] == SUPPLEMENT_SHA &&
          started["wrapper_sha256"] == wrapper_sha,
          "ATTEMPT_STARTED identity differs")
    check(done["case_id"] == case_id &&
          isapprox(parse(Float64, done["final_time_s"]), 18000; atol=1e-5, rtol=0),
          "CASE_DONE identity/final time differs")
    check(exited["schema_version"] == "1" && exited["array_job_id"] == job_id &&
          exited["task_id"] == string(index) && exited["case_id"] == case_id &&
          exited["child_exit_code"] == "0" && exited["record_complete"] == "true" &&
          exited["wrapper_sha256"] == wrapper_sha &&
          exited["source_manifest_sha256"] == CORE_SHA &&
          exited["supplemental_saved_output_sha256"] == SUPPLEMENT_SHA,
          "durable child-exit identity differs")
    return true
end

function verify_attempt(campaign, index, canonical, job_id, wrapper_sha)
    case = canonical["cases"][index]
    case_id = case["case_id"]
    check(case_id == CASE_IDS[index], "canonical case/index differs")
    run_directory = joinpath(campaign, "runs", case_id)
    log_path = joinpath(campaign, "logs", "neutral_$(job_id)_$index.out")
    exit_path = joinpath(campaign, "logs", "neutral_$(job_id)_$index.exit")
    for path in (joinpath(run_directory, "ATTEMPT_STARTED"),
                 joinpath(run_directory, "CASE_DONE"), log_path, exit_path)
        check(isfile(path), "incomplete neutral attempt: missing $path")
    end
    check(!ispath(joinpath(run_directory, "CASE_FAILED")), "CASE_FAILED present")
    started = parse_fields(joinpath(run_directory, "ATTEMPT_STARTED"))
    done = parse_fields(joinpath(run_directory, "CASE_DONE"))
    exited = parse_fields(exit_path)
    verify_completion_identity(started, done, exited, case_id, index;
                               job_id, wrapper_sha)
    log = read(log_path, String)
    check(!occursin("CASE_FAILED", log) &&
          occursin("NEUTRAL_RECORDED_CHILD_EXIT job=$job_id task=$index case=$case_id code=0 record=$exit_path", log),
          "active case log does not show durable success")
    provenance = verify_provenance(run_directory, case_id, canonical)
    return Dict("case_id" => case_id, "registry_index" => index,
                "closure" => case["closure"], "run_directory" => run_directory,
                "log_path" => log_path, "exit_path" => exit_path,
                "log_sha256" => sha(log_path), "exit_sha256" => sha(exit_path),
                "attempt_started_sha256" => sha(joinpath(run_directory, "ATTEMPT_STARTED")),
                "case_done_sha256" => sha(joinpath(run_directory, "CASE_DONE")),
                "captured_source_sha256" => provenance)
end

function finalize_neutral_attempts(campaign, job_id, wrapper_path, destination)
    check(!ispath(destination), "refusing to overwrite finalized registry")
    campaign = abspath(campaign)
    wrapper_path = abspath(wrapper_path)
    wrapper_sha = sha(wrapper_path)
    verify_launch_identity(campaign, job_id, wrapper_path, wrapper_sha)
    canonical = verify_frozen_inputs()
    check(canonical["expected_case_count"] == 2, "canonical pair count differs")
    attempts = [verify_attempt(campaign, index, canonical, job_id, wrapper_sha)
                for index in 1:2]
    for attempt in attempts
        audited = audit_neutral_raw(attempt["run_directory"], attempt["case_id"],
                                    attempt["closure"])
        attempt["raw_sha256"] = audited.raw_sha256
        attempt["checkpoint_records"] = audited.checkpoints
        attempt["physics_audit"] = audited.physics
    end
    registry = Dict{String, Any}(
        "schema_version" => 1, "mode" => "neutral_five_hour_scientific_pair",
        "admission_mode" => "durable_zero_exit_v1",
        "array_job_id" => job_id, "campaign_root" => campaign,
        "generated_utc" => string(now(UTC)), "expected_cases" => 2,
        "source_root" => CORE, "source_manifest_sha256" => CORE_SHA,
        "canonical_registry_path" => registry_path(), "canonical_registry_sha256" => REGISTRY_SHA,
        "wrapper_path" => wrapper_path, "wrapper_sha256" => wrapper_sha,
        "supplemental_gate_reader_sha256" => GATE_READER_SHA,
        "supplemental_gate_evidence_sha256" => SUPPLEMENT_SHA,
        "combined_gpu_evidence_sha256" => COMBINED_SHA,
        "original_7366_parent_passed" => false,
        "profiles_expected_times_s" => PROFILE_TIMES,
        "series_expected_times_s" => SERIES_TIMES,
        "checkpoint_expected_times_s" => CHECKPOINT_TIMES,
        "attempts" => attempts)
    mkpath(dirname(destination))
    open(destination, "w") do io
        TOML.print(io, registry; sorted=true)
    end
    return registry
end

function load_finalized(path)
    registry = TOML.parsefile(path)
    check(registry["mode"] == "neutral_five_hour_scientific_pair" &&
          registry["source_root"] == CORE && registry["source_manifest_sha256"] == CORE_SHA &&
          registry["canonical_registry_sha256"] == REGISTRY_SHA &&
          registry["supplemental_gate_evidence_sha256"] == SUPPLEMENT_SHA &&
          registry["combined_gpu_evidence_sha256"] == COMBINED_SHA &&
          registry["original_7366_parent_passed"] === false &&
          registry["expected_cases"] == 2 && length(registry["attempts"]) == 2,
          "finalized neutral registry identity differs")
    campaign = registry["campaign_root"]
    job_id = registry["array_job_id"]
    wrapper_sha = registry["wrapper_sha256"]
    verify_launch_identity(campaign, job_id, registry["wrapper_path"], wrapper_sha)
    verify_frozen_inputs()
    admission_mode = registry["admission_mode"]
    if admission_mode == "durable_zero_exit_v1"
        canonical = TOML.parsefile(registry_path())
        for index in 1:2
            active = verify_attempt(campaign, index, canonical, job_id, wrapper_sha)
            stored = registry["attempts"][index]
            check(stored["case_id"] == active["case_id"] &&
                  stored["log_sha256"] == active["log_sha256"] &&
                  stored["exit_sha256"] == active["exit_sha256"] &&
                  stored["case_done_sha256"] == active["case_done_sha256"] &&
                  stored["attempt_started_sha256"] == active["attempt_started_sha256"],
                  "active attempt differs from finalized registry")
        end
    elseif admission_mode == "root_accepted_saved_scientific_output_v1"
        check(job_id == ORIGINAL_JOB_ID && campaign == ORIGINAL_CAMPAIGN &&
              wrapper_sha == WRAPPER_V1_SHA &&
              registry["original_7367_batch_success"] === false,
              "saved-science registry is not the original failed 7367 array")
        reader = joinpath(@__DIR__, "admit_neutral_saved_science.jl")
        check(sha(reader) == SAVED_ADMISSION_READER_SHA,
              "saved-science root-acceptance reader changed")
        check(sha(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl")) ==
              registry["saved_science_auditor_sha256"],
              "saved-science audit module differs from finalized registry")
        directory = registry["saved_science_evidence_directory"]
        evidence_path = joinpath(directory, "neutral_saved_science_audit.toml")
        check(sha(evidence_path) == registry["saved_science_evidence_sha256"] &&
              sha(registry["root_acceptance_path"]) == registry["root_acceptance_sha256"],
              "saved-science evidence or root acceptance hash differs")
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(project_path()) $reader $directory`
        check(occursin("NEUTRAL_SAVED_SCIENCE_ROOT_ACCEPTED", read(cmd, String)),
              "root did not admit saved scientific output")
        evidence = TOML.parsefile(evidence_path)
        check(length(evidence["attempts"]) == 2, "saved-science pair count differs")
        for index in 1:2
            audit = evidence["attempts"][index]
            stored = registry["attempts"][index]
            check(stored["case_id"] == audit["case_id"] &&
                  stored["raw_sha256"] == audit["raw_sha256"] &&
                  stored["checkpoint_records"] == audit["checkpoint_records"] &&
                  stored["log_sha256"] == audit["original_log_sha256"] &&
                  stored["exit_sha256"] == audit["original_exit_sha256"] &&
                  stored["case_failed_sha256"] == audit["original_case_failed_sha256"] &&
                  stored["original_batch_success"] === false,
                  "saved-science attempt differs from independent raw audit")
        end
    else
        error("unsupported neutral admission mode $admission_mode")
    end
    return registry
end

function export_neutral_case(finalized_path, case_id, export_root)
    registry = load_finalized(finalized_path)
    matches = filter(attempt -> attempt["case_id"] == case_id, registry["attempts"])
    check(length(matches) == 1, "unknown neutral case")
    attempt = only(matches)
    audited = audit_neutral_raw(attempt["run_directory"], case_id, attempt["closure"])
    check(audited.raw_sha256 == attempt["raw_sha256"], "raw writer hashes differ")
    check(audited.checkpoints == attempt["checkpoint_records"], "checkpoint hashes/clocks differ")
    destination = joinpath(abspath(export_root), case_id)
    check(!ispath(destination), "refusing to overwrite neutral export")
    mkpath(export_root)
    temporary = mktempdir(export_root; prefix=".$case_id-")
    try
        profile_path = joinpath(temporary, "profiles.csv")
        write_native_profiles(profile_path, audited.initial, audited.profiles)
        Common.write_wide_csv(joinpath(temporary, "series.csv"), audited.series.records,
            sort!(collect(keys(audited.series.values))), audited.series.values)
        write_native_hour(joinpath(temporary, "profiles_final_hour_long.csv"),
            audited.profiles, FINAL_HOUR_TIMES,
            "equal_mean_of_six_preceding_600s_averages", 14400.0, 18000.0)
        write_native_hour(joinpath(temporary, "profiles_penultimate_hour_long.csv"),
            audited.profiles, PENULTIMATE_HOUR_TIMES,
            "equal_mean_of_six_preceding_600s_averages", 10800.0, 14400.0)
        output_names = ("profiles.csv", "series.csv", "profiles_final_hour_long.csv",
                        "profiles_penultimate_hour_long.csv")
        manifest = Dict{String, Any}(
            "schema_version" => 1, "case_family" => "neutral_fixed_stress_ABL",
            "case_id" => case_id, "closure" => attempt["closure"],
            "export_verified" => true, "fixture_non_scientific" => false,
            "scientific_admission" => (registry["admission_mode"] ==
                "durable_zero_exit_v1" ? "passed_durable_zero_exit" :
                "passed_root_accepted_saved_output"),
            "admission_mode" => registry["admission_mode"],
            "original_7367_batch_success" => false,
            "active_batch_success" => registry["admission_mode"] == "durable_zero_exit_v1",
            "final_time_s" => 18000.0,
            "generated_utc" => string(now(UTC)),
            "grid" => Dict("Nx" => 96, "Ny" => 96, "Nz" => 96,
                "Lx_m" => 3000.0, "Ly_m" => 3000.0, "Lz_m" => 1000.0,
                "dx_m" => 3000 / 96, "dy_m" => 3000 / 96, "dz_m" => 1000 / 96,
                "center_z_definition" => "(k-0.5)*dz_m",
                "face_z_definition" => "(k-1)*dz_m"),
            "record_audit" => Dict(
                "profiles" => Dict("initial_records" => 1, "averaged_records" => 30,
                    "total_records" => 31, "initial_times_s" => [0.0],
                    "averaged_times_s" => PROFILE_TIMES, "all_finite" => true,
                    "variables" => length(audited.profiles.data)),
                "series" => Dict("records" => 301, "times_s" => SERIES_TIMES,
                    "variables" => length(audited.series.values), "all_finite" => true),
                "state_bounds" => Dict("records" => 301, "times_s" => SERIES_TIMES,
                    "all_finite" => true),
                "checkpoints" => Dict("records" => 6, "times_s" => CHECKPOINT_TIMES,
                    "prognostic_arrays_finite" => true)),
            "profile_record_semantics" => Dict(
                "initial" => "separate instantaneous profile at t=0",
                "positive_times" => "true non-overlapping preceding-600-second time averages",
                "averaging_quadrature" => "right-Riemann; separately audited midpoint clock",
                "final_hour_source_times_s" => FINAL_HOUR_TIMES,
                "penultimate_hour_source_times_s" => PENULTIMATE_HOUR_TIMES),
            "profile_variables" => audited.profiles.information,
            "series_variables" => audited.series.information,
            "native_coordinates" => audited.profiles.native_coordinates,
            "physics_audit" => audited.physics,
            "state_bounds_audit" => audited.state_bounds,
            "source_files" => Dict(name => Dict("path" => audited.raw_paths[name],
                                                "sha256" => digest)
                                   for (name, digest) in audited.raw_sha256),
            "checkpoint_files" => audited.checkpoints,
            "raw_metadata" => Dict("initial" => audited.initial.metadata,
                                   "profiles" => audited.profiles.metadata,
                                   "series" => audited.series.metadata),
            "provenance" => Dict("finalized_registry_path" => abspath(finalized_path),
                "finalized_registry_sha256" => sha(finalized_path),
                "active_attempt_id" => "$(registry["array_job_id"])_$(attempt["registry_index"])",
                "array_job_id" => registry["array_job_id"],
                "source_manifest_sha256" => CORE_SHA,
                "canonical_registry_sha256" => REGISTRY_SHA,
                "supplemental_gpu_gate_sha256" => SUPPLEMENT_SHA,
                "combined_gpu_gate_sha256" => COMBINED_SHA,
                "original_7366_parent_passed" => false,
                "saved_science_evidence_sha256" =>
                    get(registry, "saved_science_evidence_sha256", "not_applicable"),
                "root_acceptance_sha256" =>
                    get(registry, "root_acceptance_sha256", "not_applicable"),
                "durable_child_exit_sha256" => attempt["exit_sha256"],
                "captured_source_sha256" => attempt["captured_source_sha256"]),
            "output_sha256" => Dict(name => sha(joinpath(temporary, name)) for name in output_names))
        Common.write_manifests(temporary, manifest)
        mv(temporary, destination)
        return manifest
    catch
        rm(temporary; recursive=true, force=true)
        rethrow()
    end
end

function verify_export_directory(path, attempt, finalized_sha, job_id,
                                 admission_mode; saved_evidence_sha="not_applicable",
                                 root_acceptance_sha="not_applicable")
    manifest_path = joinpath(path, "manifest.toml")
    check(isfile(manifest_path), "neutral export manifest missing")
    manifest = TOML.parsefile(manifest_path)
    case_id = attempt["case_id"]
    check(manifest["case_id"] == case_id &&
          manifest["case_family"] == "neutral_fixed_stress_ABL" &&
          manifest["closure"] == attempt["closure"] &&
          manifest["export_verified"] === true &&
          manifest["fixture_non_scientific"] === false &&
          manifest["scientific_admission"] ==
              (admission_mode == "durable_zero_exit_v1" ?
               "passed_durable_zero_exit" : "passed_root_accepted_saved_output") &&
          manifest["admission_mode"] == admission_mode &&
          manifest["original_7367_batch_success"] === false &&
          manifest["active_batch_success"] ===
              (admission_mode == "durable_zero_exit_v1") &&
          manifest["final_time_s"] == 18000.0 &&
          manifest["provenance"]["finalized_registry_sha256"] == finalized_sha &&
          manifest["provenance"]["active_attempt_id"] ==
              "$(job_id)_$(attempt["registry_index"])" &&
          manifest["provenance"]["source_manifest_sha256"] == CORE_SHA &&
          manifest["provenance"]["supplemental_gpu_gate_sha256"] == SUPPLEMENT_SHA &&
          manifest["provenance"]["original_7366_parent_passed"] === false &&
          manifest["provenance"]["saved_science_evidence_sha256"] == saved_evidence_sha &&
          manifest["provenance"]["root_acceptance_sha256"] == root_acceptance_sha &&
          manifest["provenance"]["durable_child_exit_sha256"] == attempt["exit_sha256"],
          "export scientific identity differs")
    record_audit = manifest["record_audit"]
    check(record_audit["profiles"]["initial_records"] == 1 &&
          record_audit["profiles"]["averaged_records"] == 30 &&
          record_audit["profiles"]["total_records"] == 31 &&
          record_audit["profiles"]["averaged_times_s"] == PROFILE_TIMES &&
          record_audit["profiles"]["all_finite"] === true &&
          record_audit["series"]["records"] == 301 &&
          record_audit["series"]["times_s"] == SERIES_TIMES &&
          record_audit["series"]["all_finite"] === true &&
          record_audit["state_bounds"]["records"] == 301 &&
          record_audit["checkpoints"]["records"] == 6 &&
          record_audit["checkpoints"]["times_s"] == CHECKPOINT_TIMES,
          "export record audit differs")
    for (name, digest) in manifest["output_sha256"]
        check(sha(joinpath(path, name)) == digest, "export CSV hash differs: $name")
    end
    check(Set(keys(manifest["output_sha256"])) == Set(("profiles.csv", "series.csv",
        "profiles_final_hour_long.csv", "profiles_penultimate_hour_long.csv")),
        "export output set differs")
    raw = raw_paths(attempt["run_directory"], case_id)
    for (name, digest) in attempt["raw_sha256"]
        check(sha(raw[name]) == digest &&
              manifest["source_files"][name]["sha256"] == digest,
              "raw writer hash differs: $name")
    end
    check(manifest["checkpoint_files"] == attempt["checkpoint_records"],
          "checkpoint manifest differs")
    for checkpoint in attempt["checkpoint_records"]
        check(sha(checkpoint["path"]) == checkpoint["sha256"],
              "checkpoint file hash differs")
    end
    return Dict("case_id" => case_id, "directory" => abspath(path),
                "manifest_sha256" => sha(manifest_path))
end

function collect_neutral_exports(finalized_path, export_root, destination)
    registry = load_finalized(finalized_path)
    check(!ispath(destination), "refusing to overwrite neutral collection")
    admitted = Dict{String, Any}[]
    rejected = Dict{String, Any}[]
    for attempt in registry["attempts"]
        case_id = attempt["case_id"]
        path = joinpath(export_root, case_id)
        try
            push!(admitted, verify_export_directory(path, attempt, sha(finalized_path),
                registry["array_job_id"], registry["admission_mode"];
                saved_evidence_sha=get(registry, "saved_science_evidence_sha256", "not_applicable"),
                root_acceptance_sha=get(registry, "root_acceptance_sha256", "not_applicable")))
        catch error
            push!(rejected, Dict("case_id" => case_id, "reason" => sprint(showerror, error)))
        end
    end
    check(length(admitted) == 2 && isempty(rejected),
          "neutral collection refused: " *
          join(["$(item["case_id"]): $(item["reason"])" for item in rejected], "; "))
    collection = Dict("schema_version" => 1, "case_family" => "neutral_fixed_stress_ABL",
        "expected_cases" => 2, "admitted_count" => length(admitted),
        "rejected_count" => length(rejected), "admitted" => admitted,
        "rejected" => rejected, "generated_utc" => string(now(UTC)),
        "finalized_registry_path" => abspath(finalized_path),
        "finalized_registry_sha256" => sha(finalized_path),
        "original_7366_parent_passed" => false)
    mkpath(destination)
    Common.write_manifests(destination, collection)
    return collection
end

end
