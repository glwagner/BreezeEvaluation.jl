module GABLS1SurfaceLayerDiagnostics

export install_gabls1_surface_layer_diagnostics!

using Oceananigans
using Oceananigans.Units: minute, minutes

using ..GABLSDiagnostics
using ..SurfaceLayerDiagnostics

function initialize_file!(file, metadata, kind, interval, window)
    file["metadata/diagnostic_kind"] = kind
    file["metadata/output_interval_seconds"] = interval
    file["metadata/averaging_window_seconds"] = window
    for (name, value) in pairs(metadata)
        file["metadata/$(name)"] = value
    end
    return nothing
end

function install_gabls1_surface_layer_diagnostics!(simulation;
                                                    dir=".",
                                                    prefix="gabls1_surface_layer",
                                                    profile_interval=30minutes,
                                                    series_interval=1minute,
                                                    overwrite_files=true,
                                                    kwargs...)
    base = GABLSDiagnostics.build_gabls_diagnostics(simulation.model; kwargs...)
    surface_layer = SurfaceLayerDiagnostics.surface_layer_diagnostic_outputs(simulation.model)
    profile_outputs = merge(base.profile_outputs, surface_layer.profiles)
    series_outputs = merge(base.series_outputs, surface_layer.series)
    metadata = merge(base.metadata, surface_layer.metadata, (;
        resolved_flux_factor=hasproperty(simulation.model.closure, :resolved_flux_factor) ?
            simulation.model.closure.resolved_flux_factor : 1.0,
        resolved_flux_factor_scope="closure deficit only; physical covariance and diagnostic fluxes are unscaled",
        resolved_transport=hasproperty(simulation.model.closure, :resolved_transport) ?
            (simulation.model.closure.resolved_transport isa Val{:scheme_native} ?
                "scheme_native" : "covariance") : "none",
        diagnostic_case="GABLS1 matched SurfaceLayerDiffusivity evaluation",
        sgs_flux_diagnostic_definition="For SurfaceLayerDiffusivity, evaluate the full constitutive vertical flux with explicit-discretization operators for output only; the model retains vertically implicit diffusion",
        initial_profile_definition="separate instantaneous record at t=0",
        averaged_profile_definition="true non-overlapping 30-minute averages",
        required_final_hour_source_times_seconds=(30600, 32400),
        required_penultimate_hour_source_times_seconds=(27000, 28800)))

    profile_init = (file, model) -> initialize_file!(
        file, metadata, "true_time_averaged_profiles", profile_interval, profile_interval)
    initial_init = (file, model) -> initialize_file!(
        file, metadata, "instantaneous_initial_profile", 0, 0)
    series_init = (file, model) -> initialize_file!(
        file, metadata, "instantaneous_reduced_series", series_interval, 0)

    simulation.output_writers[:gabls1_surface_layer_profiles] = JLD2Writer(
        simulation.model, profile_outputs;
        filename="$(prefix)_statistics.jld2", dir,
        schedule=AveragedTimeInterval(profile_interval; window=profile_interval, stride=1),
        with_halos=false, overwrite_files, init=profile_init)

    simulation.output_writers[:gabls1_surface_layer_initial] = JLD2Writer(
        simulation.model, profile_outputs;
        filename="$(prefix)_initial.jld2", dir,
        schedule=SpecifiedTimes([0.0]), with_halos=false,
        overwrite_files, init=initial_init)

    simulation.output_writers[:gabls1_surface_layer_series] = JLD2Writer(
        simulation.model, series_outputs;
        filename="$(prefix)_series.jld2", dir,
        schedule=TimeInterval(series_interval), with_halos=false,
        overwrite_files, init=series_init)

    return (; profile_outputs, series_outputs, metadata,
            diagnostic_fields=base.diagnostic_fields)
end

end
