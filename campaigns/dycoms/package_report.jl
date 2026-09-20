#!/usr/bin/env julia
const ROOT=@__DIR__
const WORK=joinpath(dirname(ROOT),"work")
archive=joinpath(ROOT,"dycoms_reference_bundle.zip")
isfile(archive) && rm(archive)
files=String[]
for (dir,dirs,names) in walkdir(ROOT)
    filter!(!=("__pycache__"),dirs)
    for file in names
        endswith(file,".zip") && continue
        push!(files,relpath(joinpath(dir,file),ROOT))
    end
end
cd(ROOT) do
    run(`zip -q $archive $files`)
    if "--sync" in ARGS
        tarpath=joinpath(WORK,"report-update.tar.gz")
        tarcmd=Sys.isapple() ? `tar --no-xattrs --disable-copyfile -czf $tarpath $files` : `tar -czf $tarpath $files`
        run(tarcmd)
        open(tarpath) do io
            run(pipeline(`ssh pcluster "tar -xzf - -C /shared/home/greg/review-coordination/dycoms-reference"`,stdin=io))
        end
    end
end
println("Packaged ",length(files)," deliverables: ",round(filesize(archive)/1e6,digits=1)," MB")
