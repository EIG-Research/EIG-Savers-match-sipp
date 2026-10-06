# 04 Scenario Diagnostics

Computed at: 2026-08-04 12:36:59.796941

SIPP-observed conditional DC participation rate: 0.6193

## Scenario results

| Scenario | Group | Eligible (M) | Participants (M) | Take-up | Avg match | Match cost ($M) | Seed cost ($M) | Total incl. seed ($M) |
|---|---|---|---|---|---|---|---|---|
| headline_sipp_observed_conditional | headline | 49.78 | 30.83 | 0.6193 | $529 | $16303 | $4978 | $21281 |
| headline_dc_access_row_level | headline | 17.56 | 10.88 | 0.6193 | $496 | $5393 | $1756 | $7150 |
| headline_universal_account_uniform | headline | 32.22 | 19.95 | 0.6193 | $547 | $10910 | $3222 | $14132 |
| sens_auto_enroll_80pct | sensitivity | 49.78 | 39.83 | 0.8000 | $530 | $21093 | $4978 | $26071 |
| sens_full_participation_100pct | sensitivity | 49.78 | 49.78 | 1.0000 | $530 | $26366 | $4978 | $31345 |

## Seed variants (participation-invariant)

| Variant | Cost ($M) | Recipients (M) | Full $100 (M) | Avg per recipient | Bottom-3-decile share |
|---|---|---|---|---|---|
| flat | $4978 | 49.78 | 49.78 | $100 | 75.2% |
| pro_rata | $1882 | 49.78 | 0.03 | $38 | 88.3% |
| flat_then_taper | $4025 | 49.78 | 30.99 | $81 | 80.8% |
| extended_taper | $5836 | 66.91 | 49.78 | $87 | 70.5% |

## Notes

- Headline scenario combines: (A) DC-access workers using row-level PARTICIPATING_DC, and (B) universal-account workers using the SIPP-observed conditional DC rate as a uniform participation assumption.
- Sensitivities apply the rate uniformly across the whole universe.
- Seed cost is a flat $100 automatic contribution to every eligible worker, paid regardless of participation, so it is constant across behavioral scenarios and reaches the full eligible population (seed recipients = eligible count). It does not count toward the $1,000 match cap.
