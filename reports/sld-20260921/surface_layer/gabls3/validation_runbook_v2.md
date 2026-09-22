# GABLS3 surface-q read-only GPU gate v2 — root-only handoff

Status: prepared, **not GPU-admitted and not science-ready**. The v1 gate and its
handoff are preserved but superseded: v1 `capture()` reset the operand and clock
being tested. Do not launch v1. Pane 48 submitted no GPU/science job and made no
change to active 7120_2, GABLS1 7293, or the separate factor-2 worktrees.

## Fixed scientific and analysis sources

- Scientific core: `surface-layer-harness-freeze-20260921-131ad9b-02a1647`,
  Evaluation `131ad9be2cf58340cdfaf94029bdec290f6aa8ea`, Breeze
  `02a16478869abf556a464f0874925510bb7c233c`, 762 source hashes,
  manifest `1cc45c554fe4675a5ffde2dc6bfe70953d9c5294f9df4e6fe76b6f1f033886ac`.
- Analysis-only binding: `surface-layer-analysis-freeze-20260921-f234ff7-02a1647`,
  Evaluation `f234ff79c01bd94f59607b073d472140a13f7315`, same Breeze,
  762/762 hashes, zero writable files, manifest
  `c791cdf43e5a2a44e161c3adabd66c35d810caa0b71548dfcb4c409e4c67d64d`.
- Four-case GABLS3 scientific registry unchanged: n64 WENO9 none, SLD t100
  face1, SLD t300 face1, SLD t300 face2; seed 20260702, stop 32400 s. The
  old 7241 GPU pass applies to old source only and is checked as a prerequisite,
  never relabeled as new-source admission.

## What v2 actually tests

`capture()` reads the existing model clock and surface-q operand. It computes
diagnostic Fields but never assigns the clock or operand; it checks they remain
bitwise unchanged. Explicit setters appear only in the independent static wall
samples and the labeled nonphysical initial 3599 s clock rebase. Event and RK
stage observers during actual `Simulation.run!` have **zero model mutation**.
The gate samples all 64×64 materialized vapor-flux values from the real bottom
boundary condition, independently reconstructs flux using the prescribed
target-q table and actual transfer coefficient/wall state, and requires a
cellwise float-roundoff bound. Raw numeric planes and hashes are saved for an
independent admission recheck. Static coverage includes no closure, SLD one
face, SLD two faces at 0, 10800, 11100, 12600, 14400, 21600, 25200 and
32400 s. The two-face actual 3599→3611 s integration checks the initial
callback, exact 3600/3610 s events, RK stages, forcing switch, native 64-center/
65-face diagnostic profiles, 107-series/30-point records and true serialized
restart/continuation. This is a synthetic gate, **not** nine-hour LES evidence.

CPU static wall reconstruction passed 7 checks with zero actual/target flux
difference. The full 64-cube CPU actual-run fixture passed 539 checks: 3 event
captures, 73 RK-stage captures, final time 3611 s. Independently auditing its
raw writer files and preserved GPU 7241 output found 51 profile, 107 series,
30 point variables with exact initial/scheduled times and native heights. At
3599/3600/3610 s the saved wall-q operand was respectively
0.009900028/0.0099/0.0099002775; the maximum cellwise materialized-minus-
target vapor-flux error was exactly zero at all three events. Analysis tests
passed 74/74; GPU reader negative/contract tests 13/13 including hash-valid
flux tampering; finalizer identity tests 5/5. The exact sealed v2 script was
rerun on CPU and also passed: 3 events, 73 stages, final time 3611 s,
51/107/30 profile/series/point variables and 539 checks. GPU v2 has **not** run.
Root must review/admit
the combined gate before any new GABLS3 array.
The independent v2 admission writer auditor also passed on the final-script
CPU files, including exact times, finite full-variable records, 64 center/65
face heights and native-face w moments.

The first CPU fixture data remain under
`/shared/home/greg/review-coordination/gabls3-surface-q-v2-cpu-crossing-20260921/event_crossing`;
the exact-final-script repeat writes separately to the corresponding
`gabls3-surface-q-v2-final-cpu-crossing-20260921` root. The first run used the
frozen runner project and called `crossing_gpu_contract(output;
architecture="cpu")` after including the v2 gate; it printed
`V2_CPU_READ_ONLY_CROSSING_PASS events=3 stages=73 final_time_s=3611.0 checks=539`.
The final-script source preflight independently passed 5/5 checks. CPU fixtures
are never a substitute for the H100 gate. The coordination scripts are
read-only (wrappers executable) and their hashes still match the table below.
The v2 reader independently re-admitted old 7241 evidence strictly as an
old-source prerequisite (combined SHA
`55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02`);
this does **not** admit the corrected source.

## Pinned coordination files

| Role | File in `/shared/home/greg/review-coordination` | SHA-256 |
|---|---|---|
| GPU gate | `gabls3-surface-q-gpu-gate-131ad9b-v2.jl` | `dc437c856626a0c67b74ef3e174c9f786b0ba87487291c6d4bcb5fe4dd939ffa` |
| GPU wrapper | `run_gabls3_surface_q_gpu_gate_131ad9b-v2.sh` | `f70e13e1b4ba0a19c9816e5e2c274f0417eed6a060d0cb1842a0c04c3a8dab16` |
| strict reader | `admit_gabls3_surface_q_gpu_gate_131ad9b-v2.jl` | `dfdfeeede4d3020749b3e629b11958ba4ebbf6961af1dc80f5be6c7f7054643a` |
| science wrapper | `run_gabls3_sld_recorded_array_131ad9b-v2.sh` | `f9fe455a0450cf83c936c53b95418697a84d00e07666a5a09a7b4eca23ce3e31` |
| finalizer | `prepare_gabls3_sld_attempts_131ad9b-v2.jl` | `b445bf351c4880f1302d73ea1a0cf5baa6eb64ef25c6a9c056829854c376871b` |

Root-only gate command, when an approved H100 slot is free (output path must
not exist; archive actual job ID/log and launcher bytes):

```bash
CORE=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-131ad9b-02a1647
GATE_OUT=/shared/home/greg/review-coordination/gabls3-surface-q-gpu-v2-NEW
GATE_LOG=/shared/home/greg/review-coordination/gabls3-surface-q-gpu-v2-NEW-%j.log
sbatch --partition=gpu-prod --gpus=h100:1 --cpus-per-task=8 --mem=32G --time=01:30:00 \
  --output="$GATE_LOG" --export=ALL,GABLS3_Q_GATE_OUTPUT="$GATE_OUT" \
  /shared/home/greg/review-coordination/run_gabls3_surface_q_gpu_gate_131ad9b-v2.sh
```

After queue absence and stable log, strict admission requires DONE, no FAILED,
durable child exit zero, matching job/log/source/gate/wrapper hashes, full
raw-JLD2 finite/shape/flux/time/coordinate audits, event/forcing evidence and
serialized continuation. A fatal signal with no DONE is a failure.

```bash
/shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project="$CORE/source/BreezeEvaluation.jl/cases/gabls3/runner" \
  /shared/home/greg/review-coordination/admit_gabls3_surface_q_gpu_gate_131ad9b-v2.jl \
  "$GATE_OUT" GPU_JOB_ID ACTUAL_GATE_LOG_PATH
```

Only after strict admission, root may launch the separate four-case GABLS3
science array with the v2 wrapper. Use a **new** campaign root and preserve
all old 7166/v1 output. Keep `%1` concurrency if original 7120_2 still occupies
one GPU; never exceed two evaluation jobs. The wrapper re-runs v2 admission
before enabling science and writes schema-2 child-exit records.

```bash
CAMPAIGN=/shared/home/greg/review-coordination/gabls3-sld-production-131ad9b-v2-NEW
mkdir -p "$CAMPAIGN/runs" "$CAMPAIGN/logs" "$CAMPAIGN/metadata"
sbatch --partition=gpu-prod --gpus=h100:1 --cpus-per-task=8 --mem=32G \
  --time=12:00:00 --array=1-4%1 \
  --output="$CAMPAIGN/logs/gabls3_sld_%A_%a.out" \
  --export=ALL,SLD_FREEZE_ROOT="$CORE",SLD_VALIDATION_EVIDENCE="$GATE_OUT",GABLS3_Q_GPU_JOB_ID=GPU_JOB_ID,GABLS3_Q_GPU_LOG=ACTUAL_GATE_LOG_PATH,SLD_REGISTRY_RELATIVE=cases/surface_layer/registries/gabls3_sld_4case.toml,SLD_RUN_ROOT="$CAMPAIGN/runs",SLD_EXIT_RECORD_ROOT="$CAMPAIGN/logs" \
  /shared/home/greg/review-coordination/run_gabls3_sld_recorded_array_131ad9b-v2.sh
```

Once all four jobs have left the queue, reached CASE_DONE with no failure,
and have stable logs plus four durable child exits, finalize to a **new**
registry path, then use the frozen Julia exporter/collector. Raw schedule
times are never rounded; exporter rejects drift/incomplete or mismatched
attempts. No report curves are admitted by this handoff.

```bash
ANALYSIS=/shared/home/greg/review-coordination/surface-layer-analysis-freeze-20260921-f234ff7-02a1647
/shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project="$ANALYSIS/source/BreezeEvaluation.jl/cases/gabls3/runner" \
  /shared/home/greg/review-coordination/prepare_gabls3_sld_attempts_131ad9b-v2.jl \
  "$GATE_OUT" GPU_JOB_ID ACTUAL_GATE_LOG_PATH ARRAY_JOB_ID \
  "$CAMPAIGN/runs" "$CAMPAIGN/logs" "$CAMPAIGN/metadata/gabls3_sld_attempts.toml"
```


2026-09-22: Factor10 science7339 completed9h with childexit0, GPU7338 passed4462checks. Strict collection admitted1/rejected0. GPUevidence4d9e203c5c25f8f98d9ea6fe89419f9a647556996e009fdee30f2490fe738b01, attempts d92a62ac01b2fa45165c4a6c1c086758e6dc5289c846437e4ab9a92542a4c12b. Factor helpers collect/analyze; root integrates report. USER HOLD: no WENO-native reconstructed flux implementation or run until Greg has seen factor10 results. Root submitted GABLS3 array7343,1-4%1,node1,12h/case, new campaign /shared/home/greg/review-coordination/gabls3-sld-production-131ad9b-v2-20260922; gate7335, core131ad9b, sealed v2 science wrapper unchanged invoked with sbatch --wrap exec /bin/bash to avoid login teardown. Original7120_2node2 remains running. No new G3 science curves yet.
