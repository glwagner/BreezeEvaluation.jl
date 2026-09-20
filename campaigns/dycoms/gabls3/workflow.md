# GABLS3 and BreezeEvaluation handoff

User requested 2026-09-20: add GABLS3 to the same master document, retain all GABLS1/DYCOMS, direct both existing pcluster agents to prepare cases, create glwagner/BreezeEvaluation.jl and persist all three evaluations there rather than on the Breeze branch.

Remote task brief: /shared/home/greg/review-coordination/gabls3-evaluation-task.md. Agent47 owns runner/forcing/case matrix; agent48 owns repo creation/migration/reference inputs/export. Remote statuses: gabls3-pane47-status.md and gabls3-pane48-status.md in the same coordination directory. Inspect current UI before sending messages. Pane47 was in an obsolete rerun menu; Escape dismissed it, then task appended to an existing manuscript-coordination draft. Check acknowledgment rather than assuming delivery. Pane48 acknowledged and created private repo https://github.com/glwagner/BreezeEvaluation.jl (push/migration still to verify at this note).

Canonical GABLS3 LES: Basu et al.2012 ECMWF proceedings, 00-09UTC July2,2006; 800m cube,6.25m common grid. Distinguish24hourSCM. Proposed Breeze comparison12.5/6.25/3.125m=64/128/256cubed, each WENO9/none,WENO5/none,WENO9/Smag. Only preparation and bounded validation now; no new expensive production campaign before reviewable case/data contract. Existing GABLS1 priority and max2GPUjobs.

Desktop added reference.md as PartIII through build_master_report.jl. Julia generation and2page PDF visual inspection passed. Original DYCOMS section hash remains0b35ce7f026a35249e5e23f8d3fc0ea8da9fe62866f45942da6de002bd3fbfe8. GABLS1 text/figures retained. Keep reference.md current with verified status, distinguishing proposed from submitted/completed.

Repo migration must include original source/dependency provenance, compact audited outputs, reference provenance, plots and master/report scripts. Third-party PDFs are linked; large raw arrays stay in place with checked manifests. Do not rewrite production hashes or move/freeze running jobs. Agent48 owns repository git mutations; coordinate edits to avoid conflicts. Desktop supplies updated deliverables through package_report.jl --sync into dycoms-reference; notify48 when ready to import. Current plots use fixed1mGABLS1 reference, which does not transfer to GABLS3 as an ensemble reference.

Existing GABLS1 collection and plot commands remain in ../gabls/workflow.md. Resolve live job IDs from schema2 cases.json, including startup_dt_v1 revisions. At new-task handoff12/15verified;7103_2 and7120_1running,7120_2pending. No duplicate runs or watcher. All original15DYCOMS intact.

Automation finish-dycoms-comparison-report updated to Monitor Breeze evaluations and master report, ACTIVE10min. Follow GABLS1 completion AND repository/GABLS3 preparation; do not pause solely because GABLS1 finishes. Quiet unchanged healthy state, notify meaningful progress/failure/blocker. Julia only, never Python.

Confirmed peer limitation: pane47 task submission reached its provider spending-limit error. Do not repeatedly send work expecting it to run. Desktop fallback subagent gabls3_preparation now owns disjoint remote /shared/home/greg/review-coordination/gabls3-preparation/ for forcing/table scaffold, tests and proposed9case matrix; publishes gabls3-pane47-status.md. Pane48 was notified. Continue repository/migration via active pane48. Original pane47 remains intact.
