#!/usr/bin/env julia
using JSON, Statistics, SHA, Printf
include("svg_paths.jl")
include("../dycoms_data.jl")
using .DYCOMSData: writecsv
const DIR=@__DIR__
const COLORS=["rgb(3.137207%, 46.665955%, 70.588684%)","rgb(3.137207%, 65.098572%, 49.01886%)","rgb(83.137512%, 40.391541%, 15.293884%)","rgb(78.039551%, 47.058105%, 65.098572%)","rgb(91.764832%, 89.411926%, 32.940674%)","rgb(29.019165%, 69.804382%, 89.804077%)"]
const CASES=Dict("Mixed-SGS"=>["25MS","45MS","65MS"],"Paired-SGS"=>["22MS","44MS","66MS","55MS","77MS","99MS"],"Mixed-NSGS"=>["25MN","45MN","65MN"],"Paired-NSGS"=>["55NN","77NN","99NN"])
const CONFIG=[(1,7,"q_l","kg kg^-1",0.,.0004,0.,1200.,true),(2,7,"cloud_fraction","1",0.,4.,.1,1.1,false),(3,8,"LWP","g m^-2",0.,4.,0.,80.,false),(4,9,"q_t","kg kg^-1",0.,.01,0.,1200.,true),(5,10,"theta_l","K",288.,308.,0.,1200.,true),(6,11,"w_variance","m^2 s^-2",0.,.6,0.,1200.,true),(7,12,"w_skewness","1",-.75,4.2,0.,1200.,true)]
# SVG coordinates are points, origin at page top left. Profiles have true stroked
# centerlines; time-series curves have filled stroke outlines in the PDF.
function intersections(ps,a,dim)
    vals=Float64[]
    for (p,q) in zip(ps[1:end-1],ps[2:end])
        if min(p[dim],q[dim])<=a<max(p[dim],q[dim])
            t=(a-p[dim])/(q[dim]-p[dim]);push!(vals,p[3-dim]+t*(q[3-dim]-p[3-dim]))
        end
    end
    sort!(unique(round.(vals,digits=7)))
end
function axesrects(ps,fig)
    axes=[]
    for p in ps
        p.color=="rgb(14.901733%, 14.901733%, 14.901733%)"||continue
        x0,x1,y0,y1=p.box
        x1-x0>100 && y1-y0<.6 || continue
        fig==1 && y0>400 && continue
        fig==2 && y0<400 && continue
        verts=filter(q->q.color==p.color && q.box[2]-q.box[1]<.6 && q.box[4]-q.box[3]>60 && abs(q.box[1]-x0)<.6 && abs(q.box[4]-y1)<.6,ps)
        length(verts)==1 || continue
        v=only(verts);vx0,vx1,vy0,vy1=v.box
        r=p.stroke ? (x0,x1,vy0,y0) : ((vx0+vx1)/2,x1-.25,vy0+.25,(y0+y1)/2)
        push!(axes,(rect=r,axis_path=p.i))
    end
    @assert length(axes)==4 (fig,axes)
    sort!(axes,by=a->(round(a.rect[4]/40),a.rect[1])) # rows, then columns
end
rows=[];cal=[];audit=[]
for (fig,page,var,unit,xlo,xhi,ylo,yhi,profile) in CONFIG
    file=joinpath(DIR,"figures","page-$page.svg");ps=paths(file);axes=axesrects(ps,fig)
    for (ax,experiment) in zip(axes,["Mixed-SGS","Paired-SGS","Mixed-NSGS","Paired-NSGS"])
        x0,x1,y0,y1=ax.rect
        push!(cal,(figure=fig,page=page,experiment=experiment,axis_svg_path=ax.axis_path,x_left_pt=x0,x_right_pt=x1,y_top_pt=y0,y_bottom_pt=y1,x_min=xlo,x_max=xhi,y_min=ylo,y_max=yhi))
        colors=experiment=="Paired-NSGS" ? (4:6) : (1:length(CASES[experiment]))
        for (ci,case) in zip(colors,CASES[experiment])
            candidates=filter(p->p.color==COLORS[ci] && (profile ? p.box[4]-p.box[3]>60 : p.box[2]-p.box[1]>100) && abs((p.box[1]+p.box[2])/2-(x0+x1)/2)<(x1-x0)/2+1 && p.box[3]>=y0-2 && p.box[4]<=y1+2,ps)
            # Profiles with small x range can sit at the edge; select by vertical panel extent.
            candidates=filter(p->p.box[1]>=x0-2 && p.box[2]<=x1+2,candidates)
            @assert length(candidates)==1 (fig,case,[p.i for p in candidates])
            p=only(candidates);@assert p.stroke==profile (fig,case,p.stroke)
            multi=0
            for q in (profile ? collect(10.:10.:1190.) : collect(.02:.02:3.98))
                a=profile ? y1-(q-ylo)/(yhi-ylo)*(y1-y0) : x0+(q-xlo)/(xhi-xlo)*(x1-x0)
                hits=intersections(p.points,a,profile ? 2 : 1)
                isempty(hits)&&continue
                expected=profile ? 1 : 2
                length(hits)>expected && (multi+=1)
                b=(first(hits)+last(hits))/2
                value=profile ? xlo+(b-x0)/(x1-x0)*(xhi-xlo) : ylo+(y1-b)/(y1-y0)*(yhi-ylo)
                sx,sy=profile ? (b,a) : (a,b)
                # Filled outlines have finite thickness; expose it as geometric extraction uncertainty.
                halfwidth=profile ? 0. : (last(hits)-first(hits))/2/(y1-y0)*(yhi-ylo)
                push!(rows,(figure=fig,page=page,experiment=experiment,case_id=case,variable=var,coordinate=profile ? "height_m" : "time_h",coordinate_value=q,value=value,units=unit,averaging=profile ? "2-4 h" : "instantaneous plotted series",svg_path_index=p.i,svg_x_pt=sx,svg_y_pt=sy,outline_halfwidth_value=halfwidth,intersection_count=length(hits),method=profile ? "vector centerline interpolation" : "filled vector outline midpoint"))
            end
            push!(audit,(figure=fig,case_id=case,svg_path_index=p.i,vector_centerline=p.stroke,multiple_intersection_samples=multi))
        end
    end
end
for (fig,_,var,_,_,_,_,_,_) in CONFIG
    rr=filter(r->r.figure==fig,rows)
    @assert length(unique(r.case_id for r in rr))==15
    writecsv(joinpath(DIR,"data","figure$(fig)_$(var).csv"),rr)
end
writecsv(joinpath(DIR,"data","axis_calibrations.csv"),cal)
writecsv(joinpath(DIR,"data","extraction_audit.csv"),audit)
write(joinpath(DIR,"data","provenance.json"),JSON.json(Dict("doi"=>"10.1002/2016MS000778","source_url"=>"https://climate-dynamics.org/wp-content/uploads/2016/08/Pressel_et_al-2017a.pdf","pdf_sha256"=>bytes2hex(sha256(read(joinpath(DIR,"pressel2017.pdf")))),"language"=>"Julia","julia"=>string(VERSION),"extractor"=>"Poppler pdftocairo SVG plus Julia path decoding; affine transforms retained; cubic outline segments sampled at 16 subdivisions","rows"=>length(rows),"curves"=>length(audit),"profile_height_spacing_m"=>10,"series_time_spacing_h"=>.02,"important"=>"These are resampled published plot geometries, not raw LES outputs. Outline halfwidth is geometric extraction uncertainty, not observational/model uncertainty. Figure7 is skewness, not w3. Profile window is2-4h.","svg_sha256"=>Dict("page-$p.svg"=>bytes2hex(sha256(read(joinpath(DIR,"figures","page-$p.svg")))) for p in 7:12))))
println("EXTRACTED rows=",length(rows)," curves=",length(audit))
