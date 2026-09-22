#!/bin/bash -l
#SBATCH --job-name=sld-neutral-cost
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:00:00

set -euo pipefail

: "${SLD_CORE_FREEZE_ROOT:?set the repaired sealed core GPU-contract snapshot}"
: "${SLD_CORE_GPU_EVIDENCE:?set its admitted gpu_full evidence directory}"
: "${SLD_NEUTRAL_FREEZE_ROOT:?set the separate read-only neutral snapshot}"
: "${SLD_NEUTRAL_OUTPUT:?set a new neutral throughput output directory}"

JULIA_EXE=/shared/home/greg/.juliaup/bin/julia
CORE_EVALUATION_ROOT="${SLD_CORE_FREEZE_ROOT}/source/BreezeEvaluation.jl"
NEUTRAL_EVALUATION_ROOT="${SLD_NEUTRAL_FREEZE_ROOT}/source/BreezeEvaluation.jl"
PROJECT_ROOT="${NEUTRAL_EVALUATION_ROOT}/cases/gabls3/runner"
ADMISSION="${CORE_EVALUATION_ROOT}/cases/surface_layer/gpu_validation/admit_gpu_validation.jl"
HARNESS="${NEUTRAL_EVALUATION_ROOT}/cases/surface_layer/neutral/run_neutral_gpu_throughput.jl"

test ! -e "${SLD_NEUTRAL_OUTPUT}"
cd "${SLD_CORE_FREEZE_ROOT}"
sha256sum --check source_sha256.txt
"${JULIA_EXE}" --startup-file=no --project="${CORE_EVALUATION_ROOT}/cases/gabls3/runner" \
    "${ADMISSION}" "${SLD_CORE_GPU_EVIDENCE}" "${SLD_CORE_FREEZE_ROOT}"
cd "${SLD_NEUTRAL_FREEZE_ROOT}"
sha256sum --check source_sha256.txt
export SLD_NEUTRAL_GPU_ACK=ADMITTED_CORE_GPU_CONTRACT
exec "${JULIA_EXE}" --startup-file=no --project="${PROJECT_ROOT}" \
    "${HARNESS}"
