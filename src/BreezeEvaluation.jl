module BreezeEvaluation

using TOML: parsefile

export campaign_data_directory, evaluation_root, external_path

"""Return the root of the checked-out evaluation repository."""
evaluation_root() = normpath(joinpath(@__DIR__, ".."))

"""Return the version-controlled data directory for `campaign`."""
function campaign_data_directory(campaign)
    directory = joinpath(evaluation_root(), "data", string(campaign))
    isdir(directory) || throw(ArgumentError("Unknown campaign data directory: $campaign"))
    return directory
end

"""
Resolve an external raw-data path without embedding machine-specific paths in analysis code.

Environment variable `BREEZE_EVALUATION_<NAME>` takes precedence over `config/local_paths.toml`.
The local configuration is intentionally ignored by Git.
"""
function external_path(name; config_path=joinpath(evaluation_root(), "config", "local_paths.toml"))
    key = string(name)
    environment_key = "BREEZE_EVALUATION_" * uppercase(replace(key, '-' => '_'))
    haskey(ENV, environment_key) && return normpath(ENV[environment_key])
    isfile(config_path) || throw(ArgumentError(
        "Set $environment_key or copy config/paths.example.toml to config/local_paths.toml"))
    paths = get(parsefile(config_path), "paths", Dict{String, String}())
    haskey(paths, key) || throw(ArgumentError("Missing paths.$key in $config_path"))
    return normpath(paths[key])
end

end

