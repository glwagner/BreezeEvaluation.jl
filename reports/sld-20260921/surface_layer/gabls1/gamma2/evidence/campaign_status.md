# GABLS1 SLD γ=2 admitted campaign

Source: Breeze `b0338bc2921526431763e54caf41675ad062a5d4`, BreezeEvaluation `2e6f2029b416100be17405a586282a7bcd76adda`. Immutable freeze: `/shared/home/greg/review-coordination/sld-stability-gamma2-freeze-20260923-v1`; source-manifest SHA-256 `2b873a552acf2781532e55f50236e730b070cedfee3100ab9b71e946dbeace68`.

CPU smoke Slurm 7595 passed 48/48. H100 gate 7596 passed CUDA parity 34/34 and 1,800 s validation 48/48; durable exit zero and `GATE_PASS` matched the source manifest. Independent local-state Julia audit through 1,800 s passed.

Nine-hour science Slurm array 7615 task 1 ended with durable exit zero and `CASE_DONE final_time_s=32400.0`. The source hashes remained unchanged. Independent Julia raw-output audit admitted 46 native-height profiles and 135 time series, exact schedules, finite values, density-consistent wall flux, evolving filters, and scheme-native flux partition. The paired initial θ digest was `1f5db33f2971ee607ac46b1a014b038a09fc876cc1669394dce023a9aa2f198b`. A separate local-stability audit passed 1/L and φ identities at all 55 saved times. The 8–9 h stable fraction was 1.0 with no upward-flux fallback; mean φₘ=1.8930 and φₕ=2.4512.

The 8–9 h vector shear at 12.5/25/37.5 m is 0.09152/0.06140/0.05235 s⁻¹. The fixed 1 m LES median sampled at those heights is 0.10038/0.06666/0.05607. The 25 m γ=4 notch is absent. The five-page γ=2 chapter was appended to the public 109-page BreezeEvaluation master report in commit `1da63bda251a4fcbf8148835d76eab5b067f7f0b`. Raw JLD2 and checkpoints remain in `/shared/home/greg/review-coordination/sld-stability-gamma2-20260923/`.
