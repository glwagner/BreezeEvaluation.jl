using Test
using JLD2

include(joinpath(@__DIR__, "runner", "gabls3_case.jl"))

function configure_fixture!(directory; stop_time, diagnostics)
    ENV["GABLS3_ARCH"] = "cpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno9"
    ENV["GABLS3_CLOSURE"] = "none"
    ENV["GABLS3_STOP_SECONDS"] = string(stop_time)
    ENV["GABLS3_DIAGNOSTICS"] = diagnostics ? "1" : "0"
    ENV["GABLS3_RUN_DIR"] = directory
    return nothing
end

function raw_times(path)
    return jldopen(path, "r") do file
        time_group = file["timeseries/t"]
        sort([time_group[key] for key in keys(time_group)])
    end
end

function raw_outputs_are_finite(path)
    return jldopen(path, "r") do file
        for variable in keys(file["timeseries"])
            variable in ("serialized", "t") && continue
            group = file["timeseries/$variable"]
            for key in keys(group)
                key == "serialized" && continue
                all(isfinite, group[key]) || return false
            end
        end
        return true
    end
end

function skip_past_specified_times!(simulation, current_time)
    activities = (values(simulation.output_writers)..., values(simulation.callbacks)...)
    for activity in activities
        schedule = activity.schedule
        if schedule isa SpecifiedTimes
            schedule.previous_actuation = searchsortedlast(schedule.times, current_time)
        end
    end
    return nothing
end

root = length(ARGS) == 1 ? abspath(ARGS[1]) : mktempdir(; cleanup=false)
mkpath(root)
fixture = get(ENV, "GABLS3_INTEGRATION_FIXTURE", "all")
fixture in ("all", "writer", "morning") ||
    error("GABLS3_INTEGRATION_FIXTURE must be all, writer, or morning")

if fixture in ("all", "writer")
@testset "Nonphysical clock-jump writer fixture" begin
    directory = joinpath(root, "writer_schedule")
    configure_fixture!(directory; stop_time=301, diagnostics=true)
    setup = build_simulation(; run_directory=directory)
    setup.model.clock.time = 295.0
    skip_past_specified_times!(setup.simulation, setup.model.clock.time)
    run!(setup.simulation)

    prefix = joinpath(directory, "n064_weno9_none_diag")
    profile_path = prefix * "_profiles.jld2"
    series_path = prefix * "_series.jld2"
    point_path = prefix * "_points.jld2"
    @test 300.0 in raw_times(profile_path)
    @test 300.0 in raw_times(series_path)
    @test 300.0 in raw_times(point_path)
    @test raw_outputs_are_finite(profile_path)
    @test raw_outputs_are_finite(series_path)
    @test raw_outputs_are_finite(point_path)
end
end

if fixture in ("all", "morning")
@testset "Nonphysical clock-jump 06:00 forcing-event fixture" begin
    directory = joinpath(root, "morning_event")
    configure_fixture!(directory; stop_time=21601, diagnostics=false)
    setup = build_simulation(; run_directory=directory)
    setup.model.clock.time = 21599.0
    event_time = Ref(NaN)
    event_surface_q = Ref(NaN)
    function observe_event(model)
        event_time[] = time(model)
        event_surface_q[] = minimum(setup.surface_q)
        return nothing
    end
    # TimeStepCallsite is intentional: Breeze executes UpdateState callbacks at every RK
    # update without consulting their schedule, which would overwrite the observed event time.
    add_callback!(setup.simulation, observe_event, SpecifiedTimes([21600.0]))
    skip_past_specified_times!(setup.simulation, setup.model.clock.time)
    run!(setup.simulation)

    final_time = time(setup.simulation)
    expected_q = GABLS3ModelForcing.surface_state(setup.inputs, final_time).q
    @test final_time >= 21600
    @test event_time[] == 21600
    @test event_surface_q[] ≈ GABLS3ModelForcing.surface_state(setup.inputs, 21600).q
    @test all(value -> value ≈ expected_q, interior(setup.surface_q))
    @test advective_theta_tendency(setup.inputs, 200f0, prevfloat(21600f0)) > 0
    @test advective_theta_tendency(setup.inputs, 200f0, 21600f0) == 0
end
end

println("fixture_root=", root)
println("WARNING: clock-jump fixtures test scheduling and callback plumbing only; they are not evolved scientific states.")
