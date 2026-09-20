# Current GABLS scope (user correction, 2026-09-19)

Exactly three configurations at each of five grids:

- WENO(order=9), no interior closure.
- WENO(order=5), no interior closure.
- WENO(order=9), Smagorinsky-Lilly (Cs=0.16, Cb=1, Pr=1).

There are **15 GABLS production cases**, not 25. WENO5/Smagorinsky and Centered2/Smagorinsky are excluded for now. Retain completed smoke-test evidence, but do not submit excluded configurations. The completed 15-case DYCOMS experiment is unchanged.

Five fixed-domain isotropic grids: 32³, 64³, 128³, 200³, 400³, each in a 400 m cube. Use explicit dependencies between successive grid groups and at most two concurrent GPU jobs. All remaining 15 cases are authorized. Both existing cluster agents remain engaged: pane 47 owns implementation and scheduling, pane 48 diagnostics and exports.

This correction supersedes every older 25-case brief, matrix, scheduling note, or monitor instruction. Update the authoritative cases.json, watcher case list/count and completion condition, local matrix, automation and master report consistently.
