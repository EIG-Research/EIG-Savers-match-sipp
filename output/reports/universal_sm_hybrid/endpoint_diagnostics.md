# 04 Endpoint Diagnostics

Computed at: 2026-08-04 12:30:29.07098

## The schedule

One straight line per filing group: a **200 percent match at $0 income**, declining linearly to a **0 percent match at the designated endpoint**.

```
rate(income) = 200 * (1 - income / endpoint),  clamped to [0, 200]
```

Two numbers describe it. There is no interior reference point.

## The designated endpoint

**$44,045** — the weighted median total personal income (INCTOT) of single filers age 15+, all values, from IPUMS CPS ASEC 2025 (income year 2024). Nominal 2024 dollars, compared against SIPP income at the same price level with no projection.

Because the schedule scores filers on total income and the endpoint IS the median single filer's total income, the median single filer sits exactly at the 0 percent point. See `output/reports/asec_endpoint_diagnostics.md` for the full median grid and why this cell was chosen.

## Endpoints by filing group

Ratios are the statutory IRC sec 6433 ratios (MFJ $41,000 / Single $20,500 = 2.0; HoH $30,750 / $20,500 = 1.5). They are imposed by design, not estimated.

| Filing group | Ratio | N (rows) | Weighted (M) | SIPP universe median | Endpoint | Endpoint - median | Slope (pp/$) |
|---|---|---|---|---|---|---|---|
| single_mfs | 1.00 | 5168 | 61.52 | $51,900 | $44,045 | $-7,855 | -0.00454 |
| mfj | 2.00 | 6531 | 70.93 | $139,652 | $88,090 | $-51,562 | -0.00227 |
| hoh | 1.50 | 1004 | 11.76 | $51,397 | $66,068 | $14,670 | -0.00303 |

## Interpretation

A worker at $0 income receives a 200 percent match on their contribution. The rate falls by 0.00454 percentage points per dollar of income for a single filer, reaching zero at the endpoint. Workers at or above their filing group's endpoint receive no match.

The `SIPP universe median` column is the median income of the population the simulation actually scores, which is a *worker* population and therefore higher than the ASEC all-single-filer median that sets the endpoint. The `Endpoint - median` column makes the gap visible: a negative value means more than half of that filing group's workers sit above the endpoint and receive nothing.

## Retired vocabulary

Earlier versions described this same line by an interior 50 percent crossing (a "pivot") derived from an external median (an "anchor") read from IRS SOI Table 1.2. Both terms and the SOI dependency are retired. Audit bridge for reconciling pre-2026-08-04 outputs: `old_pivot = 0.75 x endpoint`.
