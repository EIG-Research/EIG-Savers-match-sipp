# code/02_eligibility/

Saver's Match eligible-population estimates, projected to tax year 2027.

## `02a_eligibility_buckets.R`

**Role.** The core eligibility engine. Classifies workers into nested buckets — any-match
(below the upper phase-out threshold), full-match (at or below the full-match threshold), and
full-match-with-account (full-match AND holds a qualifying DC account) — plus the access gap, on both a
worker and a filer basis.

**Reads.** `data/processed/sipp_modeled.parquet` (the canonical frame).
**Writes.** `output/tables/savers_match_eligibility_buckets*.{rds,parquet}` (worker + filer basis) and
`output/reports/savers_match_eligibility_buckets.md`.

## `02b_filing_match_decomposition.R`

**Role.** Filing-status × match-status contingency tables (full universe, account holders, access gap).
Reconciles its column marginals against `02a`'s `savers_match_eligibility_buckets.rds` and stops on a
mismatch, so `02a` must run first.

**Reads.** `data/processed/sipp_modeled.parquet`; `output/tables/savers_match_eligibility_buckets.rds`.
**Writes.** `output/tables/answers_eligibility_*.{rds,parquet,xlsx}`.
