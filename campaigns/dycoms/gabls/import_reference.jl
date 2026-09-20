#!/usr/bin/env julia
using JSON, SHA, Dates
include("../dycoms_data.jl")
using .DYCOMSData: writecsv
const ROOT=@__DIR__
const WORK=normpath(joinpath(ROOT,"..","..","work","gabls","archive"))
mkpath(WORK)
archive=joinpath(ROOT,"gabls_data.tar.gz")
paths=split(chomp(read(`tar -tzf $archive`,String)),'\n')
@assert all(p->startswith(p,"gabls_data/") && !(".." in split(p,'/')),paths)
run(`tar -xzf $archive -C $WORK`)
const vars=Dict(
 "A"=>["z_m","u_mean","v_mean","theta_mean"],
 "B"=>["z_m","u_variance","v_variance","w_variance","w_skewness","sgs_tke","theta_variance"],
 "C"=>["z_m","uw_resolved","uw_sgs","vw_resolved","vw_sgs","wtheta_resolved","wtheta_sgs","utheta_resolved","utheta_sgs","vtheta_resolved","vtheta_sgs"],
 "D"=>["z_m","shear_production_resolved","shear_production_sgs","buoyancy_production_resolved","transport_total","dissipation","tke_tendency"],
 "E"=>["time_s","boundary_layer_height","surface_theta_flux","ustar","obukhov_length","max_abs_w"])
mkpath(joinpath(ROOT,"reference_data"))
audit=[];data=[];finalprofiles=[];referenceseries=[]
for rel in filter(p->endswith(p,".dat"),paths)
 parts=split(rel,'/'); length(parts)==4 || continue
 grid,model,file=parts[2:4]
 m=match(r"_([ABCDE])([89]?)_",file)
 m===nothing && (push!(audit,(file=rel,status="unrecognized_name",records=0,expected=0,actual=0));continue)
 set=m[1];win=m[2];lines=readlines(joinpath(WORK,rel))
 n=tryparse(Int,strip(lines[2]))
 if n===nothing
  push!(audit,(file=rel,status="invalid_count",records=0,expected=0,actual=0));continue
 end
 # NERSC explicitly writes NaNQ for undefined surface skewness; retain its slot.
 payload=replace(join(lines[3:end]," "),"NaNQ"=>"-0.9999999E+07")
 nums=[parse(Float64,replace(x.match,'D'=>'E','d'=>'e')) for x in eachmatch(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eEdD][-+]?\d+)?",payload)]
 expected=n*length(vars[set])
 if length(nums)!=expected
  push!(audit,(file=rel,status="shape_mismatch",records=n,expected=expected,actual=length(nums)));continue
 end
 arr=reshape(nums,n,:)
 push!(audit,(file=rel,status="parsed",records=n,expected=expected,actual=length(nums)))
 if win=="9" && set in ("A","B","C","D")
  for j in 2:size(arr,2)
   push!(finalprofiles,Dict("source_file"=>rel,"grid"=>grid,"model"=>model,"variable"=>vars[set][j],"source_header"=>strip(lines[1]),"z_m"=>arr[:,1],"value"=>[!isfinite(v)||v<=-9.9e6||v==-9999 ? nothing : v for v in arr[:,j]]))
  end
 end
 if set=="E"
 for j in 2:size(arr,2)
  push!(referenceseries,Dict("source_file"=>rel,"grid"=>grid,"model"=>model,"variable"=>vars[set][j],"source_header"=>strip(lines[1]),"time_s"=>arr[:,1],"value"=>[!isfinite(v)||v<=-9.9e6||v==-9999 ? nothing : v for v in arr[:,j]]))
 end
end
for j in 2:size(arr,2),i in 1:n
  val=arr[i,j];missing=val<=-9.9e6 || val==-9999 || !isfinite(val)
  push!(data,(source_file=rel,grid=grid,model=model,set=set,window=win=="8" ? "7-8h" : win=="9" ? "8-9h" : "series",source_header=strip(lines[1]),coordinate=arr[i,1],variable=vars[set][j],value=missing ? "" : string(val),missing=missing))
 end
end
writecsv(joinpath(ROOT,"reference_data","values.csv"),data)
writecsv(joinpath(ROOT,"reference_data","import_audit.csv"),audit)
write(joinpath(ROOT,"reference_data","final_hour_profiles.json"),JSON.json(finalprofiles))
write(joinpath(ROOT,"reference_data","series.json"),JSON.json(referenceseries))
write(joinpath(ROOT,"reference_data","provenance.json"),JSON.json(Dict("source"=>"https://gabls.metoffice.gov.uk/gabls_data_zip/gabls_data.tar.gz","citation"=>"Beare et al. (2006), doi:10.1007/s10546-004-2820-6","archive_sha256"=>bytes2hex(sha256(read(archive))),"generated_utc"=>string(now(UTC)),"definition_source"=>"original_instructions.ps pp.3-5; arrays written variable by variable","variables"=>vars,"note"=>"Source coordinates retained including ghost/boundary levels. Missing sentinels -9999999 and -9999 plus NaNQ masked. Moment/skewness temporal convention requires source-model verification; no w3 reconstructed from skewness. Parsed shape alone is not full physical validation.")))
println("REFERENCE_IMPORT parsed=",count(r->r.status=="parsed",audit)," of ",length(audit)," values=",length(data))
foreach(println,filter(r->r.status!="parsed",audit))
