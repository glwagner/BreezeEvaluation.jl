#!/bin/bash
#SBATCH --job-name=sld-factor3-gate
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:00:00
set -euo pipefail
: "${SLD_FREEZE_ROOT:?}"
: "${SLD_VALIDATION_OUTPUT:?}"
: "${HOME:?}"
evaluation="$SLD_FREEZE_ROOT/source/BreezeEvaluation.jl"
julia=/shared/home/greg/.juliaup/bin/julia
test -x "$julia"
test -r "$evaluation/cases/gabls3/runner/Manifest.toml"
cd "$SLD_FREEZE_ROOT"
sha256sum --check source_sha256.txt >/dev/null
export SLD_FACTOR_MODE=gpu
exec "$julia" --startup-file=no --project="$evaluation/cases/gabls3/runner" \
  "$evaluation/cases/surface_layer/gpu_validation/validate_factor3.jl"
