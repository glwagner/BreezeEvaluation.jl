using TOML, SHA
include("GABLS3Forcing.jl")
using .GABLS3Forcing
inputs = load_case(joinpath(@__DIR__, "inputs.toml"))
cases = [Dict("case_id" => "gabls3_n$(n)_$(scheme)_$(closure)",
    "nx" => n, "ny" => n, "nz" => n, "dx_m" => 800/n,
    "domain_m" => [800,800,800], "advection" => scheme, "closure" => closure,
    "duration_s" => 32400, "status" => "prepared_not_launchable", "job_id" => "",
    "schedule_group" => rank) for (rank,n) in enumerate((64,128,256))
    for (scheme,closure) in (("weno9","none"),("weno5","none"),("weno9","smagorinsky"))]
matrix = Dict("schema_version"=>1, "campaign"=>"GABLS3-LES", "time_origin_utc"=>inputs["time_origin_utc"],
    "production_authorized"=>false, "maximum_total_gpu_jobs"=>2, "gabls1_priority"=>true,
    "case_count"=>length(cases), "cases"=>cases, "inputs_sha256"=>bytes2hex(sha256(read(joinpath(@__DIR__, "inputs.toml")))),
    "profile_interval_s"=>300, "profile_temporal_averaging"=>"none", "surface_interval_s"=>10,
    "point_interval_s"=>10, "point_target_heights_m"=>[10,25,50,100,200],
    "paper_comparison_utc"=>"03:00-04:00", "comparison_samples"=>"12; exact endpoint convention must be recorded", 
    "readiness"=>inputs["readiness"])
open(joinpath(@__DIR__, "case_matrix.toml"), "w") do io
    TOML.print(io, matrix; sorted=true)
end
println("Prepared ",length(cases)," logical cases; zero jobs submitted. Model integration is explicitly gated.")
