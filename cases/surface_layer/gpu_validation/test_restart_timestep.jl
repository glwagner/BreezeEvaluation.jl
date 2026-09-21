using Test
using Oceananigans

function timestep_fixture(directory; stop_iteration)
    grid = RectilinearGrid(CPU(); size=(4, 4, 4), extent=(4, 4, 4))
    model = NonhydrostaticModel(grid; advection=nothing, closure=nothing)
    simulation = Simulation(model; Δt=0.4, stop_iteration)
    conjure_time_step_wizard!(simulation; cfl=0.7, max_Δt=1.0)
    simulation.output_writers[:checkpoint] = Checkpointer(model;
        prefix="timestep_fixture", dir=directory,
        schedule=IterationInterval(1), overwrite_files=true)
    return simulation
end

@testset "serialized applied timestep survives restart fixture" begin
    mktempdir() do directory
        reference = timestep_fixture(joinpath(directory, "reference"); stop_iteration=2)
        run!(reference)
        reference_time = time(reference)

        split_directory = joinpath(directory, "split")
        split = timestep_fixture(split_directory; stop_iteration=1)
        run!(split)
        checkpoint = joinpath(split_directory, "timestep_fixture_iteration1.jld2")
        @test isfile(checkpoint)
        applied_Δt = split.model.clock.last_Δt
        @test isfinite(applied_Δt) && applied_Δt > 0
        @test applied_Δt != 0.4

        restarted = timestep_fixture(joinpath(directory, "restart"); stop_iteration=2)
        set!(restarted; checkpoint)
        @test iteration(restarted) == 1
        @test restarted.model.clock.last_Δt == applied_Δt
        @test restarted.Δt != applied_Δt
        restarted.Δt = restarted.model.clock.last_Δt
        run!(restarted)
        @test iteration(restarted) == 2
        @test time(restarted) == reference_time
    end
end
