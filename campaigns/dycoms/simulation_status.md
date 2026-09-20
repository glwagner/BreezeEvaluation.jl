# DYCOMS GPU simulation status

Checked 2026-09-19T11:58:17.096Z. Julia-only collection and plotting.

| Case | State | Solver wall (s) | Export available |
|---|---|---:|---|
| coarse_none_weno9 | COMPLETED | 243.1 | true |
| coarse_none_weno5 | COMPLETED | 239.3 | true |
| coarse_smagorinsky_weno9 | COMPLETED | 246.0 | true |
| coarse_smagorinsky_weno5 | COMPLETED | 247.6 | true |
| canonical_none_weno9 | COMPLETED | 726.6 | true |
| canonical_none_weno5 | COMPLETED | 717.6 | true |
| canonical_smagorinsky_weno9 | COMPLETED | 701.7 | true |
| canonical_smagorinsky_weno5 | COMPLETED | 679.2 | true |
| fine_none_weno9 | COMPLETED | 5569.6 | true |
| fine_none_weno5 | COMPLETED | 4232.2 | true |
| fine_smagorinsky_weno9 | COMPLETED | 6130.5 | true |
| fine_smagorinsky_weno5 | COMPLETED | 4820.6 | true |
| coarse_smagorinsky_centered2 | COMPLETED | 252.5 | true |
| canonical_smagorinsky_centered2 | COMPLETED | 742.1 | true |
| fine_smagorinsky_centered2 | COMPLETED | 4212.2 | true |

[Report](dycoms_report.md) · [Exact source hashes](cluster/source_provenance.json) · [Status evidence](cluster/run_status.json).

Original JLD2 files and checkpoints remain at `/shared/home/greg/review-coordination/dycoms-production-20260919/runs/` on pcluster. Solver wall excludes Julia startup and compilation outside the time integration call.
