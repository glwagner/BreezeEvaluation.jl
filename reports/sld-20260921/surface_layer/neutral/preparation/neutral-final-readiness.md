# Neutral ABL SLD: root-only bounded cost-gate launch handoff

Reviewed 2026-09-22 UTC. **No neutral GPU job has been submitted.** This handoff covers only the paired, non-scientific 120 s throughput/flux-semantics gate. Root is the sole scheduler; no five-hour scientific pair is authorized by a CPU test or by the previously admitted GABLS GPU gate alone.

## Source and evidence identities

| Item | Exact path / SHA-256 |
|---|---|
| Read-only scientific core | `/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647`; `source_sha256.txt` `d2a6c2adea31fca7b6ed370780fc319e65c5cc7418f8153efb45dca6d563920c`; **761/761** source hashes pass; zero writable source files. Evaluation commit `a14c3586708de70cd3a47f44878991a440678442`, Breeze feature `02a16478869abf556a464f0874925510bb7c233c`. |
| Frozen runner environment | `source/BreezeEvaluation.jl/cases/gabls3/runner/Manifest.toml` SHA `1c74d77dab44e6a4c81a033d7e8fd7e1f21349614a9223b5e02665c75eb47365`; Julia `/shared/home/greg/.juliaup/bin/julia` **1.12.6**, snapshot-local Breeze loaded, Oceananigans **0.113.0**. |
| Matched neutral registry | `source/BreezeEvaluation.jl/cases/surface_layer/neutral/neutral_sld_2case.toml` SHA `5bb83f458af6cce588450bc70cac58655edaadff0e601c191773505ce5aa7156`. It is still `UNSUBMITTED`. |
| Neutral runner / diagnostics | `neutral_abl_case.jl` `aab32904134691ed4fc50149199ed16f9e3eee3b0215224be48c8750b15b7fe4`; `NeutralSurfaceLayerDiagnostics.jl` `0edcb6793cff74b9a8eed77f1900fc8e3ddbf5925500e039737bc3f213d5c49e`; corrected `LegacyGABLSDiagnosticsAdaptation.jl` `a8d029d23d9765c76895337c6d537008c5d322f401756fc9d1eae714c9052257`. The first two match the prior CPU168 snapshot byte-for-byte; the adaptation is the later constitutive SGS-flux correction and does **not** alter prognostic tendencies. |
| Frozen 120 s throughput harness | `source/BreezeEvaluation.jl/cases/surface_layer/neutral/run_neutral_gpu_throughput.jl` SHA `15acf1ea5f24c390dcf7319b1a429b7076caa3d353192bcb688173ee656c0a91`. |
| Admitted prerequisite GPU gate | `/shared/home/greg/review-coordination/surface-layer-flux-schedule-gpu-validation-v3-20260921-1806`; v3 reader `admit_sld_flux_schedule_gpu_gate_a14c358-v3.jl` SHA `9b8782a1fd29d95841a9af2ed382c57751662052dcef877f3797ad224c0aec10` independently re-admitted job **7241**: combined evidence `55138ed4123e656e2bc595cff1320fb3073f42bddd10402ef220bbe4c458ac02`, semantic evidence `47826ecbfb00dde15e281cf94bea0e98d0dc5bbbad85eaccf1b68797cc7411a1`, source manifest `d2a6c2...563920c`. No FAILED sentinel. |
| Coordination-only cost launcher | `/shared/home/greg/review-coordination/neutral_speed_gate_a14c358-v3.slurm` SHA `eea38d600667f5a5e1c85584944c88f0894bd9bf680d6f47d4653289061c543b`; `bash -n` passed. |
| Coordination-only raw-JLD2 auditor | `/shared/home/greg/review-coordination/audit_neutral_speed_gate_a14c358-v3.jl` SHA `4b5c0bcbbefd7f1d7bd136dd849ae561dadd3a4e686d410e9693dd216e292fbc`; synthetic accept/reject test SHA `b903aa9d717d31711e254cf734aa294b237e18c010931daf5f201ec275bc6eb8` passed **10/10** in the frozen runner environment. |

The original preparation and pre-v3 handoff are at `cases/surface_layer/neutral/preparation.md` in the frozen core and `/shared/home/greg/review-coordination/sld-neutral-speed-gate-a14c358-handoff.md`. This document supersedes only their obsolete 7199/v1 launch binding. Later `131ad9b` corrects **GABLS3 humidity**; the dry neutral runner, constant-stress physics and a14c358/v3 GPU admission remain the intended neutral pair. Do not silently relabel the neutral source as `131ad9b` or use the GABLS3-only 7335 gate as its admission.

## CPU and physical contract

The inherited source-bound 371e152 neutral CPU evidence (`/shared/home/greg/review-coordination/surface-layer-neutral-cpu-evidence-20260921-371e152.toml`) passed **168/168** under the same Julia/runner Manifest. It covers five provenance, 16 canonical/paired digest, 20 actual fixed-stress/zero-heat/one-face/support/conservation, 58 native writer and six-record hour-window, and 69 serialized restart/continuation checks. It predates the corrected diagnostic SGS helper; do not describe it as a current-core GPU-flux test. A fresh exact-a14c358 CPU rerun is recorded below after completion.

The immutable registry defines paired WENO9/no closure and WENO9/SLD `filter_timescale=300 s`, one supported interior face, seed **1994**, Float32, **96³**, **3000×3000×1000 m**, original physical 468–530.5 m inversion, `dt_initial=0.5 s`, CFL target 0.7, and five-hour target. Both use prescribed `u*=0.5 m/s` (kinematic wall-stress magnitude 0.25 m²/s²), zero surface heat flux, **no roughness/MOST law**, identical geostrophic/Coriolis/sponge forcing and initial-array digests. SLD θ-flux guard is `1e-8`, so the neutral scalar diffusivity should stay inactive. This experiment can assess vertical transport under imposed wall stress, **not** prediction of surface drag.

Canonical scientific output remains separate: instantaneous t=0, 30 true preceding-600 s averaged profiles ending `600:600:18000`, 60 s series, 3600 s checkpoints, six final-hour bins `15000:600:18000`, six penultimate bins `11400:600:14400`. The 120 s fixture has separate case IDs and cannot satisfy this scientific admission.

## Root-only cost-gate command; not submitted

When root confirms GPU capacity and the global two-GPU limit, choose a **new**, absolute, nonexistent output root and sibling log. The original launcher has a login-shell shebang; to avoid the previously observed cluster `~/.bash_logout`/`clear_console` post-success exit-code hazard, invoke its unchanged bytes through non-login `/bin/bash` and provide all resources explicitly because `sbatch --wrap` does not read embedded `#SBATCH` lines:

```bash
SLD_NEUTRAL_OUTPUT=/shared/home/greg/review-coordination/neutral-speed-gate-UNIQUE \
SLD_COMBINED_GPU_EVIDENCE=/shared/home/greg/review-coordination/surface-layer-flux-schedule-gpu-validation-v3-20260921-1806 \
sbatch --partition=gpu-prod --nodes=1 --ntasks=1 --gpus=h100:1 \
  --cpus-per-task=8 --mem=32G --time=01:00:00 --export=ALL \
  --output=/shared/home/greg/review-coordination/neutral-speed-gate-UNIQUE.log \
  --wrap='exec /bin/bash /shared/home/greg/review-coordination/neutral_speed_gate_a14c358-v3.slurm'
```

Archive the exact launcher/auditor SHA values with the job ID and fresh output path. The launcher rechecks all 761 frozen files, its pinned script hashes and v3 combined GPU admission, then warms both 96³ variants for 1 s with full writers and evolves each for **120 s** with native profiles at 60/120 s and 10 s series. The raw auditor checks exact record times/96-center/97-face heights, finite native u/v/θ fluxes, z=0 prescribed wall substitution, interior `total=resolved+SGS`, nonzero supported SLD SGS momentum stress/viscosity, exact zero no-closure SGS, zero wall heat, and inactive SLD θ diffusivity/guard. It also matches both initial digests and raw JLD2 hashes to the frozen throughput evidence.

**Cost-gate admission:** require job child exit zero, no `NEUTRAL_THROUGHPUT_FAILED` or `NEUTRAL_SPEED_GATE_FAILED`, both `NEUTRAL_THROUGHPUT_DONE` and `NEUTRAL_SPEED_GATE_DONE`, and the latter's `evidence_sha256` equal to `neutral_speed_gate_evidence.toml`. Review actual per-case 120 s wall time, iterations/dt extrema, after-warmup seconds per step, control/SLD ratio, and naive five-hour projection. The projection is a planning estimate only; compilation/writer overhead and changing dt can make it inaccurate. Do not count the warmups or this fixture as LES science.

Only after this bounded GPU gate passes and root reviews measured cost should a separately versioned **scientific** two-case launcher/registry activation, durable exit capture, full five-hour completion audit, Julia export and plots be prepared and scheduled. No such neutral scientific array is launched by this handoff. Preserve all old sources/results and do not implement WENO reconstructed-flux closure.

### Fresh frozen-core CPU rerun

Command:

```bash
/shared/home/greg/.juliaup/bin/julia --startup-file=no \
  --project=/shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647/source/BreezeEvaluation.jl/cases/gabls3/runner \
  /shared/home/greg/review-coordination/surface-layer-harness-freeze-20260921-a14c358-02a1647/source/BreezeEvaluation.jl/cases/surface_layer/neutral/test_neutral_runner.jl
```

Result: **in progress at handoff drafting**; replace this line with actual exit and testset counts before treating the cost gate as ready.
