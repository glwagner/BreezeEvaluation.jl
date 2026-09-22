using SHA, TOML
include("SurfaceLayerAnalysisData.jl")
using .SurfaceLayerAnalysisData
const ROOT = normpath(joinpath(@__DIR__, ".."))
sha(path) = bytes2hex(open(sha256, path))
const SOURCE_SHA = "32ebced6c54266ce5f9d7300759635e51d599bc1b090ced070eaa6111e540b0f"
const GPU_SHA = "4d9e203c5c25f8f98d9ea6fe89419f9a647556996e009fdee30f2490fe738b01"
const CPU_SHA = "5262822d0358d2deb473cadfbe545b9db6cf0c98e4f2b23fb80ee76565083f28"
const REGISTRY_SHA = "d1f4e56ed705ce035207d9900e8da441cb8f4d3a06a283acaa4958e08f314519"
const ID = "gabls1_n032_weno9_surface_layer_t300_s1_rf10p0"
source_manifest = joinpath(@__DIR__, "source_sha256.txt")
@assert sha(source_manifest) == SOURCE_SHA
for name in ("SurfaceLayerAnalysisData.jl", "SurfaceLayerScientificPlots.jl")
    line = only(filter(line -> endswith(line, "source/BreezeEvaluation.jl/cases/surface_layer/analysis/$name"), readlines(source_manifest)))
    @assert sha(joinpath(@__DIR__, name)) == first(split(line))
end
collection = TOML.parsefile(joinpath(ROOT, "collection_v2/manifest.toml"))
@assert collection["admitted_count"] == 1 && collection["rejected_count"] == 0
entry = only(collection["admitted"])
@assert entry["case_id"] == ID
directory = joinpath(ROOT, "exports_v2", ID)
@assert sha(joinpath(directory, "manifest.toml")) == entry["manifest_sha256"]
@assert sha(joinpath(@__DIR__, "attempts.toml")) == collection["attempt_registry_sha256"]
attempts = TOML.parsefile(joinpath(@__DIR__, "attempts.toml"))
@assert attempts["source_evaluation_commit"] == "cbe90cee275866f742275127de95b6148d2a4653"
@assert attempts["source_breeze_commit"] == "1df78f2bb94db159e3a296f7439e1a5e90286014"
attempt = only(attempts["attempts"])
@assert attempt["batch_child_exit_code"] == 0
@assert sha(joinpath(ROOT, "logs_v2", basename(attempt["batch_exit_record_path"]))) == attempt["batch_exit_record_sha256"]
@assert sha(joinpath(ROOT, "logs_v2", basename(attempt["log_path"]))) == attempt["log_sha256"]
for (kind, expected, prefix) in (("gpu", GPU_SHA, "GPU"), ("cpu", CPU_SHA, "CPU"))
    @assert sha(joinpath(ROOT, "evidence_v2", kind, "validation_evidence.toml")) == expected
    done = read(joinpath(ROOT, "evidence_v2", kind, "$(prefix)_VALIDATION_DONE"), String)
    @assert occursin("evidence_sha256=$expected", done)
    evidence = TOML.parsefile(joinpath(ROOT, "evidence_v2", kind, "validation_evidence.toml"))
    @assert evidence["all_passed"] && evidence["factors"] == [10.0]
    @assert evidence["freeze_source_manifest_sha256"] == SOURCE_SHA
end
c = load_case_export(directory)
p = c.manifest["provenance"]
@assert p["source_freeze_manifest_sha256"] == p["analysis_freeze"]["manifest_sha256"] == SOURCE_SHA
@assert p["scientific_registry_sha256"] == REGISTRY_SHA
@assert p["gpu_validation"]["evidence_sha256"] == GPU_SHA
@assert p["scientific_case_settings"]["resolved_flux_factor"] == 10
@assert p["scientific_case_settings"]["support"] == 1
@assert p["scientific_case_settings"]["filter_seconds"] == 300
@assert p["completion"]["final_time_s"] == 32400
for kind in ("initial", "profiles", "series")
    @assert c.manifest["raw_metadata"][kind]["resolved_flux_factor"] == 10
end
@assert c.series.time_s == collect(0.0:60.0:32400.0)
@assert sort(unique(r.time_s for r in c.profiles)) == collect(0.0:1800.0:32400.0)
@assert all(isfinite(r.value) for r in c.profiles)
@assert all(all(isfinite, series) for series in values(c.series.values))
for name in unique(r.variable for r in c.profiles), t in 0.0:1800.0:32400.0
    rows = filter(r -> r.variable == name && r.time_s == t, c.profiles)
    location = only(unique(r.location for r in rows))
    @assert length(rows) == (location == "Center" ? 32 : 33)
end
rows = Dict((r.variable,r.time_s,r.z_m) => r.value for r in c.profiles)
residuals = Float64[]
for stem in ("u_w_flux", "v_w_flux", "w_theta_flux"), t in 0.0:1800.0:32400.0, z in 12.5:12.5:387.5
    resolved, sgs, total = (rows[(part * "_" * stem,t,z)] for part in ("resolved","sgs","total"))
    @assert isapprox(total, resolved+sgs; atol=2e-7,rtol=2e-5)
    z > 12.5 && @assert sgs == 0
    push!(residuals,abs(total-resolved-sgs))
end
for name in keys(c.series.values)
    endswith(name, "_fraction") || continue
    @assert all(value -> 0 <= value <= 1, c.series.values[name])
end
for stem in ("momentum", "ρθ")
    coefficient = stem == "momentum" ? "viscosity" : "ρθ_diffusivity"
    active = c.series.values["surface_layer_face1_$(stem)_active_fraction"]
    rawzero = c.series.values["surface_layer_face1_$(stem)_deficit_zero_fraction"]
    validzero = c.series.values["surface_layer_face1_$(stem)_valid_zero_deficit_fraction"]
    coefficientzero = c.series.values["surface_layer_face1_$(coefficient)_zero_fraction"]
    @assert all(validzero .<= rawzero .+ 1e-6)
    @assert all(validzero .<= active .+ 1e-6)
    @assert all(validzero .+ (1 .- active) .<= coefficientzero .+ 1e-6)
end
result = Dict(
    "admitted_count" => 1, "rejected_count" => 0, "case_id" => ID,
    "manifest_sha256" => entry["manifest_sha256"],
    "attempts_sha256" => collection["attempt_registry_sha256"],
    "source_manifest_sha256" => SOURCE_SHA, "gpu_evidence_sha256" => GPU_SHA,
    "cpu_evidence_sha256" => CPU_SHA, "profile_times_verified" => 19,
    "series_times_verified" => 541, "batch_child_exit_code" => 0,
    "native_vertical_shapes_verified" => true,
    "fractions_finite_in_unit_interval_and_consistent" => true,
    "maximum_interior_flux_partition_residual" => maximum(residuals),
    "local_output_checksums_verified" => true,
    "audit_source_sha256" => sha(@__FILE__))
open(io -> TOML.print(io,result; sorted=true), joinpath(@__DIR__, "audit_transfer.toml"), "w")
TOML.print(stdout,result; sorted=true)
