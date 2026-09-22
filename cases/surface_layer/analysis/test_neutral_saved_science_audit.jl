using Test

include(joinpath(@__DIR__, "NeutralSavedScienceAudit.jl"))
using .NeutralSavedScienceAudit
const Saved = NeutralSavedScienceAudit

@testset "neutral 7367 saved-science postprocessing proof" begin
    paths = Saved.failure_paths(1)
    log = read(paths.log_path, String)
    proof = Saved.verify_postprocessing_failure(log, 1, paths.case_id, paths.exit_path)
    @test proof["solver_returned_zero_inferred_from_wrapper_branch"] === true
    @test proof["original_batch_exit_code"] == 3
    @test proof["missing_rg_occurrences"] == 1
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        replace(log, "rg: command not found" => "sentinel checked"),
        1, paths.case_id, paths.exit_path)
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        log * "\nrg: command not found\n", 1, paths.case_id, paths.exit_path)
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        log * "\nERROR: solver failure\n", 1, paths.case_id, paths.exit_path)
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        replace(log, "NEUTRAL_ABL_RUN_DONE" => "MISSING_RUN_DONE"),
        1, paths.case_id, paths.exit_path)
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        replace(log, "final_time = 18000.0" => "final_time = 120.0"),
        1, paths.case_id, paths.exit_path)
    @test_throws ErrorException Saved.verify_postprocessing_failure(
        replace(log, "code=3" => "code=0"), 1, paths.case_id, paths.exit_path)
    canonical = Saved.Neutral.TOML.parsefile(Saved.Neutral.registry_path())
    for index in 1:2
        audited = Saved.verify_saved_attempt(index, canonical)
        @test audited["original_batch_success"] === false
        @test audited["record_audit"]["initial_records"] == 1
        @test audited["record_audit"]["averaged_profile_records"] == 30
        @test audited["record_audit"]["series_records"] == 301
        @test audited["record_audit"]["checkpoint_records"] == 6
        @test audited["physics_audit"]["maximum_theta_sgs_flux_K_m_s"] == 0
    end
end
