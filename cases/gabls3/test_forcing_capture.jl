using Test
using Breeze
using Oceananigans

module GABLS3ForcingCaptureRunner
    include(joinpath(@__DIR__, "runner", "gabls3_case.jl"))
end

function enclosed_function(forcing)
    hasproperty(forcing, :forcing) || error("missing SpecificForcing inner forcing")
    hasproperty(forcing.forcing, :func) || error("missing continuous forcing function")
    return forcing.forcing.func
end

@testset "GABLS3 prescribed advection capture contract" begin
    ENV["GABLS3_ARCH"] = "cpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno5"
    ENV["GABLS3_CLOSURE"] = "none"
    ENV["GABLS3_STOP_SECONDS"] = "10"
    ENV["GABLS3_DIAGNOSTICS"] = "0"
    run_directory = mktempdir(; cleanup=false)
    setup = GABLS3ForcingCaptureRunner.build_simulation(; run_directory)
    model = setup.model
    u_forcing = model.forcing.ρu
    v_forcing = model.forcing.ρv
    @test length(u_forcing.forcings) == 2
    @test length(v_forcing.forcings) == 2
    @test fieldcount(typeof(enclosed_function(u_forcing.forcings[1]))) > 0
    @test fieldcount(typeof(enclosed_function(u_forcing.forcings[2]))) == 0
    @test fieldcount(typeof(enclosed_function(v_forcing.forcings[2]))) == 0

    model_fields = Breeze.AtmosphereModels.fields(model)
    z = collect(znodes(model.grid, Center(), Center(), Center()))
    original_time = model.clock.time
    event_times = (3600f0, 7200f0, 10800f0, 18000f0, 21600f0)
    times = (0f0, 32400f0,
             (time for event in event_times for time in
              (prevfloat(event), event, nextfloat(event)))...)
    try
        for time in times, k in (1, 8, 16, 32, 64)
            model.clock.time = convert(typeof(original_time), time)
            actual_u = u_forcing.forcings[2].forcing(
                1, 1, k, model.grid, model.clock, model_fields)
            actual_v = v_forcing.forcings[2].forcing(
                1, 1, k, model.grid, model.clock, model_fields)
            @test actual_u == GABLS3ForcingCaptureRunner.advective_u_tendency(
                nothing, z[k], time)
            @test actual_v == GABLS3ForcingCaptureRunner.advective_v_tendency(
                nothing, z[k], time)
        end
    finally
        model.clock.time = original_time
    end
end
