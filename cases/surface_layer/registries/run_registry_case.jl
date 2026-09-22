using TOML
import Dates

function require_contract(condition, message)
    condition || error(message)
    return nothing
end

length(ARGS) == 3 || error(
    "usage: run_registry_case.jl REGISTRY.toml ONE_BASED_INDEX RUN_ROOT")
get(ENV, "SLD_CASE_EXECUTION_ACK", "") == "IMMUTABLE_GPU_VALIDATED" || error(
    "refusing case execution without SLD_CASE_EXECUTION_ACK=IMMUTABLE_GPU_VALIDATED")

registry_path = abspath(ARGS[1])
case_index = parse(Int, ARGS[2])
run_root = abspath(ARGS[3])
registry = TOML.parsefile(registry_path)
cases = registry["cases"]
require_contract(registry["submission_state"] == "UNSUBMITTED",
                 "this launcher accepts only the reviewed unsubmitted scaffold")
require_contract(1 <= case_index <= length(cases), "case index is out of bounds")
case = cases[case_index]
case_id = case["case_id"]
run_directory = joinpath(run_root, case_id)
ispath(run_directory) && !isempty(readdir(run_directory)) &&
    error("refusing to overwrite nonempty run directory $run_directory")
mkpath(run_directory)

open(joinpath(run_directory, "ATTEMPT_STARTED"), "w") do io
    println(io, "case_id=", case_id)
    println(io, "registry=", registry_path)
    println(io, "registry_index=", case_index)
    println(io, "started_utc=", Dates.now(Dates.UTC))
end

try
    if registry["case_family"] == "GABLS1"
        ENV["GABLS1_SLD_ARCH"] = "gpu"
        ENV["GABLS1_SLD_NX"] = string(registry["grid"][1])
        ENV["GABLS1_SLD_CLOSURE"] = case["closure"]
        ENV["GABLS1_SLD_FILTER_SECONDS"] = string(case["filter_seconds"])
        ENV["GABLS1_SLD_SUPPORT"] = string(case["support"])
        if haskey(case, "resolved_flux_factor")
            ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = string(case["resolved_flux_factor"])
        else
            pop!(ENV, "GABLS1_SLD_RESOLVED_FLUX_FACTOR", nothing)
        end
        ENV["GABLS1_SLD_RESOLVED_TRANSPORT"] =
            get(case, "resolved_transport", "covariance")
        ENV["GABLS1_SLD_STOP_SECONDS"] = string(registry["duration_s"])
        ENV["GABLS1_SLD_SEED"] = string(registry["seed"])
        ENV["GABLS1_SLD_DIAGNOSTICS"] = "1"
        ENV["GABLS1_SLD_RUN_DIR"] = run_directory
        include(normpath(joinpath(@__DIR__, "..", "gabls1", "gabls1_case.jl")))
        setup = build_simulation(; run_directory)
        require_contract(setup.case_id == case_id,
                         "registry/runner case-id mismatch: $case_id != $(setup.case_id)")
        require_contract(setup.settings.theta_initial_sha256 ==
                         registry["paired_initial_theta_sha256"],
                         "GABLS1 paired initial-array digest mismatch")
        @info "SLD_REGISTERED_CASE_START" case_id settings=setup.settings
        run!(setup.simulation)
        open(joinpath(run_directory, "CASE_DONE"), "w") do io
            println(io, "case_id=", case_id)
            println(io, "final_time_s=", time(setup.simulation))
            println(io, "finished_utc=", Dates.now(Dates.UTC))
        end
    elseif registry["case_family"] == "GABLS3"
        ENV["GABLS3_ARCH"] = "gpu"
        ENV["GABLS3_NX"] = string(registry["grid"][1])
        ENV["GABLS3_SCHEME"] = "weno9"
        ENV["GABLS3_CLOSURE"] = case["closure"]
        ENV["GABLS3_SLD_FILTER_SECONDS"] = string(case["filter_seconds"])
        ENV["GABLS3_SLD_SUPPORT"] = string(case["support"])
        ENV["GABLS3_STOP_SECONDS"] = string(registry["duration_s"])
        ENV["GABLS3_SEED"] = string(registry["seed"])
        ENV["GABLS3_DIAGNOSTICS"] = "1"
        ENV["GABLS3_RUN_DIR"] = run_directory
        include(normpath(joinpath(@__DIR__, "..", "..", "gabls3", "runner",
                                  "gabls3_case.jl")))
        setup = build_simulation(; run_directory)
        require_contract(setup.case_id == case_id,
                         "registry/runner case-id mismatch: $case_id != $(setup.case_id)")
        for (name, expected) in registry["paired_initial_state_sha256"]
            actual = getproperty(setup.settings.initial_state_sha256, Symbol(name))
            require_contract(actual == expected,
                             "GABLS3 paired initial-array digest mismatch for $name")
        end
        @info "SLD_REGISTERED_CASE_START" case_id settings=setup.settings
        run!(setup.simulation)
        open(joinpath(run_directory, "CASE_DONE"), "w") do io
            println(io, "case_id=", case_id)
            println(io, "final_time_s=", time(setup.simulation))
            println(io, "finished_utc=", Dates.now(Dates.UTC))
        end
    else
        error("unsupported case_family $(registry["case_family"])")
    end
catch error
    open(joinpath(run_directory, "CASE_FAILED"), "w") do io
        println(io, "case_id=", case_id)
        println(io, "failed_utc=", Dates.now(Dates.UTC))
        showerror(io, error, catch_backtrace())
        println(io)
    end
    rethrow()
end

println("SLD_REGISTERED_CASE_DONE case_id=", case_id, " run_directory=", run_directory)
