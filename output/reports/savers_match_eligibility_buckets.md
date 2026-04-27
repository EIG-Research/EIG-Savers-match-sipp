# Saver's Match Eligible Population: Three-Bucket Estimate

_Generated: 2026-04-27_

## Headline (overall, worker-level, SIPP 2024, 2027-projected thresholds)

- Bucket 1 (any-match eligible): 38.5 million workers.
- Bucket 2 (full-match eligible): 15.1 million workers.
- Bucket 3 (full-match eligible AND currently hold a qualifying account): 3.5 million workers.
- Any-match eligible AND currently hold a qualifying account: 12.4 million workers (superset of Bucket 3; includes phaseout-range owners who are not in Bucket 2).

## Worker-basis comparison to CPS ASEC 2025 (PRIMARY)

The headline counts above are reported on a worker basis: each adult in a married couple is counted separately. CPS ASEC 2025 (income year 2024) is the primary external anchor and is constructed on the same worker basis here so the comparison is unit-consistent. SIPP 2024 Wave 1 covers reference year 2023, so the SIPP figure understates the 2024-on-2024 comparison by one income year of nominal growth — this caveat drops when SIPP 2025 Wave 2 releases.

- Bucket 1 (any-match, worker basis): 38.54 million SIPP workers vs. 45.73 million CPS workers (SIPP is 84.3 percent of CPS).
- Bucket 2 (full-match, worker basis): 15.06 million SIPP workers vs. 22.37 million CPS workers (SIPP is 67.3 percent of CPS).
- Bucket 3 (full-match + owns, worker basis): 3.53 million SIPP workers. CPS ASEC core does not carry retirement-account ownership flags, so there is no CPS anchor for this quantity.
- Any-match eligible AND owns qualifying account (worker basis): 12.42 million SIPP workers. CPS has no parallel quantity.

## Filer-basis comparison to CPS ASEC 2025 (secondary)

The filer-basis comparison collapses each resolved MFJ couple to its lower-PNUM member (SIPP) or lower-PERNUM member (CPS) so each tax-filing unit contributes one observation. The IRS administers the Saver's Match per filer, so filer-basis numbers are the right unit for fiscal-cost discussions. For population-eligibility communication the worker-basis numbers above are primary.

- Bucket 1 (any-match, filer basis): 33.4 million SIPP filers vs. 39.94 million CPS filers (SIPP is 83.6 percent of CPS).
- Bucket 2 (full-match, filer basis): 13.38 million SIPP filers vs. 20.4 million CPS filers (SIPP is 65.6 percent of CPS).
- Bucket 3 (full-match + owns, filer basis): 3.1 million SIPP filers. CPS has no parallel quantity. Note: lower bound — couples where only the dropped member owns the account are missed (see U5 caveat).

## Methodology notes

- Income concept: calendar-year personal income built by summing observed monthly TPTOTINC across all twelve MONTHCODE rows per person (sum scaled to 12 months via sum * 12 / n_valid_months for the small share of partial-year respondents). This replaces the prior December-times-twelve proxy. See the Income period entry under Open items below for the partial-year share from this run.
- Above-the-line adjustments to AGI (IRC sec 62: IRA deduction, HSA, student-loan interest, etc.) are not yet applied to the SIPP gross-income proxy. SIPP bucket counts are therefore lower bounds on true AGI-defined eligibility.
- Historical references not used as anchors: EBRI Copeland (2024, Issue Brief No. 602, IRS SOI 2018 filers, no inflation adjustment) and Morningstar (January 2025, SCF 2022 households). Both are noted for context only.

## Open items (see methodology doc)

- CPI-U projection factor: 1 (set to 1.0 per IRC Section 6433(h)(1); COLA applies to tax years after 2027).
- Student-proxy earnings cap placeholder: $15,000.
- Dependent-proxy earnings cap placeholder: $5,050.
- MFJ own-earnings rule: requires own earnings
- Income period: SIPP TPTOTINC, TFTOTINC, and TPEARN are monthly reference-month values. Calendar-year values are built by aggregating across all observed MONTHCODE rows per person (sum scaled to 12 months via sum * 12 / n_valid_months; Option B). Retirement-module attributes remain on the December reference-month record. Partial-year (< 12 months observed) share from run: 2.54%.
