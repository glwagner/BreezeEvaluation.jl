using SHA, TOML
const ROOT=@__DIR__
manifest=TOML.parsefile(joinpath(ROOT,"files_sha256.toml"))
for (name,hash) in manifest["files"]
 @assert bytes2hex(open(sha256,joinpath(ROOT,name)))==hash "Snapshot hash mismatch: $name"
end
include("surface_layer/analysis/SurfaceLayerAnalysisData.jl")
using .SurfaceLayerAnalysisData
cases=vcat([readdir(joinpath(ROOT,"surface_layer/gabls1",d);join=true) for d in ("exports_0bfa03d","exports_e0655cf")]...)
@assert length(cases)==8
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
println("SLD_SNAPSHOT_INTEGRITY_VERIFIED files=",length(manifest["files"])," corrected_cases=4 historical_cases=4 historical_smagorinsky=1; old7156 flux exclusions preserved; run audit_corrected_fluxes.jl for corrected physical checks")
fd=joinpath(ROOT,"surface_layer/resolved_factor/exports_v2")
fc=[load_case_export(d) for d in readdir(fd;join=true)]
@assert length(fc)==2
for c in fc
 @assert c.series.time_s==collect(0.:60.:32400.)
 @assert sort(unique(r.time_s for r in c.profiles))==collect(0.:1800.:32400.)
end
println("FACTOR_SNAPSHOT_VERIFIED cases=2; use compare.jl for physical and paired-source audit")
