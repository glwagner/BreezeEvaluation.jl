# DYCOMS-II RF01: figures and extracted data

For the second paper, see [Pressel et al. (2017): seven figures, 105 recovered model curves and bulk tables](pressel2017/reference.md). Its curves use a separate directory and 2–4 h profile convention.

Companion to the [paper reference](paper_reference.md) and [full extracted text](paper_extracted.md). Source: Stevens et al. (2005), DOI [10.1175/MWR2930.1](https://doi.org/10.1175/MWR2930.1).

This document keeps all 11 figure images and the currently extracted numerical data together. The 157 digitized points below comprise 114 model ensemble-mean samples and 43 observational marker centers. These are approximate figure-derived coordinates, not original archive data. Observational extraction is partial, and error bars have not been extracted. Pixel-selection tolerances in the CSV files are not observational uncertainty.

The linked `figures/` and `data/` directories are part of this folder and the downloadable bundle. Move the whole folder together to preserve the relative links. The [standalone figure picker](figure_picker.html) embeds all images and seeded points for offline use. [Provenance and image hashes](data/provenance.json).

## Contents

- [Figure 1: Radiative flux parameterization](#figure-1)
- [Figure 2: LWP, cloud fraction, and integrated TKE evolution](#figure-2)
- [Figure 3: Cloud boundary evolution](#figure-3)
- [Figure 4: Mean thermodynamic profiles](#figure-4)
- [Figure 5: Vertical velocity statistics](#figure-5)
- [Figure 6: Decoupling and turbulence versus LWP](#figure-6)
- [Figure 7: Radiation and entrainment versus LWP](#figure-7)
- [Figure 8: Cloud and flow structure](#figure-8)
- [Figure 9: Vertical-resolution sensitivity](#figure-9)
- [Figure 10: Free-tropospheric moisture sensitivity](#figure-10)
- [Figure C1: Ensemble statistics overview](#figure-c1)
- [Published tables](#published-tables)


## Figure 1

Radiative flux parameterization.

![Figure 1: Radiative flux parameterization](figures/figure-1.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 2

LWP, cloud fraction, and integrated TKE evolution.

![Figure 2: LWP, cloud fraction, and integrated TKE evolution](figures/figure-2.png)

[Numerical CSV](data/figure2_ensemble_means.csv) · [Axis calibration](data/figure2_calibration.json) · [Audit overlay](data/figure2_digitization_overlay.png) · [Extraction script](digitize_figure2.py)

The curves below are **model ensemble means**, not observations. They cover 0.2–3.9 h; the shaded ensemble ranges are not extracted. Small digitized cloud-fraction overshoots above one are retained within pixel tolerance.

| variable | time_h | value | units | pixel_x | pixel_y |
| --- | --- | --- | --- | --- | --- |
| LWP | 0.1997 | 62.21154 | g m-2 | 173 | 67.0 |
| LWP | 0.3022 | 60.0 | g m-2 | 193 | 78.5 |
| LWP | 0.3995 | 53.65385 | g m-2 | 212 | 111.5 |
| LWP | 0.5019 | 46.63462 | g m-2 | 232 | 148.0 |
| LWP | 0.5992 | 42.21154 | g m-2 | 251 | 171.0 |
| LWP | 0.7017 | 40.57692 | g m-2 | 271 | 179.5 |
| LWP | 0.799 | 39.51923 | g m-2 | 290 | 185.0 |
| LWP | 0.9014 | 38.46154 | g m-2 | 310 | 190.5 |
| LWP | 0.9987 | 37.11538 | g m-2 | 329 | 197.5 |
| LWP | 1.1012 | 36.25 | g m-2 | 349 | 202.0 |
| LWP | 1.1985 | 35.67308 | g m-2 | 368 | 205.0 |
| LWP | 1.3009 | 35.09615 | g m-2 | 388 | 208.0 |
| LWP | 1.3982 | 35.0 | g m-2 | 407 | 208.5 |
| LWP | 1.5006 | 35.28846 | g m-2 | 427 | 207.0 |
| LWP | 1.598 | 35.48077 | g m-2 | 446 | 206.0 |
| LWP | 1.7004 | 35.76923 | g m-2 | 466 | 204.5 |
| LWP | 1.7977 | 35.96154 | g m-2 | 485 | 203.5 |
| LWP | 1.9001 | 36.25 | g m-2 | 505 | 202.0 |
| LWP | 2.0026 | 35.86538 | g m-2 | 525 | 204.0 |
| LWP | 2.0999 | 35.67308 | g m-2 | 544 | 205.0 |
| LWP | 2.2023 | 35.57692 | g m-2 | 564 | 205.5 |
| LWP | 2.2996 | 35.67308 | g m-2 | 583 | 205.0 |
| LWP | 2.402 | 35.67308 | g m-2 | 603 | 205.0 |
| LWP | 2.4994 | 35.48077 | g m-2 | 622 | 206.0 |
| LWP | 2.6018 | 35.28846 | g m-2 | 642 | 207.0 |
| LWP | 2.6991 | 34.80769 | g m-2 | 661 | 209.5 |
| LWP | 2.8015 | 34.61538 | g m-2 | 681 | 210.5 |
| LWP | 2.8988 | 34.51923 | g m-2 | 700 | 211.0 |
| LWP | 3.0013 | 34.23077 | g m-2 | 720 | 212.5 |
| LWP | 3.0986 | 34.03846 | g m-2 | 739 | 213.5 |
| LWP | 3.201 | 34.13462 | g m-2 | 759 | 213.0 |
| LWP | 3.2983 | 34.71154 | g m-2 | 778 | 210.0 |
| LWP | 3.4008 | 34.90385 | g m-2 | 798 | 209.0 |
| LWP | 3.4981 | 35.28846 | g m-2 | 817 | 207.0 |
| LWP | 3.6005 | 35.09615 | g m-2 | 837 | 208.0 |
| LWP | 3.6978 | 35.09615 | g m-2 | 856 | 208.0 |
| LWP | 3.8003 | 34.51923 | g m-2 | 876 | 211.0 |
| LWP | 3.8976 | 34.80769 | g m-2 | 895 | 209.5 |
| cloud_fraction | 0.1997 | 1.0 | 1 | 173 | 440.5 |
| cloud_fraction | 0.3022 | 1.0 | 1 | 193 | 440.5 |
| cloud_fraction | 0.3995 | 0.99859 | 1 | 212 | 441.0 |
| cloud_fraction | 0.5019 | 0.99859 | 1 | 232 | 441.0 |
| cloud_fraction | 0.5992 | 0.99577 | 1 | 251 | 442.0 |
| cloud_fraction | 0.7017 | 0.98592 | 1 | 271 | 445.5 |
| cloud_fraction | 0.799 | 0.96338 | 1 | 290 | 453.5 |
| cloud_fraction | 0.9014 | 0.95352 | 1 | 310 | 457.0 |
| cloud_fraction | 0.9987 | 0.94507 | 1 | 329 | 460.0 |
| cloud_fraction | 1.1012 | 0.93944 | 1 | 349 | 462.0 |
| cloud_fraction | 1.1985 | 0.93662 | 1 | 368 | 463.0 |
| cloud_fraction | 1.3009 | 0.93099 | 1 | 388 | 465.0 |
| cloud_fraction | 1.3982 | 0.92535 | 1 | 407 | 467.0 |
| cloud_fraction | 1.5006 | 0.91972 | 1 | 427 | 469.0 |
| cloud_fraction | 1.598 | 0.9169 | 1 | 446 | 470.0 |
| cloud_fraction | 1.7004 | 0.91549 | 1 | 466 | 470.5 |
| cloud_fraction | 1.7977 | 0.90986 | 1 | 485 | 472.5 |
| cloud_fraction | 1.9001 | 0.90282 | 1 | 505 | 475.0 |
| cloud_fraction | 2.0026 | 0.90141 | 1 | 525 | 475.5 |
| cloud_fraction | 2.0999 | 0.9 | 1 | 544 | 476.0 |
| cloud_fraction | 2.2023 | 0.89859 | 1 | 564 | 476.5 |
| cloud_fraction | 2.2996 | 0.90141 | 1 | 583 | 475.5 |
| cloud_fraction | 2.402 | 0.9 | 1 | 603 | 476.0 |
| cloud_fraction | 2.4994 | 0.89437 | 1 | 622 | 478.0 |
| cloud_fraction | 2.6018 | 0.89155 | 1 | 642 | 479.0 |
| cloud_fraction | 2.6991 | 0.89155 | 1 | 661 | 479.0 |
| cloud_fraction | 2.8015 | 0.89155 | 1 | 681 | 479.0 |
| cloud_fraction | 2.8988 | 0.88873 | 1 | 700 | 480.0 |
| cloud_fraction | 3.0013 | 0.8831 | 1 | 720 | 482.0 |
| cloud_fraction | 3.0986 | 0.87887 | 1 | 739 | 483.5 |
| cloud_fraction | 3.201 | 0.87934 | 1 | 759 | 483.3333333333333 |
| cloud_fraction | 3.2983 | 0.87042 | 1 | 778 | 486.5 |
| cloud_fraction | 3.4008 | 0.87324 | 1 | 798 | 485.5 |
| cloud_fraction | 3.4981 | 0.87746 | 1 | 817 | 484.0 |
| cloud_fraction | 3.6005 | 0.87887 | 1 | 837 | 483.5 |
| cloud_fraction | 3.6978 | 0.87324 | 1 | 856 | 485.5 |
| cloud_fraction | 3.8003 | 0.8662 | 1 | 876 | 488.0 |
| cloud_fraction | 3.8976 | 0.87465 | 1 | 895 | 485.0 |
| vertically_integrated_TKE | 0.1997 | 19.9262 | m3 s-2 | 173 | 1176.5 |
| vertically_integrated_TKE | 0.3022 | 58.30258 | m3 s-2 | 193 | 1163.5 |
| vertically_integrated_TKE | 0.3995 | 171.95572 | m3 s-2 | 212 | 1125.0 |
| vertically_integrated_TKE | 0.5019 | 318.08118 | m3 s-2 | 232 | 1075.5 |
| vertically_integrated_TKE | 0.5992 | 434.68635 | m3 s-2 | 251 | 1036.0 |
| vertically_integrated_TKE | 0.7017 | 490.77491 | m3 s-2 | 271 | 1017.0 |
| vertically_integrated_TKE | 0.799 | 452.39852 | m3 s-2 | 290 | 1030.0 |
| vertically_integrated_TKE | 0.9014 | 378.59779 | m3 s-2 | 310 | 1055.0 |
| vertically_integrated_TKE | 0.9987 | 329.8893 | m3 s-2 | 329 | 1071.5 |
| vertically_integrated_TKE | 1.1012 | 307.74908 | m3 s-2 | 349 | 1079.0 |
| vertically_integrated_TKE | 1.1985 | 316.60517 | m3 s-2 | 368 | 1076.0 |
| vertically_integrated_TKE | 1.3009 | 331.36531 | m3 s-2 | 388 | 1071.0 |
| vertically_integrated_TKE | 1.3982 | 346.12546 | m3 s-2 | 407 | 1066.0 |
| vertically_integrated_TKE | 1.5006 | 357.93358 | m3 s-2 | 427 | 1062.0 |
| vertically_integrated_TKE | 1.598 | 366.78967 | m3 s-2 | 446 | 1059.0 |
| vertically_integrated_TKE | 1.7004 | 371.21771 | m3 s-2 | 466 | 1057.5 |
| vertically_integrated_TKE | 1.7977 | 378.59779 | m3 s-2 | 485 | 1055.0 |
| vertically_integrated_TKE | 1.9001 | 387.45387 | m3 s-2 | 505 | 1052.0 |
| vertically_integrated_TKE | 2.0026 | 391.88192 | m3 s-2 | 525 | 1050.5 |
| vertically_integrated_TKE | 2.0999 | 396.30996 | m3 s-2 | 544 | 1049.0 |
| vertically_integrated_TKE | 2.2023 | 399.26199 | m3 s-2 | 564 | 1048.0 |
| vertically_integrated_TKE | 2.2996 | 402.21402 | m3 s-2 | 583 | 1047.0 |
| vertically_integrated_TKE | 2.402 | 408.11808 | m3 s-2 | 603 | 1045.0 |
| vertically_integrated_TKE | 2.4994 | 411.07011 | m3 s-2 | 622 | 1044.0 |
| vertically_integrated_TKE | 2.6018 | 412.54613 | m3 s-2 | 642 | 1043.5 |
| vertically_integrated_TKE | 2.6991 | 414.02214 | m3 s-2 | 661 | 1043.0 |
| vertically_integrated_TKE | 2.8015 | 419.9262 | m3 s-2 | 681 | 1041.0 |
| vertically_integrated_TKE | 2.8988 | 427.30627 | m3 s-2 | 700 | 1038.5 |
| vertically_integrated_TKE | 3.0013 | 433.21033 | m3 s-2 | 720 | 1036.5 |
| vertically_integrated_TKE | 3.0986 | 437.63838 | m3 s-2 | 739 | 1035.0 |
| vertically_integrated_TKE | 3.201 | 446.49446 | m3 s-2 | 759 | 1032.0 |
| vertically_integrated_TKE | 3.2983 | 452.39852 | m3 s-2 | 778 | 1030.0 |
| vertically_integrated_TKE | 3.4008 | 453.87454 | m3 s-2 | 798 | 1029.5 |
| vertically_integrated_TKE | 3.4981 | 455.35055 | m3 s-2 | 817 | 1029.0 |
| vertically_integrated_TKE | 3.6005 | 455.35055 | m3 s-2 | 837 | 1029.0 |
| vertically_integrated_TKE | 3.6978 | 452.39852 | m3 s-2 | 856 | 1030.0 |
| vertically_integrated_TKE | 3.8003 | 446.49446 | m3 s-2 | 876 | 1032.0 |
| vertically_integrated_TKE | 3.8976 | 446.49446 | m3 s-2 | 895 | 1032.0 |

## Figure 3

Cloud boundary evolution.

![Figure 3: Cloud boundary evolution](figures/figure-3.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 4

Mean thermodynamic profiles.

![Figure 4: Mean thermodynamic profiles](figures/figure-4.png)

[Numerical CSV](data/figure4_observation_centers.csv) · [Axis calibration](data/figure4_calibration.json) · [Audit overlay](data/figure4_digitization_overlay.png) · [Extraction script](digitize_figure4.py)

Six total-water, six liquid-water potential-temperature, and four cloud-liquid-water markers. Overlapping total-water and temperature markers near 480 and 750 m are omitted. Error bars are not included.

| variable | series | height_m | value | units | pixel_x | pixel_y |
| --- | --- | --- | --- | --- | --- | --- |
| q_t | observed | 1054.98 | 1.10928 | g kg-1 | 180 | 72 |
| q_t | observed | 923.02 | 1.88454 | g kg-1 | 227 | 120 |
| q_t | observed | 637.11 | 8.86186 | g kg-1 | 650 | 224 |
| q_t | observed | 620.62 | 8.94433 | g kg-1 | 655 | 230 |
| q_t | observed | 150.52 | 9.10928 | g kg-1 | 665 | 401 |
| q_t | observed | 95.53 | 8.94433 | g kg-1 | 655 | 421 |
| theta_l | observed | 1054.98 | 303.56075 | K | 1323 | 72 |
| theta_l | observed | 923.02 | 300.33645 | K | 1208 | 120 |
| theta_l | observed | 637.11 | 288.75701 | K | 795 | 224 |
| theta_l | observed | 620.62 | 288.50467 | K | 786 | 230 |
| theta_l | observed | 150.52 | 288.81308 | K | 797 | 401 |
| theta_l | observed | 95.53 | 288.78505 | K | 796 | 421 |
| q_l | observed | 758.08 | 0.28218 | g kg-1 | 1689 | 180 |
| q_l | observed | 749.83 | 0.29208 | g kg-1 | 1699 | 183 |
| q_l | observed | 637.11 | 0.13762 | g kg-1 | 1543 | 224 |
| q_l | observed | 620.62 | 0.08911 | g kg-1 | 1494 | 230 |

## Figure 5

Vertical velocity statistics.

![Figure 5: Vertical velocity statistics](figures/figure-5.png)

[Numerical CSV](data/figure5_observation_centers.csv) · [Axis calibration](data/figure5_calibration.json) · [Audit overlay](data/figure5_digitization_overlay.png) · [Extraction script](build_reference_data.py)

Eight in-situ w-variance, eight in-situ w-third-moment, and eleven radar w-variance markers. Obscured upper markers and radar third moments are omitted. Error bars are not included.

| variable | instrument | height_m | value | units | pixel_x | pixel_y |
| --- | --- | --- | --- | --- | --- | --- |
| variance | in_situ | 94.2 | 0.3317 | m2 s-2 | 1036 | 372 |
| variance | in_situ | 150.2 | 0.4146 | m2 s-2 | 1104 | 354 |
| variance | in_situ | 480.2 | 0.4756 | m2 s-2 | 1154 | 248 |
| variance | in_situ | 480.2 | 0.4976 | m2 s-2 | 1172 | 248 |
| variance | in_situ | 617.1 | 0.5171 | m2 s-2 | 1188 | 204 |
| variance | in_situ | 632.7 | 0.4427 | m2 s-2 | 1127 | 199 |
| variance | in_situ | 751.0 | 0.3939 | m2 s-2 | 1087 | 161 |
| variance | in_situ | 751.0 | 0.4037 | m2 s-2 | 1095 | 161 |
| third_moment | in_situ | 94.2 | 0.0247 | m3 s-3 | 1744 | 372 |
| third_moment | in_situ | 150.2 | 0.0371 | m3 s-3 | 1766 | 354 |
| third_moment | in_situ | 480.2 | -0.0163 | m3 s-3 | 1671 | 248 |
| third_moment | in_situ | 480.2 | -0.0067 | m3 s-3 | 1688 | 248 |
| third_moment | in_situ | 617.1 | -0.0433 | m3 s-3 | 1623 | 204 |
| third_moment | in_situ | 632.7 | -0.0815 | m3 s-3 | 1555 | 199 |
| third_moment | in_situ | 747.9 | -0.0365 | m3 s-3 | 1635 | 162 |
| third_moment | in_situ | 747.9 | -0.0169 | m3 s-3 | 1670 | 162 |
| variance | radar | 835.0 | 0.0976 | m2 s-2 | 844 | 134 |
| variance | radar | 822.6 | 0.1195 | m2 s-2 | 862 | 138 |
| variance | radar | 807.0 | 0.1646 | m2 s-2 | 899 | 143 |
| variance | radar | 791.4 | 0.211 | m2 s-2 | 937 | 148 |
| variance | radar | 775.9 | 0.2561 | m2 s-2 | 974 | 153 |
| variance | radar | 760.3 | 0.2902 | m2 s-2 | 1002 | 158 |
| variance | radar | 744.7 | 0.3232 | m2 s-2 | 1029 | 163 |
| variance | radar | 726.1 | 0.3476 | m2 s-2 | 1049 | 169 |
| variance | radar | 710.5 | 0.378 | m2 s-2 | 1074 | 174 |
| variance | radar | 698.1 | 0.4183 | m2 s-2 | 1107 | 178 |
| variance | radar | 682.5 | 0.4561 | m2 s-2 | 1138 | 183 |

## Figure 6

Decoupling and turbulence versus LWP.

![Figure 6: Decoupling and turbulence versus LWP](figures/figure-6.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 7

Radiation and entrainment versus LWP.

![Figure 7: Radiation and entrainment versus LWP](figures/figure-7.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 8

Cloud and flow structure.

![Figure 8: Cloud and flow structure](figures/figure-8.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 9

Vertical-resolution sensitivity.

![Figure 9: Vertical-resolution sensitivity](figures/figure-9.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure 10

Free-tropospheric moisture sensitivity.

![Figure 10: Free-tropospheric moisture sensitivity](figures/figure-10.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Figure C1

Ensemble statistics overview.

![Figure C1: Ensemble statistics overview](figures/figure-C1.png)

Image saved; numerical coordinates have not been digitized for this figure. See the [paper reference](paper_reference.md) for interpretation.


## Published tables

These are model results, not observations. Table 1's LWP is the fourth-hour mean; the SGS-flux column is its contribution at the near-inversion minimum of the total theta_l flux. Table 2's grid/moisture context comes from the surrounding text. See the reference notes for source-table inconsistencies.

### Table 1

[CSV](data/table1_master_ensemble.csv)

| model | LWP_g_m2 | SGS_theta_l_flux_W_m2 | SGS_model | scalar_advection_as_printed |
| --- | --- | --- | --- | --- |
| UCLA-0 | 59 | 0 | None for scalar | M |
| DHARMA-0 | 56 | -0.8 | Dynamic | M |
| COAMPS-0 | 50 | -2.1 | Deardorff | C |
| NCAR-1 | 46 | -1.3 | Deardorff | PS-Horiz M-Vert |
| MPI-1 | 47 | -1 | Deardorff dry stability at cloud top | C |
| WVU-0 | 42 | -10.4 | Deardorff dry stability at cloud top | M |
| DHARMA-1 | 41 | -17.9 | Smagorinsky | C |
| RAMS | 37 | 0.2 | Deardorff | C |
| SAM | 35 | -10.4 | Deardorff | M |
| COAMPS-1 | 33 | -14.1 | Smagorinsky MacVean-Mason | M |
| UCLA-1 | 26 | -21.5 | Smagorinsky | M |
| NCAR-0 | 25 | -3.7 | Deardorff | M |
| WVU-1 | 21 | -16.7 | Deardorff | M |
| METO | 21 | -24.6 | Smagorinsky MacVean-Mason | M |
| MPI-0 | 9 | -7.6 | Deardorff | M |
| IMAU | 5 | -22.1 | Deardorff | M |

### Table 2

[CSV](data/table2_UCLA_sensitivities.csv)

| model | cloud_top_dz_m | free_tropospheric_qt_g_kg | LWP_g_m2 | delta_qt_g_kg | entrainment_mm_s | alpha |
| --- | --- | --- | --- | --- | --- | --- |
| UCLA-0 | 5 | 1.5 | 59 | 0.02 | 4.16 | 1.04 |
| UCLA-1 | 5 | 1.5 | 26 | 0.29 | 5.89 | 1.74 |
| UCLA-0 | 10 | 1.5 | 42 | 0.08 | 5.03 | 1.25 |
| UCLA-0 | 2 | 1.5 | 70 | 0.0 | 4.26 | 0.91 |
| UCLA-0 | 1 | 1.5 | 74 | 0.0 | 3.75 | 0.86 |
| UCLA-0 | 5 | 5.5 | 99 | 0.01 | 4.59 |  |
| UCLA-1 | 5 | 5.5 | 82 | 0.05 | 5.82 |  |

## Figure 2: ensemble envelope (Julia extraction)

Light shading: model ensemble minimum–maximum. Dark shading: interquartile range. These are not observational error bars. [CSV with source pixels](data/figure2_ensemble_envelope.csv) · [Overlay](data/figure2_envelope_overlay.png) · [Extraction provenance](data/figure2_envelope_provenance.json). Missing values indicate unresolved subpixel shading.

| Variable | Time (h) | Min | Q25 | Q75 | Max | Units |
|---|---:|---:|---:|---:|---:|---|
| LWP | 0.1997 | 40 | 61.15 | 69.62 | 72.5 | g m-2 |
| LWP | 0.3022 | 37.12 | 58.27 | 69.04 | 70.58 | g m-2 |
| LWP | 0.3995 | 26.92 | 50.19 | 61.92 | 65 | g m-2 |
| LWP | 0.5019 | 15.58 | 43.85 | 54.42 | 66.35 | g m-2 |
| LWP | 0.5992 | 11.35 | 39.81 | 52.69 | 54.81 | g m-2 |
| LWP | 0.7017 | 13.65 | 37.5 | 47.88 | 55.38 | g m-2 |
| LWP | 0.799 | 15.38 | 35.38 | 47.88 | 54.81 | g m-2 |
| LWP | 0.9014 | 14.04 | 33.85 | 47.69 | 53.85 | g m-2 |
| LWP | 0.9987 | 11.15 | 33.46 | 47.5 | 52.12 | g m-2 |
| LWP | 1.1012 | 7.885 | 32.69 | 49.04 | 51.35 | g m-2 |
| LWP | 1.1985 | 6.538 | 31.73 | 48.65 | 51.35 | g m-2 |
| LWP | 1.3009 | 5.962 | 30.58 | 47.88 | 53.08 | g m-2 |
| LWP | 1.3982 | 4.231 | 29.81 | 45.96 | 52.31 | g m-2 |
| LWP | 1.5006 | 3.846 | 28.27 | 44.62 | 53.85 | g m-2 |
| LWP | 1.598 | 3.654 | 27.69 | 47.12 | 55.58 | g m-2 |
| LWP | 1.7004 | 3.269 | 28.46 | 48.85 | 56.15 | g m-2 |
| LWP | 1.7977 | 4.231 | 28.85 | 49.42 | 57.12 | g m-2 |
| LWP | 1.9001 | 4.808 | 28.46 | 49.81 | 57.31 | g m-2 |
| LWP | 2.0026 | 4.808 | 26.15 | 49.23 | 57.31 | g m-2 |
| LWP | 2.0999 | 5.385 | 25.38 | 49.04 | 57.31 | g m-2 |
| LWP | 2.2023 | 5.577 | 25.19 | 49.23 | 56.73 | g m-2 |
| LWP | 2.2996 | 5.385 | 25.58 | 50 | 56.92 | g m-2 |
| LWP | 2.402 | 5 | 26.35 | 50.58 | 56.73 | g m-2 |
| LWP | 2.4994 | 3.846 | 27.12 | 48.85 | 57.5 | g m-2 |
| LWP | 2.6018 | 4.038 | 26.54 | 48.27 | 57.12 | g m-2 |
| LWP | 2.6991 | 4.423 | 25.96 | 47.69 | 57.31 | g m-2 |
| LWP | 2.8015 | 4.808 | 25.58 | 46.54 | 57.88 | g m-2 |
| LWP | 2.8988 | 5.385 | 26.15 | 46.35 | 58.65 | g m-2 |
| LWP | 3.0013 | 5.577 | 25.96 | 46.15 | 58.65 | g m-2 |
| LWP | 3.0986 | 5.769 | 23.65 | 46.15 | 57.88 | g m-2 |
| LWP | 3.201 | 6.154 | 24.23 | 47.12 | 58.27 | g m-2 |
| LWP | 3.2983 | 6.538 | 24.42 | 47.31 | 58.08 | g m-2 |
| LWP | 3.4008 | 6.923 | 24.42 | 47.12 | 58.46 | g m-2 |
| LWP | 3.4981 | 5.962 | 25 | 47.5 | 59.04 | g m-2 |
| LWP | 3.6005 | 4.231 | 25.38 | 48.08 | 59.81 | g m-2 |
| LWP | 3.6978 | 3.846 | 27.12 | 48.46 | 59.04 | g m-2 |
| LWP | 3.8003 | 3.462 | 25.38 | 48.65 | 58.65 | g m-2 |
| LWP | 3.8976 | 2.885 | 22.5 | 49.04 | 58.27 | g m-2 |
| cloud_fraction | 0.1997 | unresolved | unresolved | unresolved | unresolved | 1 |
| cloud_fraction | 0.3022 | unresolved | unresolved | unresolved | unresolved | 1 |
| cloud_fraction | 0.3995 | 0.9915 | unresolved | unresolved | 1.003 | 1 |
| cloud_fraction | 0.5019 | 0.9831 | unresolved | unresolved | 0.9972 | 1 |
| cloud_fraction | 0.5992 | 0.9831 | 0.9915 | 1 | 1 | 1 |
| cloud_fraction | 0.7017 | 0.8732 | 0.9831 | 0.9972 | 0.9972 | 1 |
| cloud_fraction | 0.799 | 0.6986 | 0.9746 | 0.9944 | 1 | 1 |
| cloud_fraction | 0.9014 | 0.6169 | 0.9803 | 0.9972 | 1 | 1 |
| cloud_fraction | 0.9987 | 0.507 | 0.9803 | 0.9972 | 1 | 1 |
| cloud_fraction | 1.1012 | 0.4197 | 0.9775 | 0.9972 | 1 | 1 |
| cloud_fraction | 1.1985 | 0.369 | 0.9746 | 0.9972 | 1 | 1 |
| cloud_fraction | 1.3009 | 0.3211 | 0.9775 | 0.9944 | 1 | 1 |
| cloud_fraction | 1.3982 | 0.3014 | 0.969 | 0.9944 | 1 | 1 |
| cloud_fraction | 1.5006 | 0.2986 | 0.9577 | 0.9972 | 1 | 1 |
| cloud_fraction | 1.598 | 0.2986 | 0.9465 | 0.9944 | 1 | 1 |
| cloud_fraction | 1.7004 | 0.2986 | 0.938 | 0.9944 | 0.9972 | 1 |
| cloud_fraction | 1.7977 | 0.2704 | 0.9408 | 0.9887 | 0.9972 | 1 |
| cloud_fraction | 1.9001 | 0.262 | 0.938 | 0.9915 | 0.9972 | 1 |
| cloud_fraction | 2.0026 | 0.2789 | 0.9352 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.0999 | 0.3042 | 0.9211 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.2023 | 0.3408 | 0.9042 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.2996 | 0.3606 | 0.9211 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.402 | 0.3549 | 0.9211 | 0.9915 | 1 | 1 |
| cloud_fraction | 2.4994 | 0.3099 | 0.9099 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.6018 | 0.2986 | 0.9099 | 0.9915 | 1 | 1 |
| cloud_fraction | 2.6991 | 0.2676 | 0.9127 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.8015 | 0.2507 | 0.9099 | 0.9944 | 1 | 1 |
| cloud_fraction | 2.8988 | 0.262 | 0.9042 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.0013 | 0.2986 | 0.8845 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.0986 | 0.2901 | 0.8958 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.201 | 0.2789 | 0.8704 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.2983 | 0.2704 | 0.8648 | 0.9887 | 1 | 1 |
| cloud_fraction | 3.4008 | 0.2704 | 0.862 | 0.9887 | 1 | 1 |
| cloud_fraction | 3.4981 | 0.2732 | 0.8704 | 0.9887 | 0.9972 | 1 |
| cloud_fraction | 3.6005 | 0.2986 | 0.8704 | 0.9915 | 0.9972 | 1 |
| cloud_fraction | 3.6978 | 0.2507 | 0.8479 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.8003 | 0.2197 | 0.8394 | 0.9944 | 1 | 1 |
| cloud_fraction | 3.8976 | 0.1915 | 0.8451 | 0.9944 | 1 | 1 |
| vertically_integrated_TKE | 0.1997 | -0.738 | 8.118 | 34.69 | 37.64 | m3 s-2 |
| vertically_integrated_TKE | 0.3022 | 8.118 | 19.93 | 93.73 | 164.6 | m3 s-2 |
| vertically_integrated_TKE | 0.3995 | 14.02 | 81.92 | 276.8 | 353.5 | m3 s-2 |
| vertically_integrated_TKE | 0.5019 | 46.49 | 253.1 | 418.5 | 536.5 | m3 s-2 |
| vertically_integrated_TKE | 0.5992 | 203 | 344.6 | 557.2 | 598.5 | m3 s-2 |
| vertically_integrated_TKE | 0.7017 | 279.7 | 365.3 | 583.8 | 982.3 | m3 s-2 |
| vertically_integrated_TKE | 0.799 | 229.5 | 318.1 | 512.9 | 952.8 | m3 s-2 |
| vertically_integrated_TKE | 0.9014 | 197 | 291.5 | 465.7 | 633.9 | m3 s-2 |
| vertically_integrated_TKE | 0.9987 | 185.2 | 285.6 | 409.6 | 498.2 | m3 s-2 |
| vertically_integrated_TKE | 1.1012 | 167.5 | 291.5 | 350.6 | 424.4 | m3 s-2 |
| vertically_integrated_TKE | 1.1985 | 173.4 | 282.7 | 374.2 | 448 | m3 s-2 |
| vertically_integrated_TKE | 1.3009 | 179.3 | 294.5 | 397.8 | 495.2 | m3 s-2 |
| vertically_integrated_TKE | 1.3982 | 182.3 | 297.4 | 433.2 | 530.6 | m3 s-2 |
| vertically_integrated_TKE | 1.5006 | 173.4 | 315.1 | 450.9 | 604.4 | m3 s-2 |
| vertically_integrated_TKE | 1.598 | 173.4 | 324 | 456.8 | 625.1 | m3 s-2 |
| vertically_integrated_TKE | 1.7004 | 164.6 | 326.9 | 465.7 | 636.9 | m3 s-2 |
| vertically_integrated_TKE | 1.7977 | 167.5 | 326.9 | 501.1 | 663.5 | m3 s-2 |
| vertically_integrated_TKE | 1.9001 | 182.3 | 335.8 | 527.7 | 690 | m3 s-2 |
| vertically_integrated_TKE | 2.0026 | 188.2 | 326.9 | 483.4 | 695.9 | m3 s-2 |
| vertically_integrated_TKE | 2.0999 | 200 | 318.1 | 471.6 | 693 | m3 s-2 |
| vertically_integrated_TKE | 2.2023 | 200 | 312.2 | 489.3 | 695.9 | m3 s-2 |
| vertically_integrated_TKE | 2.2996 | 194.1 | 318.1 | 512.9 | 710.7 | m3 s-2 |
| vertically_integrated_TKE | 2.402 | 188.2 | 332.8 | 539.5 | 746.1 | m3 s-2 |
| vertically_integrated_TKE | 2.4994 | 191.1 | 356.5 | 504.1 | 775.6 | m3 s-2 |
| vertically_integrated_TKE | 2.6018 | 191.1 | 347.6 | 465.7 | 778.6 | m3 s-2 |
| vertically_integrated_TKE | 2.6991 | 188.2 | 347.6 | 468.6 | 757.9 | m3 s-2 |
| vertically_integrated_TKE | 2.8015 | 191.1 | 359.4 | 512.9 | 752 | m3 s-2 |
| vertically_integrated_TKE | 2.8988 | 203 | 368.3 | 527.7 | 740.2 | m3 s-2 |
| vertically_integrated_TKE | 3.0013 | 203 | 380.1 | 515.9 | 719.6 | m3 s-2 |
| vertically_integrated_TKE | 3.0986 | 205.9 | 394.8 | 521.8 | 716.6 | m3 s-2 |
| vertically_integrated_TKE | 3.201 | 208.9 | 388.9 | 536.5 | 740.2 | m3 s-2 |
| vertically_integrated_TKE | 3.2983 | 200 | 388.9 | 563.1 | 766.8 | m3 s-2 |
| vertically_integrated_TKE | 3.4008 | 191.1 | 365.3 | 583.8 | 755 | m3 s-2 |
| vertically_integrated_TKE | 3.4981 | 197 | 356.5 | 574.9 | 757.9 | m3 s-2 |
| vertically_integrated_TKE | 3.6005 | 191.1 | 344.6 | 577.9 | 787.5 | m3 s-2 |
| vertically_integrated_TKE | 3.6978 | 191.1 | 350.6 | 589.7 | 772.7 | m3 s-2 |
| vertically_integrated_TKE | 3.8003 | 185.2 | 350.6 | 572 | 743.2 | m3 s-2 |
| vertically_integrated_TKE | 3.8976 | 188.2 | 353.5 | 515.9 | 725.5 | m3 s-2 |
