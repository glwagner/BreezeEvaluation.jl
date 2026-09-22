include("admit_factor10.jl")
admit_factor3(directory, root) = admit_single_factor(directory, root; factor=3)
if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 2 || error("usage: admit_factor3.jl EVIDENCE FREEZE")
    admit_factor3(abspath(ARGS[1]), abspath(ARGS[2]))
end
