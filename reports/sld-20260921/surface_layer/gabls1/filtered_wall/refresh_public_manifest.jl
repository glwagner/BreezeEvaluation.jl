using SHA, TOML

length(ARGS) == 1 || error("usage: julia refresh_public_manifest.jl REPORT_ROOT")
root = only(ARGS)
path = joinpath(root, "files_sha256.toml")
old = TOML.parsefile(path)["files"]
sha(file) = bytes2hex(open(sha256, file))
changed = Set(("README.md", "breeze_les_master.pdf"))
for (name, digest) in old
    name in changed && continue
    sha(joinpath(root, name)) == digest || error("historical file changed: $name")
end
new = Dict{String,String}(name => digest for (name,digest) in old)
for name in changed
    new[name] = sha(joinpath(root,name))
end
base = joinpath(root,"surface_layer/gabls1/filtered_wall")
for (dir, _, files) in walkdir(base), file in files
    full = joinpath(dir,file)
    name = relpath(full,root)
    new[name] = sha(full)
end
open(path,"w") do io
    TOML.print(io,Dict("files" => new);sorted=true)
end
println("REPORT_MANIFEST_REFRESHED historical=",length(old)," total=",length(new))
