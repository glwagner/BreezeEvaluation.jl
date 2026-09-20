using JSON
tree = abspath(only(ARGS))
script = joinpath(tree, "gabls", "plot_results.jl")
# Evaluate the original unchanged GABLS1 admission code, without generating figures.
prefix = first(split(read(script, String), "\nfunction reference_profiles"; limit=2))
temporary = tempname(dirname(script)) * ".jl"
try
    write(temporary, prefix)
    include(temporary)
finally
    rm(temporary; force=true)
end
cases, rejected = load_cases()
@assert length(cases) == 12
@assert isempty(rejected) rejected
println("ORIGINAL_GABLS1_ADMISSION_PASSED cases=$(length(cases)) rejected=$(length(rejected))")
