#!/usr/bin/env julia
using CairoMakie, FileIO, JSON, Statistics, SHA, Printf
const ROOT=@__DIR__
img=load(joinpath(ROOT,"figures","figure-2.png"))
gray=Float64.(CairoMakie.Colors.Gray.(img))
# Pixel coordinates in all published extraction files are zero-based.
cal=JSON.parsefile(joinpath(ROOT,"data","figure2_calibration.json"))
source=readlines(joinpath(ROOT,"data","figure2_ensemble_means.csv"))
windows=Dict("LWP"=>(1,405),"cloud_fraction"=>(433,805),"vertically_integrated_TKE"=>(820,1190))
rows=Vector{Any}(); overlay=CairoMakie.Colors.RGB{Float64}.(img)
function longest_near_segment(mask, ys, mean_y; near_mean=true)
    # Bridge antialiasing/black mean-line gaps no wider than four pixels.
    hits=findall(mask)
    isempty(hits) && return nothing
    groups=Vector{Vector{Int}}();g=[first(hits)]
    for k in hits[2:end]
        if k-last(g)<=5;push!(g,k);else;push!(groups,g);g=[k];end
    end
    push!(groups,g)
    near=near_mean ? filter(g->ys[first(g)]-5<=mean_y<=ys[last(g)]+5,groups) : filter(g->length(g)>=2,groups)
    isempty(near) && return nothing
    best=near[argmax(length.(near))]
    return (ys[first(best)]-.5,ys[last(best)]+.5)
end
for line in source[2:end]
    a=split(line,',');var=a[1];px=parse(Int,a[6]);mean_y=parse(Float64,a[7]);p=cal["panels"][var]
    lo,hi=windows[var];ys=collect(lo:hi)
    # Median across five columns rejects isolated text antialiasing and compression specks.
    values=[median(gray[y+1,px-1:px+3])*255 for y in ys]
    fullmask=[(120<=v<=165)||(188<=v<=220) for v in values]
    iqrmask=[120<=v<=165 for v in values]
    full=longest_near_segment(fullmask,ys,mean_y)
    # The ensemble mean need not lie within its interquartile range.
    # Select the largest dark band within the full envelope, independently of the mean.
    if full!==nothing
        iqrmask .&= (full[1].<=ys).&(ys.<=full[2])
    end
    iqr=full===nothing ? nothing : longest_near_segment(iqrmask,ys,mean_y;near_mean=false)
    full===nothing && var!="cloud_fraction" && error("Unresolved full envelope $var x=$px")
    convert_y(y)=p["v1"]+(y-p["y1"])*(p["v2"]-p["v1"])/(p["y2"]-p["y1"])
    upper,lower=full===nothing ? (NaN,NaN) : full
    qhi,qlo=iqr===nothing ? (NaN,NaN) : iqr
    # Boundary of a pixel-thin cloud-fraction band is unresolved; retain a missing IQR.
    fullmin,fullmax=convert_y(lower),convert_y(upper)
    q25,q75=convert_y(qlo),convert_y(qhi)
    isfinite(q25) && isfinite(fullmin) && @assert fullmin-.01<=q25<=q75<=fullmax+.01
    quality=full===nothing ? "full_and_iqr_unresolved" : iqr===nothing ? "iqr_unresolved" : "both_bands_resolved"
    push!(rows,(var,a[3],fullmin,q25,q75,fullmax,a[5],px,lower,qlo,qhi,upper,quality))
    for (y,color) in ((upper,"#0072B2"),(lower,"#0072B2"),(qhi,"#D55E00"),(qlo,"#D55E00"))
        isfinite(y) || continue
        yi=round(Int,y)+1;xi=px+1
        for j in max(1,xi-2):min(size(img,2),xi+2), i in max(1,yi-2):min(size(img,1),yi+2)
            overlay[i,j]=parse(CairoMakie.Colors.RGB{Float64},color)
        end
    end
end
path=joinpath(ROOT,"data","figure2_ensemble_envelope.csv")
open(path,"w") do io
    println(io,"variable,time_h,minimum,q25,q75,maximum,units,pixel_x,pixel_y_min,pixel_y_q25,pixel_y_q75,pixel_y_max,quality")
    for row in rows;println(io,join(row,','));end
end
save(joinpath(ROOT,"data","figure2_envelope_overlay.png"),overlay)
meta=Dict("source"=>"Stevens et al. (2005), Figure 2, printed p.1448; user-supplied raster", "source_sha256"=>bytes2hex(sha256(read(joinpath(ROOT,"figures","figure-2.png")))),
 "meaning"=>"Light band: model ensemble minimum–maximum. Dark band: interquartile range. Neither is observational uncertainty.",
 "method"=>"Julia: median grayscale over5 image columns; full shading gray120:165 or188:220, IQR120:165; bridge at most4 missing pixels. Full band is connected segment nearest checked ensemble mean. IQR is largest dark segment within full band, independent of mean position. Edges at outer pixel boundaries.",
 "coordinates"=>"Zero-based source pixels; axes in figure2_calibration.json; same38 times per panel as checked means, approximately0.2–3.9h.",
 "uncertainty"=>"Conservative3-original-pixel selection tolerance, not observational or ensemble uncertainty. Includes compression and column smoothing; individual model trajectories cannot be reconstructed.",
 "cloud_fraction"=>"Retain raw digitization in CSV; clip only rendered envelope to physical0–1 range where subpixel errors exceed bounds. NaN bounds denote unresolved subpixel bands at early times, not zero spread; do not interpolate across missing bounds.",
 "julia_version"=>string(VERSION),"records"=>length(rows))
write(joinpath(ROOT,"data","figure2_envelope_provenance.json"),JSON.json(meta))
println("Digitized ",length(rows)," envelope records; inspect figure2_envelope_overlay.png before plotting.")
