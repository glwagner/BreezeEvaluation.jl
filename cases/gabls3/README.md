# GABLS3 case preparation

GABLS3 is the nine-hour LES case for 00:00--09:00 UTC on 2 July 2006 at Cabauw, not the separate
24-hour SCM experiment. Pane 47 owns `runner/` and `forcing/`; pane 48 owns `diagnostics/`, input
provenance, compact export, and reference-data audit. Changes stay in disjoint commits.

Planned matrix: an 800 m cube at 64³ (12.5 m), 128³ (6.25 m canonical), and 256³ (3.125 m), each
with WENO9/no interior closure, WENO5/no interior closure, and WENO9/Smagorinsky. Preparation and
bounded smoke tests do not authorize an expensive production campaign.

Do not substitute GABLS1 constants. GABLS3 requires verified time-height geostrophic and
large-scale advective forcing, time-dependent 0.25 m temperature and specific humidity boundary
values, the published roughness, the unstable morning MOST branch, damping, and documented
perturbations.

