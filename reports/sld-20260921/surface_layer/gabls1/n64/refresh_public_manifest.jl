using SHA, TOML

length(ARGS) == 1 || error("usage: julia refresh_public_manifest.jl REPORT_ROOT")
root = abspath(only(ARGS))
manifest_path = joinpath(root, "files_sha256.toml")
old = TOML.parsefile(manifest_path)["files"]
sha(file) = bytes2hex(open(sha256, file))
changed = Set(("README.md", "breeze_les_master.pdf"))
for (name, digest) in old
    (name in changed || startswith(name, "surface_layer/gabls1/n64/")) && continue
    sha(joinpath(root, name)) == digest || error("historical file changed: $name")
end

new = Dict{String, String}(name => digest for (name, digest) in old
                          if !startswith(name, "surface_layer/gabls1/n64/"))
for name in changed
    new[name] = sha(joinpath(root, name))
end
base = joinpath(root, "surface_layer/gabls1/n64")
for (dir, _, files) in walkdir(base), file in files
    full = joinpath(dir, file)
    new[relpath(full, root)] = sha(full)
end
open(manifest_path, "w") do io
    TOML.print(io, Dict("files" => new); sorted=true)
end
println("REPORT_MANIFEST_REFRESHED historical=", length(old), " total=", length(new))
