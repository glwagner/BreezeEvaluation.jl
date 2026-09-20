#!/bin/bash
# Submits the five grid groups small-first with explicit afterany chaining.
#
# Run ONLY after pane 48's CPU contract passes. GPU 7098 has already passed
# (268/268 kernels, 422/422 raw-writer checks, both sentinels) on this exact
# diagnostics file.
#
# The v1 held arrays (7089_3, 7090, 7091, 7092) MUST be cancelled before this runs --
# they point at the defective frozen tree. This script refuses to proceed while any of
# them is still queued, so that v1 and v2 can never be in flight together.
set -euo pipefail
G=/shared/home/greg/review-coordination/gabls-production-v2-20260919
cd "$G"

[ -d "$G/source" ] || { echo "FREEZE MISSING: $G/source does not exist" >&2; exit 1; }

# The v1 failure was a diagnostics file that looked plausible but was wrong. A size check
# would not have caught it, so gate on the exact validated hash instead.
EXPECTED=$(jq -r '.source_hashes["gabls_diagnostics.jl"]' "$G/cases.json")
ACTUAL=$(sha256sum "$G/source/examples/gabls_diagnostics.jl" | cut -d' ' -f1)
[ "$ACTUAL" = "$EXPECTED" ] || {
  echo "REFUSING: frozen gabls_diagnostics.jl hash mismatch" >&2
  echo "  expected $EXPECTED" >&2
  echo "  actual   $ACTUAL" >&2
  exit 1
}

STALE=$(squeue -u "$USER" -h -o "%i" 2>/dev/null | grep -cE '^(7088|7089|7090|7091|7092)' || true)
[ "$STALE" -eq 0 ] || {
  echo "REFUSING: $STALE v1 array task(s) still queued. Cancel 7089 7090 7091 7092 first." >&2
  exit 1
}

for c in $(jq -r '.cases[].case_id' "$G/cases.json"); do
  [ -e "$G/runs/$c/provenance/git.txt" ] && { echo "REFUSING: $G/runs/$c already holds a completed case" >&2; exit 1; }
done

P=""
for spec in "32 04:00:00" "64 04:00:00" "128 08:00:00" "200 24:00:00" "400 96:00:00"; do
  set -- $spec; NX=$1; WALL=$2
  if [ -z "$P" ]; then
    J=$(sbatch --parsable --export=ALL,GABLS_GRID_NX=$NX --time=$WALL --array=1-3%2 gabls-production.batch)
  else
    J=$(sbatch --parsable --export=ALL,GABLS_GRID_NX=$NX --time=$WALL --array=1-3%2 --dependency=afterany:$P gabls-production.batch)
  fi
  echo "grid ${NX}^3  array job $J  walltime $WALL  dependency ${P:-none}"
  P=$J
done
