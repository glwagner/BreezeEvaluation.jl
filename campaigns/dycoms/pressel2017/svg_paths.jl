function points(d)
    ts=[m.match for m in eachmatch(r"[MLCZmlcz]|[-+]?(?:\d*\.)?\d+(?:[Ee][-+]?\d+)?",d)]
    out=Tuple{Float64,Float64}[];i=1;p=(0.,0.);start=p
    while i<=length(ts)
        cmd=ts[i];i+=1
        if cmd in ("M","L")
            p=(parse(Float64,ts[i]),parse(Float64,ts[i+1]));i+=2
            push!(out,p);cmd=="M"&&(start=p)
        elseif cmd=="C"
            a=(parse(Float64,ts[i]),parse(Float64,ts[i+1]));b=(parse(Float64,ts[i+2]),parse(Float64,ts[i+3]));c=(parse(Float64,ts[i+4]),parse(Float64,ts[i+5]));i+=6
            for t in (1:16)./16;push!(out,ntuple(k->(1-t)^3*p[k]+3(1-t)^2*t*a[k]+3(1-t)*t^2*b[k]+t^3*c[k],2));end
            p=c
        elseif cmd=="Z";push!(out,start);p=start
        else;error("unexpected $cmd");end
    end
    out
end
function paths(file)
    out=[]
    for (i,m) in enumerate(eachmatch(r"<path\b[^>]*>",read(file,String)))
        color=match(r"fill=\"([^\"]+)\"",m.match);d=match(r" d=\"([^\"]+)\"",m.match)
        isnothing(color) && continue;isnothing(d)&&continue
        stroke=match(r"stroke=\"([^\"]+)\"",m.match)
        isstroke=stroke!==nothing && stroke[1]!="none"
        isstroke && (color=stroke)
        ps=points(d[1]);isempty(ps)&&continue
        tr=match(r"transform=\"matrix\(([^)]+)\)\"",m.match)
        if tr!==nothing
            a,b,c,e,tx,ty=parse.(Float64,split(tr[1],r"[, ]+"))
            ps=[(a*x+c*y+tx,b*x+e*y+ty) for (x,y) in ps]
        end
        x=first.(ps);y=last.(ps)
        push!(out,(i=i,color=color[1],d=d[1],stroke=isstroke,points=ps,box=(minimum(x),maximum(x),minimum(y),maximum(y))))
    end
    out
end
if abspath(PROGRAM_FILE)==@__FILE__
 for p in paths(ARGS[1])
    x0,x1,y0,y1=p.box
    ((x1-x0>60 && y1-y0<1) || (y1-y0>60 && x1-x0<1)) && println(p.i," ",p.color," ",p.box)
 end
end
