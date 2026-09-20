using TOML

module GABLS3CheckpointRunner
    include(joinpath(@__DIR__, "..", "..", "gabls3", "runner", "gabls3_case.jl"))
end

function require_contract(condition, message)
    condition || error(message)
    return nothing
end

run_directory = length(ARGS) == 1 ? abspath(ARGS[1]) : mktempdir(; cleanup=false)
ENV["GABLS3_ARCH"] = "cpu"
ENV["GABLS3_NX"] = "64"
ENV["GABLS3_SCHEME"] = "weno9"
ENV["GABLS3_CLOSURE"] = "surface_layer"
ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
ENV["GABLS3_SLD_SUPPORT"] = "1"
ENV["GABLS3_STOP_SECONDS"] = "1"
ENV["GABLS3_DIAGNOSTICS"] = "0"
ENV["GABLS3_CHECKPOINT_SECONDS"] = "3600"

setup = GABLS3CheckpointRunner.build_simulation(; run_directory)
registry = TOML.parsefile(joinpath(@__DIR__, "..", "registries", "gabls3_sld_4case.toml"))
require_contract(haskey(setup.simulation.output_writers, :checkpoint),
                 "GABLS3 runner did not install a Checkpointer")
require_contract(setup.settings.checkpoint_interval == 3600,
                 "GABLS3 checkpoint interval provenance is missing")
for (name, expected) in registry["paired_initial_state_sha256"]
    actual = getproperty(setup.settings.initial_state_sha256, Symbol(name))
    require_contract(actual == expected, "GABLS3 initial digest mismatch for $name")
end
println("GABLS3_CHECKPOINTER_CONSTRUCTION_PASS case_id=", setup.case_id,
        " output=", run_directory)
