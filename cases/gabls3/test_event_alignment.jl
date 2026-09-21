# Actual GABLS3 runner callback/schedule plumbing, with a deliberately jumped
# clock. No model step is taken: this is not an evolved state or scientific data.
using Test
using Breeze
using Oceananigans
using Oceananigans: TimeStepCallsite, UpdateStateCallsite
using Oceananigans.Utils: next_actuation_time

module GABLS3EventAlignmentRunner
    include(joinpath(@__DIR__, "runner", "gabls3_case.jl"))
end

const Runner = GABLS3EventAlignmentRunner

function run_event_alignment_fixture()
    ENV["GABLS3_ARCH"] = "cpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno5"
    ENV["GABLS3_CLOSURE"] = "none"
    ENV["GABLS3_STOP_SECONDS"] = "3611"
    ENV["GABLS3_DIAGNOSTICS"] = "0"

    return mktempdir() do run_directory
        setup = Runner.build_simulation(; run_directory)
        simulation = setup.simulation
        event_times = collect(Runner.forcing_events())
        event_callbacks = [callback for callback in values(simulation.callbacks)
                           if callback.schedule isa SpecifiedTimes &&
                              callback.schedule.times == Float32.(event_times)]
        @test length(event_callbacks) == 1
        event_callback = only(event_callbacks)
        @test event_callback.callsite isa TimeStepCallsite
        @test event_callback.schedule.previous_actuation == 0
        @test next_actuation_time(event_callback.schedule) == 3600f0

        # This callback, unlike the no-op event marker, must continue to run
        # at every RK update stage to refresh the actual MOST surface-q operand.
        stage_callbacks = [callback for callback in values(simulation.callbacks)
                           if callback.callsite isa UpdateStateCallsite]
        @test length(stage_callbacks) == 1
        @test stage_callbacks[1].schedule isa IterationInterval

        setup.model.clock.time = 3599.0
        @test simulation.align_time_step === true
        @test Oceananigans.Utils.schedule_aligned_time_step(
            event_callback.schedule, setup.model.clock, 2.5) == 1.0
        @test Runner.advective_theta_tendency(nothing, 200f0,
              Float32(time(simulation))) == -2.5f-5
        stage_callbacks[1](setup.model)
        @test minimum(setup.surface_q) == Float32(setup.inputs.surface_q(3599.0))

        # Exercise the actual installed callback's schedule at the aligned
        # event time. Its TimeStep callsite is what lets Simulation.run! perform
        # this actuation after the completed step, rather than at an RK stage.
        setup.model.clock.time = 3600.0
        @test event_callback.schedule(setup.model)
        event_callback(simulation)
        @test event_callback.schedule.previous_actuation == 1
        @test next_actuation_time(event_callback.schedule) == 7200f0
        @test Oceananigans.Utils.schedule_aligned_time_step(
            event_callback.schedule, setup.model.clock, 2.5) == 2.5
        @test Runner.advective_theta_tendency(nothing, 200f0,
              Float32(time(simulation))) == 7.5f-5
        stage_callbacks[1](setup.model)
        @test minimum(setup.surface_q) == Float32(setup.inputs.surface_q(3600.0))

        # Check the other prescribed event-side values used by the same
        # table-free forcing functions; this callback change must not alter them.
        for (event, previous_theta, current_theta) in
            ((3600f0, -2.5f-5, 7.5f-5),
             (21600f0, 7.5f-5, 0f0))
            @test Runner.advective_theta_tendency(nothing, 200f0,
                prevfloat(event)) == previous_theta
            @test Runner.advective_theta_tendency(nothing, 200f0,
                event) == current_theta
        end
        @test Runner.advective_q_tendency(nothing, 200f0,
              prevfloat(7200f0)) == 0
        @test Runner.advective_q_tendency(nothing, 200f0, 7200f0) == -8f-8
        @test Runner.advective_u_tendency(nothing, 200f0,
              prevfloat(10800f0)) == 5f-4
        @test Runner.advective_u_tendency(nothing, 200f0, 10800f0) == 0
        println("NONSCIENTIFIC_GABLS3_EVENT_ALIGNMENT_PASS event=3600.0",
                " next_event=", next_actuation_time(event_callback.schedule))
        return nothing
    end
end

@testset "GABLS3 runner 3600-second callback/schedule wiring" begin
    run_event_alignment_fixture()
end
