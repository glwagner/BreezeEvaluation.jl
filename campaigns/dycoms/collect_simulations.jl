#!/usr/bin/env julia
using JSON, Dates
const ROOT=@__DIR__
const WORK=joinpath(dirname(ROOT),"work")
const REMOTE="/shared/home/greg/review-coordination/dycoms-production-20260919"
const matrix=JSON.parsefile(joinpath(ROOT,"experiment_matrix.json"))
mkpath(WORK);mkpath(joinpath(WORK,"cluster-logs"))
function download_archive(command,file,target)
    open(file,"w") do io;run(pipeline(`ssh pcluster $command`,stdout=io));end
    mkpath(target);run(`tar -xzf $file -C $target`)
end
# Exports are transactional: only final per-case folders are consumed by the plotting code.
sources=unique((get(c,"remote_production_root",REMOTE),get(c,"slurm_array_job_id",nothing)) for c in matrix["cases"] if get(c,"slurm_array_job_id",nothing)!==nothing)
for (remote,jobid) in sources
    # A new production family may not have an export directory or log files yet.
    download_archive("if test -d $remote/analysis_export; then tar -C $remote/analysis_export -czf - .; else tar -czf - --files-from /dev/null; fi",joinpath(WORK,"analysis_export-$jobid.tar.gz"),joinpath(ROOT,"simulation_data"))
    download_archive("cd $remote && find . -maxdepth 1 -name '*$jobid*.log' -print0 | tar --null -T - -czf -",joinpath(WORK,"production-logs-$jobid.tar.gz"),joinpath(WORK,"cluster-logs"))
end
buf=IOBuffer();err=IOBuffer()
p=run(pipeline(ignorestatus(`ssh pcluster "/opt/slurm/bin/squeue -u greg --array --noheader -o '%i|%T|%M|%S|%N'"`),stdout=buf,stderr=err))
queue=String(take!(buf));error_text=String(take!(err))
!success(p) && !occursin("Invalid job id",error_text) && error(error_text)
q=Dict{String,Any}()
for line in split(strip(queue),'\n')
    fields=split(line,'|');length(fields)>=5 || continue
    q[fields[1]]=Dict("job_id"=>fields[1],"state"=>fields[2],"elapsed"=>fields[3],"start"=>fields[4],"nodes"=>fields[5])
end
stamp=string(now(UTC))*"Z"
cases=[]
for c in matrix["cases"]
    id=c["remote_case_id"];idx=get(c,"slurm_array_task_id",nothing);jobid=get(c,"slurm_array_job_id",nothing)
    job=jobid===nothing ? "" : "$(jobid)_$idx"
    logpath=joinpath(WORK,"cluster-logs",get(c,"remote_log_filename","dycoms-$job.log"))
    log=isfile(logpath) ? read(logpath,String) : ""
    sentinel=occursin("CASE_DONE "*id,log) && occursin("DYCOMS_CASE_EXIT_SUCCESS",log)
    r=Dict{String,Any}("case_id"=>id,"array_index"=>idx,"array_job_id"=>jobid,"grid"=>c["name"],"advection_scheme"=>get(c,"advection_scheme","WENO"),"advection_order"=>c["advection_order"],"closure"=>c["closure"],"state"=>jobid===nothing ? "IN_PREPARATION" : "NOT_IN_QUEUE")
    if haskey(q,job);merge!(r,q[job])
    elseif sentinel;r["state"]="COMPLETED";r["state_evidence"]="Both success sentinels; absent from active queue. Slurm accounting disabled."
    end
    r["completion_sentinel"]=sentinel;r["export_present"]=isfile(joinpath(ROOT,"simulation_data",id,"series.csv"));r["status"]=r["state"];r["status_checked_utc"]=stamp
    m=match(r"CASE_DONE .*?wall_s=([\d.]+) iters=(\d+) final_LWP=([\d.]+)",log)
    if m!==nothing;r["solver_wall_s"]=parse(Float64,m[1]);r["iterations"]=parse(Int,m[2]);r["final_LWP_kg_m2"]=parse(Float64,m[3]);end
    c["status"]=r["state"];c["status_checked_utc"]=stamp;push!(cases,r)
end
sort!(cases,by=c->(something(c["array_job_id"],typemax(Int)),something(c["array_index"],typemax(Int))))
status=Dict("checked_utc"=>stamp,"cases"=>cases,"raw_squeue"=>queue,"accounting_note"=>"Slurm accounting disabled; completed states require success sentinels and absence from queue.")
for (file,data) in [("cluster/run_status.json",status),("cluster/production_cases.json",cases),("experiment_matrix.json",matrix)]
    write(joinpath(ROOT,file),JSON.json(data))
end
for pane in (47,48)
    remote="/shared/home/greg/review-coordination/dycoms-pane$pane-status.md"
    write(joinpath(ROOT,"cluster","pane$pane-status.md"),read(`ssh pcluster $("cat "*remote)`,String))
end
open(joinpath(ROOT,"simulation_status.md"),"w") do io
    println(io,"# DYCOMS GPU simulation status\n\nChecked $stamp. Julia-only collection and plotting.\n\n| Case | State | Solver wall (s) | Export available |\n|---|---|---:|---|")
    for c in cases;println(io,"| ",c["case_id"]," | ",c["state"]," | ",get(c,"solver_wall_s","")," | ",c["export_present"]," |");end
    println(io,"\n[Report](dycoms_report.md) · [Exact source hashes](cluster/source_provenance.json) · [Status evidence](cluster/run_status.json).\n\nOriginal JLD2 files and checkpoints remain at `$REMOTE/runs/` on pcluster. Solver wall excludes Julia startup and compilation outside the time integration call.")
end
foreach(c->println(c["case_id"],": ",c["state"],", export=",c["export_present"]),cases)
