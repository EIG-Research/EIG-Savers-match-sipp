# D1 Re-anchoring — first-pass findings (2026-06-11)

Produced by `compute_irs_anchor.R` against `data/raw/irs_soi/23in12ms.xls` (IRS SOI Table 1.2, TY2023, by marital status) and the current model pivots in `data/processed/universal_sm_hybrid/pivot_table.parquet`. Output: `out/anchor_comparison.csv`.

## The anchor value

| Anchor | Single median (MAGI≈AGI) | Single pivot (0.6×) | Single endpoint (0.8×) |
|---|---|---|---|
| IRS SOI, Single only, TY2023 nominal | $34,944 | $20,966 | $27,955 |
| IRS SOI, Single + MFS, TY2023 nominal | $35,789 | $21,473 | $28,631 |
| IRS SOI, Single+MFS, projected to TY2027 (×1.126) | $40,294 | $24,176 | $32,235 |
| **Current model (SIPP single_mfs median, TY2027$)** | **$54,799** | **$32,879** | **$43,839** |

HoH and MFJ follow by the 1.5× / 2.0× ratios (marriage-neutral), per D1.

## The finding that matters

The SIPP-derived median MAGI used to set the current pivots (**$54,799**, TY2027$) is **~26 percent above** the IRS single-filer median projected to the same year (**~$40,294**), and ~57 percent above the raw TY2023 IRS figure. Anchoring to IRS data therefore pulls the whole eligibility frontier **down** — the Single pivot moves from $32,879 toward ~$24,000, and the endpoint from $43,839 toward ~$32,000 (TY2027 basis).

This gap is the quantified version of the legal-review "material" MAGI-proxy caveat and of D1 sub-question 3. It has two components, which must be separated before re-pricing:

1. **Concept gap.** The SIPP proxy (summed monthly TPTOTINC) includes non-taxable transfers (SNAP, TANF, SSI, child support, gifts) that AGI excludes, and omits realized capital gains. Net effect at the median: SIPP proxy > AGI. This is the piece D1(3) directs us to close on the simulation side.
2. **Population/unit gap.** SOI counts *single tax returns* (includes retirees, students, investors who file single, and excludes low earners who do not file); the SIPP universe counts *workers age 18+ with positive earned income*. These are different populations, so their medians differ even on an identical income concept.

## Why this cannot be re-priced by a naive pivot swap

The simulation determines each worker's eligibility by comparing that worker's **SIPP MAGI proxy** to the pivot. If we drop in the lower IRS-anchored pivot while leaving the inflated SIPP proxy unchanged, we compare a low threshold against a high per-worker measure — concept-inconsistent, and it would **understate** eligibility and cost. The correct sequence:

1. **Realign the SIPP MAGI proxy** toward the AGI/MAGI concept (net out identifiable non-taxable transfers; document residual divergence). *This is the load-bearing Tier 2.5 task and touches the pipeline frame, not panel code.*
2. **Reconcile the population basis** for the anchor: either anchor on the SIPP worker universe's realigned median (internally consistent for the simulation), or anchor on the IRS filer median and accept/adjust for the filer-vs-worker difference. Recommend the former for the simulation, with the IRS figure as the external calibration check and the policy-text authority at enactment.
3. **Re-pivot (0.6×/0.8×, ratios), C-CPI-U-index the cap, then re-price** eligibility and cost.

After step 1, the SIPP realigned median should fall toward the IRS figure, so steps 1 and 3 move the eligibility count in partially offsetting directions (lower per-worker MAGI *and* lower pivots). The net headline effect is therefore ambiguous in sign until both are done consistently — which is precisely why a half-done swap would mislead.

## Caveats on these numbers

- TY2023 SOI stands in for "the year before implementation"; at enactment, re-anchor to the then-current prior-year SOI. The ×1.126 projection (≈4 years at the repo's implied ~3%/yr) is a rough placeholder, not the repo's canonical projection.
- Median interpolated linearly within SOI AGI bins; the deficit/zero-AGI bin treated as the lowest group.
- AGI→MAGI add-backs (§911/§931/§933) are negligible at the median and not applied.
- "Single only" vs "Single + MFS": the proposal's `single_mfs` filing group combines both, so Single+MFS ($35,789) is the faithful anchor; Single-only shown for reference.

## Gap decomposition (2026-06-11, `diagnose_gap.R`) — the gap is population, not concept

For the **single/MFS worker universe** (62.11M weighted):

| Measure (TY2027$) | Median |
|---|---|
| MAGI proxy (current, = TPTOTINC) | $54,799 |
| Personal income | $54,799 |
| Earnings only | $52,468 |
| **Median non-earnings income** | **$15** |
| Mean non-earnings share of income | 6.6% |

The median worker carries ~$15 of non-earnings income. So **netting non-taxable transfers out of the MAGI proxy (the authorized Tier 2.5/2.6 realignment) moves the single anchor by at most ~$2,300, and realistically far less** — the worker MAGI proxy is already ≈ earnings. A re-extract of transfer-component dollar amounts from `pu2024.dta` (which the current 58-column extract lacks anyway — it carries only TPTOTINC, SNAP amount, and receipt flags) is **not worth doing**: it cannot close the gap.

The gap between the SIPP worker median ($54,799) and the IRS single-filer median AGI (~$40,294 projected) is therefore almost entirely a **population** difference:
- *SIPP universe* = workers age 18+ with positive earned income (excludes students, dependents, non-workers) → higher median.
- *IRS single filers* = all single returns (students, part-year, retirees, low-income refund/credit filers) → lower median.

## The real decision (supersedes the proxy-realignment task)

The live fork is **which population the IRS Single median is computed over**, because that — not the income concept — drives the ~26 percent pivot difference:

- **(A) IRS all-single-filer median AGI (~$40,294 TY2027$).** Literal reading of "IRS within-filing-status median MAGI." Single pivot ≈ $24,176, endpoint ≈ $32,235. Lands the frontier **just below enacted §6433's $35,500 single endpoint** — i.e., closest to the enacted Saver's Match the author wants to align with — but draws the frontier over a population (all filers) different from the one the simulation scores (workers), cutting the eligible count materially.
- **(C) SIPP worker-universe median (status quo basis, ~$54,799).** Internally consistent (frontier and scoring on the same worker population), but sits well above §6433 levels and is the SIPP-dependent basis D1 set out to leave.

Concept realignment does **not** bridge these; the choice is a policy call about whose income distribution defines the frontier.

## Decision (2026-06-11): IRS all-single-filer median, 75% at ⅔ of the median

The author chose the IRS all-single-filer median as the anchor, with the 75 percent rate fixed at **two-thirds of the median** — a legislator-legible rule that puts the frontier on a stable IRS administrative basis while nearly reproducing today's coverage. Geometry: Single pivot = 0.8 × median, endpoint = 1.067 × median; HoH 1.5×, MFJ 2.0×; cap C-CPI-U-indexed; decennial re-anchor.

Confirmed re-price (`reprice_candidates.R`, working anchor M ≈ $40,294 TY2027):

| Schedule | Single pivot | Single endpoint | Eligible | Full-particip. ceiling | Avg match |
|---|---|---|---|---|---|
| Current (SIPP median, ½-anchor) | $32,879 | $43,839 | 46.07M | $24.92B | $541 |
| ½-median IRS anchor | $24,176 | $32,235 | 28.06M | $12.22B | $436 |
| Full-median IRS anchor | $48,353 | $64,470 | 73.19M | $52.26B | $714 |
| **⅔-median IRS anchor (CHOSEN)** | **$32,235** | **$42,980** | **44.47M** | **$23.87B** | **$537** |

Headline (≈59.8% take-up) ≈ $14.3B, vs the current $14.9B.

## Status — IMPLEMENTED IN PRODUCTION 2026-06-11

`04_02_compute_pivots.R` now anchors on the IRS single median (reads `data/raw/irs_soi/23in12ms.xls`, interpolates the single+MFS median AGI, projects ×1.093^(4/3) to TY2027) with the 75%-at-⅔-median rule (pivot = 0.8 × median); the 04 sub-pipeline and the HTML brief were re-run, and the proposal spec (`Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md`) prose was updated to match. New canonical headline: **44.47M eligible / $14.15B headline / $23.87B full-participation ceiling** (was 46.07M / $14.9B / $24.9B); pivots Single $32,235 / HoH $48,353 / MFJ $64,471. The C-CPI-U cap indexing is a forward-years parameter (documented in the spec; base-year cap remains $1,000). The panel assessments (`economist-panel/NN-*/`) and this folder's "current model" references retain the pre-re-anchoring figures as the basis of the review — they are historical and intentionally not rewritten.
