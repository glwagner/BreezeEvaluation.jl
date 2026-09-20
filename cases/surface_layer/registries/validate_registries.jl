using SHA
using TOML

const REGISTRY_DIRECTORY = @__DIR__

function require_contract(condition, message)
    condition || error(message)
    return nothing
end

function validate_registry(path, expected_family, expected_grid, expected_seed)
    registry = TOML.parsefile(path)
    cases = registry["cases"]
    require_contract(registry["submission_state"] == "UNSUBMITTED",
                     "$path is not an unsubmitted scaffold")
    require_contract(registry["expected_case_count"] == 4 && length(cases) == 4,
                     "$path must contain exactly four cases")
    require_contract(registry["case_family"] == expected_family,
                     "$path has the wrong case family")
    require_contract(registry["grid"] == fill(expected_grid, 3),
                     "$path has the wrong matched grid")
    require_contract(registry["seed"] == expected_seed,
                     "$path has the wrong paired seed")
    if expected_family == "GABLS3"
        digests = registry["paired_initial_state_sha256"]
        require_contract(Set(keys(digests)) == Set((
            "u_sha256", "v_sha256", "theta_sha256", "q_sha256", "w_sha256")),
            "$path does not lock all paired initial arrays")
        require_contract(all(value -> length(value) == 64, values(digests)),
                         "$path contains an invalid initial-array digest")
    end
    require_contract(length(unique(case["case_id"] for case in cases)) == 4,
                     "$path has duplicate logical case ids")
    require_contract(all(case["submission_state"] == "UNSUBMITTED" for case in cases),
                     "$path contains a submitted case")
    matrix = Set((case["closure"], case["filter_seconds"], case["support"])
                 for case in cases)
    expected = Set((
        ("none", 300.0, 1),
        ("surface_layer", 100.0, 1),
        ("surface_layer", 300.0, 1),
        ("surface_layer", 300.0, 2)))
    require_contract(matrix == expected, "$path does not implement the authorized matrix")
    return (;
        path=relpath(path, normpath(joinpath(REGISTRY_DIRECTORY, "..", "..", ".."))),
        sha256=bytes2hex(open(sha256, path)),
        case_ids=[case["case_id"] for case in cases])
end

gabls1 = validate_registry(joinpath(REGISTRY_DIRECTORY, "gabls1_sld_4case.toml"),
                           "GABLS1", 32, 123)
gabls3 = validate_registry(joinpath(REGISTRY_DIRECTORY, "gabls3_sld_4case.toml"),
                           "GABLS3", 64, 20260702)
println("REGISTRY_CONTRACT_PASS")
println("gabls1_sha256=", gabls1.sha256)
println("gabls3_sha256=", gabls3.sha256)
