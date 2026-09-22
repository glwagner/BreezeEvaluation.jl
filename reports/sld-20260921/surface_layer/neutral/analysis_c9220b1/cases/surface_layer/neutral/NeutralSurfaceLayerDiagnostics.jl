module NeutralSurfaceLayerDiagnostics

export install_neutral_surface_layer_diagnostics!

using Oceananigans
using Oceananigans.AbstractOperations: Average
using Oceananigans.Fields: Field
using Oceananigans.Grids: Center, Face, znodes
using Oceananigans.OutputWriters: AbstractOutputWriter, write_output!
using Breeze: liquid_ice_potential_temperature

using ..GABLSDiagnostics
using ..SurfaceLayerDiagnostics

struct SkipInitialJLD2Writer{W, S, O} <: AbstractOutputWriter
    writer :: W
    schedule :: S
    outputs :: O
end

SkipInitialJLD2Writer(writer) =
    SkipInitialJLD2Writer(writer, writer.schedule, writer.outputs)

Oceananigans.initialize!(writer::SkipInitialJLD2Writer, model) =
    Oceananigans.initialize!(writer.writer, model)

Oceananigans.prognostic_state(writer::SkipInitialJLD2Writer) =
    Oceananigans.prognostic_state(writer.writer)

Oceananigans.restore_prognostic_state!(writer::SkipInitialJLD2Writer, state) =
    Oceananigans.restore_prognostic_state!(writer.writer, state)

Oceananigans.OutputWriters.reconcile_restored_output_schedule!(
    writer::SkipInitialJLD2Writer, model) =
        Oceananigans.OutputWriters.reconcile_restored_output_schedule!(
            writer.writer, model)

function Oceananigans.OutputWriters.write_output!(writer::SkipInitialJLD2Writer,
                                                   simulation::Simulation)
    iteration(simulation) == 0 && return nothing
    return write_output!(writer.writer, simulation)
end

mutable struct AveragingIntervalMidpointTime
    value :: Vector{Float64}
end

AveragingIntervalMidpointTime() = AveragingIntervalMidpointTime(zeros(1))

function (output::AveragingIntervalMidpointTime)(model)
    clock = model.clock
    output.value[1] = clock.iteration == 0 ? Float64(clock.time) :
                      Float64(clock.time - clock.last_Δt / 2)
    return output.value
end

plane_mean(field) = Field(Average(field; dims=(1, 2)))

function without_keys(named_tuple, excluded)
    retained = Tuple(name for name in keys(named_tuple) if name ∉ excluded)
    return NamedTuple{retained}(getproperty(named_tuple, name) for name in retained)
end

function initialize_file!(file, metadata, kind, interval, window, model)
    file["metadata/diagnostic_kind"] = kind
    file["metadata/output_interval_seconds"] = interval
    file["metadata/averaging_window_seconds"] = window
    file["coordinates/z_center_m"] = collect(
        znodes(model.grid, Center(), Center(), Center()))
    file["coordinates/z_face_m"] = collect(
        znodes(model.grid, Center(), Center(), Face()))
    file["coordinates/native_w_moment_location"] = "Face"
    file["coordinates/scalar_and_horizontal_velocity_location"] = "Center"
    for (name, value) in pairs(metadata)
        file["metadata/$(name)"] = value
    end
    return nothing
end

function build_neutral_diagnostics(model; prescribed_friction_velocity=0.5)
    base = GABLSDiagnostics.build_gabls_diagnostics(model;
        reference_temperature=300,
        surface_temperature_initial=300,
        surface_cooling_rate=0)
    inappropriate_series = (
        :surface_bulk_richardson_mean,
        :surface_bulk_richardson_maximum,
        :surface_stability_parameter_mean,
        :surface_stability_parameter_maximum,
        :surface_stability_cap_fraction,
        :surface_neutral_fallback_fraction,
        :surface_temperature)
    inappropriate_fields = (
        :surface_bulk_richardson,
        :surface_stability_parameter,
        :surface_stability_cap_mask,
        :surface_neutral_fallback_mask)
    base_series = without_keys(base.series_outputs, inappropriate_series)
    diagnostic_fields = without_keys(base.diagnostic_fields, inappropriate_fields)
    surface_layer = SurfaceLayerDiagnostics.surface_layer_diagnostic_outputs(model)

    u, v, _ = model.velocities
    theta = liquid_ice_potential_temperature(model)
    u_vertical_gradient = plane_mean(Field(∂z(u)))
    v_vertical_gradient = plane_mean(Field(∂z(v)))
    theta_vertical_gradient = plane_mean(Field(∂z(theta)))
    profile_outputs = merge(base.profile_outputs, (;
        u_vertical_gradient,
        v_vertical_gradient,
        theta_vertical_gradient,
        averaging_interval_midpoint_time_seconds=AveragingIntervalMidpointTime()),
        surface_layer.profiles)

    FT = eltype(model.grid)
    prescribed_friction_velocity = FT(prescribed_friction_velocity)
    prescribed_stress_magnitude = prescribed_friction_velocity^2
    series_outputs = merge(base_series, (;
        prescribed_friction_velocity=model -> prescribed_friction_velocity,
        prescribed_kinematic_stress_magnitude=model -> prescribed_stress_magnitude,
        prescribed_surface_heat_flux=model -> zero(FT)), surface_layer.series)

    metadata = merge(base.metadata, (;
        diagnostic_case="neutral fixed-stress atmospheric boundary layer",
        surface_law="prescribed fixed dynamic momentum-flux vector; no roughness/MOST law",
        prescribed_friction_velocity_m_s=prescribed_friction_velocity,
        prescribed_kinematic_stress_magnitude_m2_s2=prescribed_stress_magnitude,
        prescribed_surface_heat_flux_K_m_s=zero(FT),
        thermodynamic_surface_condition="zero default thermodynamic-density flux",
        profile_record_definition="true non-overlapping time average of instantaneous horizontal reductions",
        averaging_quadrature="right-Riemann accumulation; interval midpoint time integrates linear clock time exactly",
        averaged_writer_initialization="statistics writer suppresses Oceananigans' unconditional iteration-zero write without delaying accumulation",
        initial_profile_definition="separate instantaneous record at t=0",
        native_w_definition="w mean, variance, and third central moment remain on native vertical faces",
        fixed_stress_interpretation="diagnoses vertical transport under prescribed forcing; cannot assess surface-drag prediction",
        inappropriate_most_diagnostics_omitted=true,
        authorized_final_hour_source_times_seconds=(15000, 15600, 16200, 16800, 17400, 18000),
        authorized_penultimate_hour_source_times_seconds=(11400, 12000, 12600, 13200, 13800, 14400)),
        surface_layer.metadata)
    return (; profile_outputs, series_outputs, diagnostic_fields, metadata)
end

function install_neutral_surface_layer_diagnostics!(simulation;
        dir=".", prefix="neutral_surface_layer", profile_interval=600,
        series_interval=60, stop_time=18000, overwrite_files=true,
        prescribed_friction_velocity=0.5)
    diagnostics = build_neutral_diagnostics(simulation.model;
        prescribed_friction_velocity)
    profile_times = collect(profile_interval:profile_interval:stop_time)
    run_metadata = merge(diagnostics.metadata, (;
        expected_profile_times_seconds=profile_times,
        expected_profile_record_count=length(profile_times)))
    profile_init = (file, model) -> initialize_file!(
        file, run_metadata, "true_time_averaged_profiles",
        profile_interval, profile_interval, model)
    initial_init = (file, model) -> initialize_file!(
        file, run_metadata, "instantaneous_initial_profile", 0, 0, model)
    series_init = (file, model) -> initialize_file!(
        file, run_metadata, "instantaneous_reduced_series",
        series_interval, 0, model)

    profile_writer = JLD2Writer(
        simulation.model, diagnostics.profile_outputs;
        filename="$(prefix)_statistics.jld2", dir,
        schedule=AveragedTimeInterval(profile_interval;
            window=profile_interval, stride=1),
        with_halos=false, overwrite_files, init=profile_init)
    simulation.output_writers[:neutral_profiles] = SkipInitialJLD2Writer(profile_writer)
    simulation.output_writers[:neutral_initial] = JLD2Writer(
        simulation.model, diagnostics.profile_outputs;
        filename="$(prefix)_initial.jld2", dir,
        schedule=SpecifiedTimes([0.0]), with_halos=false,
        overwrite_files, init=initial_init)
    simulation.output_writers[:neutral_series] = JLD2Writer(
        simulation.model, diagnostics.series_outputs;
        filename="$(prefix)_series.jld2", dir,
        schedule=TimeInterval(series_interval), with_halos=false,
        overwrite_files, init=series_init)
    return diagnostics
end

end
