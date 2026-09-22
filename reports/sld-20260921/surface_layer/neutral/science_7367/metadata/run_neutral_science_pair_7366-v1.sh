#!/bin/bash
# Root-review candidate only. Never launched by pane 48.
# Runs one canonical five-hour neutral LES array task with a durable child exit.
set -euo pipefail

: "${SLD_NEUTRAL_SCIENCE_ROOT:?set a fresh campaign root with runs/ and logs/}"
: "${SLURM_ARRAY_JOB_ID:?}"
: "${SLURM_ARRAY_TASK_ID:?}"
: "${SLURM_JOB_ID:?}"
[[ "${SLD_NEUTRAL_SCIENCE_ROOT}" = /* ]] || exit 2
[[ "${SLURM_ARRAY_JOB_ID}" =~ ^[0-9]+$ && "${SLURM_JOB_ID}" =~ ^[0-9]+$ ]] || exit 2
[[ "${SLURM_ARRAY_TASK_ID}" =~ ^[12]$ ]] || exit 2
[[ -d "${SLD_NEUTRAL_SCIENCE_ROOT}/runs" && -d "${SLD_NEUTRAL_SCIENCE_ROOT}/logs" ]] || exit 2

core=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647
core_manifest_sha=d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c
registry="${core}/source/BreezeEvaluation.jl/cases/surface_layer/neutral/neutral_sld_2case.toml"
registry_sha=5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156
reader=/shared/home/greg/review-coordination/admit_neutral_saved_output_7366-v4.jl
reader_sha=f5b57980bb076f4304bc908c15e334d5acceb2e71896fdd698bc8c276bb08b36
runner="${core}/source/BreezeEvaluation.jl/cases/surface_layer/neutral/neutral_abl_case.jl"
project="${core}/source/BreezeEvaluation.jl/cases/gabls3/runner"
julia=/shared/home/greg/.juliaup/bin/julia

[[ ! -e "${SLD_NEUTRAL_SCIENCE_ROOT}/logs/neutral_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.exit" ]] || exit 2
printf '%s  %s\n' \
    "$core_manifest_sha" "${core}/source_sha256.txt" \
    "$registry_sha" "$registry" \
    "$reader_sha" "$reader" | sha256sum --check --quiet
(cd "$core" && sha256sum --check --quiet source_sha256.txt)
"$julia" --startup-file=no --project="$project" "$reader"

if [[ "${SLURM_ARRAY_TASK_ID}" == 1 ]]; then
    closure=none
    case_id=neutral_n096_weno9_control
else
    closure=surface_layer
    case_id=neutral_n096_weno9_surface_layer_t300_s1
fi
run_dir="${SLD_NEUTRAL_SCIENCE_ROOT}/runs/${case_id}"
mkdir "$run_dir"
wrapper_sha=$(sha256sum "${BASH_SOURCE[0]}")
wrapper_sha=${wrapper_sha%% *}
started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
    printf 'case_id=%s\n' "$case_id"
    printf 'registry=%s\n' "$registry"
    printf 'registry_index=%s\n' "$SLURM_ARRAY_TASK_ID"
    printf 'array_job_id=%s\n' "$SLURM_ARRAY_JOB_ID"
    printf 'slurm_job_id=%s\n' "$SLURM_JOB_ID"
    printf 'source_manifest_sha256=%s\n' "$core_manifest_sha"
    printf 'gpu_gate_combined_sha256=%s\n' 55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02
    printf 'supplemental_saved_output_sha256=%s\n' c3c44a8a6c71a5b8e0166dc26477e18ab823c708d75faabe0b367ba8a13bec7c
    printf 'wrapper_sha256=%s\n' "$wrapper_sha"
    printf 'fixture=false\nstarted_utc=%s\n' "$started_utc"
} > "${run_dir}/ATTEMPT_STARTED"

export NEUTRAL_ABL_ARCH=gpu
export NEUTRAL_ABL_FIXTURE=0
export NEUTRAL_ABL_NX=96 NEUTRAL_ABL_NY=96 NEUTRAL_ABL_NZ=96
export NEUTRAL_ABL_CLOSURE="$closure"
export NEUTRAL_ABL_FILTER_SECONDS=300 NEUTRAL_ABL_SUPPORT=1
export NEUTRAL_ABL_STOP_SECONDS=18000 NEUTRAL_ABL_SEED=1994
export NEUTRAL_ABL_DIAGNOSTICS=1
export NEUTRAL_ABL_PROFILE_INTERVAL=600 NEUTRAL_ABL_SERIES_INTERVAL=60
export NEUTRAL_ABL_CHECKPOINT_INTERVAL=3600 NEUTRAL_ABL_PROGRESS_INTERVAL=1000
export NEUTRAL_ABL_RUN_DIR="$run_dir"

set +e
"$julia" --startup-file=no --project="$project" "$runner"
child_exit_code=$?
set -e
if [[ "$child_exit_code" == 0 ]]; then
    if [[ ! -f "${run_dir}/CASE_DONE" ]] ||
       ! rg -q -F -x "case_id=${case_id}" "${run_dir}/CASE_DONE" ||
       ! rg -q '^final_time_s=18000(\.0+)?$' "${run_dir}/CASE_DONE"; then
        child_exit_code=3
    fi
fi
if [[ "$child_exit_code" != 0 ]]; then
    printf 'case_id=%s\nchild_exit_code=%s\n' "$case_id" "$child_exit_code" > "${run_dir}/CASE_FAILED"
fi
finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
record="${SLD_NEUTRAL_SCIENCE_ROOT}/logs/neutral_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.exit"
temporary=$(mktemp "${SLD_NEUTRAL_SCIENCE_ROOT}/logs/neutral_exit.XXXXXXXX")
{
    printf 'schema_version=1\n'
    printf 'array_job_id=%s\n' "$SLURM_ARRAY_JOB_ID"
    printf 'slurm_job_id=%s\n' "$SLURM_JOB_ID"
    printf 'task_id=%s\n' "$SLURM_ARRAY_TASK_ID"
    printf 'case_id=%s\n' "$case_id"
    printf 'started_utc=%s\nfinished_utc=%s\n' "$started_utc" "$finished_utc"
    printf 'child_exit_code=%s\n' "$child_exit_code"
    printf 'wrapper_sha256=%s\n' "$wrapper_sha"
    printf 'source_manifest_sha256=%s\n' "$core_manifest_sha"
    printf 'supplemental_saved_output_sha256=%s\n' c3c44a8a6c71a5b8e0166dc26477e18ab823c708d75faabe0b367ba8a13bec7c
    printf 'record_complete=true\n'
} > "$temporary"
ln "$temporary" "$record"
rm "$temporary"
printf 'NEUTRAL_RECORDED_CHILD_EXIT job=%s task=%s case=%s code=%s record=%s\n' \
    "$SLURM_ARRAY_JOB_ID" "$SLURM_ARRAY_TASK_ID" "$case_id" "$child_exit_code" "$record"
exit "$child_exit_code"
