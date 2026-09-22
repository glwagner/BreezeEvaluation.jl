module SurfaceLayerAnalysisData

export load_case_export, read_long_profiles, read_wide_series

using SHA
using TOML

file_sha256(path) = bytes2hex(open(sha256, path))

function split_csv_line(line)
    # Exported variable names, locations, units, and numeric values contain no commas.
    return split(chomp(line), ','; keepempty=true)
end

function read_wide_series(path)
    lines = readlines(path)
    isempty(lines) && error("empty CSV $path")
    names = split_csv_line(first(lines))
    names[1] == "time_s" || error("first column is not time_s in $path")
    columns = Dict(name => Float64[] for name in names)
    for line in Iterators.drop(lines, 1)
        values = split_csv_line(line)
        length(values) == length(names) || error("malformed row in $path")
        for (name, value) in zip(names, values)
            push!(columns[name], parse(Float64, value))
        end
    end
    return (; time_s=columns["time_s"],
            values=Dict(name => columns[name] for name in names[2:end]))
end

function read_long_profiles(path)
    lines = readlines(path)
    isempty(lines) && error("empty CSV $path")
    header = split_csv_line(first(lines))
    required = ("time_s", "z_m", "variable", "value", "location", "units")
    all(name -> name in header, required) || error("profile CSV lacks required columns")
    index = Dict(name => findfirst(==(name), header) for name in header)
    records = NamedTuple[]
    for line in Iterators.drop(lines, 1)
        values = split_csv_line(line)
        length(values) == length(header) || error("malformed row in $path")
        push!(records, (;
            time_s=parse(Float64, values[index["time_s"]]),
            z_m=parse(Float64, values[index["z_m"]]),
            variable=values[index["variable"]],
            value=parse(Float64, values[index["value"]]),
            location=values[index["location"]],
            units=values[index["units"]]))
    end
    return records
end

function load_case_export(directory)
    manifest_path = joinpath(directory, "manifest.toml")
    isfile(manifest_path) || error("missing manifest.toml in $directory")
    manifest = TOML.parsefile(manifest_path)
    manifest["export_verified"] === true || error("case export is not scientifically admitted")
    manifest["fixture_non_scientific"] === false || error("fixture export is inadmissible")
    for (name, expected) in manifest["output_sha256"]
        path = joinpath(directory, name)
        isfile(path) || error("missing exported artifact $name")
        file_sha256(path) == expected || error("hash mismatch for exported artifact $name")
    end
    series = read_wide_series(joinpath(directory, "series.csv"))
    profiles = read_long_profiles(joinpath(directory, "profiles.csv"))
    points_path = joinpath(directory, "points.csv")
    points = isfile(points_path) ? read_wide_series(points_path) : nothing
    return (; manifest, series, profiles, points)
end

end
