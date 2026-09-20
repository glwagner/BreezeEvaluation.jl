using Test
using Oceananigans.OutputWriters: jldopen

include(joinpath(@__DIR__, "..", "gabls3", "runner", "gabls3_case.jl"))

function numeric_keys(group)
    record_keys = filter(key -> key != "serialized", collect(keys(group)))
    return sort(record_keys; by=key -> parse(Int, key))
end

function outputs_are_finite(file, group_name)
    for variable in keys(file[group_name])
        variable in ("serialized", "t") && continue
        group = file["$group_name/$variable"]
        for key in numeric_keys(group)
            all(isfinite, group[key]) || return false
        end
    end
    return true
end

function audit_profile_contract(path, nz; dissipation_present, dissipation_available,
                                surface_layer_available)
    return jldopen(path, "r") do file
        variables = filter(name -> name ∉ ("serialized", "t"),
                           collect(keys(file["timeseries"])))
        @test !isempty(variables)
        @test ("sgs_resolved_tke_dissipation" in variables) == dissipation_present
        @test file["metadata/sgs_resolved_tke_dissipation_available"] ==
              dissipation_available
        @test file["metadata/surface_layer_diffusivity_available"] ==
              surface_layer_available
        @test outputs_are_finite(file, "timeseries")

        for variable in variables
            group = file["timeseries/$variable"]
            records = numeric_keys(group)
            @test !isempty(records)
            for key in records
                vertical_length = length(group[key])
                @test vertical_length in (nz, nz + 1)
            end
        end
        return variables
    end
end

function audit_surface_layer_series(path)
    required = (
        "surface_layer_filtered_friction_velocity",
        "surface_layer_face1_filtered_u_mean",
        "surface_layer_face1_filtered_v_mean",
        "surface_layer_face1_filtered_w_mean",
        "surface_layer_face1_filtered_uw_product",
        "surface_layer_face1_filtered_vw_product",
        "surface_layer_face1_filtered_u_mean_w_mean_transport",
        "surface_layer_face1_filtered_v_mean_w_mean_transport",
        "surface_layer_face1_resolved_u_flux",
        "surface_layer_face1_resolved_v_flux",
        "surface_layer_face1_ρθ_filtered_scalar_mean",
        "surface_layer_face1_ρθ_filtered_scalar_w_product",
        "surface_layer_face1_ρθ_filtered_scalar_mean_w_mean_transport",
        "surface_layer_face1_ρθ_resolved_flux",
        "surface_layer_face1_ρqᵉ_filtered_scalar_mean",
        "surface_layer_face1_ρqᵉ_filtered_scalar_w_product",
        "surface_layer_face1_ρqᵉ_filtered_scalar_mean_w_mean_transport",
        "surface_layer_face1_ρqᵉ_resolved_flux")
    jldopen(path, "r") do file
        variables = collect(keys(file["timeseries"]))
        @test all(name -> name in variables, required)
        @test outputs_are_finite(file, "timeseries")
        @test file["metadata/surface_layer_interior_face_indices"] == (2, 3)
        @test file["metadata/surface_layer_interior_face_heights_m"] == (12.5f0, 25.0f0)
        @test file["metadata/surface_layer_interior_face_weights"] == (1.0f0, 0.0f0)
        @test file["metadata/surface_layer_flux_guard_ρθ"] == 1.0f-8
        @test file["metadata/surface_layer_flux_guard_ρqᵉ"] == 1.0f-12
        @test file["metadata/surface_layer_flux_guard_ρqᵉ_units"] == "m s-1"
    end
    return nothing
end

function configure!(directory, closure)
    ENV["GABLS3_ARCH"] = "cpu"
    ENV["GABLS3_NX"] = "64"
    ENV["GABLS3_SCHEME"] = "weno9"
    ENV["GABLS3_CLOSURE"] = closure
    ENV["GABLS3_SLD_FILTER_SECONDS"] = "300"
    ENV["GABLS3_SLD_SUPPORT"] = "1"
    ENV["GABLS3_STOP_SECONDS"] = "10"
    ENV["GABLS3_DIAGNOSTICS"] = "1"
    ENV["GABLS3_RUN_DIR"] = directory
    return nothing
end

root = length(ARGS) == 1 ? abspath(ARGS[1]) : mktempdir(; cleanup=false)
mkpath(root)

variants = (
    (closure="none", id="n064_weno9_none", present=true, available=false),
    (closure="smagorinsky", id="n064_weno9_smagorinsky", present=true, available=true),
    (closure="surface_layer", id="n064_weno9_surface_layer_t300_s1",
     present=false, available=false))

@testset "Legacy GABLS diagnostic adaptation" begin
    for variant in variants
        directory = joinpath(root, variant.id)
        configure!(directory, variant.closure)
        setup = build_simulation(; run_directory=directory)
        run!(setup.simulation)

        prefix = joinpath(directory, variant.id * "_diag")
        profile_path = prefix * "_profiles.jld2"
        series_path = prefix * "_series.jld2"
        @test isfile(profile_path)
        @test isfile(series_path)
        variables = audit_profile_contract(profile_path, 64;
            dissipation_present=variant.present,
            dissipation_available=variant.available,
            surface_layer_available=variant.closure == "surface_layer")
        for name in ("resolved_tke_shear_production",
                     "sgs_tke_shear_production",
                     "total_tke_shear_production",
                     "resolved_tke_buoyancy_production",
                     "sgs_tke_buoyancy_production",
                     "total_tke_buoyancy_production")
            @test name in variables
        end
        variant.closure == "surface_layer" && audit_surface_layer_series(series_path)
    end
end

println("diagnostic_adaptation_fixture_root=", root)
