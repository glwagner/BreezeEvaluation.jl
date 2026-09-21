module SurfaceLayerScientificPlots

export comparison_profile, load_comparison_cases, plot_profile_comparison,
       plot_scalar_comparison, plot_moment_comparison, plot_closure_diagnostics,
       plot_surface_timeline

using CairoMakie
using JSON

include("SurfaceLayerAnalysisData.jl")
using .SurfaceLayerAnalysisData: load_case_export

const STYLES = (
    control=(color="#202020", linestyle=:solid, marker=:circle, label="Matched control"),
    t100_s1=(color="#0072B2", linestyle=:dash, marker=:rect, label="One face, 100 s"),
    t300_s1=(color="#D55E00", linestyle=:dot, marker=:utriangle, label="One face, 300 s"),
    t300_s2=(color="#CC79A7", linestyle=:dashdot, marker=:diamond, label="Two faces, 300 s"))

function variant(case_id)
    endswith(case_id, "_control") && return :control
    endswith(case_id, "_none") && return :control
    endswith(case_id, "_t100_s1") && return :t100_s1
    endswith(case_id, "_t300_s1") && return :t300_s1
    endswith(case_id, "_t300_s2") && return :t300_s2
    error("unrecognized matched SLD case ID: $case_id")
end

function load_comparison_cases(directories; require_four=true)
    isempty(directories) && error("no admitted case exports supplied")
    cases = [load_case_export(directory) for directory in directories]
    families = unique(case.manifest["case_family"] for case in cases)
    length(families) == 1 || error("GABLS1 and GABLS3 cannot share a comparison panel")
    family = only(families)
    family in ("GABLS1", "GABLS3") || error("unsupported family $family")
    variants = [variant(case.manifest["case_id"]) for case in cases]
    length(unique(variants)) == length(variants) || error("duplicate matched variant")
    bindings = [(case.manifest["provenance"]["source_freeze_manifest_sha256"],
                 case.manifest["provenance"]["scientific_registry_sha256"],
                 case.manifest["provenance"]["analysis_freeze"]["manifest_sha256"])
                for case in cases]
    length(unique(bindings)) == 1 || error("matched cases use different frozen sources")
    all(case.manifest["grid"] == first(cases).manifest["grid"] for case in cases) ||
        error("matched cases use different grids")
    if require_four
        Set(variants) == Set(keys(STYLES)) || error("comparison requires all four matched cases")
    end
    return (; family, cases=sort(cases; by=case -> findfirst(==(
        variant(case.manifest["case_id"])), keys(STYLES))))
end

function comparison_times(family, window)
    if family == "GABLS1"
        window == :final_hour && return [30600.0, 32400.0]
        window == :penultimate_hour && return [27000.0, 28800.0]
    elseif family == "GABLS3"
        window == :paper_03_04utc && return collect(11100.0:300.0:14400.0)
    end
    error("unsupported $family comparison window $window")
end

function comparison_profile(case, variable, times)
    selected = [record for record in case.profiles if
                record.variable == variable && record.time_s in times]
    isempty(selected) && error("missing profile $variable for $(case.manifest["case_id"])")
    sort(unique(record.time_s for record in selected)) == sort(times) ||
        error("incomplete $variable comparison window")
    locations = unique(record.location for record in selected)
    units = unique(record.units for record in selected)
    length(locations) == 1 && length(units) == 1 ||
        error("inconsistent native location or units for $variable")
    coordinates = sort(unique(record.z_m for record in selected))
    values = Float64[]
    for height in coordinates
        samples = [record.value for record in selected if record.z_m == height]
        length(samples) == length(times) || error("missing height $height in $variable")
        push!(values, sum(samples) / length(samples))
    end
    return (; z_m=coordinates, value=values, location=only(locations),
            units=only(units), source_times_s=times)
end

function reference_curve(reference, variable; maximum_height=Inf)
    curves = reference["curves"]
    key = "profile/" * variable
    haskey(curves, key) || return nothing
    curve = curves[key]
    indices = [i for i in eachindex(curve["coordinates"]) if
               curve["coordinates"][i] <= maximum_height &&
               curve["median"][i] !== nothing && curve["member_count"][i] > 0]
    isempty(indices) && return nothing
    return (; z_m=Float64[curve["coordinates"][i] for i in indices],
            value=Float64[curve["median"][i] for i in indices])
end

function reference_series(reference, variable)
    key = "series/" * variable
    haskey(reference["curves"], key) || return nothing
    curve = reference["curves"][key]
    indices = [i for i in eachindex(curve["coordinates"]) if
               curve["median"][i] !== nothing && curve["member_count"][i] > 0]
    isempty(indices) && return nothing
    return (; time_s=Float64[curve["coordinates"][i] for i in indices],
            value=Float64[curve["median"][i] for i in indices])
end

function comparison_profile(case, variable::Symbol, times)
    variable == :w_skewness_ratio_of_means || error("unsupported derived profile")
    variance = comparison_profile(case, "w_variance", times)
    third = comparison_profile(case, "w_third_central_moment", times)
    variance.z_m == third.z_m && variance.location == "Face" &&
        third.location == "Face" || error("native-face moment coordinates mismatch")
    values = [a > 1e-8 ? b / a^1.5 : NaN for (a, b) in
              zip(variance.value, third.value)]
    return (; z_m=variance.z_m, value=values, location="Face", units="1",
            source_times_s=times)
end

function add_profile!(axis, case, variable, times; component=:total)
    profile = comparison_profile(case, variable, times)
    style = getproperty(STYLES, variant(case.manifest["case_id"]))
    linewidth = component == :total ? 2.8 : 1.2
    alpha = component == :total ? 1.0 : 0.65
    label = component == :total ? style.label : nothing
    lines!(axis, profile.value, profile.z_m; color=(style.color, alpha),
           linestyle=component == :total ? style.linestyle : :solid,
           linewidth, label)
    if component == :total
        indices = 1:max(1, cld(length(profile.z_m), 8)):length(profile.z_m)
        scatter!(axis, profile.value[indices], profile.z_m[indices];
                 color=style.color, marker=style.marker, markersize=7)
    end
    return profile
end

function add_reference!(axis, reference, variable; maximum_height=Inf)
    curve = reference_curve(reference, variable; maximum_height)
    isnothing(curve) && return nothing
    lines!(axis, curve.value, curve.z_m; color=:black, linestyle=:dot,
           linewidth=2.4, label="Fixed 1 m archive median")
    return curve
end

function render_profile_comparison(comparison, output_path;
                                   window=nothing, reference=nothing,
                                   near_wall_height=100.0, fixture=false)
    family = comparison.family
    window = isnothing(window) ? (family == "GABLS1" ? :final_hour : :paper_03_04utc) : window
    times = comparison_times(family, window)
    figure = Figure(size=(1550, 900), fontsize=17)
    title = family == "GABLS1" ?
        "GABLS1 $(window == :final_hour ? "final" : "penultimate")-hour matched comparison" :
        "GABLS3 03:00–04:00 UTC matched comparison"
    fixture && (title = "NON-SCIENTIFIC layout fixture — " * title)
    Label(figure[0, 1:3], "$title — source times $(first(times))–$(last(times)) s",
          fontsize=23)
    specs = (("u_mean", "Mean u (m s⁻¹)", "profile/u_mean"),
             ("total_u_w_flux", "Upward u flux (m² s⁻²)", "profile/uw_total"),
             ("w_variance", "Native-face w² (m² s⁻²)", "profile/w_variance"))
    first_axis = nothing
    for row in 1:2, column in 1:3
        variable, xlabel, _ = specs[column]
        axis = Axis(figure[row, column]; xlabel, ylabel=column == 1 ? "z (m)" : "",
                    title=row == 1 ? "Full depth" : "Near wall")
        row == 1 && column == 1 && (first_axis = axis)
        row == 2 && ylims!(axis, 0, near_wall_height)
        for case in comparison.cases
            profile = add_profile!(axis, case, variable, times)
            if column == 2
                # The thinner line is the resolved share. Difference from the
                # thick total line is the explicit SGS contribution, not WENO transport.
                add_profile!(axis, case, "resolved_u_w_flux", times; component=:resolved)
            end
            expected_location = column == 1 ? "Center" : "Face"
            profile.location == expected_location ||
                error("$variable is at $(profile.location), expected $expected_location")
        end
        if !isnothing(reference)
            reference_variable = column == 2 ? "uw_total" : variable
            maximum_height = column == 2 ? 300.0 : Inf
            add_reference!(axis, reference, reference_variable; maximum_height)
        end
        if row == 1
            axis.title = "$(specs[column][2])"
        end
    end
    caveat = "Interior thick flux = resolved + explicit SGS; thin flux = resolved. " *
             "Boundary flux is wall-prescribed. WENO numerical transport is unmeasured. " *
             "Native Center/Face heights retained."
    family == "GABLS1" &&
        (caveat *= " Archive momentum-flux reference above 300 m omitted due to suspected source exponent damage.")
    Label(figure[3, 1:3], caveat,
          fontsize=13, tellwidth=false)
    Legend(figure[4, 1:3], first_axis, orientation=:horizontal, nbanks=2)
    mkpath(dirname(output_path))
    save(output_path, figure)
    endswith(lowercase(output_path), ".pdf") &&
        save(splitext(output_path)[1] * ".png", figure)
    return output_path
end

function plot_profile_comparison(directories, output_path;
                                 window=nothing, reference_path=nothing,
                                 near_wall_height=100.0)
    comparison = load_comparison_cases(directories)
    reference = load_reference(comparison.family, reference_path)
    return render_profile_comparison(comparison, output_path;
                                     window, reference, near_wall_height)
end

function load_reference(family, path)
    family == "GABLS3" && return nothing
    isnothing(path) && error("GABLS1 fixed 1 m reference JSON is required")
    return JSON.parsefile(path)
end

function render_surface_timeline(comparison, output_path; reference=nothing, fixture=false)
    family = comparison.family
    diagnostics = family == "GABLS1" ?
        (("friction_velocity", "u* (m s⁻¹)"),
         ("surface_theta_kinematic_flux", "Surface wθ (K m s⁻¹)"),
         ("boundary_layer_height", "Boundary-layer height (m)")) :
        (("friction_velocity", "u* (m s⁻¹)"),
         ("surface_theta_kinematic_flux", "Surface wθ (K m s⁻¹)"),
         ("surface_q_kinematic_flux", "Surface wq (m s⁻¹)"))
    activity = "surface_layer_face1_momentum_active_fraction"
    diagnostics = (diagnostics..., (activity, "Face-1 momentum active fraction"))
    figure = Figure(size=(1450, 1150), fontsize=17)
    title = fixture ? "NON-SCIENTIFIC layout fixture" : "admitted comparison"
    Label(figure[0, 1], "$family $title: surface and boundary-layer evolution",
          fontsize=22)
    first_axis = nothing
    for (row, (variable, ylabel)) in enumerate(diagnostics)
        xlabel = family == "GABLS1" ? "elapsed time since start (h)" :
                 "time since 00:00 UTC (h)"
        axis = Axis(figure[row, 1]; xlabel=row == 4 ? xlabel : "",
                    ylabel)
        row == 1 && (first_axis = axis)
        for case in comparison.cases
            if variable == activity && variant(case.manifest["case_id"]) == :control
                continue
            end
            haskey(case.series.values, variable) || error("missing series $variable")
            style = getproperty(STYLES, variant(case.manifest["case_id"]))
            values = copy(case.series.values[variable])
            if variable == "boundary_layer_height"
                valid = case.series.values["boundary_layer_height_valid"]
                length(valid) == length(values) || error("boundary-layer validity length mismatch")
                values[valid .== 0] .= NaN
            end
            lines!(axis, case.series.time_s ./ 3600, values;
                   color=style.color, linestyle=style.linestyle, linewidth=2.4,
                   label=style.label)
            indices = 1:max(1, cld(length(case.series.time_s), 10)):length(case.series.time_s)
            scatter!(axis, case.series.time_s[indices] ./ 3600,
                     values[indices];
                     color=style.color, marker=style.marker, markersize=6)
        end
        if family == "GABLS3"
            vlines!(axis, [6.0]; color=(:gray, 0.55), linestyle=:dash)
        elseif !isnothing(reference)
            key = variable == "friction_velocity" ? "ustar" :
                  variable == "surface_theta_kinematic_flux" ? "surface_theta_flux" :
                  variable == "boundary_layer_height" ? "boundary_layer_height" : nothing
            if !isnothing(key)
                curve = reference_series(reference, key)
                if isnothing(curve)
                    text!(axis, 0.98, 0.95; text="1 m reference unavailable",
                          space=:relative, align=(:right, :top), color=:gray45)
                else
                    lines!(axis, curve.time_s ./ 3600, curve.value;
                           color=:black, linestyle=:dot, linewidth=2.4,
                           label="Fixed 1 m archive median")
                end
            end
        end
    end
    Legend(figure[5, 1], first_axis, orientation=:horizontal)
    mkpath(dirname(output_path))
    save(output_path, figure)
    endswith(lowercase(output_path), ".pdf") &&
        save(splitext(output_path)[1] * ".png", figure)
    return output_path
end

function plot_surface_timeline(directories, output_path; reference_path=nothing)
    comparison = load_comparison_cases(directories)
    reference = load_reference(comparison.family, reference_path)
    return render_surface_timeline(comparison, output_path; reference)
end

function save_figure(output_path, figure)
    mkpath(dirname(output_path))
    save(output_path, figure)
    endswith(lowercase(output_path), ".pdf") &&
        save(splitext(output_path)[1] * ".png", figure)
    return output_path
end

function render_companion_profiles(comparison, output_path, specs;
                                   window=nothing, reference=nothing,
                                   near_wall_height=100.0, heading="", fixture=false)
    family = comparison.family
    window = isnothing(window) ? (family == "GABLS1" ? :final_hour : :paper_03_04utc) : window
    times = comparison_times(family, window)
    columns = length(specs)
    figure = Figure(size=(max(1100, 470 * columns), 900), fontsize=17)
    period = family == "GABLS1" ?
        (window == :final_hour ? "final hour" : "penultimate hour") :
        "03:00–04:00 UTC"
    prefix = fixture ? "NON-SCIENTIFIC layout fixture — " : ""
    Label(figure[0, 1:columns],
          "$prefix$family $period $heading — source times $(first(times))–$(last(times)) s",
          fontsize=23)
    first_axis = nothing
    for row in 1:2, (column, spec) in enumerate(specs)
        axis = Axis(figure[row, column]; xlabel=spec.xlabel,
                    ylabel=column == 1 ? "z (m)" : "",
                    title=row == 1 ? "Full depth" : "Near wall")
        row == 1 && column == 1 && (first_axis = axis)
        row == 2 && ylims!(axis, 0, near_wall_height)
        for case in comparison.cases
            profile = add_profile!(axis, case, spec.variable, times)
            profile.location == spec.location ||
                error("$(spec.variable) is at $(profile.location), expected $(spec.location)")
            if hasproperty(spec, :resolved) && !isnothing(spec.resolved)
                add_profile!(axis, case, spec.resolved, times; component=:resolved)
            end
        end
        if !isnothing(reference)
            curve = add_reference!(axis, reference, spec.reference;
                                   maximum_height=spec.reference_maximum_height)
            isnothing(curve) && text!(axis, 0.98, 0.95;
                text="1 m reference unavailable", space=:relative,
                align=(:right, :top), color=:gray45)
        end
        row == 1 && (axis.title = spec.xlabel)
    end
    caveat = family == "GABLS1" ?
        "Black dotted: fixed 1 m archive median where available; gaps remain gaps. " :
        "No interchangeable GABLS1 reference is used for GABLS3. "
    caveat *= "Native Center/Face heights and physical units are retained."
    Label(figure[3, 1:columns], caveat; fontsize=13, tellwidth=false)
    Legend(figure[4, 1:columns], first_axis; orientation=:horizontal, nbanks=2)
    return save_figure(output_path, figure)
end

function scalar_specs(family)
    theta = (variable="theta_mean", xlabel="Mean θ (K)", location="Center",
             reference="theta_mean", reference_maximum_height=Inf,
             resolved=nothing)
    theta_flux = (variable="total_w_theta_flux", xlabel="Upward wθ (K m s⁻¹)",
                  location="Face", reference="wtheta_total",
                  reference_maximum_height=Inf, resolved="resolved_w_theta_flux")
    if family == "GABLS1"
        transverse = (variable="total_v_w_flux", xlabel="Upward v flux (m² s⁻²)",
                      location="Face", reference="vw_total",
                      reference_maximum_height=300.0, resolved="resolved_v_w_flux")
        return (theta, theta_flux, transverse)
    else
        moisture = (variable="q_mean", xlabel="Mean qᵗ (kg kg⁻¹)", location="Center",
                    reference="", reference_maximum_height=Inf, resolved=nothing)
        moisture_flux = (variable="total_w_q_flux", xlabel="Upward wqᵗ (m s⁻¹)",
                         location="Face", reference="", reference_maximum_height=Inf,
                         resolved="resolved_w_q_flux")
        return (theta, theta_flux, moisture, moisture_flux)
    end
end

function plot_scalar_comparison(directories, output_path;
                                window=nothing, reference_path=nothing)
    comparison = load_comparison_cases(directories)
    reference = load_reference(comparison.family, reference_path)
    return render_companion_profiles(comparison, output_path,
        scalar_specs(comparison.family); window, reference,
        heading="thermodynamics and scalar flux")
end

function moment_specs()
    return ((variable="w_variance", xlabel="Native-face w² (m² s⁻²)",
             location="Face", reference="w_variance",
             reference_maximum_height=Inf, resolved=nothing),
            (variable="w_third_central_moment", xlabel="Native-face w³ (m³ s⁻³)",
             location="Face", reference="w_third_central_moment",
             reference_maximum_height=Inf, resolved=nothing),
            (variable=:w_skewness_ratio_of_means,
             xlabel="w³ / (w²)³ᐟ² (ratio of window means)", location="Face",
             reference="w_skewness", reference_maximum_height=Inf,
             resolved=nothing))
end

function plot_moment_comparison(directories, output_path;
                                window=nothing, reference_path=nothing)
    comparison = load_comparison_cases(directories)
    reference = load_reference(comparison.family, reference_path)
    return render_companion_profiles(comparison, output_path, moment_specs();
        window, reference, heading="native-face vertical-velocity moments")
end

function closure_specs(family)
    face = "surface_layer_face1_"
    theta = face * "ρθ_"
    moisture = face * "ρqᵉ_"
    third_deficit = family == "GABLS3" ? moisture * "deficit" :
                    "surface_layer_face2_momentum_deficit"
    third_active = family == "GABLS3" ? moisture * "active_fraction" :
                   "surface_layer_face2_momentum_active_fraction"
    third_cap = family == "GABLS3" ? moisture * "cap_fraction" :
                "surface_layer_face2_viscosity_cap_fraction"
    return ((face * "viscosity", "Face-1 ν (m² s⁻¹)"),
            ("surface_layer_face2_viscosity", "Face-2 ν (m² s⁻¹)"),
            (theta * "diffusivity", "Face-1 θ κ (m² s⁻¹)"),
            (face * "momentum_deficit", "Face-1 momentum deficit (m² s⁻²)"),
            (theta * "deficit", "Face-1 θ deficit (K m s⁻¹)"),
            (third_deficit, family == "GABLS3" ?
                "Face-1 q deficit (m s⁻¹)" : "Face-2 momentum deficit (m² s⁻²)"),
            (face * "momentum_active_fraction", "Face-1 momentum active"),
            (theta * "active_fraction", "Face-1 θ active"),
            (third_active, family == "GABLS3" ?
                "Face-1 q active" : "Face-2 momentum active"),
            (face * "viscosity_cap_fraction", "Face-1 viscosity cap"),
            (theta * "cap_fraction", "Face-1 θ diffusivity cap"),
            (third_cap, family == "GABLS3" ?
                "Face-1 q diffusivity cap" : "Face-2 viscosity cap"))
end

function render_closure_diagnostics(comparison, output_path; fixture=false)
    family = comparison.family
    specs = closure_specs(family)
    figure = Figure(size=(1700, 1650), fontsize=15)
    prefix = fixture ? "NON-SCIENTIFIC layout fixture — " : ""
    Label(figure[0, 1:3], "$prefix$family SLD coefficients, deficits, activity and caps";
          fontsize=22)
    first_axis = nothing
    for (index, (variable, ylabel)) in enumerate(specs)
        row = cld(index, 3)
        column = mod1(index, 3)
        axis = Axis(figure[row, column];
                    xlabel=row == 4 ? (family == "GABLS1" ?
                        "elapsed time (h)" : "time since 00:00 UTC (h)") : "",
                    ylabel)
        index == 1 && (first_axis = axis)
        for case in comparison.cases
            variant(case.manifest["case_id"]) == :control && continue
            haskey(case.series.values, variable) || error("missing SLD diagnostic $variable")
            style = getproperty(STYLES, variant(case.manifest["case_id"]))
            lines!(axis, case.series.time_s ./ 3600, case.series.values[variable];
                   color=style.color, linestyle=style.linestyle,
                   linewidth=2.2, label=style.label)
        end
        family == "GABLS3" && vlines!(axis, [6.0];
            color=(:gray, 0.55), linestyle=:dash)
    end
    Label(figure[5, 1:3],
          "Face-2 values require support weight > 0; one-face variants have no active face-2 closure. " *
          "Zero active fraction is not a valid scalar-flux measurement. Exact support heights/weights and guards are in each admitted manifest.";
          fontsize=13, tellwidth=false)
    Legend(figure[6, 1:3], first_axis; orientation=:horizontal)
    return save_figure(output_path, figure)
end

function plot_closure_diagnostics(directories, output_path)
    comparison = load_comparison_cases(directories)
    return render_closure_diagnostics(comparison, output_path)
end

end
