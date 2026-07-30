# 04 Scenario Diagnostics

Computed at: 2026-07-28 14:03:23.394529

SIPP-observed conditional DC participation rate: 0.5897

## Scenario results

| Scenario | Group | Eligible (M) | Participants (M) | Take-up | Avg match | Match cost ($M) | Seed cost ($M) | Total incl. seed ($M) |
|---|---|---|---|---|---|---|---|---|
| headline_sipp_observed_conditional | headline | 44.47 | 26.23 | 0.5898 | $539 | $14146 | $4447 | $18593 |
| headline_dc_access_row_level | headline | 15.22 | 8.98 | 0.5897 | $524 | $4706 | $1522 | $6228 |
| headline_universal_account_uniform | headline | 29.25 | 17.25 | 0.5897 | $547 | $9440 | $2925 | $12365 |
| sens_auto_enroll_80pct | sensitivity | 44.47 | 35.58 | 0.8000 | $537 | $19092 | $4447 | $23540 |
| sens_full_participation_100pct | sensitivity | 44.47 | 44.47 | 1.0000 | $537 | $23866 | $4447 | $28313 |

## Seed variants (participation-invariant)

| Variant | Cost ($M) | Recipients (M) | Full $100 (M) | Avg per recipient | Bottom-3-decile share |
|---|---|---|---|---|---|
| flat | $4447 | 44.47 | 44.47 | $100 | 79.0% |
| pro_rata | $1709 | 44.47 | 0.03 | $38 | 90.9% |
| flat_then_taper | $3643 | 44.47 | 28.06 | $82 | 84.5% |
| extended_taper | $5270 | 60.31 | 44.47 | $87 | 74.2% |

## Notes

- Headline scenario combines: (A) DC-access workers using row-level PARTICIPATING_DC, and (B) universal-account workers using the SIPP-observed conditional DC rate as a uniform participation assumption.
- Sensitivities apply the rate uniformly across the whole universe.
- Seed cost is a flat $100 automatic contribution to every eligible worker, paid regardless of participation, so it is constant across behavioral scenarios and reaches the full eligible population (seed recipients = eligible count). It does not count toward the $1,000 match cap.
