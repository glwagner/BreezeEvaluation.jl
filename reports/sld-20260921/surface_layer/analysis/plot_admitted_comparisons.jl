#!/usr/bin/env julia

include(joinpath(@__DIR__, "SurfaceLayerScientificPlots.jl"))
using .SurfaceLayerScientificPlots
using SHA

length(ARGS) == 7 || error(
    "usage: plot_admitted_comparisons.jl FAMILY OUTPUT_DIR FIXED_1M_JSON_OR_NONE CASE_DIR_1 CASE_DIR_2 CASE_DIR_3 CASE_DIR_4")

family, output_directory, reference_path = ARGS[1:3]
directories = ARGS[4:end]
family in ("GABLS1", "GABLS3") || error("family must be GABLS1 or GABLS3")
comparison = load_comparison_cases(directories)
comparison.family == family || error("requested family does not match admitted exports")
family == "GABLS1" && !isfile(reference_path) &&
    error("GABLS1 requires the fixed 1 m archive median JSON")
family == "GABLS3" && reference_path != "none" &&
    error("GABLS3 has no interchangeable GABLS1 reference; pass none")

mkpath(output_directory)
profile_path = joinpath(output_directory, lowercase(family) * "_sld_profiles.pdf")
scalar_path = joinpath(output_directory, lowercase(family) * "_sld_scalars.pdf")
moment_path = joinpath(output_directory, lowercase(family) * "_sld_moments.pdf")
timeline_path = joinpath(output_directory, lowercase(family) * "_sld_timeline.pdf")
closure_path = joinpath(output_directory, lowercase(family) * "_sld_closure.pdf")
plot_profile_comparison(directories, profile_path;
    reference_path=family == "GABLS1" ? reference_path : nothing)
plot_scalar_comparison(directories, scalar_path;
    reference_path=family == "GABLS1" ? reference_path : nothing)
plot_moment_comparison(directories, moment_path;
    reference_path=family == "GABLS1" ? reference_path : nothing)
plot_surface_timeline(directories, timeline_path;
    reference_path=family == "GABLS1" ? reference_path : nothing)
plot_closure_diagnostics(directories, closure_path)
section_path = joinpath(output_directory, lowercase(family) * "_sld_admitted_section.md")
open(section_path, "w") do io
    println(io, "## $family matched SurfaceLayerDiffusivity comparison")
    println(io)
    println(io, "Four completed cases were loaded through `load_case_export`, which verifies scientific admission and all exported artifact hashes. The comparison uses native Center/Face heights, never interpolated model levels. The matched control and three SLD variants share the frozen scientific source and paired initialization recorded in their manifests.")
    println(io)
    if family == "GABLS1"
        println(io, "Profiles are equal means of the true 30-minute records ending at 30600 and 32400 s. The fixed 1 m archive median is shown only on comparable panels; its upper-level momentum-flux values above 300 m are omitted because the historical source has apparent exponent damage. The archive is a reference ensemble, not exact truth.")
    else
        println(io, "Profiles are equal means of the twelve instantaneous records at 11100:300:14400 s (03:00–04:00 UTC); 10800 s is the left boundary, not a sample. No GABLS1 archive curves are used as GABLS3 observations.")
    end
    println(io)
    println(io, "At interior faces, thick momentum-flux curves show resolved plus explicitly modeled SGS flux; thin curves show the resolved share. The bottom boundary flux is wall-prescribed. This sum excludes unmeasured WENO numerical transport. Skewness is the ratio of window-mean native-face w³ and w², not a mean of instantaneous skewness. Missing/invalid boundary-layer heights are not converted to physical zero. These are single-seed comparisons, not sampling-uncertainty estimates.")
    println(io)
    println(io, "Plot-source SHA-256: `",
            bytes2hex(open(sha256, joinpath(@__DIR__, "SurfaceLayerScientificPlots.jl"))), "`.")
    if family == "GABLS1"
        println(io, "Fixed 1 m reference SHA-256: `",
                bytes2hex(open(sha256, reference_path)), "`.")
    end
    println(io)
    for directory in directories
        manifest = SurfaceLayerScientificPlots.SurfaceLayerAnalysisData.load_case_export(
            directory).manifest
        println(io, "- `", manifest["case_id"], "`: admitted manifest `",
                bytes2hex(open(sha256, joinpath(directory, "manifest.toml"))), "`.")
    end
    println(io)
    for path in (profile_path, scalar_path, moment_path, timeline_path, closure_path)
        png_path = splitext(path)[1] * ".png"
        println(io, "![", basename(png_path), "](", basename(png_path), ")")
        println(io)
        println(io, "[Vector figure](", basename(path), ") · PDF SHA-256 `",
                bytes2hex(open(sha256, path)), "` · PNG SHA-256 `",
                bytes2hex(open(sha256, png_path)), "`.")
        println(io)
    end
end
println("SLD_ADMITTED_PLOTS family=", family, " profiles=", profile_path,
        " scalars=", scalar_path, " moments=", moment_path,
        " timeline=", timeline_path, " closure=", closure_path,
        " section=", section_path)
