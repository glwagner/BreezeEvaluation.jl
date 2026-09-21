#!/bin/bash -l
# Root submits exactly --array=1-2%1 after the new-source factor gate passes.
#SBATCH --job-name=gabls1-sld-factor
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
set -euo pipefail
: "${SLD_FREEZE_ROOT:?}"
: "${SLD_VALIDATION_EVIDENCE:?}"
: "${SLD_RUN_ROOT:?}"
: "${SLD_EXIT_RECORD_ROOT:?}"
: "${SLURM_ARRAY_JOB_ID:?}"
: "${SLURM_ARRAY_TASK_ID:?}"
[[ "$SLURM_ARRAY_TASK_ID" =~ ^[12]$ ]] || exit 2
EVAL="$SLD_FREEZE_ROOT/source/BreezeEvaluation.jl"
PROJECT="$EVAL/cases/gabls3/runner"
JULIA=/shared/home/greg/.juliaup/bin/julia
cd "$SLD_FREEZE_ROOT"
sha256sum --check source_sha256.txt >/dev/null
"$JULIA" --startup-file=no --project="$PROJECT" \
  "$EVAL/cases/surface_layer/gpu_validation/admit_resolved_flux_factor.jl" "$SLD_VALIDATION_EVIDENCE" "$SLD_FREEZE_ROOT"
export SLD_CASE_EXECUTION_ACK=IMMUTABLE_GPU_VALIDATED
record="$SLD_EXIT_RECORD_ROOT/gabls1_factor_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.exit"
[[ ! -e "$record" ]] || exit 2
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
set +e
"$JULIA" --startup-file=no --project="$PROJECT" \
  "$EVAL/cases/surface_layer/registries/run_registry_case.jl" \
  "$EVAL/cases/surface_layer/registries/gabls1_sld_resolved_factor.toml" "$SLURM_ARRAY_TASK_ID" "$SLD_RUN_ROOT"
code=$?
set -e
temporary=$(mktemp "$SLD_EXIT_RECORD_ROOT/factor-exit.XXXXXX")
{
  printf 'array_job_id=%s\ntask_id=%s\nslurm_job_id=%s\nchild_exit_code=%s\n' "$SLURM_ARRAY_JOB_ID" "$SLURM_ARRAY_TASK_ID" "$SLURM_JOB_ID" "$code"
  printf 'started_utc=%s\nfinished_utc=%s\n' "$started" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'source_manifest_sha256=%s\n' "$(sha256sum source_sha256.txt | cut -d' ' -f1)"
  printf 'wrapper_sha256=%s\n' "$(sha256sum "${BASH_SOURCE[0]}" | cut -d' ' -f1)"
  printf 'gpu_evidence_directory=%s\nrecord_complete=true\n' "$SLD_VALIDATION_EVIDENCE"
} > "$temporary"
ln "$temporary" "$record"
rm "$temporary"
printf 'SLD_FACTOR_BATCH_EXIT job=%s task=%s child_exit_code=%s record=%s\n' "$SLURM_ARRAY_JOB_ID" "$SLURM_ARRAY_TASK_ID" "$code" "$record"
exit "$code"
