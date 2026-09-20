#!/bin/bash -l
#SBATCH --job-name=sld-bounded-les
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=12:00:00

set -euo pipefail

: "${SLD_FREEZE_ROOT:?set SLD_FREEZE_ROOT to the admitted immutable snapshot}"
: "${SLD_VALIDATION_EVIDENCE:?set SLD_VALIDATION_EVIDENCE to the admitted gpu_full output}"
: "${SLD_REGISTRY_RELATIVE:?set the registry path relative to BreezeEvaluation.jl}"
: "${SLD_RUN_ROOT:?set a new campaign run root}"
: "${SLURM_ARRAY_TASK_ID:?submit only as an explicit four-task array}"

JULIA_EXE=/shared/home/greg/.juliaup/bin/julia
EVALUATION_ROOT="${SLD_FREEZE_ROOT}/source/BreezeEvaluation.jl"
PROJECT_ROOT="${EVALUATION_ROOT}/cases/gabls3/runner"
REGISTRY="${EVALUATION_ROOT}/${SLD_REGISTRY_RELATIVE}"
LAUNCHER="${EVALUATION_ROOT}/cases/surface_layer/registries/run_registry_case.jl"
ADMISSION="${EVALUATION_ROOT}/cases/surface_layer/gpu_validation/admit_gpu_validation.jl"

cd "${SLD_FREEZE_ROOT}"
sha256sum --check source_sha256.txt
"${JULIA_EXE}" --startup-file=no --project="${PROJECT_ROOT}" \
    "${ADMISSION}" "${SLD_VALIDATION_EVIDENCE}" "${SLD_FREEZE_ROOT}"
export SLD_CASE_EXECUTION_ACK=IMMUTABLE_GPU_VALIDATED
exec "${JULIA_EXE}" --startup-file=no --project="${PROJECT_ROOT}" \
    "${LAUNCHER}" "${REGISTRY}" "${SLURM_ARRAY_TASK_ID}" "${SLD_RUN_ROOT}"
