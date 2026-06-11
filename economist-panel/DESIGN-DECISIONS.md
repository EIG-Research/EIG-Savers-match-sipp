# Design Decisions Record — Universal Account, Targeted Saver's Match Hybrid

**Date:** 2026-06-11
**Author of record:** Benjamin Glasner (decisions); panel evidence per `PANEL-SYNTHESIS.md`.
**Status:** Decisions locked for the next draft of `Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md`. Tier 1/Tier 2 work items in the synthesis are re-scoped against these decisions in §"Cross-tier impact" below.

**Scope note (governs the whole record).** Per **D9**, this proposal describes the **steady-state design of the program once implemented**. Transition mechanics — phase-in order, effective dates, agency stand-up — are explicitly left to policymakers and are out of scope for the draft.

Each decision below records: the **decision**, the **rationale** (author's reasoning plus the panel evidence it rests on or overrides), **governance notes** (convention, replicability, scoring legibility), **open sub-questions** the author still needs to settle, and **downstream impact** on the synthesis work tiers.

---

## D1 — Eligibility indexing

**Decision.** The policy is defined independently of SIPP; SIPP is used only to inform the simulation. The eligibility schedule is anchored to **IRS data for the Single filing group only**: the **IRS all-single-filer median AGI (→ MAGI) for the tax year immediately preceding implementation**, with the **75 percent rate fixed at two-thirds of that median** (→ Single pivot = 0.8 × median, endpoint = 1.067 × median). The **Head-of-Household and Married-Filing-Jointly schedules are derived from the Single anchor by the statutory §6433 ratios (HoH = 1.5 × Single, MFJ = 2.0 × Single)** — preserving marriage neutrality and matching the enacted Saver's Match threshold structure. Base-year values are indexed forward by the **chained CPI for All Urban Consumers (C-CPI-U)**, and **re-anchored to a fresh IRS median every ten years**. The ⅔-of-median anchor was chosen so the IRS-anchored schedule reproduces today's coverage within ~3–4 percent (see the resolved formula below) while putting the frontier on a stable administrative basis with a legislator-legible "two-thirds of the median" rule.

**Sub-question 2 resolved (2026-06-11): anchor the Single median to IRS data and keep the 2.0×/1.5× ratios.** This preserves the exact marriage neutrality Raghunathan's analysis depends on (MFJ pivot = 2.0 × Single pivot), and it aligns the design with enacted §6433, whose statutory thresholds are themselves Single × 1.5 (HoH: $30,750 / $20,500) and Single × 2.0 (MFJ: $41,000 / $20,500). The current spec already uses these ratios; D1 changes only the *Single* anchor (from the SIPP weighted median to the IRS median) and the indexing/re-anchoring rule, not the inter-filing-group geometry.

**Resolved schedule formula (all sub-questions settled 2026-06-11; anchor point finalized after the gap-decomposition finding below).** Let *M* = the **IRS all-single-filer median AGI** for the base year (adjusted to MAGI; add-backs ≈0 at the median). The 75 percent rate is fixed at **two-thirds of M** (a deliberately legible "two-thirds of the median" rule for legislators), which under the 200-percent-floor / 50-percent-pivot geometry gives:
- **Single pivot = 0.8 M**, **Single endpoint = (4/3)(0.8 M) = 1.067 M**;
- **HoH pivot = 1.5 × Single pivot**, **MFJ pivot = 2.0 × Single pivot** (endpoints at 4/3 × pivot).

The rate runs linearly from 200 percent at zero MAGI, through 75 percent at ⅔ M, 50 percent at the pivot, to 0 at the endpoint. The **$1,000 per-individual cap is C-CPI-U-indexed** on the same basis as the pivots. All parameters re-anchor on the decennial cycle.

**Why ⅔ and not ½ (the gap-decomposition finding, `_shared/anchoring/`).** Switching the anchor from the SIPP worker median to the IRS all-filer median is a *population* change, not an income-concept change: the median single worker carries only ~$15 of non-earnings income, so netting transfers out of the proxy (the originally-authorized realignment) is a no-op — the SIPP-vs-IRS gap (~$55k vs. ~$40k TY2027) is entirely that SIPP scores *workers* while IRS measures *all single filers*. At a ½-median anchor the IRS basis would cut eligibility to 28.06M / $12.2B (endpoint $32,235, just below §6433) — excluding the median worker. The ⅔-median anchor (pivot 0.8 M) puts the schedule on the stable IRS basis **and** reproduces today's coverage within ~3–4 percent (**44.47M eligible, $23.87B full-participation ceiling, ≈$14.3B headline**, vs. 46.07M / $24.92B / $14.9B), with the clean two-thirds handle. Verified TY2027 working anchor M ≈ $40,294 (IRS SOI single median AGI TY2023 $34,944, projected ×1.126).

**Rationale.** No panelist defended SIPP-wave re-anchoring (Synthesis §3). Raghunathan (R1) and Okafor (R2) called for a statutory administrative-data anchor for replicability and scoring legibility; Calloway, Liu, and Hale wanted CPI-style indexing against a fixed base to avoid a self-perpetuating entitlement. This decision takes the administrative anchor (IRS) *and* the CPI indexing *and* a decennial re-anchor — a deliberate middle path.

**Governance notes.**
- **Convention alignment.** C-CPI-U is the measure the Internal Revenue Code has used for bracket and threshold indexing since the 2017 Tax Cuts and Jobs Act, so this matches current statutory practice and is the natural choice a drafting committee would expect. (Enacted §6433 itself indexes its MAGI thresholds by CPI from 2028.)
- **Replicability / scoring.** IRS Statistics of Income publishes AGI by filing status annually; anchoring to a published administrative median is reproducible by JCT and CBO without access to SIPP, which is the property Raghunathan and Okafor asked for. SIPP is relegated to ex-ante simulation only.
- **The indexing mechanics are a genuine compromise, and worth stating explicitly in the draft.** Because C-CPI-U grows more slowly than average wages, between re-anchorings the eligible *share* drifts down with real wage growth — like current law, but more slowly — and then re-anchors back up each decade. This is materially different from both poles of the §3 split: it neither holds the eligible share constant forever (continuous median-anchoring) nor erodes coverage toward zero (pure fixed-dollar CPI). The decennial re-anchor is the cost circuit-breaker Okafor wanted.

**Sub-questions — all resolved 2026-06-11.**
1. **Statistic-to-schedule mapping → fix a 75 percent rate at one-half the Single median.** This is the existing geometry, now fed by the IRS Single median. Verified mechanically against the model: it implies **pivot = 0.6 × Single median MAGI** and **endpoint = (4/3) × pivot = 0.8 × Single median MAGI**, with the schedule running 200 percent at zero MAGI, 75 percent at one-half the median, 50 percent at the pivot, and 0 at the endpoint. (Confirmed: current Single pivot $32,879 ÷ SIPP median $54,799 = 0.600; endpoint $43,839 ÷ median = 0.800.) HoH and MFJ follow by the 1.5× / 2.0× ratios.
2. **Independent vs. ratio-derived anchoring → anchor the Single median to IRS data, keep the statutory 2.0×/1.5× ratios.** Preserves marriage neutrality and matches enacted §6433 threshold structure. See the decision text above.
3. **MAGI vs. AGI → use the MAGI concept (as the enacted Saver's Match does), built from SOI-reported AGI with an adjustment toward MAGI, and align the SIPP simulation proxy to that concept as closely as SIPP's collected variables allow.** Two layers, kept distinct:
   - *Anchor (policy/administrative side):* start from the IRS SOI **AGI** median for Single returns and adjust to MAGI by adding back the §6433 MAGI items (§911 foreign-earned-income exclusion; §931/§933 territorial exclusions). At the median filer these add-backs are negligible, so the SOI Single AGI median is a close proxy for the Single MAGI median; document the adjustment regardless.
   - *Simulation side (the load-bearing Tier 2.5 task):* the current SIPP MAGI proxy (summed monthly TPTOTINC) is broader than AGI (it includes non-taxable transfers) and narrower in places (it omits realized capital gains). Move the proxy toward the AGI/MAGI concept by netting out the non-AGI transfer components SIPP can identify (e.g., SNAP, TANF, SSI, child support, gifts), then add §911/§931/§933 (≈0; SIPP excludes foreign/territorial residents). Residual divergence remains — this is the legal-review "material" caveat (headline cost likely within ±15 percent of a true §6433-MAGI simulation) and should be stated, not hidden.
4. **Cap indexation → yes, C-CPI-U-index the $1,000 per-individual cap** on the same basis as the pivots, for internal consistency (Okafor flagged cap indexation as first-order over a ten-year window).

**Downstream impact.** Re-run pivots/endpoints from the IRS Single median + C-CPI-U (replaces the SIPP-median figures $32,879/$49,319/$65,758 in the current spec — the headline eligibility and cost numbers will move). Promotes Tier 2.5 (MAGI proxy alignment) from a robustness check to a **load-bearing input**.

**First-pass computation done (2026-06-11; see `_shared/anchoring/FINDINGS.md`).** The IRS SOI single-filer median AGI is **$34,944 (TY2023), ≈$40,294 projected to TY2027** — about **26 percent below** the SIPP-derived median ($54,799 TY2027$) the current pivots rest on. That gap combines a *concept* component (the SIPP proxy includes non-taxable transfers AGI excludes) and a *population* component (SOI counts single tax filers; the SIPP universe counts workers with earned income). **The headline cannot be re-priced by a naive pivot swap:** dropping the lower IRS pivot against the un-realigned (inflated) SIPP proxy would compare inconsistent concepts and understate eligibility. Correct sequence — (1) realign the SIPP MAGI proxy toward AGI/MAGI (Tier 2.5, *pipeline work*), (2) reconcile the anchor population, (3) re-pivot, C-CPI-U-index the cap, and re-price. Steps 1 and 3 move the eligibility count in partially offsetting directions, so the net headline effect is ambiguous in sign until both are done together. **Recommend the author authorize the Tier 2.5 proxy realignment before any re-pivoted figures are quoted.**

---

## D2 — Default destination channel

**Decision.** Option (a): a **federal universal account**, built on the Retirement Savings for Americans Act's American Worker Retirement Plan architecture — functionally an extension of the Thrift Savings Plan to workers without an employer-provided plan. The account exists at the **individual-worker level (not the employer level) and is fully portable**, moving with the worker.

**Rationale.** The portability design is the author's direct answer to the auto-enrollment literature Bridger and the behavioral panelists cited: worker-level portable accounts avoid the benefit erosion that churning coverage, early-withdrawal/cash-out at job change, vesting schedules, and minimum-tenure requirements impose inside employer-sponsored plans. The author accepts the political risk Liu flagged (ICI/ARA/IRI opposition; the MyRA precedent) as the price of design integrity and evidence-aligned portability.

**Governance notes.**
- Aligning to RSAA's AWRP lets the draft cite an existing legislative architecture rather than invent one, and inherits RSAA's portability and TSP-like-menu provisions wholesale.
- Keeps the small-dollar account-economics problem (Brandt; see **D11**) live and unresolved-by-design; the draft should acknowledge it even though it will not model it.

**Downstream impact.** Tier 1.6 becomes a steady-state **scope statement** rather than a timeline caveat (transition is out of scope per D9). The federal-account choice is the hinge for the Tier 4 stakeholder map (S4) — record that the political cost is accepted knowingly.

---

## D3 — Match floor at launch

**Decision.** Retain the **200 percent floor** at zero MAGI at launch. No phased escalation trigger.

**Rationale.** This deliberately overrides the panel's strongest convergent empirical finding (Synthesis §2a: in the model, the floor above 50 percent buys ~9 percent of cost in net new generosity and *no* additional savers). The override is principled, not casual: the simulation **assumes participation is invariant to the match rate** — the exact limitation Mwangi flagged — so the model is structurally incapable of crediting the floor with any behavioral payoff. The "no additional savers" result is therefore an artifact of that assumption, not evidence against the floor. The author's bet is on a liquidity-constrained participation/persistence response the model does not capture: over-matching at the bottom helps the lowest earners (who skew younger and less-educated) overcome liquidity barriers and move a marginal dollar out of consumption, where it is hardest to move. A fixed-dollar contribution concentrated only at the bottom is also judged politically infeasible and far more costly.

**Governance notes.**
- State this rationale explicitly in the draft, because it is the panel's central disagreement. The honest framing is: *the floor's case is behavioral, and the simulation cannot adjudicate it — which is precisely why a built-in evaluation (Tier 4 S2) matters.*
- The author flags an RSAA-style 1 percent government match as a possible complement but notes it skews toward higher earners — this is parked under **D5**.

**Downstream impact.** Elevates Tier 2.1 (rail-specific take-up) and especially Tier 4 S2 (legislate a randomized match-generosity arm, 50/100/200) from "nice to have" to "the mechanism that would validate this decision." Reinforces the Tier 1.4 reframing ("up to $1,000 on a $500 contribution").

---

## D4 — Default contribution rate

**Decision.** Keep a **flat 3 percent default** as the headline for clarity. Carry, as a costed **option**, an income-graduated default: **1 percent for workers below 100 percent of the federal poverty line, 2 percent below 150 percent, and 3 percent at 150 percent or above.**

**Rationale.** The flat 3 percent keeps the topline legible (Lindqvist's salience concern). The graduated option is a liquidity accommodation for the lowest earners (Calloway's variant; Vásquez-Cole's affordability point that 3 percent of a poverty-level wage is a real bite), without abandoning the simple headline.

**Governance notes.**
- **Administrability wrinkle.** A poverty-ratio-based default needs household size and income at enrollment, which a payroll file does not carry. The practical approximation is prior-year MAGI relative to the FPL for a default household size — which dovetails with the **D7** prior-year-MAGI basis. Specify this approximation if the option is pursued.
- Bridger's and the state programs' 5 percent-with-escalation default is *not* adopted; note the tradeoff (forgoes the best-evidenced savings-increasing instrument) and that the graduated option moves in the opposite direction at the bottom, by design, for liquidity reasons.

**Downstream impact.** Adds a Tier 2 sensitivity: simulate the 1/2/3 percent graduated default and report its cost and cap-reachability effects against the flat-3-percent headline. Supersedes the old Tier 2.9 (5-percent repricing) — replace it with the graduated-default repricing.

---

## D5 — Non-contingent base contribution

**Decision.** **Out of the baseline.** Record as a documented future option: a universal or income-targeted RSAA-style 1 percent automatic contribution, or a flat dollar contribution.

**Rationale.** Vásquez-Cole (R1) and Raghunathan supported it (it would close the decile-1-below-decile-2 incidence dip, $285 vs. $518); Hale and Calloway read it as a pure demogrant. The author defers rather than decides — keeps the baseline contribution-contingent but signals the option is live.

**Governance notes.** Connected to the D3 parenthetical (RSAA 1 percent match) and the D4 graduated default; if any of the three is later adopted, price them together so the bottom-of-distribution incidence is assessed as one package.

**Downstream impact.** No baseline change. Optional one-line Tier 2 costing if the author revisits.

---

## D6 — Liquidity architecture / withdrawals

**Decision.** Adopt the **withdrawal and vesting design of the RSAA** (S.1526), verified against the bill text:
- Participant contributions are **Roth / after-tax and freely withdrawable**, with Roth-IRA distribution-ordering rules applied (S.1526 §106(k), applying IRC §§408(d) and 408A(d)).
- **Hardship withdrawals and loans are limited to the participant's own contributions** (§106(i), §106(h)); age-59½ access without penalty.
- The **federal match is subject to a 6-month holding requirement (§25F(h)): if a contribution does not remain in the account for at least 6 months, the match attributable to it is forfeited back to Treasury — with no tax penalty on the distribution itself.**
- All contributions are otherwise **nonforfeitable when made**, except the §25F(h) 6-month rule (§101(i)).

**Rationale.** Three panelists from very different priors — Vásquez-Cole (R2), Calloway (R3), Bridger (R3) — independently asked for a liquidity accommodation. RSAA's design supplies it cleanly: the worker's own money stays liquid (Roth ordering), so liquidity-constrained workers are not forced to choose between enrolling and keeping access to their savings; only the federal match carries a short anti-churn hold.

**Governance notes.**
- **This replaces §6433(d)(2)'s 3-year distribution-recapture with RSAA's simpler 6-month match-forfeiture.** State the override explicitly: the hybrid's match anti-gaming rule is the 6-month hold, not the §6433 testing period. This is both simpler to administer and a smaller behavioral bite.
- Because the worker's own contributions are Roth and withdrawable by design, some leakage is *accepted by design* (the Beshears/Argento leakage literature Calloway cited). The draft should frame this as a deliberate liquidity-for-participation trade, not an oversight.

**Downstream impact.** Largely **resolves and replaces Tier 2.3** (modeling the §6433(d)(2) 3-year recapture): instead, model — or bound — the 6-month match-forfeiture, which is a far smaller adjustment. Settles the D6 liquidity question for the draft.

---

## D7 — Schedule administration

**Decision.** Determine the match on **prior-year MAGI**. Keep the **continuous linear MAGI schedule** (no flat brackets — brackets create inflection points and notches). Add a **legibility layer** that walks a reader through what the schedule means via clearly defined worker scenarios.

**Rationale.** Brandt offered flat prior-year-MAGI brackets as an administrative safe harbor; the author takes the prior-year *basis* but rejects the *brackets* to avoid notch distortions, pairing the continuous schedule with Lindqvist's "personalized dollar promise" legibility layer instead.

**Governance notes — this is the highest-leverage administrative decision in the set.**
- **Reconciliation problem largely dissolved.** Keying the match to *prior-year* MAGI means the match rate is a **known quantity at the moment of contribution**. This eliminates the year-end true-up and clawback exposure Brandt computed for ~40.3 million sub-cap workers: there is nothing to reconcile against current-year income.
- **EMTR concern substantially muted.** Because the phase-out runs on *prior-year* income, a worker's *current-year* earnings do not reduce their *current-year* match. The implicit marginal tax rate from match phase-out is therefore not a contemporaneous labor-supply wedge in the standard sense — it is a lagged, already-determined parameter. This significantly weakens Raghunathan's EMTR-stacking concern and changes how Tier 1.2 and Tier 2.11 must be framed.
- **Edge case to specify:** workers with no prior-year return (new labor-market entrants, recent immigrants, first filers). Provide a rule — e.g., default to a current-year estimate with a no-penalty reconciliation, or to the most-generous band pending the first filed return.

**Downstream impact.** **Rewrite Tier 1.2** (EMTR qualification) around the prior-year basis: the headline is now that the design imposes little or no *current-year* marginal distortion, not that it adds 3.25 pp. **Reframe Tier 2.11** (stacked EMTR) accordingly. **Downgrades Brandt's reconciliation map** (Tier 2 reconciliation work) to the new-entrant edge case only.

---

## D8 — Financing

**Decision.** Present the program as **debt-financed, as currently drafted**, but explicitly cite the RAND RSAA analysis showing **long-run cost savings through reduced spending on asset-tested safety-net programs**, which this program should also generate.

**Rationale.** The author keeps the static cost presentation but adds the dynamic, long-run offset Okafor's national-saving point gestures at — grounded in RAND's RSAA modeling rather than asserted.

**Governance notes (RAND finding verified 2026-06-11).** RAND, "Impacts of the Retirement Savings for Americans Act: A Preliminary Analysis Using the RAND Budget Model" (RRA2614-3, 2024), estimates RSAA net costs of about **$274 billion over the first 10 years and ~$1.5 trillion over 40 years**, but a reduction of **more than $3.6 trillion in Medicaid and SSI spending on seniors over 40 years** — RSAA reduces spending on asset-tested programs by more than its annual cost after roughly **20–30 years** and is **cumulatively net-positive after 30–45 years**, by delaying seniors' eligibility for SSI and Medicaid.
- Apply this to the hybrid with care: RSAA's gross cost is far larger than the hybrid's because RSAA's match is a percent-of-income contribution with no per-person dollar cap, whereas the hybrid's $1,000 cap bounds gross cost. The *same offsetting mechanism* (delayed asset-test eligibility) should apply to the hybrid at a lower gross cost — but the magnitude is not transferable one-for-one and should be framed as directional, not a point estimate.
- The asset-test offset presumes the relevant interaction with SSI/Medicaid asset rules; note that RAND models *delayed eligibility*, and that whether account balances are counted or excluded under means-tested asset tests is itself a policy parameter worth a sentence.

**Downstream impact.** No change to the static cost tables. Optional Tier 2 note: a directional long-run dynamic-savings paragraph citing RAND, clearly labeled as illustrative.

---

## D9 — Phase-in schedule

**Decision.** **Do not integrate a phase-in.** This is left to policymakers; the proposal addresses steady-state design once implemented.

**Rationale.** Keeps the document a design artifact, not an implementation plan. Brandt's phase-in template is acknowledged but out of scope.

**Governance notes.** Add the scope statement (see top of this record) to the draft so readers do not mistake silence on transition for an implied TY2027 launch.

**Downstream impact.** Converts Tier 1.6 to a one-line scope statement. Moves Tier 2.8 (compliance-ramp costing) and Tier 4 S1 (phase-in sequencing) **out of scope for this draft** (retain in the synthesis as policymaker-facing, not author-facing).

---

## D10 — Self-employed contribution rail

**Decision.** The **self-employed remain in the headline universe.** The draft adds explicit mechanism flags for: (1) an **estimated-tax piggyback** (a Schedule SE election with auto-debit), (2) **1099-payer withholding**, and (3) **platform-facilitated contributions** — noting that platform/gig work can facilitate saving into these accounts without triggering employer reclassification, with a **safe harbor for benefit provision via flexible/portable benefits.**

**Rationale.** Lack of facilitated, matched retirement saving among the self-employed, independent contractors, and gig workers is a **core motivating problem** of the proposal — so the author rejects Lindqvist's "engineer the rail or stop counting them" disjunction by engineering the rail. The classification safe harbor addresses a real legal barrier: platforms currently avoid providing benefits for fear of triggering employee reclassification.

**Governance notes.**
- The flexible-/portable-benefits safe harbor connects to the active portable-benefits policy debate; framing the contribution channel as a safe harbor (rather than an employment indicium) is the legally load-bearing element and should be stated in statutory terms.
- These rails are necessary precisely because the self-employed have no payroll mechanism — the gap the universal account (D2) is meant to close.

**Downstream impact.** Keeps the 4.41 million self-employed eligibles in the headline. Tier 2.1 still needs a **self-employed-specific take-up sensitivity**, now with the three rails named as the basis for the assumption.

---

## D11 — Small-dollar account economics

**Decision.** Include **one sentence** acknowledging the per-account administrative-cost issue as a consideration. **Do not simulate it or carry it as a flagged cost** in this draft.

**Rationale.** Brandt's $20–30/account-year subsidy and fee-glide-path proposals are real implementation concerns but are transition/administration matters; consistent with D9's steady-state scope, the author notes but does not model them.

**Governance notes.** The acknowledgment matters for credibility (the small-dollar problem is well documented), but pricing an administrative subsidy is an implementation-financing question outside the design scope.

**Downstream impact.** No modeling work. One acknowledgment sentence in the draft.

---

## Cross-tier impact summary

> **Update 2026-06-11: D1 is now implemented in production** (44.47M / $14.15B / $23.87B ceiling; pivots $32,235 / $48,353 / $64,471). The per-item **▶ Impact** annotations in `PANEL-SYNTHESIS.md` §5 are the live, item-level re-assessment; the tables below are the decision-level view. Net new effect of *implementing* (beyond the decisions themselves): all item-level and §2/§4 figures computed on the old pivots are ~3–6 percent stale and must be recomputed before use, and a new spec-prose task (synthesis item 1.7) collects the decided elements not yet written into the spec.

How the locked decisions re-scope the synthesis work items (the user's reason for deciding design first):

### Tier 1 (correctness/presentation) — net changes
| Item | Status after decisions |
|------|------------------------|
| 1.1 Marriage prose | **Decoupled from D1 (sub-question 2 resolved): neutrality is preserved** by keeping the 2.0×/1.5× ratios. The item reduces to a pure prose-correctness fix — state that the schedule is marriage-neutral for equal earners and bonus-generating for single-earner couples (Raghunathan), correcting the current spec's reversed signs. No structural dependency remains. |
| 1.2 EMTR qualification | **Rewrite around D7.** Prior-year-MAGI keying means little/no current-year marginal distortion; the framing flips from "adds 3.25 pp" to "imposes negligible contemporaneous EMTR." |
| 1.3 Take-up band | Unchanged — still publish the band and closed-form rule. |
| 1.4 Floor reframing | **Reinforced by D3** — "up to $1,000 on a $500 contribution" is now the primary defense of the retained 200 percent floor. |
| 1.5 Losers' map | Unchanged. |
| 1.6 Timeline caveat | **Becomes a steady-state scope statement** (D9). |

### Tier 2 (model/analysis) — net changes
| Item | Status after decisions |
|------|------------------------|
| 2.1 Rail-specific take-up | **Elevated** (D2, D3, D10); incorporate the graduated-default option (D4) and self-employed rails (D10). |
| 2.2 Persistence adjustment | Keep, but note D2 portability and D6 Roth liquidity partly mitigate churn-driven loss. |
| 2.3 §6433(d)(2) recapture | **Replaced by D6** — model/bound the RSAA 6-month match-forfeiture instead of the 3-year recapture. |
| 2.4 Ten-year path + cap indexation | **Re-run under D1** (C-CPI-U pivots, decennial re-anchor); resolve cap-indexation sub-question D1(4). |
| 2.5 MAGI validation | **Promoted to load-bearing** (D1) — construct and document the IRS within-filing-status median-MAGI anchor. |
| 2.6 Demographic/secondary-earner incidence | Unchanged; secondary-earner margin still relevant under joint-MAGI keying. |
| 2.7 Crowd-out scenario | Unchanged. |
| 2.8 Compliance ramp | **Out of scope for the draft** (D9); retain as policymaker-facing. |
| 2.9 5-percent default repricing | **Replaced** by the graduated 1/2/3-percent default repricing (D4). |
| 2.10 Replicate-weight SEs | Unchanged. |
| 2.11 Stacked EMTR | **Reframe under D7** (prior-year basis). |
| New | **Re-anchor pivots/endpoints to IRS medians + C-CPI-U** (D1) — a repricing task that moves the headline eligibility and cost figures. |
| New | **Self-employed take-up sensitivity** with the three D10 rails. |
| New (optional) | Graduated-default sensitivity (D4); directional long-run safety-net-offset note citing RAND (D8). |

### The one tension — RESOLVED 2026-06-11
**D1 sub-question 2 is settled: anchor the Single median to IRS data, keep the statutory 2.0×/1.5× ratios.** Marriage neutrality is preserved by construction, so Tier 1.1 is now a pure prose fix with no structural dependency. The pivot re-anchoring (2.4/2.5) proceeds on a single moving part — the Single IRS-median anchor — with HoH/MFJ following mechanically. Remaining D1 sub-questions before the re-anchoring run: (1) which Single statistic maps to which schedule point, (3) the MAGI add-back definition from IRS tables, (4) whether to C-CPI-U-index the $1,000 cap.

---

*Decisions recorded by the author on 2026-06-11. Panel evidence and the full tiered plan are in `PANEL-SYNTHESIS.md`. RSAA withdrawal/vesting provisions (D6) verified against S.1526 bill text via govinfo (BILLS-119s1526is); RAND safety-net findings (D8) verified against RAND RRA2614-3 (2024) on 2026-06-11.*
