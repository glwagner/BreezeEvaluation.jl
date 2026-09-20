# Bounded SurfaceLayerDiffusivity GPU contract

This directory contains preparation only. No job represented here has been submitted. The harness
must be run from a new read-only snapshot whose checksum manifest includes the harness, both case
runners, both registries, the pinned runner environment, and the reviewed Breeze feature source.
The earlier `surface-layer-freeze-20260920-34e955b` remains immutable and is not modified.

`validate_surface_layer.jl` has two modes:

- `cpu_contract` runs the same tiny Float32 dry/moist, one/two-face kernel, native-profile writer,
  implicit conservation, and serialized checkpoint/continued-evolution contracts on CPU. It does
  not claim GPU validation.
- `gpu_full` refuses a nonfunctional CUDA device, disables scalar indexing, runs those contracts on
  GPU, then compiles and runs the real GABLS1 and GABLS3 diagnostic writers. It checks the GABLS1
  native-height initial profiles, exact GABLS3 t=300 s profile/series/point records, and exact
  t=21600 s sunrise callback/surface-humidity/guard plumbing. The two GABLS3 clock jumps are labeled
  nonphysical scheduler fixtures and their output is never admissible as a scientific state.

Every tiny dry/moist support combination is checkpointed to JLD2, loaded through Oceananigans'
real `set!(simulation; checkpoint=...)` pickup path, evolved further, and compared bit-for-bit with
an uninterrupted reference. GPU-full mode additionally performs that serialized split/restart
comparison with the actual 64-cubed moist GABLS3 runner and its time-dependent surface operands.
CPU mode writes distinct `CPU_VALIDATION_*` sentinels and can never
admit an array. GPU mode writes mutually exclusive `GPU_VALIDATION_DONE` and
`GPU_VALIDATION_FAILED` sentinels plus a hashed TOML evidence record.

The separate registries in `../registries` contain exactly four GABLS1 and four GABLS3 logical
cases. They preserve same-runner paired initial arrays/seeds and remain `UNSUBMITTED`. They do not
replace or modify the original 15-case GABLS1 registry.

After GPU capacity is free and a new snapshot has passed its own checksum audit, the prepared GPU
contract command is:

```sh
SLD_FREEZE_ROOT=/absolute/read-only/snapshot \
SLD_VALIDATION_OUTPUT=/absolute/new/validation-output \
sbatch surface_layer_gpu_validation.slurm
```

Only after that contract is admitted, each four-case matrix can be submitted explicitly with a
maximum array concurrency of one (and never more than two total GPU jobs across campaigns):

```sh
SLD_FREEZE_ROOT=/absolute/read-only/admitted-snapshot \
SLD_VALIDATION_EVIDENCE=/absolute/admitted/gpu-validation-output \
SLD_REGISTRY_RELATIVE=cases/surface_layer/registries/gabls1_sld_4case.toml \
SLD_RUN_ROOT=/absolute/new/gabls1-run-root \
sbatch --array=1-4%1 ../registries/run_four_case_array.slurm
```

The array script independently rejects CPU evidence, failure/missing sentinels, an altered evidence
file, a mismatched freeze, any failed source-manifest hash, and changed harness/runner sources
before it sets the guarded launcher acknowledgement. The GABLS3 command differs only in registry
and run root. These are documentation commands, not
authorization to submit. Export admission additionally requires `CASE_DONE`, `EXPORT_VERIFIED`,
source hashes, exact schedule/coordinate audits, finite diagnostics, and matching initial digests.
