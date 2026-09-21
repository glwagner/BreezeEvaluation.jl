# Focused changed-source gate. This never claims the broader gpu_full GABLS3 suite.
using Breeze, Oceananigans, CUDA, SHA, TOML, JLD2
import Dates
include("audit_resolved_factor_outputs.jl")
include("factor10_zero_fraction_contract.jl")
module Helpers
    include("validate_surface_layer.jl")
end
const MODE = get(ENV, "SLD_FACTOR_MODE", "cpu")
const OUTPUT = abspath(ENV["SLD_VALIDATION_OUTPUT"])
const ROOT = abspath(ENV["SLD_FREEZE_ROOT"])
const EVAL = normpath(joinpath(@__DIR__, "..", "..", ".."))
const checks = Ref(0)
check(value, message) = (value || error(message); checks[] += 1; nothing)
hashfile(path) = bytes2hex(open(sha256, path))
host(field) = Array(interior(field))

function audit_coefficients(model, factor)
    f = model.closure_fields
    closure = model.closure
    check(closure.resolved_flux_factor == factor, "factor not materialized")
    τu, τv = -host(f.surface_u_flux), -host(f.surface_v_flux)
    τ = sqrt.(τu.^2 .+ τv.^2)
    ru, rv = -host(f.resolved_u_flux[1]), -host(f.resolved_v_flux[1])
    parallel = (ru .* τu .+ rv .* τv) ./ τ
    expected = max.(0, 1 .- factor .* parallel ./ τ)
    active = host(f.momentum_active[1]) .== 1
    check(any(active), "momentum guard fixture inactive")
    check(all(isapprox.(host(f.momentum_deficit[1])[active], expected[active]; atol=3e-6, rtol=3e-6)),
          "GPU momentum deficit does not use factor")
    sf = host(f.surface_scalar_flux.ρθ)
    rf = host(f.resolved_scalar_flux.ρθ[1])
    expected_scalar = max.(0, 1 .- factor .* rf ./ sf)
    active_scalar = host(f.scalar_active.ρθ[1]) .== 1
    check(any(active_scalar), "heat guard fixture inactive")
    check(all(isapprox.(host(f.scalar_deficit.ρθ[1])[active_scalar], expected_scalar[active_scalar]; atol=3e-6, rtol=3e-6)),
          "GPU scalar deficit does not use factor")
    for K in (f.Kᵘ, f.tupled_tracer_diffusivities.ρθ)
        values = host(K)
        check(all(isfinite, values) && minimum(values) >= 0, "invalid implicit coefficient")
        check(all(iszero, values[:, :, 3:end]), "one-face coefficient leaks")
    end
    return nothing
end

function runner_check(factor, architecture_name)
    directory = joinpath(OUTPUT, "factor$(Int(factor))")
    ENV["GABLS1_SLD_ARCH"] = architecture_name
    ENV["GABLS1_SLD_CLOSURE"] = "surface_layer"
    ENV["GABLS1_SLD_RESOLVED_FLUX_FACTOR"] = string(Float64(factor))
    ENV["GABLS1_SLD_FILTER_SECONDS"] = "300"
    ENV["GABLS1_SLD_SUPPORT"] = "1"
    ENV["GABLS1_SLD_STOP_SECONDS"] = "1800"
    ENV["GABLS1_SLD_SEED"] = "123"
    setup = Helpers.GABLS1ValidationRunner.build_simulation(; run_directory=directory)
    check(setup.settings.theta_initial_sha256 == "1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b", "seed digest changed")
    seen = Set{Int}()
    # This observer only reads state. It does not refresh fields or repair clocks.
    function observe(sim)
        f = sim.model.closure_fields
        check(f.previous_update_iteration[] <= iteration(sim), "filter ran in future iteration")
        check(f.previous_update_time[] <= time(sim), "filter ran at future time")
        push!(seen, f.previous_update_iteration[])
    end
    setup.simulation.callbacks[:factor_observer] = Callback(observe, IterationInterval(1))
    run!(setup.simulation)
    check(time(setup.simulation) == 1800, "short runner missed end time")
    check(length(seen) > 2, "accepted-step filter did not advance")
    audit_coefficients(setup.model, factor)
    prefix = joinpath(directory, "$(setup.case_id)_diag")
    # Factor10 may validly switch mixing off. The manufactured contract tests
    # nonzero coefficients separately; actual saved fluxes must still partition.
    audit_resolved_factor_outputs(prefix, factor; check, require_nonzero_momentum=false)
    audit_zero_fraction_series(prefix; check)
    return Dict("case_id" => setup.case_id, "factor" => Float64(factor), "accepted_filter_iterations_observed" => length(seen), "end_time_s" => time(setup.simulation))
end

function main()
    MODE in ("cpu", "gpu") || error("SLD_FACTOR_MODE must be cpu or gpu")
    ispath(OUTPUT) && !isempty(readdir(OUTPUT)) && error("refusing existing output")
    mkpath(OUTPUT)
    gpu = MODE == "gpu"
    prefix = gpu ? "GPU" : "CPU"
    mode = gpu ? "gpu_factor10" : "cpu_factor10"
    try
        gpu && (CUDA.functional() || error("CUDA unavailable"))
        gpu && CUDA.allowscalar(false)
        arch = gpu ? GPU() : CPU()
        # Pure same-input properties prove sign/floor behavior and unchanged diagnostics.
        props = Breeze.TurbulenceClosures.momentum_surface_layer_properties
        scalar = Breeze.TurbulenceClosures.scalar_surface_layer_properties
        ten = SurfaceLayerDiffusivity(Float32; resolved_flux_factor=10)
        capped = SurfaceLayerDiffusivity(Float32; resolved_flux_factor=10, maximum_viscosity=0.1, maximum_diffusivity=0.1)
        args = (-0.01f0, 0f0, -0.04f0, 0f0, 12.5f0, 1f0)
        p = props(args..., ten)
        check(p.deficit == 0 && p.viscosity == 0 && p.valid, "factor10 aligned target switch-off")
        opposed = props(0.01f0, 0f0, -0.04f0, 0f0, 12.5f0, 1f0, ten)
        check(opposed.deficit == 3.5f0 && opposed.viscosity > 0, "opposing signed flux incorrectly switches off")
        check(scalar(-0.0025f0, -0.01f0, 0.2f0, 12.5f0, 1f0, 1f-8, ten).diffusivity == 0, "heat factor10 switch-off")
        check(!scalar(0f0, 0f0, 0.2f0, 12.5f0, 1f0, 1f-8, ten).valid, "zero-target guard inactive expected")
        check(props(0f0,0f0,-0.04f0,0f0,12.5f0,1f0,capped).cap_active, "momentum cap fixture")
        check(scalar(0f0,-0.01f0,0.2f0,12.5f0,1f0,1f-8,capped).cap_active, "heat cap fixture")
        fraction_evidence = zero_fraction_contract(arch; check)
        restarts = Dict{String, Any}()
        for factor in (10,)
            restarts[string(factor)] = Helpers.serialized_restart_check(arch; moist=false,
                support=1, resolved_flux_factor=factor, directory=joinpath(OUTPUT, "restart$factor"))
        end
        # The longer runner path is a source-specific GPU gate, not a CPU smoke run.
        runs = gpu ? [runner_check(10, "gpu")] : Any[]
        sources = ("cases/surface_layer/gpu_validation/validate_factor10.jl",
                   "cases/surface_layer/gpu_validation/factor10_zero_fraction_contract.jl",
                   "cases/surface_layer/diagnostics/SurfaceLayerDiagnostics.jl",
                   "cases/surface_layer/gpu_validation/audit_resolved_factor_outputs.jl",
                   "cases/surface_layer/gpu_validation/validate_surface_layer.jl",
                   "cases/surface_layer/gabls1/gabls1_case.jl",
                   "cases/surface_layer/registries/gabls1_sld_factor10.toml")
        evidence = Dict("validation_mode" => mode, "case_family" => "GABLS1",
            "all_passed" => true, "factors" => [10.0], "changed_path_checks_passed" => true,
            "zero_fraction_contract_passed" => true, "zero_fraction_contract" => fraction_evidence,
            "passed_checks" => checks[] + Helpers.PASS_COUNT[], "architecture" => summary(arch),
            "cuda_functional" => gpu, "cuda_scalar_indexing_disabled" => gpu,
            "freeze_root" => ROOT, "freeze_source_manifest_sha256" => hashfile(joinpath(ROOT, "source_sha256.txt")),
            "freeze_source_manifest_entries" => length(readlines(joinpath(ROOT, "source_sha256.txt"))),
            "source_sha256" => Dict(p => hashfile(joinpath(EVAL, p)) for p in sources),
            "restart" => restarts, "runners" => runs, "completed_utc" => string(Dates.now(Dates.UTC)),
            "observers_are_read_only" => true, "scientific_output" => false)
        path = joinpath(OUTPUT, "validation_evidence.toml")
        open(io -> TOML.print(io, evidence; sorted=true), path, "w")
        write(joinpath(OUTPUT, "$(prefix)_VALIDATION_DONE"), "mode=$mode\nevidence_sha256=$(hashfile(path))\n")
        println("RESOLVED_FLUX_FACTOR_GATE_PASS mode=$mode checks=$(evidence["passed_checks"])")
    catch err
        open(joinpath(OUTPUT, "$(prefix)_VALIDATION_FAILED"), "w") do io
            showerror(io, err, catch_backtrace())
        end
        rethrow()
    end
end
abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
