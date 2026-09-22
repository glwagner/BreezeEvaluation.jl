include("finalize_factor10_attempt.jl")
if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 6 || error("usage: finalize_factor3_attempt.jl FREEZE EVIDENCE JOB RUNS LOGS NEW_ATTEMPTS.toml")
    finalize(abspath(ARGS[1]), abspath(ARGS[2]), ARGS[3], abspath.(ARGS[4:6])...; factor=3)
end
