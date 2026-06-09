# Canonical modeled frame — data dictionary

`data/processed/sipp_modeled.parquet`, built by `code/01_data_preparation/01b_build_modeled_frame.R`
via `build_modeled_frame()` (`code/_shared/build_frame.R`). One row per person, December reference month,
SIPP 2024 Wave 1. Income is projected to TY2027 (×1.093). `<m>` denotes a multiplier in
{m100, m125, m150, m200} = current-law, 1.25×, 1.50×, 2.00× AGI thresholds.

## Identifiers & weight
| Column | Meaning |
|---|---|
| `ssuid`, `pnum` | SIPP household / person identifiers |
| `spouse_pnum` | within-household spouse pointer (EPNSPOUSE); used for the filer-basis collapse |
| `weight` | WPFINWGT, Wave 1 person weight; all estimates are weighted |
| `age` | TAGE |
| `efstatus`, `filing_group`, `filing_status` | raw filing code; grouped key `single_mfs`/`mfj`/`hoh`; label `Single`/`MFJ`/`MFS`/`HoH` |

## Income (dollars)
| Column | Meaning |
|---|---|
| `sm_income_2024` | MFJ-aware Saver's Match income, 2024 nominal (U1 spouse-pair sum for MFJ, else personal) |
| `sm_income_2027` | `sm_income_2024 × 1.093` — the MAGI used for eligibility and the hybrid schedule |
| `personal_income_2027` | personal total income (TPTOTINC), projected to 2027 |
| `earnings_2027` | personal earnings (TPEARN), projected to 2027 — the contribution base |

## Universe & sub-population flags
| Column | Meaning |
|---|---|
| `has_earned_income`, `is_student`, `is_dependent` | §25B/§152 eligibility proxies |
| `in_universe` | age ≥ 18 & not dependent & not student & has earned income & valid filing group |
| `is_private_sector_employee`, `is_self_employed` | worker-class flags; the hybrid universe is the full `in_universe` (all worker classes), and these flags drive only the hybrid employer-plan vs. universal-account routing, not universe membership |

## Account access
| Column | Meaning |
|---|---|
| `has_dc_account` | holds a DC/IRA account (EOWN_THR401/EOWN_IRAKEO/EMJOB_401/EMJOB_IRA); NA→FALSE |
| `any_retirement_access` | "Yes"/"No"/"Missing" employer-offer-aware access (for hybrid routing) |
| `is_participating_dc` | actively contributing to a DC plan (NA = not determinable) |
| `contrib_rate_draw` | uniform draw used for the band contribution-rate assignment |

## Eligibility, by multiplier `<m>`
| Column | Meaning |
|---|---|
| `threshold_lower_<m>`, `threshold_upper_<m>` | full-match and phase-out ceilings (statutory × multiplier) |
| `sm_factor_<m>` | phase-in factor in [0,1] on 2027 income |
| `is_anymatch_<m>` | eligible for any match (`in_universe` & factor > 0; income below upper) |
| `is_fullmatch_<m>` | eligible for full match (income ≤ lower) |
| `is_anymatch_with_account_<m>`, `is_fullmatch_with_account_<m>` | the above, AND holds a DC account |
| `is_eligible_dc_<m>` | any-match AND holds a DC account (the JCT-baseline population) |

## Cost — per-person match dollars
| Column | Meaning |
|---|---|
| `contrib_for_sm` | SOI-band contribution (2024 band → ×1.093 → capped at $2,000); used by DC-access scenarios |
| `sm_match_per_person` | band-based match at current law = `sm_factor_m100 × 0.50 × contrib_for_sm` |
| `univ_contrib_for_sm` | universal-access contribution: DC holders use band; others use the 15/60/25 rate split |
| `univ_sm_match_<m>` | universal match = `sm_factor_<m> × 0.50 × univ_contrib_for_sm` |
| `univ_sm_match_<m>_alt` | same on the alternative 15/25/60 contribution split (robustness sweep) |
