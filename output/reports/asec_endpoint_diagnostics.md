# CPS ASEC Income Medians and the Designated Endpoint

Computed at: 2026-08-04 12:24:49.219532
Source: IPUMS CPS ASEC 2025 (income year 2024), variables INCTOT, INCWAGE, FILESTAT, ASECWT, AGE.
All values are nominal 2024 dollars. No inflation adjustment and no projection (decision S3).

## The policy, in full

A **200 percent match at $0 income**, declining in a straight line to a **0 percent match at $44,045** for single filers. Two numbers. Married filing jointly and head of household endpoints follow from the single-filer endpoint by the statutory IRC sec 6433 ratios (2.0x and 1.5x).

| Filing group | Designated endpoint | Ratio to single |
|---|---|---|
| Single / MFS | $44,045 | 1.0 |
| Married filing jointly | $88,090 | 2.0 |
| Head of household | $66,067 | 1.5 |

## Which median sets the endpoint, and why

The designated endpoint is the **weighted median total personal income (INCTOT) of single filers age 15+, all values**: $44,045.

Total income rather than wages, because the schedule scores filers on total income — so a total-income endpoint makes "zero percent at the median" literally true. The median single filer's income equals the endpoint by construction and therefore sits exactly at the zero-percent point. A wage-based endpoint sits below the total-income median and would push the median filer outside the band while the headline still said "at the median".

All values rather than positive-only, because it needs no qualifier to state, and for single filers the two differ by $38.

## Two findings that change how these numbers read

**1. FILESTAT cannot identify married-filing-separately.** Codes are 1/2/3 Joint (split by age), 4 Head of household, 5 Single, 6 Nonfiler. Neither IPUMS FILESTAT nor the underlying Census tax-model variable carries an MFS category, because the tax model assigns married couples to joint filing. The requested "single and MFS filers" cut is therefore **single filers only**, and every label below says so. MFS is roughly 2-3 percent of returns nationally — small, but the omission is real and not correctable from this source.

**2. The documented ASEC 2019 INCWAGE universe break does not bind in the delivered data.** The IPUMS universe note says the INCWAGE universe narrowed from persons age 15+ (through ASEC 2018) to persons age 15+ *with earnings last year* (ASEC 2019 onward). Taken at face value that would mean non-earners arrive as not-in-universe sentinels and drop out as missing, making the "all values" median an earners-only median almost equal to the positive-only one. **Measured here, that is not what happens:** the `out_of_universe` column is **0 in every cell**, and non-earners instead carry `INCWAGE == 0`. The two cells therefore differ enormously rather than converging. The check is retained deliberately — the universe note is real documentation, so a future vintage could begin emitting sentinels, and a non-zero `out_of_universe` on a later run means this section must be revisited before the "all values" medians are quoted.

## Median grid

| Concept | Population | Positive only | N rows | Weighted (M) | Median | Median (Hmisc) | Zeros in base | Negatives in base | Out of universe |
|---|---|---|---|---|---|---|---|---|---|
| INCTOT | all_persons_15plus | no | 114446 | 278.31 | $38,000 | $38,000 | 13283 | 75 | 0 |
| INCTOT | all_persons_15plus | yes | 101088 | 246.31 | $45,000 | $45,000 | 13283 | 75 | 0 |
| INCTOT | single_filers_15plus | no | 31888 | 86.01 | $44,045 | $44,045 | 0 | 19 | 0 |
| INCTOT | single_filers_15plus | yes | 31869 | 85.97 | $44,083 | $44,080 | 0 | 19 | 0 |
| INCWAGE | all_persons_15plus | no | 114446 | 278.31 | $20,000 | $20,000 | 45877 | 0 | 0 |
| INCWAGE | all_persons_15plus | yes | 68569 | 166.75 | $50,002 | $50,002 | 45877 | 0 | 0 |
| INCWAGE | single_filers_15plus | no | 31888 | 86.01 | $33,280 | $33,280 | 5550 | 0 | 0 |
| INCWAGE | single_filers_15plus | yes | 26338 | 71.71 | $40,000 | $40,000 | 5550 | 0 | 0 |
| INCTOT | all_persons_18_64 | yes | 74395 | 182.70 | $50,000 | $50,000 | 8077 | 70 | 0 |
| INCTOT | single_filers_18_64 | yes | 25059 | 69.71 | $44,200 | $44,200 | 0 | 16 | 0 |
| INCWAGE | all_persons_18_64 | yes | 62133 | 152.02 | $52,000 | $52,000 | 20409 | 0 | 0 |
| INCWAGE | single_filers_18_64 | yes | 23470 | 65.30 | $42,000 | $42,000 | 1605 | 0 | 0 |
| INCTOT | joint_filers_15plus | yes | 49984 | 115.20 | $60,100 | $60,100 | 2929 | 53 | 0 |
| INCTOT | hoh_filers_15plus | yes | 5902 | 12.83 | $45,000 | $45,000 | 0 | 3 | 0 |
| INCWAGE | joint_filers_15plus | yes | 36167 | 81.85 | $65,000 | $65,001 | 16799 | 0 | 0 |
| INCWAGE | hoh_filers_15plus | yes | 5380 | 11.61 | $41,000 | $41,000 | 525 | 0 | 0 |
| INCWAGE | all_filers_15plus | yes | 67885 | 165.17 | $52,000 | $52,000 | 22874 | 0 | 0 |

Largest disagreement between the two weighted-median estimators across all cells: 0.01 percent. The `weighted_quantile` column is the headline (it matches the Household-income-and-composition estimator); the Hmisc column is the estimator used elsewhere in this repo.

## Statutory vs. observed inter-group ratios

Decision S1 imposes the statutory sec 6433 ratios (MFJ = 2.0x Single, HoH = 1.5x Single) regardless of the data. Observed ratios are diagnostic only — they show how far the imposed geometry sits from the empirical distribution. Computed on INCTOT, the same concept as the endpoint, so the comparison is like-for-like.

| Group | Statutory ratio | Observed ratio (INCTOT, positive) |
|---|---|---|
| MFJ | 2.00 | 1.36 |
| HoH | 1.50 | 1.02 |

## Stated implicit choices

a. Reserved codes cleared before any statistic: INCTOT 999999999 (NIU) / 999999998 (missing); INCWAGE 99999999 / 99999998. Leaving them would put nine-digit sentinels in the distribution.
b. INCTOT negatives are **kept** in the all-values cells — personal income can genuinely be negative (business and farm losses). Dropping them would be a substantive edit, not cleaning.
c. Age floor 15, matching the INCTOT universe. An 18-64 variant is reported because the Saver's Match universe is age 18+.
d. ASECWT is the weight, not WTFINL. WTFINL is the basic monthly weight and ignores the ASEC oversample.
e. No topcode adjustment — topcoding compresses the upper tail and cannot move a median.
f. Single-year cross-section, so no inflation adjustment is applied or needed.

## Downstream contract

This script writes `data/processed/asec_endpoint.rds`, carrying the designated endpoint and the three derived filing-group endpoints. `04_02_compute_endpoints.R` reads it and passes the endpoint table to `compute_match_rate()`. There is no intermediate derivation: the endpoint written here is the endpoint the model uses.

## Retired vocabulary

Earlier versions of this design described the same straight line by an interior 50 percent crossing (a "pivot") derived from an external median (an "anchor"). Both terms are retired. Audit bridge for reconciling pre-2026-08-04 outputs only: `old_pivot = 0.75 x endpoint`.
