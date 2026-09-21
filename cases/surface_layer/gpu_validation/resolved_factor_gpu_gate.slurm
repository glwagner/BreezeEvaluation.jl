#!/bin/bash -l
#SBATCH --job-name=sld-factor-gate
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:00:00
set -euo pipefail
: "${SLD_FREEZE_ROOT:?}"
: "${SLD_VALIDATION_OUTPUT:?}"
EVAL="$SLD_FREEZE_ROOT/source/BreezeEvaluation.jl"
cd "$SLD_FREEZE_ROOT"
sha256sum --check source_sha256.txt >/dev/null
export SLD_FACTOR_MODE=gpu
exec /shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project="$EVAL/cases/gabls3/runner" \
  "$EVAL/cases/surface_layer/gpu_validation/validate_resolved_flux_factor.jl"
