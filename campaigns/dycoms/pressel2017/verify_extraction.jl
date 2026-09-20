using Statistics, Printf
include("../dycoms_data.jl")
using .DYCOMSData
root=@__DIR__
cases=table(joinpath(root,"data","case_configuration_and_bulk_results.csv"));rows=[]
for (fig,var,column,tol) in [(2,"cloud_fraction",:cloud_fraction_2_4h,.006),(3,"LWP",:LWP_g_m2_2_4h,.12)]
    data=table(joinpath(root,"data","figure$(fig)_$var.csv"))
    for c in cases
        rr=filter(r->r.case_id==c.case_id,data);t=num.(getproperty.(rr,:coordinate_value));v=num.(getproperty.(rr,:value))
        tt=vcat(2.,t[2 .<t.<4],4.);vv=[interp(t,v,x) for x in tt]
        meanval=sum(diff(tt).*(vv[1:end-1].+vv[2:end])./2)/2
        exact=num(getproperty(c,column));error=meanval-exact
        push!(rows,(case_id=c.case_id,variable=var,extracted_mean_2_4h=meanval,published_table4_mean=exact,difference=error,tolerance=tol,pass=abs(error)<tol))
        @printf("%s %s reconstructed=%.4f table=%.4f difference=%+.4f\n",c.case_id,var,meanval,exact,error)
    end
end
writecsv(joinpath(root,"data","table4_crosscheck.csv"),rows)
@assert all(r->r.pass,rows)
println("TABLE4_CROSSCHECK_PASSED 30 comparisons")
