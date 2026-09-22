#!/bin/bash
# Root submits ONE case afterok the source-specific GPU gate; no array required.
#SBATCH --job-name=gabls1-factor3
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
: "${SLURM_JOB_ID:?}"
: "${HOME:?}"
evaluation="$SLD_FREEZE_ROOT/source/BreezeEvaluation.jl"
project="$evaluation/cases/gabls3/runner"
julia=/shared/home/greg/.juliaup/bin/julia
test -x "$julia"
test -r "$project/Manifest.toml"
cd "$SLD_FREEZE_ROOT"
sha256sum --check source_sha256.txt >/dev/null
"$julia" --startup-file=no --project="$project" \
  "$evaluation/cases/surface_layer/gpu_validation/admit_factor3.jl" "$SLD_VALIDATION_EVIDENCE" "$SLD_FREEZE_ROOT"
export SLD_CASE_EXECUTION_ACK=IMMUTABLE_GPU_VALIDATED
record="$SLD_EXIT_RECORD_ROOT/gabls1_factor3_${SLURM_JOB_ID}.exit"
[[ ! -e "$record" ]] || exit 2
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
set +e
"$julia" --startup-file=no --project="$project" \
  "$evaluation/cases/surface_layer/registries/run_registry_case.jl" \
  "$evaluation/cases/surface_layer/registries/gabls1_sld_factor3.toml" 1 "$SLD_RUN_ROOT"
code=$?
set -e
temporary=$(mktemp "$SLD_EXIT_RECORD_ROOT/factor3-exit.XXXXXX")
{
  printf 'batch_job_id=%s\ncase_index=1\nslurm_job_id=%s\nchild_exit_code=%s\n' "$SLURM_JOB_ID" "$SLURM_JOB_ID" "$code"
  printf 'started_utc=%s\nfinished_utc=%s\n' "$started" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'source_manifest_sha256=%s\n' "$(sha256sum source_sha256.txt | cut -d' ' -f1)"
  printf 'wrapper_sha256=%s\n' "$(sha256sum "${BASH_SOURCE[0]}" | cut -d' ' -f1)"
  printf 'gpu_evidence_directory=%s\nrecord_complete=true\n' "$SLD_VALIDATION_EVIDENCE"
} > "$temporary"
ln "$temporary" "$record"
rm "$temporary"
printf 'SLD_FACTOR3_BATCH_EXIT job=%s case=1 child_exit_code=%s record=%s\n' "$SLURM_JOB_ID" "$code" "$record"
exit "$code"
