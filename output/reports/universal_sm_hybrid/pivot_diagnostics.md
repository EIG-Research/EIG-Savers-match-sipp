# 04 Pivot Diagnostics

Computed at: 2026-06-11 17:14:47.269004

## Method

The schedule is a single straight line with a 200 percent max match rate at $0 MAGI. Per design decision D1 (2026-06-11) the **design anchor** fixes the Single rate at **75 percent at 0.667 x the IRS all-single-filer median AGI** (SOI Table 1.2, single + MFS returns; TY2023 median $35789 projected to TY2027 $40294 at x1.1259). The policy is anchored to administrative IRS data, not the SIPP sample (SIPP relegated to simulation only; the SIPP in-universe single median was $54799, shown for comparison). Holding the max rate fixed, the anchor places the 50 percent crossing (the pivot `compute_match_rate()` keys on) at 0.800 x the IRS single median and the 0 percent endpoint at 1.333 x pivot = 1.067 x the median. MFJ and HoH pivots are scaled from the Single pivot using the statutory Saver's Match lower-threshold ratios from `sm_calibration_constants()$sm_lower`:

- **MFJ ratio:** sm_lower[MFJ] / sm_lower[Single] = 41000 / 20500 = 2.00
- **HoH ratio:** sm_lower[HoH] / sm_lower[Single] = 30750 / 20500 = 1.50

Endpoint (where the rate hits zero) = 1.333 x pivot for each filing group (= max rate / (max rate - pivot rate) = 200 / (200 - 50)). The Single pivot is 0.800 x the IRS single median, so the Single endpoint is 1.067 x that median. For MFJ and HoH the pivot is 2.0 x and 1.5 x the Single pivot, and the endpoint is 1.333 x that pivot. The `data median` column below is the SIPP in-universe median for each group (the population the simulation scores), shown against the IRS-anchored frontier.

## Pivot table

| Filing group | SM ratio | N (rows) | Weighted (M) | Data median MAGI | Pivot | Endpoint | Endpoint - data median | Slope (pp/$) |
|---|---|---|---|---|---|---|---|---|
| single_mfs | 1.00 | 6142 | 62.11 | $54799 | $32235 | $42980 | $-11818 | -0.00465 |
| mfj | 2.00 | 7594 | 70.95 | $154781 | $64471 | $85961 | $-68820 | -0.00233 |
| hoh | 1.50 | 1225 | 12.28 | $55061 | $48353 | $64471 | $9410 | -0.00310 |

## Interpretation

The match rate follows a single straight line per filing group: 200 percent (the max match rate) at zero MAGI, declining linearly through 50 percent at the pivot, and continuing at the same slope to zero at 1.333 x pivot. Workers below the pivot receive a match rate above 50 percent; workers between the pivot and the endpoint receive a phased-down match from 50 percent to zero; workers at or above the endpoint receive no match.

Because MFJ and HoH pivots are anchored to Single via the SM ratios rather than rescaled to each group's own median, the MFJ endpoint may sit well below the MFJ median (capturing a larger share of the MFJ distribution above the endpoint) and the HoH endpoint may sit above the HoH median (capturing more HoH filers within the eligibility band). The `Endpoint - data median` column makes this visible at a glance.
