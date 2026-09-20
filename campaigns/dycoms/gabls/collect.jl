#!/usr/bin/env julia
using JSON, Dates, SHA
const ROOT=@__DIR__
const REMOTE="/shared/home/greg/review-coordination/gabls-production-v2-20260919"
const WORK=normpath(joinpath(ROOT,"..","..","work","gabls"))
sshcommand(command)=`ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 pcluster $command`
function sshretry(f)
 for attempt in 1:3
  try
   return f()
  catch err
   attempt==3 && rethrow()
   @warn "SSH collection failed; retrying" attempt
   sleep(2)
  end
 end
end
sshread(command)=sshretry(()->read(sshcommand(command),String))
mkpath(joinpath(ROOT,"cluster"));mkpath(joinpath(ROOT,"simulation_data"));mkpath(WORK)
# Metadata collection works before the runner/scaffold exists.
for (remote,localname) in [
 ("/shared/home/greg/review-coordination/gabls-pane47-status.md","pane47-status.md"),
 ("/shared/home/greg/review-coordination/gabls-pane48-status.md","pane48-status.md"),
 ("/shared/home/greg/review-coordination/gabls-export-status.json","export_status.json"),
 ("$REMOTE/cases.json","cases.json")]
 result=sshread("if test -f "*remote*"; then cat "*remote*"; fi")
 isempty(strip(result)) || write(joinpath(ROOT,"cluster",localname),result)
end
archive=joinpath(WORK,"exports.tar.gz")
sshretry() do
 open(archive,"w") do io
  run(pipeline(sshcommand("if test -d $REMOTE/analysis_export; then tar -C $REMOTE/analysis_export -czf - .; else tar -czf - --files-from /dev/null; fi"),stdout=io))
 end
end
paths=split(read(`tar -tzf $archive`,String),'\n')
@assert all(p->!startswith(p,"/") && !(".." in split(p,'/')),paths)
run(`tar -xzf $archive -C $(joinpath(ROOT,"simulation_data"))`)
queue=sshread("/opt/slurm/bin/squeue -u greg --array --noheader -o '%i|%T|%M|%S|%R'")
write(joinpath(ROOT,"cluster","queue.txt"),queue)
write(joinpath(ROOT,"cluster","last_collection.json"),JSON.json(Dict("checked_utc"=>string(now(UTC))*"Z","root"=>REMOTE,"queue"=>queue,"note"=>"Collected exports are not automatically marked verified by presence alone; use manifest/verifier evidence and local audits.")))
# Reconcile actual submission metadata while checking the authorized scientific matrix.
casefile=joinpath(ROOT,"cluster","cases.json")
if isfile(casefile)
 remote=JSON.parsefile(casefile);matrixfile=joinpath(ROOT,"experiment_matrix.json");matrix=JSON.parsefile(matrixfile)
 byid=Dict(c["case_id"]=>c for c in remote["cases"])
 @assert length(remote["cases"])==length(byid)==length(matrix["cases"])==15 "Remote GABLS registry must contain exactly the 15 authorized cases"
 @assert Set(keys(byid))==Set(c["case_id"] for c in matrix["cases"]) "Remote GABLS case IDs differ from the authorized matrix"
 for c in matrix["cases"]
  r=byid[c["case_id"]]
  @assert c["nx"]==r["nx"] && c["dx_m"]==r["dx_m"] && c["closure"]==r["closure"] && c["advection_order"]==r["order"]
  @assert r["Lx_m"]==r["Ly_m"]==r["Lz_m"]==400 && r["stop_hours"]==9 && r["seed"]==123
  for key in ("array_job_id","array_task_id","job_id","log","root","outputs","Cb","source_hashes","source_revision","attempt_history")
   haskey(r,key) && (c[key]=r[key])
  end
  c["state"]=get(c,"job_id",nothing)!==nothing || get(c,"array_job_id",nothing)!==nothing ? "SUBMITTED" : "IN_PREPARATION"
 end
 matrix["cluster_fixed_physics"]=remote["fixed_physics"]
 matrix["cluster_source_hashes"]=remote["source_hashes"]; matrix["cluster_source_hashes_status"]=get(remote,"source_hashes_status","unspecified")
 matrix["metadata_checked_utc"]=string(now(UTC))*"Z"
 matrix["production_root"]=REMOTE
 write(matrixfile,JSON.json(matrix))
end
# Retain completed-run timing separately from scientific export admission.
# CASE_DONE wall_s excludes process startup and compilation before the simulation.
status=JSON.parsefile(joinpath(ROOT,"cluster","export_status.json"))
@assert status["production_root"]==REMOTE
registry=JSON.parsefile(casefile)
byid=Dict(c["case_id"]=>c for c in registry["cases"])
costs=Dict{String,Any}()
for c in status["cases"]
 get(c,"export_verified",false)===true || continue
 r=byid[c["case_id"]];path=r["log"]
 @assert startswith(path,REMOTE*"/") && occursin(r"^[A-Za-z0-9_./-]+$",path)
 log=sshread("cat -- "*path)
 id=r["case_id"]
 line=match(Regex("CASE_DONE "*id*" wall_s=([0-9.eE+-]+) iters=([0-9]+)"),log)
 line===nothing && error("Missing completion timing for $id")
 costs[id]=Dict("job_id"=>r["job_id"],"solver_wall_s"=>parse(Float64,line[1]),
                "iterations"=>parse(Int,line[2]),"log_sha256"=>bytes2hex(sha256(log)),
                "source_log"=>path)
end
write(joinpath(ROOT,"cluster","completion_metrics.json"),JSON.json(Dict(
 "production_root"=>REMOTE,"checked_utc"=>string(now(UTC))*"Z","cases"=>costs,
 "timing_definition"=>"CASE_DONE wall_s: simulation wall time, excluding process startup and preceding compilation; not total allocated GPU time.")))
println("GABLS_COLLECTION_COMPLETE ",now(UTC))
