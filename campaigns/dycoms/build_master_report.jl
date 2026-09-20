#!/usr/bin/env julia
using JSON,Dates,Markdown,CairoMakie
include("report_layout.jl")
using .ReportLayout
const ROOT=@__DIR__
const G=joinpath(ROOT,"gabls")
const G3=joinpath(ROOT,"gabls3")
const WORK=joinpath(dirname(ROOT),"work","master-report")
mkpath(WORK)
# Frozen standalone chapter prevents accidentally nesting the master inside itself.
for ext in ("pdf","md","html")
 dst=joinpath(ROOT,"dycoms_section."*ext)
 isfile(dst)||cp(joinpath(ROOT,"dycoms_report."*ext),dst)
end
plan=JSON.parsefile(joinpath(G,"experiment_matrix.json"))
checkedfile=joinpath(G,"cluster","last_collection.json")
stamp=isfile(checkedfile) ? JSON.parsefile(checkedfile)["checked_utc"] : string(now(UTC))*"Z"
resultfile=joinpath(G,"results_summary.json")
results=isfile(resultfile) ? JSON.parsefile(resultfile) : Dict("verified_cases"=>Any[],"figures"=>Any[],"findings"=>Any[])
verified=results["verified_cases"];n=length(verified);total=length(plan["cases"]);submitted=count(c->get(c,"job_id",nothing)!==nothing || get(c,"array_job_id",nothing)!==nothing,plan["cases"])
queuefile=joinpath(G,"cluster","queue.txt")
queue=isfile(queuefile) ? strip(read(queuefile,String)) : "Not yet checked"
summary="DYCOMS: 15 completed cases. GABLS1: $n of $total planned cases have completed, audited local results."
intro=["Data/status checked: $stamp",summary,"This document combines the completed DYCOMS RF01 experiment (including the Pressel comparison) with the developing GABLS1 experiment. The GABLS run order is smallest grids first; incomplete runs contribute status information only, never scientific curves.","Read finite-output completion separately from physical fidelity: all three unbounded DYCOMS Centered2 cases developed negative total water. The DYCOMS chapter retains that audit.","GABLS1 uses a fixed 400 m cube and 9 h of surface cooling and geostrophic forcing. Its no-interior-closure configurations retain MOST wall stress and heat exchange. The question is whether numerical choices preserve resolved shear-driven turbulence on coarser grids.","Contents: Part I - completed DYCOMS and Pressel comparison; Part II - GABLS setup, progress, numerical references, then audited results as they arrive."]
push!(intro,"Part III adds GABLS3: an observational evaluation now in preparation. All prior DYCOMS and GABLS1 information is retained. The requested persistent evaluation repository is glwagner/BreezeEvaluation.jl.")
front=textpages("Breeze LES master report",intro,"front",WORK)
setup=["Part II: GABLS1", "$n/$total completed exports admitted to the scientific comparison. Checked $stamp.","Grids: 12.5, 6.25, 3.125, 2, and 1 m isotropic; 32³, 64³, 128³, 200³, and 400³ cells, all in the same 400 m cube. Small grids run first.","Each grid has exactly three configurations: WENO9 with no interior closure, WENO5 with no interior closure, and WENO9 with Smagorinsky. Smagorinsky Cs=0.16, Pr=1; paired seed 123 within each grid. These are controlled Breeze settings, not a reproduction of one named historical LES member.","Forcing: Ug = 8 m/s, Vg = 0, f = 1.39e-4/s. Initial potential temperature 265 K below 100 m and 265+0.01(z-100) K above. Initial temperature noise is uniform with 0.1 K peak-to-peak range below 50 m. Surface theta_s=265-0.25t_hours K; theta_ref=263.5 K is a separate buoyancy reference.","Wall: MOST exchange with kappa = 0.4, beta_m = 4.8, beta_h = 7.8, roughness = 0.1 m for heat and momentum. Impermeable boundaries, free-slip upper lid. Vertical-velocity damping is zero below 300 m and ramps linearly to a 60 s relaxation time at 400 m. MOST uses a minimum wind of 0.01 m/s and caps z/L at 10, with a neutral fallback for nonpositive bulk Richardson number; their activity is diagnosed. Exact implementation, damping and timestep choices are recorded in production provenance.","Diagnostics: 541 instantaneous series records at 60 s intervals; 19 profile times with preceding 30 min means after instantaneous t0. Compare 7-8 h and 8-9 h. Final-hour profiles combine bins ending at 30600 and 32400 s; penultimate-hour bins end at 27000 and 28800 s.","Compare mean u/v/theta, jet speed/height/turning, total-stress boundary-layer height, surface heat flux/ustar/L, native-face w2/w3/skewness, resolved/SGS flux partitions and available TKE-budget terms. Missing SGS energy or budget terms remain unavailable; a residual is not numerical dissipation.","Beare et al. (2006), Boundary-Layer Meteorology 118, 247-272, doi:10.1007/s10546-004-2820-6. Official reduced data archive contains 423 files. Native coordinates and missing values are retained; some NERSC headers give 474-534 min for nominal 8-9 h, so exact window matching is not universal.","Cluster agents own implementation, scheduling and audited exports. Desktop monitoring is scheduled every 10 min to collect newly completed cases and rebuild this document. Actual submitted jobs and completed-export evidence are recorded in the status files, separate from the authorized matrix."]
push!(setup,"Production submission records: $submitted/$total cases have assigned Slurm jobs. Submitted is distinct from running or scientifically complete. The live queue snapshot below also includes any smoke tests.")
push!(setup,"Implementation choices: Breeze uses anelastic dynamics and Float32 arithmetic; the reference archive is predominantly Boussinesq. Base pressure is 100000 Pa so the prescribed surface temperature equals surface potential temperature; the corresponding reference density differs from the specification's rounded 1.3223 kg/m³ by about 8 parts per million. Smagorinsky-Lilly uses Cs=0.16, Cb=1, Pr=1.")
append!(setup,String.(results["findings"]))
incidentfile=joinpath(G,"campaign_incidents.json")
if isfile(incidentfile)
 currentjobs=Set(string(get(c,"job_id","")) for c in plan["cases"])
 for incident in JSON.parsefile(incidentfile)
  any(id->id in currentjobs,incident["applies_to_job_ids"]) && push!(setup,incident["message"])
 end
end
if n==0
 push!(setup,submitted>0 ? "No fully audited GABLS results yet. Scientific curves will appear only after complete exports pass all audits." : "No completed GABLS simulation results yet. Implementation and diagnostics checks precede production; the case matrix is not evidence of job submission.")
end
for c in verified
 push!(setup,get(c,"summary",string(c)))
end
push!(setup,"Current queue snapshot (job|state|elapsed|start|node or pending reason):\n" * (isempty(queue) ? "No active jobs in the last collected queue snapshot." : queue))
gpages=textpages("GABLS1: setup and results",setup,"gabls",WORK)
for file in results["figures"]
 path=joinpath(ROOT,file*".pdf");isfile(path)&&push!(gpages,path)
end
run(`pdfunite $gpages $(joinpath(G,"gabls_section.pdf"))`)
allpages=vcat(front,[joinpath(ROOT,"dycoms_section.pdf"),joinpath(G,"gabls_section.pdf")])
g3md=read(joinpath(G3,"reference.md"),String)
g3paragraphs=[replace(strip(p),r"(?m)^#+ "=>"",r"\[([^\]]+)\]\([^\)]+\)"=>s"\1") for p in split(g3md,"\n\n") if !isempty(strip(p))]
g3pages=textpages("Part III: GABLS3 preparation",g3paragraphs,"gabls3",WORK)
run(`pdfunite $g3pages $(joinpath(G3,"gabls3_section.pdf"))`)
push!(allpages,joinpath(G3,"gabls3_section.pdf"))
master=joinpath(ROOT,"breeze_les_master.pdf")
run(`pdfunite $allpages $master`)
cp(master,joinpath(ROOT,"dycoms_report.pdf");force=true)
md="# Breeze LES master report\n\n"*summary*"\n\nChecked "*stamp*".\n\n"*join(intro[3:end],"\n\n")*"\n\n---\n\n# Part I: DYCOMS RF01\n\n"*read(joinpath(ROOT,"dycoms_section.md"),String)*"\n\n---\n\n# Part II: GABLS1\n\n"*join(setup,"\n\n")*"\n\n[Setup and reference](gabls/reference.md) · [Workflow](gabls/workflow.md) · [Case matrix](gabls/experiment_matrix.json) · [Implementation status](gabls/cluster/pane47-status.md) · [Export status](gabls/cluster/pane48-status.md)\n"
md*=join(["\n![$(basename(file))]($file.png)\n\n[Vector figure]($file.pdf)\n" for file in results["figures"]],"")
md*="\n\n---\n\n# Part III: GABLS3\n\n"*g3md
write(joinpath(ROOT,"breeze_les_master.md"),md)
css="body{font:17px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;color:#203340;background:#f5f7f8;margin:0}main{max-width:1200px;margin:25px auto;padding:45px;background:white;border-top:6px solid #0072B2}h1{font-size:32px}h2{margin-top:2em;color:#176d9c}img{max-width:100%;height:auto}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:8px;border-bottom:1px solid #dce3e7;text-align:left}a{color:#176d9c}pre{background:#f4f6f8;padding:12px;overflow:auto}"
html="<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Breeze LES master report</title><style>$css</style><main>"*Markdown.html(Markdown.parse(md))*"</main></html>"
write(joinpath(ROOT,"breeze_les_master.html"),html)
write(joinpath(ROOT,"dycoms_report.html"),html)
println("MASTER_REPORT_COMPLETE DYCOMS=15 GABLS=$n/$total")
