#!/usr/bin/env julia

# Independent, read-only audit of the admitted GABLS3 SLD CSV exports.
using SHA
using TOML

length(ARGS) == 2 || error("usage: audit_gabls3_final_7343.jl EXPORT_ROOT COLLECTION_DIR")
export_root, collection_directory = abspath.(ARGS)
digest(path) = bytes2hex(open(sha256, path))
ensure(test, message) = test || error(message)
expected_profile_times = collect(0.0:300.0:32400.0)
expected_series_times = collect(0.0:10.0:32400.0)
comparison_times = collect(11100.0:300.0:14400.0)
expected_cases = Set(("n064_weno9_none", "n064_weno9_surface_layer_t100_s1",
                      "n064_weno9_surface_layer_t300_s1",
                      "n064_weno9_surface_layer_t300_s2"))
collection = TOML.parsefile(joinpath(collection_directory, "manifest.toml"))
ensure(collection["admitted_count"] == 4 && collection["rejected_count"] == 0,
       "collection admission count differs")
ensure(Set(item["case_id"] for item in collection["admitted"]) == expected_cases,
       "collection case IDs differ")

function audit_wide(path, expected_times, information)
    count = 0
    names = String[]
    maxima = Dict{String, Float64}()
    open(path) do io
        names = split(readline(io), ','; keepempty=true)
        ensure(first(names) == "time_s" && Set(names[2:end]) == Set(keys(information)),
               "wide CSV variable set differs in $path")
        for line in eachline(io)
            count += 1
            fields = split(line, ','; keepempty=true)
            ensure(length(fields) == length(names), "wide CSV row width differs in $path")
            ensure(count <= length(expected_times) &&
                   parse(Float64, fields[1]) == expected_times[count],
                   "wide CSV schedule differs in $path record $count")
            for index in 2:length(fields)
                value = parse(Float64, fields[index])
                ensure(isfinite(value), "nonfinite wide CSV value in $path")
                name = names[index]
                maxima[name] = max(get(maxima, name, 0.0), abs(value))
            end
        end
    end
    ensure(count == length(expected_times), "wide CSV record count differs in $path")
    return maxima
end

function read_surface_flux_samples(path)
    fields = ("surface_drag_u_kinematic_flux", "surface_drag_v_kinematic_flux",
              "surface_theta_kinematic_flux", "surface_q_kinematic_flux")
    samples = Dict{Tuple{String, Int}, Float64}()
    open(path) do io
        names = split(readline(io), ',')
        positions = Dict(name => findfirst(==(name), names) for name in fields)
        ensure(all(!isnothing(position) for position in values(positions)),
               "missing direct surface exchange series")
        for line in eachline(io)
            row = split(line, ',')
            time = parse(Float64, row[1])
            time % 300 == 0 || continue
            time_index = Int(round(time / 300)) + 1
            for name in fields
                samples[(name, time_index)] = parse(Float64, row[positions[name]])
            end
        end
    end
    ensure(length(samples) == 4 * 109, "surface exchange samples missing")
    return samples
end

function audit_profiles(path, information)
    values = Dict{Tuple{String, Int, Int}, Float64}()
    counts = Dict{Tuple{String, Int}, Int}()
    row_count = 0
    open(path) do io
        header = split(readline(io), ',')
        ensure(header == ["time_s", "z_m", "variable", "value", "location",
                          "units", "record_kind", "window_start_s", "window_end_s"],
               "profile CSV header differs")
        for line in eachline(io)
            fields = split(line, ','; keepempty=true)
            ensure(length(fields) == 9, "profile CSV row width differs")
            time = parse(Float64, fields[1])
            time_index = Int(round(time / 300)) + 1
            ensure(1 <= time_index <= 109 && time == expected_profile_times[time_index],
                   "profile time differs")
            name = fields[3]
            ensure(haskey(information, name), "unknown profile variable $name")
            info = information[name]
            location = info["location"]
            ensure(fields[5] == location && fields[6] == info["units"],
                   "profile location/units differ for $name")
            expected_length = location == "Face" ? 65 : 64
            key = (name, time_index)
            vertical_index = get(counts, key, 0) + 1
            counts[key] = vertical_index
            ensure(vertical_index <= expected_length, "profile vertical length differs")
            expected_z = location == "Face" ? (vertical_index - 1) * 12.5 :
                (vertical_index - 0.5) * 12.5
            ensure(parse(Float64, fields[2]) == expected_z, "native z differs for $name")
            ensure(fields[7] == "instantaneous_horizontal_profile" &&
                   parse(Float64, fields[8]) == time &&
                   parse(Float64, fields[9]) == time,
                   "profile record semantics differ")
            value = parse(Float64, fields[4])
            ensure(isfinite(value), "nonfinite profile value for $name")
            values[(name, time_index, vertical_index)] = value
            row_count += 1
        end
    end
    for (name, info) in information, time_index in 1:109
        expected_length = info["location"] == "Face" ? 65 : 64
        ensure(get(counts, (name, time_index), 0) == expected_length,
               "missing native profile records for $name")
    end
    return values, row_count
end

function audit_mean(path, profile_values, information)
    count = 0
    open(path) do io
        header = split(readline(io), ',')
        ensure(header == ["time_s", "z_m", "variable", "value", "location",
                          "units", "record_kind", "window_start_s", "window_end_s",
                          "source_times_s"], "comparison mean header differs")
        for line in eachline(io)
            fields = split(line, ','; keepempty=true)
            ensure(length(fields) == 10 && parse(Float64, fields[1]) == 14400.0 &&
                   fields[7] == "equal_mean_of_12_instantaneous_profiles" &&
                   parse(Float64, fields[8]) == 10800.0 &&
                   parse(Float64, fields[9]) == 14400.0 &&
                   parse.(Float64, split(fields[10], ';')) == comparison_times,
                   "03–04 UTC averaging semantics differ")
            name = fields[3]
            info = information[name]
            z = parse(Float64, fields[2])
            vertical_index = info["location"] == "Face" ? Int(round(z / 12.5)) + 1 :
                Int(round(z / 12.5 + 0.5))
            expected = sum(profile_values[(name, Int(round(time / 300)) + 1, vertical_index)]
                           for time in comparison_times) / 12
            actual = parse(Float64, fields[4])
            ensure(isfinite(actual) && isapprox(actual, expected; rtol=2e-14, atol=2e-14),
                   "03–04 UTC mean differs for $name at z=$z")
            count += 1
        end
    end
    ensure(count == sum(info["location"] == "Face" ? 65 : 64
                        for info in values(information)), "mean profile row count differs")
    return count
end

function audit_flux_split(profile_values, information, closure, surface_flux_samples)
    splits = (("resolved_u_w_flux", "sgs_u_w_flux", "total_u_w_flux"),
              ("resolved_v_w_flux", "sgs_v_w_flux", "total_v_w_flux"),
              ("resolved_w_theta_flux", "sgs_w_theta_flux", "total_w_theta_flux"),
              ("resolved_w_q_flux", "sgs_w_q_flux", "total_w_q_flux"))
    maximum_mismatch = 0.0
    maximum_wall_mismatch = 0.0
    maxima = Dict{String, Float64}()
    wall_variable = Dict("total_u_w_flux" => "surface_drag_u_kinematic_flux",
        "total_v_w_flux" => "surface_drag_v_kinematic_flux",
        "total_w_theta_flux" => "surface_theta_kinematic_flux",
        "total_w_q_flux" => "surface_q_kinematic_flux")
    for (resolved, sgs, total) in splits
        for name in (resolved, sgs, total)
            ensure(haskey(information, name) && information[name]["location"] == "Face",
                   "missing native-face flux $name")
        end
        sgs_maximum = 0.0
        first_interior_maximum = 0.0
        for time_index in 1:109, vertical_index in 1:65
            a = profile_values[(resolved, time_index, vertical_index)]
            b = profile_values[(sgs, time_index, vertical_index)]
            c = profile_values[(total, time_index, vertical_index)]
            if vertical_index == 1
                wall = surface_flux_samples[(wall_variable[total], time_index)]
                mismatch = abs(c - wall)
                maximum_wall_mismatch = max(maximum_wall_mismatch, mismatch)
                ensure(mismatch <= 2e-6 * max(1e-6, abs(c), abs(wall)),
                       "wall total != direct surface exchange for $total")
            else
                mismatch = abs(c - (a + b))
                maximum_mismatch = max(maximum_mismatch, mismatch)
                ensure(mismatch <= 2e-6 * max(1e-6, abs(a), abs(b), abs(c)),
                       "interior resolved+SGS != total for $total")
            end
            sgs_maximum = max(sgs_maximum, abs(b))
            vertical_index == 2 && (first_interior_maximum = max(first_interior_maximum, abs(b)))
        end
        maxima[sgs] = sgs_maximum
        maxima["$(sgs)_first_interior"] = first_interior_maximum
        if closure == "none"
            ensure(sgs_maximum == 0.0, "control has nonzero $sgs")
        else
            ensure(first_interior_maximum > 0.0, "SLD first interior $sgs is zero")
        end
    end
    return maximum_mismatch, maximum_wall_mismatch, maxima
end

for admitted in collection["admitted"]
    case_id = admitted["case_id"]
    directory = joinpath(export_root, case_id)
    ensure(abspath(admitted["directory"]) == directory, "collection path differs")
    manifest_path = joinpath(directory, "manifest.toml")
    ensure(digest(manifest_path) == admitted["manifest_sha256"],
           "collection manifest SHA differs")
    manifest = TOML.parsefile(manifest_path)
    ensure(manifest["export_verified"] === true &&
           manifest["scientific_admission"] == "passed" &&
           manifest["case_id"] == case_id, "case admission differs")
    ensure(manifest["record_audit"]["profiles"]["records"] == 109 &&
           manifest["record_audit"]["series"]["records"] == 3241 &&
           manifest["record_audit"]["points"]["records"] == 3241,
           "record counts differ")
    point_metadata = manifest["raw_metadata"]["points"]
    ensure(parse.(Float64, split(point_metadata["actual_native_w_face_heights_m"], ',')) ==
           [12.5, 25.0, 50.0, 100.0, 175.0, 200.0] &&
           parse.(Float64, split(point_metadata["actual_scalar_and_horizontal_velocity_heights_m"], ',')) ==
           [6.25, 18.75, 43.75, 93.75, 181.25, 193.75],
           "native point coordinate metadata differs")
    for (name, expected) in manifest["output_sha256"]
        ensure(digest(joinpath(directory, name)) == expected, "output SHA differs: $name")
    end
    for source in values(manifest["source_files"])
        ensure(digest(source["path"]) == source["sha256"], "raw JLD2 SHA differs")
    end
    for name in ("prescribed_surface_pressure", "prescribed_surface_theta",
                 "prescribed_surface_q")
        info = manifest["series_variables"][name]
        ensure(info["raw_element_type_counts"] ==
               Dict("Float64" => 3240, "Float32" => 1) &&
               info["final_record_float32_exception"] === true,
               "prescribed scalar raw type audit differs for $name")
    end
    series_maxima = audit_wide(joinpath(directory, "series.csv"),
        expected_series_times, manifest["series_variables"])
    audit_wide(joinpath(directory, "points.csv"),
        expected_series_times, manifest["point_variables"])
    profiles, profile_rows = audit_profiles(joinpath(directory, "profiles.csv"),
        manifest["profile_variables"])
    mean_rows = audit_mean(joinpath(directory, "profiles_03_04utc_mean.csv"),
        profiles, manifest["profile_variables"])
    surface_samples = read_surface_flux_samples(joinpath(directory, "series.csv"))
    mismatch, wall_mismatch, flux_maxima = audit_flux_split(
        profiles, manifest["profile_variables"], manifest["closure"], surface_samples)
    paper_sgs_u = Dict(z => sum(profiles[("sgs_u_w_flux",
        Int(round(time / 300)) + 1, z)] for time in comparison_times) / 12
        for z in (2, 3))
    if manifest["closure"] == "none"
        ensure(paper_sgs_u[2] == 0.0 && paper_sgs_u[3] == 0.0,
               "control has nonzero paper-window SGS momentum flux")
    elseif endswith(case_id, "_s2")
        ensure(paper_sgs_u[2] != 0.0 && paper_sgs_u[3] != 0.0,
               "two-face paper-window SGS momentum support is missing")
    else
        ensure(paper_sgs_u[2] != 0.0 && paper_sgs_u[3] == 0.0,
               "one-face paper-window SGS momentum support differs")
    end
    println("AUDITED case=", case_id, " profiles=109 series=3241 points=3241",
            " profile_rows=", profile_rows, " mean_rows=", mean_rows,
            " variables=", length(manifest["profile_variables"]), "/",
            length(manifest["series_variables"]), "/",
            length(manifest["point_variables"]),
            " interior_flux_split_max_abs_error=", mismatch,
            " wall_flux_max_abs_error=", wall_mismatch,
            " sgs_u_w_first_interior_max=", flux_maxima["sgs_u_w_flux_first_interior"],
            " sgs_w_theta_first_interior_max=", flux_maxima["sgs_w_theta_flux_first_interior"],
            " sgs_w_q_first_interior_max=", flux_maxima["sgs_w_q_flux_first_interior"],
            " paper_sgs_u_w_z12p5=", paper_sgs_u[2],
            " paper_sgs_u_w_z25=", paper_sgs_u[3],
            " q_minimum_abs_max=", series_maxima["q_minimum"])
end
println("GABLS3_FINAL_7343_INDEPENDENT_AUDIT_PASSED admitted=4 rejected=0")
