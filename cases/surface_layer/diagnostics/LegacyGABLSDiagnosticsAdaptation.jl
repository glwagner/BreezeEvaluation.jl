module LegacyGABLSDiagnosticsAdaptation

export load_adapted_gabls_diagnostics!

using SHA

const EXPECTED_SOURCE_SHA256 =
    "6486c8ccd94f45df1c204fc57d1f3c0a79b8c4f3c27b3412c1b2bb81573e0c24"

const ORIGINAL_OPTIONAL_DISSIPATION = """function optional_sgs_dissipation(model)
    if isnothing(model.closure)
        zero_dissipation = plane_mean(0 * Field(@at (C, C, C) model.velocities.w))
        return (; sgs_resolved_tke_dissipation=zero_dissipation,
                  available=false)
    end

    hasproperty(model.closure_fields, :νₑ) || return (; profiles=NamedTuple(), available=false)
    u, v, w = model.velocities
    operation = KernelFunctionOperation{C, C, C}(
        eddy_viscosity_dissipation, model.grid, model.closure_fields.νₑ, u, v, w)
    dissipation = plane_mean(Field(operation))
    return (; sgs_resolved_tke_dissipation=dissipation, available=true)
end"""

const ADAPTED_OPTIONAL_DISSIPATION = """function optional_sgs_dissipation(model)
    if isnothing(model.closure)
        zero_dissipation = plane_mean(0 * Field(@at (C, C, C) model.velocities.w))
        return (; profiles=(; sgs_resolved_tke_dissipation=zero_dissipation),
                  available=false)
    end

    hasproperty(model.closure_fields, :νₑ) ||
        return (; profiles=NamedTuple(), available=false)
    u, v, w = model.velocities
    operation = KernelFunctionOperation{C, C, C}(
        eddy_viscosity_dissipation, model.grid, model.closure_fields.νₑ, u, v, w)
    dissipation = plane_mean(Field(operation))
    return (; profiles=(; sgs_resolved_tke_dissipation=dissipation), available=true)
end"""

const ORIGINAL_PROFILE_ENTRY =
    "sgs_resolved_tke_dissipation=sgs_dissipation.sgs_resolved_tke_dissipation,"
const ADAPTED_PROFILE_ENTRY = "sgs_dissipation.profiles...,"

# The frozen helper evaluates SGS fluxes via the explicit-tendency path. For a vertically
# implicit SLD closure, Oceananigans elides the interior vertical flux from that path;
# the constitutive flux is still applied by the implicit solver. This adaptation changes
# only diagnostic evaluation, never the model closure or its time discretization.
const SGS_DIAGNOSTIC_IMPORT = """using Breeze.TurbulenceClosures: SurfaceLayerDiffusivity
using Oceananigans.TurbulenceClosures: ExplicitTimeDiscretization

@inline diagnostic_sgs_discretization(closure) = time_discretization(closure)
@inline diagnostic_sgs_discretization(::SurfaceLayerDiffusivity) = ExplicitTimeDiscretization()

"""

const SGS_DIAGNOSTIC_CALLS = (
    "@inline function scalar_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                                 id, scalar, clock, model_fields, buoyancy)\n" *
    "    discretization = time_discretization(closure)" =>
    "@inline function scalar_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                                 id, scalar, clock, model_fields, buoyancy)\n" *
    "    discretization = diagnostic_sgs_discretization(closure)",
    "@inline function u_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                            clock, model_fields)\n" *
    "    discretization = time_discretization(closure)" =>
    "@inline function u_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                            clock, model_fields)\n" *
    "    discretization = diagnostic_sgs_discretization(closure)",
    "@inline function v_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                            clock, model_fields)\n" *
    "    discretization = time_discretization(closure)" =>
    "@inline function v_sgs_flux(i, j, k, grid, density, closure, closure_fields,\n" *
    "                            clock, model_fields)\n" *
    "    discretization = diagnostic_sgs_discretization(closure)")

const TKE_PRODUCTION_PROFILE_ADAPTATIONS = (
    "Field(@at (C, C, C) resolved_shear_production_face)" =>
        "plane_mean(Field(@at (C, C, C) resolved_shear_production_face))",
    "Field(@at (C, C, C) sgs_shear_production_face)" =>
        "plane_mean(Field(@at (C, C, C) sgs_shear_production_face))",
    "Field(@at (C, C, C) total_shear_production_face)" =>
        "plane_mean(Field(@at (C, C, C) total_shear_production_face))",
    "Field(@at (C, C, C) resolved_buoyancy_flux)" =>
        "plane_mean(Field(@at (C, C, C) resolved_buoyancy_flux))",
    "Field(@at (C, C, C) sgs_buoyancy_flux_profile)" =>
        "plane_mean(Field(@at (C, C, C) sgs_buoyancy_flux_profile))",
    "Field(@at (C, C, C) total_buoyancy_flux)" =>
        "plane_mean(Field(@at (C, C, C) total_buoyancy_flux))")

function replace_once(source, original, replacement, label)
    matches = findall(original, source)
    length(matches) == 1 ||
        error("expected exactly one $label adaptation site, found $(length(matches))")
    return replace(source, original => replacement; count=1)
end

function load_adapted_gabls_diagnostics!(parent::Module, source_path)
    source_hash = bytes2hex(open(sha256, source_path))
    source_hash == EXPECTED_SOURCE_SHA256 ||
        error("frozen GABLS diagnostic hash mismatch: $source_hash")
    source = read(source_path, String)
    adapted = replace_once(source, ORIGINAL_OPTIONAL_DISSIPATION,
                           ADAPTED_OPTIONAL_DISSIPATION, "optional dissipation")
    adapted = replace_once(adapted, ORIGINAL_PROFILE_ENTRY,
                           ADAPTED_PROFILE_ENTRY, "profile tuple")
    adapted = replace_once(adapted, "const C = Center",
                           SGS_DIAGNOSTIC_IMPORT * "const C = Center",
                           "physical SGS diagnostic dispatch")
    for (index, adaptation) in enumerate(SGS_DIAGNOSTIC_CALLS)
        adapted = replace_once(adapted, first(adaptation), last(adaptation),
                               "physical SGS diagnostic call $index")
    end
    for (index, adaptation) in enumerate(TKE_PRODUCTION_PROFILE_ADAPTATIONS)
        adapted = replace_once(adapted, first(adaptation), last(adaptation),
                               "TKE production profile reduction $index")
    end
    Base.include_string(parent, adapted, source_path * "#surface-layer-adapted")
    return (; source_hash, adaptation_count=12)
end

end
