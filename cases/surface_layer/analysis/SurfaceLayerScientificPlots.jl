module SurfaceLayerScientificPlots

export comparison_profile, load_comparison_cases, plot_profile_comparison,
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

function plot_profile_comparison(directories, output_path;
                                 window=nothing, reference_path=nothing,
                                 near_wall_height=100.0)
    comparison = load_comparison_cases(directories)
    family = comparison.family
    window = isnothing(window) ? (family == "GABLS1" ? :final_hour : :paper_03_04utc) : window
    times = comparison_times(family, window)
    reference = if family == "GABLS1"
        isnothing(reference_path) && error("GABLS1 fixed 1 m reference JSON is required")
        JSON.parsefile(reference_path)
    else
        nothing
    end
    figure = Figure(size=(1550, 900), fontsize=17)
    title = family == "GABLS1" ? "GABLS1 final-hour matched comparison" :
            "GABLS3 03:00–04:00 UTC matched comparison"
    Label(figure[0, 1:3], "$title — source times $(first(times))–$(last(times)) s",
          fontsize=23)
    specs = (("u_mean", "Mean u (m s⁻¹)", "profile/u_mean"),
             ("total_u_w_flux", "Upward u flux (m² s⁻²)", "profile/uw_total"),
             ("w_variance", "Native-face w² (m² s⁻²)", "profile/w_variance"))
    for row in 1:2, column in 1:3
        variable, xlabel, _ = specs[column]
        axis = Axis(figure[row, column]; xlabel, ylabel=column == 1 ? "z (m)" : "",
                    title=row == 1 ? "Full depth" : "Near wall")
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
    Label(figure[3, 1:3],
          "Interior thick flux = resolved + explicit SGS; thin flux = resolved. Boundary flux is wall-prescribed. WENO numerical transport is unmeasured. " *
          "Archive flux above 300 m omitted because source exponents are suspect. Native Center/Face heights retained.",
          fontsize=13, tellwidth=false)
    Legend(figure[4, 1:3], figure[1, 1], orientation=:horizontal, nbanks=2)
    mkpath(dirname(output_path))
    save(output_path, figure)
    return output_path
end

function plot_surface_timeline(directories, output_path)
    comparison = load_comparison_cases(directories)
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
    Label(figure[0, 1], "$family admitted surface and boundary-layer evolution",
          fontsize=22)
    for (row, (variable, ylabel)) in enumerate(diagnostics)
        axis = Axis(figure[row, 1]; xlabel=row == 4 ? "time since 00:00 UTC (h)" : "",
                    ylabel)
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
        end
    end
    Legend(figure[5, 1], figure[1, 1], orientation=:horizontal)
    mkpath(dirname(output_path))
    save(output_path, figure)
    return output_path
end

end
