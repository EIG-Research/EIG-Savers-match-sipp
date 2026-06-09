# 04 Pivot Diagnostics

Computed at: 2026-06-09 13:58:22.823975

## Method

The schedule is a single straight line with a 200 percent floor at $0 MAGI. The **design anchor** fixes the Single rate at **75 percent at one half the Single weighted-median MAGI** (the median is computed inside the 04_01 universe via `Hmisc::wtd.quantile(probs = 0.5)`). Holding the floor fixed, that anchor places the 50 percent crossing (the pivot `compute_match_rate()` keys on) at 0.6 x the Single median and the 0 percent endpoint at (4/3) x pivot = 0.8 x the Single median. MFJ and HoH pivots are scaled from the Single pivot using the statutory Saver's Match lower-threshold ratios from `sm_calibration_constants()$sm_lower`:

- **MFJ ratio:** sm_lower[MFJ] / sm_lower[Single] = 41000 / 20500 = 2.00
- **HoH ratio:** sm_lower[HoH] / sm_lower[Single] = 30750 / 20500 = 1.50

Endpoint (where the rate hits zero) = (4/3) x pivot for each filing group. The Single pivot is 0.6 x the Single median, so the Single endpoint is 0.8 x the Single median. For MFJ and HoH the pivot is 2.0 x and 1.5 x the Single pivot, and the endpoint is (4/3) x that pivot (not tied to that group's own data median).

## Pivot table

| Filing group | SM ratio | N (rows) | Weighted (M) | Data median MAGI | Pivot | Endpoint | Endpoint - data median | Slope (pp/$) |
|---|---|---|---|---|---|---|---|---|
| single_mfs | 1.00 | 6142 | 62.11 | $54799 | $32879 | $43839 | $-10960 | -0.00456 |
| mfj | 2.00 | 7594 | 70.95 | $154781 | $65758 | $87678 | $-67103 | -0.00228 |
| hoh | 1.50 | 1225 | 12.28 | $55061 | $49319 | $65758 | $10697 | -0.00304 |

## Interpretation

The match rate follows a single straight line per filing group: 200 percent at zero MAGI, declining linearly through 50 percent at the pivot, and continuing at the same slope to zero at (4/3) x pivot. Workers below the pivot receive a match rate above 50 percent; workers between the pivot and the endpoint receive a phased-down match from 50 percent to zero; workers at or above the endpoint receive no match.

Because MFJ and HoH pivots are anchored to Single via the SM ratios rather than rescaled to each group's own median, the MFJ endpoint may sit well below the MFJ median (capturing a larger share of the MFJ distribution above the endpoint) and the HoH endpoint may sit above the HoH median (capturing more HoH filers within the eligibility band). The `Endpoint - data median` column makes this visible at a glance.
