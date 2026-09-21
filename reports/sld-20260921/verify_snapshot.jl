using SHA, TOML
const ROOT=@__DIR__
manifest=TOML.parsefile(joinpath(ROOT,"files_sha256.toml"))
for (name,hash) in manifest["files"]
 @assert bytes2hex(open(sha256,joinpath(ROOT,name)))==hash "Snapshot hash mismatch: $name"
end
include("surface_layer/analysis/SurfaceLayerAnalysisData.jl")
using .SurfaceLayerAnalysisData
cases=readdir(joinpath(ROOT,"surface_layer/gabls1/exports_0bfa03d");join=true)
@assert length(cases)==4
for d in cases
 c=load_case_export(d)
 @assert length(c.series.time_s)==541
 @assert sort(unique(r.time_s for r in c.profiles))==collect(0.:1800.:32400.)
 @assert c.series.time_s[end]==32400.
end
@assert isfile(joinpath(ROOT,"surface_layer/gabls1/diagnostic_exclusions.md"))
h=joinpath(ROOT,"surface_layer/gabls1/historical_smagorinsky")
@assert read_wide_series(joinpath(h,"series.csv")).time_s==collect(0.:60.:32400.)
@assert sort(unique(r.time_s for r in read_long_profiles(joinpath(h,"profiles.csv"))))==collect(0.:1800.:32400.)
println("SLD_SNAPSHOT_INTEGRITY_VERIFIED files=",length(manifest["files"])," matched_cases=4 historical_smagorinsky=1; implicit SGS/total flux and dependent diagnostics EXCLUDED, not physically admitted")
