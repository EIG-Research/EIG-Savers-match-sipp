# Re-Review Changelog — What Changed Since the First-Round Panel

**Date:** 2026-06-11
**For:** the ten-economist panel, ahead of a re-review.
**Purpose:** orient you to what changed between your first-round assessments and the current design, so the re-review focuses on (1) whether the changes correctly address the concern you raised and (2) what *new* concerns the changes introduce — not on re-flagging settled items. Genuine critique is still wanted; several decisions deliberately *declined* a panel recommendation, and those are fair game to contest.

**Authoritative current numbers:** `economist-panel/_shared/data-guide.md` (the "CURRENT DESIGN" block). The proposal spec (`Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md`) and companion brief are updated to match. Your first-round `NN-*/assessment.md` files are preserved unchanged as the prior round.

---

## A. Headline at a glance

| | First round | Current |
|---|---|---|
| Eligible workers | 46.07M | **44.47M** (~30.6%) |
| Headline cost | $14.9B (SIPP-observed ~59.8%) | **$14.15B** conservative / **$19.09B** at 80% auto-enrollment (brief's central case) / $23.87B ceiling |
| Avg. match | $543 | ~$537–539 |
| Single pivot / endpoint | $32,879 / $43,839 | **$32,235 / $42,980** |
| HoH pivot / MFJ pivot | $49,319 / $65,758 | **$48,353 / $64,471** |
| Eligibility anchor | SIPP weighted median, 75% at ½ median, re-anchored each SIPP wave | **IRS all-single-filer median, 75% at ⅔ median, C-CPI-U-indexed, re-anchored each decade** |

## B. The Tier 3 design decisions (full detail in `DESIGN-DECISIONS.md`)

- **D1 Indexing** — eligibility band anchored to the IRS single-filer median (75% at ⅔ of it → pivot 0.8× median), C-CPI-U-indexed, decennial re-anchor; SIPP relegated to simulation. (Gap decomposition: the SIPP-vs-IRS difference is *population*, not income concept; the proxy realignment some of you implied was a near-no-op for workers.)
- **D2 Default channel** — kept the federal universal account (RSAA American Worker Retirement Plan model), individual-level and portable.
- **D3 Match floor** — kept the 200% floor at launch (no escalation).
- **D4 Default rate** — flat 3% headline; graduated 1/2/3%-by-FPL carried as a costed option.
- **D5 Base contribution** — out of baseline; documented as a future option.
- **D6 Withdrawals** — RSAA design: own contributions Roth-accessible; federal match vests after a six-month hold; **replaces §6433(d)(2)'s three-year recapture**.
- **D7 Schedule basis** — prior-year MAGI; continuous schedule (no brackets) + legibility layer.
- **D8 Financing** — debt-financed, with a directional long-run safety-net-offset note (RAND).
- **D9 Phase-in** — out of scope; the document is steady-state design only.
- **D10 Self-employed** — kept in the headline, with estimated-tax / 1099 / platform rails and a worker-classification safe harbor.
- **D11 Account economics** — acknowledged, not modeled.

## C. Your first-round recommendations → disposition

"Adopted" = your recommendation is now in the design. "Declined" = a deliberate choice against it, with a stated rationale you may contest. "Open" = not yet done; a legitimate re-review target (not a settled item).

| Panelist | Recommendation | Disposition |
|---|---|---|
| **Hale** (oppose) | CPI-index instead of median-anchoring | **Adopted** (IRS anchor + C-CPI-U + decennial). |
| | Decouple access from the rate increase / strip the rate | **Declined** — 200% floor kept (D3); rationale: the model assumes match-invariant participation, so its "no new savers" result cannot adjudicate the floor; evaluation path proposed (S2). Contest welcome. |
| | Model §6433(d)(2) before any rate > 100% | **Superseded** — D6 replaces §6433(d)(2) with a 6-month match-forfeiture; bounding that effect is **open** (Tier 2.3). |
| **Vásquez-Cole** | Non-contingent base contribution | **Deferred** (D5, documented option). |
| | Liquidity sidecar | **Partially** — D6 keeps own contributions Roth-liquid; a dedicated emergency sidecar not added. |
| | Demographic + secondary-earner incidence | **Open** (Tier 2.6); the secondary-earner distortion is now acknowledged in the spec's marriage section. |
| **Lindqvist** | Rail-specific take-up; publish the band | **Partially** — brief publishes the range with 80% as the central case; rail-specific rungs **open** (Tier 2.1). |
| | Engineer the self-employed rail | **Adopted** (D10). |
| | Legibility layer | **Adopted** (D7). |
| **Raghunathan** | Statutory administrative anchor, not SIPP | **Adopted** (D1, IRS). |
| | Complete the stacked-EMTR analysis | **Open** (Tier 2.11); the EMTR concern is muted by the D7 prior-year basis. |
| | Correct the marriage prose | **Adopted / fixed** (now marriage-neutral / single-earner-bonus, archetypes recomputed). |
| **Calloway** (oppose) | Kill median re-anchoring (CPI + sunset) | **Adopted** (IRS + C-CPI-U + decennial re-anchor). |
| | No federal account; use EO marketplace / state rails | **Declined** — D2 keeps the federal account (RSAA model); rationale: worker-level portability avoids the churn/vesting erosion. Contest welcome. |
| | Liquidity / clawback-free emergencies; pilot first | **Partially** — D6 Roth access adopted; a formal pilot is **open** (S2). |
| **Brandt** | Legislate the phase-in | **Out of scope** (D9, steady-state only). |
| | Blunt MAGI sensitivity (brackets, safe harbor) | **Addressed differently** — D7 prior-year basis dissolves the reconciliation problem; rate brackets declined to avoid notches. |
| | Price the small-dollar admin subsidy | **Noted only** (D11). |
| **Okafor** | Finance inside the DC-exclusion envelope | **Declined** — debt-financed (D8), with a long-run-offset note. Contest welcome. |
| | Resolve indexing; publish the 10-year path | Indexing **adopted** (D1); 10-year path **open** (Tier 2.4, recompute on the new base + C-CPI-U). |
| | Close the three scoring gaps | **Partially** — proxy gap characterized; §6433(d)(2)→6-month; self-employed rails specified, take-up sensitivity **open**. |
| **Liu** | Swap the default channel to EO/state | **Declined** — D2 keeps the federal account. Contest welcome. |
| | CPI-index pivots; reframe the floor | **Adopted** (D1; brief frames it as "$500 unlocks $1,000"). |
| | JCT score early, delay effective date, stage mandate | **Out of scope** (D9; policymaker decisions). |
| **Bridger** | 5% default with auto-escalation | **Declined** — kept 3% headline + graduated 1/2/3% option (D4). Contest welcome. |
| | Score on a compliance ramp | **Out of scope** (D9). |
| | Engineer for churn/leakage; self-employed rail | Liquidity **partially** (D6); persistence adjustment **open** (Tier 2.2); self-employed rail **adopted** (D10). |
| **Mwangi** | Launch at 100% floor, escalate to 200% | **Declined** — kept 200% at launch (D3), same rationale as Hale. Contest welcome. |
| | Legislate the evaluation (RD/RKD + randomized arm) | **Endorsed direction, open** (S2) — strong candidate; not yet drafted. |
| | Close the self-employed gap; automatic deposit | **Adopted** (D10; the federal account auto-accepts the deposit). |

## D. Where the artifacts now stand

- **Spec** — updated for all of D1–D11; marriage prose corrected; legal-review table updated (§6433(d)(2)→6-month, self-employed rails specified); steady-state scope statement added.
- **Brief** (`output/reports/universal_sm_hybrid/universal_hybrid_brief.html`) — 80% auto-enrollment as the central case; four figures repositioned; funnel dropped; panel-informed design language throughout.
- **Deck** (`...universal_hybrid_brief_deck.pptx`) — EIG-styled, built from the brief.
- **Figures** — regenerated on the new pivots; all titles/captions/values current.
- **Data guide** — current numbers are now canonical for this re-review.

## E. Still open / not yet modeled — please do NOT re-flag as if new; advise on the assumption instead

These are acknowledged and tracked (Tier 2 in `PANEL-SYNTHESIS.md`). They are deliberately *not* pre-run, because each turns on an assumption you are better placed to advise on than we are to pre-bake — running them now would invite a critique of our assumption rather than the design. For each, the open methodological choice is named; **panel input on that choice is what we want.**

1. **Rail-specific & self-employed take-up** (Tier 2.1, 2.13). *Open: the W-2 payroll-default participation rate and the (lower) self-employed rate. What values are defensible?*
2. **Contribution-persistence adjustment** (Tier 2.2). *Open: the persistence factor (state auto-IRA evidence ≈ 0.59). Is that the right anchor for a matched federal account?*
3. **D6 six-month match-forfeiture bound** (Tier 2.3). *Open: the share of matched contributions withdrawn within six months. What withdrawal propensity should bound the cost overstatement?*
4. **Ten-year outlay path** (Tier 2.4) — **recomputed 2026-06-11** (`_shared/anchoring/ten_year_path.md`). On the current base, the brief's 80 percent headline runs about **$216 billion over FY2027–FY2036** (range $191B flat to $228B wage-indexed), reaching ~$24B/yr by year ten; the conservative and ceiling rungs are ~$160B and ~$270B. This replaces Okafor's first-round $151.5B/$202.1B/$252.6B, which were on the old base and a median-indexed growth assumption. Two effects: a ~6 percent *base* reduction, and an *indexing* reduction — the D1 switch to C-CPI-U + decennial re-anchor cuts the 10-year growth premium from ~19.5% to ~13%. *Open assumption the panel may contest: the ~2.7%/yr C-CPI-U central growth rate (vs. ~3.9% wage-indexed).*
5. **Demographic / secondary-earner incidence** (Tier 2.6). *Requires adding SIPP race/ethnicity/sex to the extract; the secondary-earner margin is now acknowledged in the spec.*
6. **Employer crowd-out scenario** (Tier 2.7). *Open: the small-employer plan-drop rate. Flagged as an unmodeled caveat in the spec and brief.*
7. **Replicate-weight standard errors** (Tier 2.10). *Requires pulling SIPP replicate weights; would put design-based CIs on the headline.*
8. **Graduated-default repricing** (Tier 2.9 / D4). *Open: the FPL/household-size approximation needed to assign the 1/2/3% band from prior-year MAGI.*

## F. The genuinely-open questions to focus on

If you want the re-review to add the most value, weigh in on these:

1. **The 200% floor (D3).** Is the behavioral bet defensible given the model cannot see a match-rate participation response, and is a built-in evaluation (S2) the right way to resolve it?
2. **The federal account (D2).** Is worker-level portability worth the political cost of keeping a Treasury-run account rather than the EO-marketplace/state-rail alternative?
3. **The population basis of the anchor (D1).** Anchoring the band to IRS *filers* while scoring a *worker* universe is what the ⅔-median tuning compensates for — is ⅔ the right calibration, or should the anchor population change?
4. **The 80%-as-central framing.** Is auto-enrollment stickiness sufficient justification to foreground $19.09B over the SIPP-observed $14.15B?
5. **Debt financing (D8).** Is the long-run safety-net offset a sufficient answer, or does the proposal need an explicit pay-for?
