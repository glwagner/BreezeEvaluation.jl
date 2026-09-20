#!/usr/bin/env julia

# Independent Julia-only verification of one exported DYCOMS case. The verifier reads
# only numeric JLD2 leaves and never deserializes Oceananigans grids or GPU objects.

using Oceananigans
using SHA
using Statistics

const JLD2 = Oceananigans.OutputReaders.JLD2
length(ARGS) == 1 || error("usage: verify_export.jl analysis_export/<case>")

const CASE_DIR = abspath(ARGS[1])
const CASE = basename(CASE_DIR)
const PRODUCTION_ROOT = dirname(dirname(CASE_DIR))
const RUN_DIR = joinpath(PRODUCTION_ROOT, "runs", CASE)
const STATISTICS_PATH = joinpath(RUN_DIR, "$(CASE)_diag_statistics.jld2")
const SERIES_PATH = joinpath(RUN_DIR, "$(CASE)_diag_series.jld2")

grid_name = first(split(CASE, '_'))
grid = if grid_name == "coarse"
    (Nz=75, Lz=1500.0)
elseif grid_name in ("canonical", "fine")
    (Nz=300, Lz=1500.0)
else
    error("Unknown grid in $CASE")
end

function numeric_records(file)
    group = file["timeseries/t"]
    records = [(key=key, time=Float64(group[key])) for key in keys(group)]
    sort!(records; by=record -> record.time)
    return records
end

output_names(file) = filter(!=("t"), String.(collect(keys(file["timeseries"]))))

function scalar_value(value)
    scalar = value isa Number ? value : only(value)
    isfinite(scalar) || error("Non-finite scalar")
    return Float64(scalar)
end

function profile_vector(value, Nz)
    value isa AbstractArray || error("Profile record is not an array")
    all(isfinite, value) || error("Non-finite profile record")
    z_length = size(value, ndims(value))
    z_length in (Nz, Nz + 1) || error("Unexpected vertical length $z_length")
    reduced = size(value, 1) != 1 || size(value, 2) != 1
    spread = 0.0
    if reduced
        for k in axes(value, 3)
            lo, hi = extrema(view(value, :, :, k))
            spread = max(spread, Float64(hi - lo))
        end
        profile = vec(dropdims(mean(value; dims=(1, 2)); dims=(1, 2)))
    else
        profile = vec(value)
    end
    return Float64.(profile), reduced, spread
end

vertical_location(length) = length == grid.Nz ? "Center" :
                            length == grid.Nz + 1 ? "Face" : error("Bad profile length $length")

function coordinates(profile_location)
    dz = grid.Lz / grid.Nz
    return profile_location == "Center" ? [(k - 0.5) * dz for k in 1:grid.Nz] :
           [(k - 1.0) * dz for k in 1:grid.Nz+1]
end

function csv_lines(path)
    lines = readlines(path)
    isempty(lines) && error("Empty CSV: $path")
    header = split(first(lines), ','; keepempty=true)
    rows = [split(line, ','; keepempty=true) for line in Iterators.drop(lines, 1)]
    all(length(row) == length(header) for row in rows) || error("Malformed CSV: $path")
    return header, rows
end

function csv_matches(exported, source; scale=abs(source))
    tolerance = 2e-8 * max(scale, 1e-30)
    return isapprox(exported, source; rtol=2e-7, atol=tolerance)
end

function sha256_file(path)
    open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end

series_header, series_rows = csv_lines(joinpath(CASE_DIR, "series.csv"))
length(series_rows) == 241 || error("Expected 241 series rows")
length(series_header) == 33 || error("Expected time_s plus 32 series columns")
series_header[1] == "time_s" || error("First series column is not time_s")
series_csv_names = series_header[2:end]
series_csv_times = parse.(Float64, getindex.(series_rows, 1))
series_csv_times == collect(0.0:60.0:14400.0) || error("Bad series times")

JLD2.jldopen(SERIES_PATH, "r") do file
    records = numeric_records(file)
    names = output_names(file)
    names == series_csv_names || error("Series variable order/name mismatch")
    [record.time for record in records] == series_csv_times || error("Series JLD/CSV time mismatch")
    for (name_index, name) in enumerate(names)
        column = name_index + 1
        for (row, record) in zip(series_rows, records)
            exported = parse(Float64, row[column])
            source = scalar_value(file["timeseries/$name/$(record.key)"])
            csv_matches(exported, source) || error("Series mismatch $name at $(record.time)")
        end
    end
end

profile_header, profile_rows = csv_lines(joinpath(CASE_DIR, "profiles.csv"))
profile_header[1:6] == ["variable", "time_s", "z_m", "value", "location", "units"] ||
    error("Unexpected profile header")
expected_profile_rows = 9 * (27 * grid.Nz + 19 * (grid.Nz + 1))
length(profile_rows) == expected_profile_rows || error("Bad profile row count")

profile_groups = Dict{Tuple{String, Float64}, Vector{Tuple{Float64, Float64, String}}}()
for row in profile_rows
    name = row[1]
    time = parse(Float64, row[2])
    z = parse(Float64, row[3])
    value = parse(Float64, row[4])
    isfinite(z) && isfinite(value) || error("Non-finite profile CSV value")
    push!(get!(profile_groups, (name, time), Tuple{Float64, Float64, String}[]),
          (z, value, row[5]))
end

reduced_names = Set{String}()
maximum_spreads = Dict{String, Float64}()
profile_names = String[]
profile_times = Float64[]
JLD2.jldopen(STATISTICS_PATH, "r") do file
    records = numeric_records(file)
    profile_times = [record.time for record in records]
    profile_times == collect(0.0:1800.0:14400.0) || error("Bad profile times")
    profile_names = output_names(file)
    length(profile_names) == 46 || error("Expected 46 profile variables")
    for name in profile_names
        maximum_spreads[name] = 0.0
        for record in records
            source_value = file["timeseries/$name/$(record.key)"]
            source, reduced, spread = profile_vector(source_value, grid.Nz)
            reduced && push!(reduced_names, name)
            maximum_spreads[name] = max(maximum_spreads[name], spread)
            rows = profile_groups[(name, record.time)]
            profile_location = vertical_location(length(source))
            z = coordinates(profile_location)
            length(rows) == length(source) || error("Profile length mismatch $name")
            for k in eachindex(source)
                exported_z, exported_value, exported_location = rows[k]
                exported_location == profile_location || error("Location mismatch $name")
                exported_z == z[k] || error("Coordinate mismatch $name at $(record.time)")
                csv_matches(exported_value, source[k]) ||
                    error("Profile mismatch $name at $(record.time), z=$(z[k])")
            end
        end
    end

    fourth_header, fourth_rows = csv_lines(joinpath(CASE_DIR, "profiles_fourth_hour_long.csv"))
    length(fourth_rows) == 27 * grid.Nz + 19 * (grid.Nz + 1) ||
        error("Bad fourth-hour row count")
    fourth = Dict{Tuple{String, Float64}, Float64}()
    for row in fourth_rows
        row[8] == "12600.0;14400.0" || error("Bad fourth-hour source bins")
        fourth[(row[1], parse(Float64, row[4]))] = parse(Float64, row[5])
    end
    first_record = only(filter(record -> record.time == 12600.0, records))
    second_record = only(filter(record -> record.time == 14400.0, records))
    for name in profile_names
        first_profile, _, _ = profile_vector(file["timeseries/$name/$(first_record.key)"], grid.Nz)
        second_profile, _, _ = profile_vector(file["timeseries/$name/$(second_record.key)"], grid.Nz)
        z = coordinates(vertical_location(length(first_profile)))
        for k in eachindex(z)
            source = (first_profile[k] + second_profile[k]) / 2
            scale = max(abs(first_profile[k]), abs(second_profile[k]))
            exported = fourth[(name, z[k])]
            csv_matches(exported, source; scale) ||
                error("Fourth-hour mismatch $name at z=$(z[k])")
        end
    end
end

expected_reduced = Set([
    "resolved_tke_buoyancy_production",
    "resolved_tke_shear_production",
    "sgs_tke_dissipation",
    "sgs_tke_shear_production",
    "total_tke_shear_production",
])
reduced_names == expected_reduced || error("Unexpected export-reduced variables: $reduced_names")
all(maximum_spreads[name] == 0 for name in reduced_names) ||
    error("Horizontally replicated arrays have nonzero spread")

for name in ("w_mean", "w_variance", "w_third_central_moment")
    rows = profile_groups[(name, 0.0)]
    all(row[3] == "Face" for row in rows) || error("$name is not on native faces")
    first.(rows) == coordinates("Face") || error("$name face coordinates are incorrect")
end

manifest_text = read(joinpath(CASE_DIR, "manifest.json"), String)
for path in (STATISTICS_PATH, SERIES_PATH)
    digest = sha256_file(path)
    occursin(digest, manifest_text) || error("Source hash absent from manifest: $path")
end

verified_profile_variables = length(unique(key[1] for key in keys(profile_groups)))
verified_profile_times = length(unique(key[2] for key in keys(profile_groups)))

println("EXPORT_VERIFIED_JULIA ", CASE,
        " series_rows=", length(series_rows),
        " profile_rows=", length(profile_rows),
        " profile_variables=", verified_profile_variables,
        " profile_times=", verified_profile_times,
        " fourth_hour_rows=", 27 * grid.Nz + 19 * (grid.Nz + 1),
        " native_face_w_moments=true source_hashes=true replicated_xy_spread=0")
