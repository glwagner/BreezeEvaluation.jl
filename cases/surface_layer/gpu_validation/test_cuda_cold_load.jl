using Test

length(ARGS) == 1 || error("usage: test_cuda_cold_load.jl validation|gabls1|gabls3|neutral")
const TARGET = only(ARGS)
const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))

const TARGETS = Dict(
    "validation" => (;
        path=joinpath(@__DIR__, "validate_surface_layer.jl"),
        variable="SLD_VALIDATION_MODE",
        cpu_value="cpu_contract",
        gpu_value="gpu_full",
        function_name=:validation_architecture),
    "gabls1" => (;
        path=joinpath(ROOT, "cases", "surface_layer", "gabls1", "gabls1_case.jl"),
        variable="GABLS1_SLD_ARCH", cpu_value="cpu", gpu_value="gpu",
        function_name=:architecture_from_environment),
    "gabls3" => (;
        path=joinpath(ROOT, "cases", "gabls3", "runner", "gabls3_case.jl"),
        variable="GABLS3_ARCH", cpu_value="cpu", gpu_value="gpu",
        function_name=:architecture_from_environment),
    "neutral" => (;
        path=joinpath(ROOT, "cases", "surface_layer", "neutral", "neutral_abl_case.jl"),
        variable="NEUTRAL_ABL_ARCH", cpu_value="cpu", gpu_value="gpu",
        function_name=:architecture_from_environment))

haskey(TARGETS, TARGET) || error("unknown cold-load target $TARGET")
const SPECIFICATION = TARGETS[TARGET]

# validation_architecture captures its mode in a constant at include time.
ENV[SPECIFICATION.variable] = TARGET == "validation" ?
    SPECIFICATION.gpu_value : SPECIFICATION.cpu_value

module ColdLoadTarget end
Base.include(ColdLoadTarget, SPECIFICATION.path)

@testset "cold CUDA load: $TARGET" begin
    @test isdefined(ColdLoadTarget, :CUDA)
    architecture_function = getproperty(ColdLoadTarget, SPECIFICATION.function_name)
    if TARGET != "validation"
        @test summary(architecture_function()) == "CPU"
        ENV[SPECIFICATION.variable] = SPECIFICATION.gpu_value
    end

    result = try
        architecture_function()
    catch error
        error
    end
    if result isa Exception
        @test !(result isa UndefVarError)
        @test occursin("CUDA", sprint(showerror, result))
        @test occursin("not functional", sprint(showerror, result))
    else
        @test summary(result) == "GPU"
        @test ColdLoadTarget.CUDA.functional()
    end
end

println("CUDA_COLD_LOAD_PASS target=", TARGET)
