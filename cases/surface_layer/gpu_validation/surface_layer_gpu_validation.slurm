#!/bin/bash -l
#SBATCH --job-name=sld-gpu-contract
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:00:00

set -euo pipefail

: "${SLD_FREEZE_ROOT:?set SLD_FREEZE_ROOT to the immutable harness snapshot}"
: "${SLD_VALIDATION_OUTPUT:?set SLD_VALIDATION_OUTPUT to a new result directory}"

JULIA_EXE=/shared/home/greg/.juliaup/bin/julia
EVALUATION_ROOT="${SLD_FREEZE_ROOT}/source/BreezeEvaluation.jl"
PROJECT_ROOT="${EVALUATION_ROOT}/cases/gabls3/runner"
HARNESS="${EVALUATION_ROOT}/cases/surface_layer/gpu_validation/validate_surface_layer.jl"

test -r "${SLD_FREEZE_ROOT}/source_sha256.txt"
test ! -e "${SLD_VALIDATION_OUTPUT}/GPU_VALIDATION_DONE"
test ! -e "${SLD_VALIDATION_OUTPUT}/GPU_VALIDATION_FAILED"

cd "${SLD_FREEZE_ROOT}"
sha256sum --check source_sha256.txt
export SLD_VALIDATION_MODE=gpu_full
exec "${JULIA_EXE}" --startup-file=no --project="${PROJECT_ROOT}" "${HARNESS}"
