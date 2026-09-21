using JLD2

function audit_resolved_factor_outputs(prefix, factor; check, require_nonzero_momentum=true)
    records(file) = sort([(time=Float64(file["timeseries/t/$key"]), key=String(key))
                         for key in keys(file["timeseries/t"])]; by=record -> record.time)
    times(path) = jldopen(file -> [r.time for r in records(file)], path, "r")
    initial_path = prefix * "_initial.jld2"
    statistics_path = prefix * "_statistics.jld2"
    series_path = prefix * "_series.jld2"
    check(times(initial_path) == [0.0], "initial output schedule changed")
    # Oceananigans initializes every writer at t=0. This record is an exact
    # duplicate of the separate initial writer, not a zero-duration mean.
    check(times(statistics_path) == [0.0, 1800.0], "statistics initial/averaged schedule changed")
    check(times(series_path) == collect(0.0:60.0:1800.0), "series output schedule changed")
    jldopen(initial_path, "r") do initial
        jldopen(statistics_path, "r") do statistics
            ikey, skey = only(records(initial)).key, first(records(statistics)).key
            names(file) = Set(filter(name -> name ∉ ("t", "serialized"), String.(collect(keys(file["timeseries"])))))
            check(names(initial) == names(statistics), "initial/statistics variable sets differ")
            for name in names(initial)
                check(initial["timeseries/$name/$ikey"] == statistics["timeseries/$name/$skey"],
                      "statistics t=0 is not exact duplicate for $name")
            end
        end
    end
    for path in (initial_path, statistics_path, series_path)
        jldopen(path, "r") do file
            check(file["metadata/resolved_flux_factor"] == factor, "raw output factor metadata mismatch")
            path == series_path && return
            for record in records(file)
                key = record.key
                for stem in ("u_w", "v_w", "w_theta")
                    res = vec(file["timeseries/resolved_$(stem)_flux/$key"])
                    sgs = vec(file["timeseries/sgs_$(stem)_flux/$key"])
                    total = vec(file["timeseries/total_$(stem)_flux/$key"])
                    check(length(res) == length(sgs) == length(total) == 33, "flux lost native vertical faces")
                    check(all(isfinite, res) && all(isfinite, sgs) && all(isfinite, total), "nonfinite flux")
                    # Uniform initial wind has zero shear and zero SGS flux;
                    # the evolved 1800s profile must have active implicit transport.
                    if require_nonzero_momentum && path == statistics_path && record.time == 1800 && stem == "u_w"
                        check(abs(sgs[2]) > 1e-8, "supported implicit momentum flux is zero")
                    end
                    check(all(isapprox.(total[2:end-1], res[2:end-1] .+ sgs[2:end-1]; atol=5e-6, rtol=5e-5)), "unscaled flux partition failed")
                end
            end
        end
    end
    return nothing
end
