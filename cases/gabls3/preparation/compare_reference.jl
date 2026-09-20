using Test
include("GABLS3Forcing.jl")
using .GABLS3Forcing
length(ARGS) == 1 || error("Usage: julia compare_reference.jl PATH_TO_PANE48_REFERENCE_CSV_DIRECTORY")
d = load_case(joinpath(@__DIR__, "inputs.toml"))
rows(name) = [split(line, ',') for line in readlines(joinpath(ARGS[1], name))[2:end] if !isempty(strip(line))]
@testset "Independent transcriptions agree" begin
    for r in rows("surface_state.csv")
        t = parse(Float64, r[1]); x = surface_state(d,t)
        @test (x.pressure,x.theta,x.q) == Tuple(parse.(Float64,r[3:5]))
    end
    for r in rows("initial_velocity.csv")
        z = parse(Float64, r[1]); w = d["initial_wind"]
        @test (linear_value(w["z"],w["u"],z),linear_value(w["z"],w["v"],z)) == Tuple(parse.(Float64,r[2:3]))
    end
    for r in rows("initial_thermodynamics.csv")
        z = parse(Float64,r[1]); s = d["initial_thermodynamics"]
        @test Tuple(linear_value(s["z"],s[k],z) for k in ("pressure","theta","q")) == Tuple(parse.(Float64,r[2:4]))
    end
    for r in rows("geostrophic_surface.csv")
        t = parse(Float64,r[1]); g = d["geostrophic"]
        @test (linear_value(g["t"],g["u"],t),linear_value(g["t"],g["v"],t)) == Tuple(parse.(Float64,r[3:4]))
    end
    for r in rows("large_scale_advection.csv")
        t = parse(Float64,r[2]); 0 <= t <= 32400 || continue
        r[6] == "before" && (t = prevfloat(t))
        key = r[1] == "specific_humidity" ? :q : Symbol(r[1]); expected = parse(Float64,r[4])
        @test getproperty(advection(d,800,t),key) == expected
    end
end
