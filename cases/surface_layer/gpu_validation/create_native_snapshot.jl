using SHA
using Tar
import Dates

length(ARGS) == 3 || error(
    "usage: create_immutable_snapshot.jl DESTINATION EVALUATION_REPOSITORY BREEZE_REPOSITORY")

destination = abspath(ARGS[1])
evaluation_repository = abspath(ARGS[2])
breeze_repository = abspath(ARGS[3])
ispath(destination) && error("refusing to overwrite existing snapshot $destination")

git(repository, args...) = readchomp(Cmd(["git", "-C", repository, args...]))
for repository in (evaluation_repository, breeze_repository)
    isempty(git(repository, "status", "--short")) ||
        error("snapshot source is dirty: $repository")
end

evaluation_commit = git(evaluation_repository, "rev-parse", "HEAD")
evaluation_tree = git(evaluation_repository, "rev-parse", "HEAD^{tree}")
breeze_commit = git(breeze_repository, "rev-parse", "HEAD")
breeze_tree = git(breeze_repository, "rev-parse", "HEAD^{tree}")
source_root = joinpath(destination, "source")
evaluation_destination = joinpath(source_root, "BreezeEvaluation.jl")
breeze_destination = joinpath(source_root, "Breeze-sld-native-flux")
mkpath(evaluation_destination)
mkpath(breeze_destination)

function extract_commit(repository, commit, target)
    mktempdir() do temporary
        archive = joinpath(temporary, "source.tar")
        run(pipeline(`git -C $repository archive --format=tar $commit`; stdout=archive))
        Tar.extract(archive, target)
    end
    return nothing
end

extract_commit(evaluation_repository, evaluation_commit, evaluation_destination)
extract_commit(breeze_repository, breeze_commit, breeze_destination)

# The reviewed Breeze root Manifest is intentionally ignored by Git but is part of the
# dependency freeze. Copy it explicitly before constructing the checksum manifest.
breeze_manifest_source = joinpath(breeze_repository, "Manifest.toml")
isfile(breeze_manifest_source) || error("reviewed Breeze root Manifest.toml is missing")
cp(breeze_manifest_source, joinpath(breeze_destination, "Manifest.toml"))

file_sha256(path) = bytes2hex(open(sha256, path))
runner_manifest = joinpath(
    evaluation_destination, "cases", "gabls3", "runner", "Manifest.toml")
breeze_manifest = joinpath(breeze_destination, "Manifest.toml")

readme = joinpath(destination, "README.md")
open(readme, "w") do io
    println(io, "# GABLS1 scheme-native surface flux source freeze")
    println(io)
    println(io, "Created UTC: `", Dates.now(Dates.UTC), "`")
    println(io)
    println(io, "- BreezeEvaluation.jl commit: `", evaluation_commit, "`")
    println(io, "- BreezeEvaluation.jl tree: `", evaluation_tree, "`")
    println(io, "- Breeze.jl feature commit: `", breeze_commit, "`")
    println(io, "- Breeze.jl tree: `", breeze_tree, "`")
    println(io, "- Runner Manifest SHA-256: `", file_sha256(runner_manifest), "`")
    println(io, "- Breeze root Manifest SHA-256: `", file_sha256(breeze_manifest), "`")
    println(io)
    println(io, "This read-only snapshot contains one GABLS1 matched-case candidate and")
    println(io, "the validated scheme-native Breeze branch. The original 15-case")
    println(io, "GABLS1 registry, factor studies, and earlier freezes are unchanged.")
end

files = String[]
for (directory, _, names) in walkdir(source_root)
    append!(files, joinpath(directory, name) for name in names)
end
sort!(files; by=path -> relpath(path, destination))
checksum_path = joinpath(destination, "source_sha256.txt")
open(checksum_path, "w") do io
    for path in files
        println(io, file_sha256(path), "  ", relpath(path, destination))
    end
end

for line in readlines(checksum_path)
    expected, relative = split(line; limit=2)
    path = joinpath(destination, strip(relative))
    file_sha256(path) == expected || error("snapshot verification failed for $relative")
end

for (directory, _, names) in walkdir(destination; topdown=false)
    for name in names
        chmod(joinpath(directory, name), 0o444)
    end
    chmod(directory, 0o555)
end

println("IMMUTABLE_SNAPSHOT_CREATED path=", destination)
println("evaluation_commit=", evaluation_commit)
println("breeze_commit=", breeze_commit)
println("source_files=", length(files))
println("source_manifest_sha256=", file_sha256(checksum_path))
