#!/bin/bash -l
# Root-owned submission only; non-scientific matched 120 s GPU throughput fixture.
#SBATCH --job-name=sld-neutral-120s
#SBATCH --partition=gpu-prod
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus=h100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:00:00

set -euo pipefail

: "${SLD_NEUTRAL_OUTPUT:?set an absolute, nonexistent output directory}"
case "${SLD_NEUTRAL_OUTPUT}" in
    /*) ;;
    *) echo "SLD_NEUTRAL_OUTPUT must be absolute" >&2; exit 2 ;;
esac
test ! -e "${SLD_NEUTRAL_OUTPUT}"

JULIA_EXE=/shared/home/greg/.juliaup/bin/julia
CORE=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647
EVALUATION="${CORE}/source/BreezeEvaluation.jl"
PROJECT="${EVALUATION}/cases/gabls3/runner"
HARNESS="${EVALUATION}/cases/surface_layer/neutral/run_neutral_gpu_throughput.jl"
REGISTRY="${EVALUATION}/cases/surface_layer/neutral/neutral_sld_2case.toml"
ADAPTATION="${EVALUATION}/cases/surface_layer/diagnostics/LegacyGABLSDiagnosticsAdaptation.jl"
: "${SLD_COMBINED_GPU_EVIDENCE:?set the admitted fresh v2 parent}"
GATE="${SLD_COMBINED_GPU_EVIDENCE}"
ADMISSION=/shared/home/greg/review-coordination/admit_sld_flux_schedule_gpu_gate_a14c358-v3.jl
AUDIT=/shared/home/greg/review-coordination/audit_neutral_speed_gate_a14c358-v3.jl

cd "${CORE}"
printf '%s  %s\n' \
    'd2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c' source_sha256.txt \
    '15acf1ea5f24c390dcf7319b1a429b7076caa3d353192bcb688173ee656c0a91' "${HARNESS}" \
    '5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156' "${REGISTRY}" \
    'a8d029d23d9765c76895337c6d537008c5d322f401756fc9d1eae714c9052257' "${ADAPTATION}" \
    '1c74d77dab44e6a4c81a033d7e8fd7e1f21349614a9223b5e02665c75eb47365' "${PROJECT}/Manifest.toml" \
    '9b8782a1fd29d95841a9af2ed382c57751662052dcef877f3797ad224c0aec10' "${ADMISSION}" \
    '4b5c0bcbbefd7f1d7bd136dd849ae561dadd3a4e686d410e9693dd216e292fbc' "${AUDIT}" |
    sha256sum --check --quiet
sha256sum --check --quiet source_sha256.txt

# The supplemental admission itself requires the full gpu_full contract,
# source hashes, nonzero physical SGS flux, and exact scheduled event writers.
"${JULIA_EXE}" --startup-file=no --project="${PROJECT}" \
    "${ADMISSION}" "${GATE}"

on_exit() {
    status=$?
    if (( status != 0 )) && [[ -d "${SLD_NEUTRAL_OUTPUT}" ]]; then
        printf 'mode=gpu_neutral_120s_speed_and_flux_semantics\nexit_code=%s\n' \
            "${status}" > "${SLD_NEUTRAL_OUTPUT}/NEUTRAL_SPEED_GATE_FAILED"
    fi
    exit "${status}"
}
trap on_exit EXIT

export SLD_NEUTRAL_GPU_ACK=ADMITTED_CORE_GPU_CONTRACT
"${JULIA_EXE}" --startup-file=no --project="${PROJECT}" \
    "${HARNESS}"
"${JULIA_EXE}" --startup-file=no --project="${PROJECT}" \
    "${AUDIT}" "${SLD_NEUTRAL_OUTPUT}"

test -f "${SLD_NEUTRAL_OUTPUT}/NEUTRAL_SPEED_GATE_DONE"
echo "NEUTRAL_SPEED_GATE_COMPLETED_NONSCIENTIFIC job_id=${SLURM_JOB_ID:-unknown}"
