#!/usr/bin/env julia

using JSON
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DATA = joinpath(ROOT, "data", "gabls3", "reference")

function table(path)
    lines = filter(!isempty, readlines(path))
    names = Symbol.(split(first(lines), ','))
    return [NamedTuple{Tuple(names)}(Tuple(split(line, ','))) for line in lines[2:end]]
end

number(value) = parse(Float64, value)
file_sha256(path) = bytes2hex(open(sha256, path))

surface = table(joinpath(DATA, "surface_state.csv"))
velocity = table(joinpath(DATA, "initial_velocity.csv"))
thermodynamics = table(joinpath(DATA, "initial_thermodynamics.csv"))
geostrophic = table(joinpath(DATA, "geostrophic_surface.csv"))
advection = table(joinpath(DATA, "large_scale_advection.csv"))

@assert length(surface) == 10
@assert number.(getproperty.(surface, :time_s)) == collect(0.0:3600.0:32400.0)
@assert number.(getproperty.(surface, :pressure_Pa)) ==
        [102210, 102200, 102200, 102180, 102190, 102210, 102230, 102230, 102230, 102220]
@assert minimum(number.(getproperty.(surface, :theta_0p25_K))) == 288.43
@assert extrema(number.(getproperty.(surface, :specific_humidity_0p25_kg_kg))) == (0.0099, 0.0129)

@assert length(velocity) == 25
@assert length(thermodynamics) == 19
@assert all(diff(number.(getproperty.(velocity, :z_m))) .> 0)
@assert all(diff(number.(getproperty.(thermodynamics, :z_m))) .> 0)
@assert all(x -> 0 < x < 0.02,
            number.(getproperty.(thermodynamics, :specific_humidity_kg_kg)))

@assert number.(getproperty.(geostrophic, :time_s)) == [-3600, 10800, 21600, 43200]
@assert number.(getproperty.(geostrophic, :u_geostrophic_m_s)) == [-6.5, -5.0, -5.0, -6.5]
@assert number.(getproperty.(geostrophic, :v_geostrophic_m_s)) == [4.5, 4.5, 4.5, 2.5]

function jump(variable, time_s)
    rows = filter(row -> row.variable == variable && number(row.time_s) == time_s, advection)
    @assert length(rows) == 2
    @assert Set(getproperty.(rows, :side)) == Set(["before", "after"])
    return Dict(row.side => number(row.value) for row in rows)
end

@assert jump("u", 10800) == Dict("before" => 5e-4, "after" => 0.0)
@assert jump("theta", 3600) == Dict("before" => -2.5e-5, "after" => 7.5e-5)
@assert jump("theta", 21600) == Dict("before" => 7.5e-5, "after" => 0.0)
@assert jump("specific_humidity", 7200) == Dict("before" => 0.0, "after" => -8e-8)
@assert jump("specific_humidity", 18000) == Dict("before" => -8e-8, "after" => 0.0)

vertical_taper(z) = clamp(z / 200, 0, 1)
@assert vertical_taper.([0, 100, 200, 800]) == [0, 0.5, 1, 1]
@assert collect(11100:300:14400) == collect(3 * 3600 + 300:300:4 * 3600)

latitude_degrees = 51.9711
earth_rotation_rate = 7.292115e-5
coriolis_parameter = 2 * earth_rotation_rate * sind(latitude_degrees)
@assert isapprox(coriolis_parameter, 1.149e-4; rtol=1e-3)

provenance = JSON.parsefile(joinpath(ROOT, "provenance", "gabls3_sources.json"))
cache = get(ENV, "BREEZE_EVALUATION_REFERENCE_CACHE", "")
if !isempty(cache)
    jax = joinpath(cache, "jax-alfa")
    run_directory = joinpath(jax, provenance["jax_alfa"]["reference_run"])
    paths = Dict(
        "Config.py" => joinpath(run_directory, "Config.py"),
        "CreateInputs_GABLS3.py" => joinpath(run_directory, "CreateInputs_GABLS3.py"),
        "CreateGeoWind_GABLS3.py" => joinpath(run_directory, "CreateGeoWind_GABLS3.py"),
        "CreateAdvForcing_GABLS3.py" => joinpath(run_directory, "CreateAdvForcing_GABLS3.py"),
        "CreateSurfaceBC_GABLS3.py" => joinpath(run_directory, "CreateSurfaceBC_GABLS3.py"),
        "src/surface/SurfaceFlux.py" => joinpath(jax, "src", "surface", "SurfaceFlux.py"))
    for (role, expected) in provenance["jax_alfa"]["files"]
        @assert isfile(paths[role])
        @assert file_sha256(paths[role]) == expected
    end
    instructions = joinpath(jax, "examples", "SBL_GABLS3", "GABLS3_LES_Revised.docx")
    @assert file_sha256(instructions) == provenance["authoritative_instructions"]["sha256"]
end

println("GABLS3_INPUT_AUDIT_PASSED surface=10 velocity=25 thermodynamics=19 ",
        "geostrophic=4 advection=$(length(advection)) f=$(coriolis_parameter)")
