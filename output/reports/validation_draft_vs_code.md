# Saver's Match Draft Validation: V2 and V3 vs. Code Output

**Generated:** 2026-04-20  
**Code source:** `code/03_main_estimation/03g_savers_match_eligibility_buckets.R`  
**Verified output:** `output/reports/savers_match_eligibility_buckets.md` (generated 2026-04-20)  
**Draft source:** `V2 Ben's Exploratory Draft.docx` and `V3 Ben's Exploratory Draft.docx`  

---

> **Methodology note (2026-04-25):** The numbers in this validation predate
> three changes adopted in late April 2026. (1) SIPP income was previously
> approximated as `December TPTOTINC × 12`; the current production
> methodology builds calendar-year income by summing observed monthly
> `TPTOTINC` across all twelve `MONTHCODE` rows per person (sum scaled to
> twelve months for partial-year respondents). (2) External-anchor reporting
> moved from EBRI Copeland (2024) to CPS ASEC 2025 (income year 2024).
> (3) The CPS comparison is now reported on a **worker basis** (each adult
> counted separately) as the primary unit, with the filer-basis comparison
> demoted to a secondary reference for fiscal-cost discussions. V3 draft
> numbers should be re-validated against a fresh run of `03g` before
> publication; the bucket counts have moved.

---

## Summary

V3 is fully consistent with the verified code outputs **as of 2026-04-20**. V2
contained stale numbers from an earlier methodology; those discrepancies are
documented below. All numbers in V3 can be traced directly to `03g` output of
that date. Re-verification under the post-2026-04-25 methodology is pending.

---

## Validation Table — V2 Draft vs. Verified 03g Output

| # | Draft (V2) claim | Verified value (03g) | Status | Notes |
|---|---|---|---|---|
| 1 | "14.5 million workers would qualify for the full 50 percent match" | **12.2M** (B2, worker basis) | **MISMATCH** | V2 uses pre-methodology-upgrade figures (before student/dependent exclusions and U1 spouse-join were applied). V3 corrects to 12.2M. |
| 2 | "an additional 19.9 million in the partial-match phaseout range" | **21.0M** (B1 − B2 = 33.2 − 12.2) | **MISMATCH** | Phaseout range = B1 minus B2. V2 reports 19.9M; verified phaseout = 21.0M. V3 corrects this implicitly via 12.2 + 9.1 + 13.3 structure. |
| 3 | "roughly 34 million in total" (any-match eligible) | **33.2M** (B1, worker basis) | **MISMATCH** | 33.2M rounds to 33M, not 34M. V2 total is internally inconsistent (14.5 + 19.9 = 34.4 ≈ 34M), which partially explains the discrepancy. V3 uses 33.2M. |

**Root cause of V2 discrepancies:** V2 appears to have been written against an intermediate version of the analysis that predated three methodology improvements incorporated in 03g: (1) student and dependent exclusions per IRC sec 25B cross-references, (2) the U1 spouse-pair joint-income construction for MFJ filers (replacing TFTOTINC with the EPNSPOUSE self-join sum), and (3) a stricter earned-income filter (`TPEARN > 0` rather than `TPTOTINC > 0`). Each change reduces the eligible count. V3 was written against the current 03g output and is fully consistent.

---

## Validation Table — V3 Draft vs. Verified 03g Output

| # | Draft (V3) claim | Verified value (03g) | Status | Source in 03g memo |
|---|---|---|---|---|
| 1 | "12.2 million workers would qualify for the full 50 percent match" (fn. 6) | **12.2M** (B2, worker basis) | **MATCH** | B2 = 12.15M → rounds to 12.2M |
| 2 | "3.1 million of these workers currently have a qualifying retirement account" | **3.1M** (B3, worker basis) | **MATCH** | B3 = 3.08M → rounds to 3.1M |
| 3 | "9.1 million workers will have new retirement accounts…full Saver's Match" | **9.1M** (B2 − B3 = 12.2 − 3.1) | **MATCH** | Derived: 12.2 − 3.1 = 9.1M |
| 4 | "13.3 million workers will have new accounts…partial Saver's Match" | **13.3M** (phaseout-no-acct = (B1−B2) − (B1∩acct − B3)) | **MATCH** | Derived: 21.0 − 7.7 = 13.3M |
| 5 | "roughly 22 million workers who will gain new access" | **22.4M** (9.1 + 13.3) | **APPROXIMATE** | 9.1 + 13.3 = 22.4; draft rounds to "roughly 22M" — acceptable |
| 6 | "33.2 million" any-match eligible (fn. 7) | **33.2M** (B1, worker basis) | **MATCH** | B1 = 33.17M → rounds to 33.2M |
| 7 | "28.48 million any-match eligible" (filer basis, fn. 7) | **28.48M** | **MATCH** | U5 filer-basis overall B1 |
| 8 | "10.5 million full-match eligible" (filer basis, fn. 7) | **10.5M** | **MATCH** | U5 filer-basis B2 = 10.5M |
| 9 | "2.59 million full-match-and-account filers" (filer basis, fn. 7) | **2.59M** | **MATCH** | U5 filer-basis B3 = 2.59M |
| 10 | "54 million total workers" without employer plan | **53.7M** (ASEC-calibrated) | **APPROXIMATE** | From 03d ASEC-calibrated estimate; V3 footnote 3 cites 53.7M explicitly |

---

## Bucket Definitions (for reference)

| Bucket | Label | Verified count (worker basis) |
|---|---|---|
| B1 | Any-match eligible (AGI < upper phase-out threshold) | **33.2M** |
| B2 | Full-match eligible (AGI ≤ full-match threshold) | **12.2M** |
| B3 | Full-match eligible AND owns qualifying account | **3.1M** |
| B1 ∩ account | Any-match eligible AND owns qualifying account | **10.8M** |
| B1 − B2 | Phase-out range (partial match) | **21.0M** |
| (B1 ∩ acct) − B3 | Phase-out range AND owns account | **7.7M** |
| B2 − B3 | Full-match eligible, NO qualifying account | **9.1M** |
| (B1−B2) − [(B1∩acct)−B3] | Phase-out range, NO qualifying account | **13.3M** |

**Access gap (total new accounts needed):** B2 − B3 + phaseout-no-acct = 9.1 + 13.3 = **22.4M**

---

## Income thresholds used (2027, CPI factor = 1.0)

| Filing status | Full-match ceiling | Phase-out ceiling |
|---|---|---|
| Single / MFS | $20,500 | $35,500 |
| Married filing jointly | $41,000 | $71,000 |
| Head of household | $30,750 | $53,250 |

---

## Notes on methodology (from 03g header and footnote 6 in V3, **as of 2026-04-20**)

- **Income proxy (this snapshot)**: annualized December TPTOTINC (monthly × 12); above-the-line adjustments not applied → all counts are **lower bounds** on true eligibility. **Superseded 2026-04-25** by the calendar-year sum-of-monthly-values methodology (Option B); see the methodology note at the top of this file.
- **MFJ income**: spouse-pair sum via EPNSPOUSE self-join (U1), not TFTOTINC
- **Student exclusion**: RENROLL == 1 AND EEDFTPT == 1 (full-time enrolled in December), with fallback for ages 18–23 with EEDUC < 40 and earnings < $15,000
- **Dependent exclusion**: age < 19, or age 19–23 with student flag and earnings < $5,050
- **Qualifying account**: EOWN_THR401 == 1 (401k/403b/TSP) OR EOWN_IRAKEO == 1 (IRA/Keogh); DB pensions excluded
- **Filer basis**: MFJ couples collapsed to lower-PNUM member; each non-MFJ person is their own filer
