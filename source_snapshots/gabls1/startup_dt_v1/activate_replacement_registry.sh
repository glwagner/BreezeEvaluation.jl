#!/bin/bash
# Transactionally retarget exactly the two failed 400^3 WENO9 logical cases after smoke pass
# and replacement-array submission. The caller supplies the replacement Slurm array job ID.
set -euo pipefail

[[ $# -eq 1 && $1 =~ ^[0-9]+$ ]] || {
  echo "usage: $0 REPLACEMENT_ARRAY_JOB_ID" >&2
  exit 2
}

JOB_ID=$1
CAMPAIGN=/shared/home/greg/review-coordination/gabls-production-v2-20260919
REVISION_ROOT=$CAMPAIGN/revisions/startup_dt_v1
REGISTRY=$CAMPAIGN/cases.json
BACKUP=$REVISION_ROOT/cases.before-startup_dt_v1.json
TEMPORARY=$REVISION_ROOT/cases.updated.tmp.json

[[ ! -e $BACKUP ]] || {
  echo "REFUSING: immutable registry backup already exists: $BACKUP" >&2
  exit 3
}
cp -a "$REGISTRY" "$BACKUP"

ORIGINAL_HASH=$(sha256sum "$REGISTRY" | cut -d' ' -f1)
[[ $ORIGINAL_HASH == abefa764e8645a2c29196cd085967020bd938a55ba87e175baff0fc73f802aad ]] || {
  echo "REFUSING: cases.json changed unexpectedly: $ORIGINAL_HASH" >&2
  exit 4
}

jq --arg job "$JOB_ID" --arg campaign "$CAMPAIGN" --arg revision_root "$REVISION_ROOT" '
  .registry_schema_version = 2
  | .replacement_arrays = ((.replacement_arrays // {}) + {
      "startup_dt_v1": {
        "array_job_id": ($job | tonumber),
        "array": "1-2%1",
        "logical_cases": ["n400_weno9_none", "n400_weno9_smagorinsky"],
        "walltime": "144:00:00"
      }
    })
  | .source_revisions = ((.source_revisions // {}) + {
      "startup_dt_v1": {
        "source_path": ($revision_root + "/source"),
        "metadata_path": ($revision_root + "/source_revision.json"),
        "change": "initial Simulation dt only: 0.5 -> min(0.5, 0.5 * dx / 8)"
      }
    })
  | .cases |= map(
      if .case_id == "n400_weno9_none" or .case_id == "n400_weno9_smagorinsky" then
        . as $old
        | (if .case_id == "n400_weno9_none" then 1 else 2 end) as $task
        | .source_revision = "startup_dt_v1"
        | .source_hashes = {
            "root_Manifest.toml": "9a410126b4340c4e2c17838e4c920df94d376e3852815b9db09033c01cd8a9fc",
            "gabls_diagnostics.jl": "6486c8ccd94f45df1c204fc57d1f3c0a79b8c4f3c27b3412c1b2bb81573e0c24",
            "gabls_case.jl": "8d408477905868429fcd3a7defba2428984cb2efcf461450ace5bbb2b2f4140a",
            "gabls_rough_wall_coefficient.jl": "5af7df039cf665817cd5ca0a9d48dca6d28bbae3bc300f3c5e79bd982aee20c3"
          }
        | .attempt_history = ((.attempt_history // []) + [{
            "job_id": ($old.array_job_id | tostring),
            "array_task_id": $old.array_task_id,
            "log_path": $old.log,
            "run_path": $old.root,
            "outcome": "failed_startup_nan_iteration_100",
            "source_revision": "v2_original"
          }])
        | .array_job_id = ($job | tonumber)
        | .array_task_id = $task
        | .job_id = ($job + "_" + ($task | tostring))
        | .root = ($revision_root + "/runs/" + .case_id)
        | .log = ($revision_root + "/logs/replacement-" + $job + "_" + ($task | tostring) + ".log")
        | .recommended_walltime = "144:00:00"
        | .submit = ("sbatch --parsable --time=144:00:00 --array=1-2%1 " +
                     $revision_root + "/replacement_production.batch")
      else . end)
  | .case_count = 15
' "$REGISTRY" > "$TEMPORARY"

jq -e '.case_count == 15 and (.cases | length) == 15 and
       ([.cases[].case_id] | unique | length) == 15 and
       ([.cases[] | select(.source_revision == "startup_dt_v1")] | length) == 2' \
   "$TEMPORARY" >/dev/null

mv "$TEMPORARY" "$REGISTRY"
echo "GABLS_REPLACEMENT_REGISTRY_ACTIVATED job=$JOB_ID old_sha256=$ORIGINAL_HASH new_sha256=$(sha256sum "$REGISTRY" | cut -d' ' -f1)"
