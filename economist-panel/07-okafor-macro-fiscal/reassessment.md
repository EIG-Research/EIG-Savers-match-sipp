# Macro-Fiscal Re-Review: Universal Account, Targeted Saver's Match Hybrid

**Panelist 07 — Dr. Sam Okafor, macro-fiscal economist**
**Date: 2026-06-11 — re-review addendum to `assessment.md` (first round, unchanged)**

All numbers below are scored against the current canonical base (44.47M eligible; $14.15B / $19.09B / $23.87B; pivots $32,235 / $48,353 / $64,471). Spot-checks in `code/04_reassessment_checks.R`, run against `data/processed/universal_sm_hybrid/simulation_results.parquet`, confirm the row-level frame reproduces every one of those figures, including the route split (18.49M / $9.92B employer; 25.98M / $13.95B universal).

## 1. Disposition check

**Indexing (adopted, D1).** I accept the reading, and I want it on the record that D1 is a better answer than what I asked for. I asked for resolved indexing; the design delivers an administrative anchor JCT can replicate from published SOI tables, C-CPI-U indexation matching post-TCJA Code practice, a decennial re-anchor that functions as the cost circuit-breaker I wanted, and — the item I flagged as first-order — the $1,000 cap explicitly C-CPI-U-indexed on the same basis as the pivots. Resolved in my favor on every sub-point.

**Ten-year path (open, recomputed — Tier 2.4).** I audited `_shared/anchoring/ten_year_path.md`. The arithmetic is exact: from a $19.09B FY2027 base, ten years at 2.7 percent compounds to $215.8B with a $24.3B year-ten annual; the flat and wage-indexed brackets ($190.9B / $228.1B) reproduce likewise. The base-effect/indexing-effect decomposition is the right way to show why my first-round $202.1B (80 percent rung, flat convention) becomes $190.9B flat and $215.8B on the new central growth. I accept the recomputation and retire my first-round totals. Two audit flags on method, not arithmetic:

- **Fiscal-year timing is omitted.** The path treats FY2027 as a full outlay year. §6433-style matches deposit after the return is filed — JCT's score of the enacted match shows nothing before FY2028 — so a FY2027–FY2036 window contains only nine tax years of cost. On the 2.7 percent path that is **$191.6B in-window versus $215.8B over ten tax years, an 11.2 percent gap** (same proportional gap on every rung). Neither number is wrong; they answer different questions. But the document a committee staffer reads must say which convention it uses, or the first JCT table will look like a $24B "score cut" that is pure timing.
- **The "eligible share held roughly stable by the decennial re-anchor" line is loose.** If launch is FY2027, the first re-anchor lands at year eleven — *outside* the window. Within the window the eligible share drifts down with real wage growth (C-CPI-U pivots against ~3.9 percent wages), which is cost-reducing; partially offsetting, below-cap matches grow with wages while the cap grows only with C-CPI-U, so more participants hit the cap. The stated 2.7 percent is a defensible *net* of those two opposing drifts — but it should be presented as that net, not as "share stable."

**On the open assumption itself (the changelog asks):** I endorse **C-CPI-U ~2.7 percent as the central path** and would not move to 3.9 percent. The 3.9 percent wage-indexed line describes the *old* design; under D1 the statutory parameters — pivots and cap — grow at C-CPI-U by construction, so wage-indexing the projection would contradict the statute being scored. Keep 3.9 percent exactly as the document uses it: an isolation of the indexing effect, not a live scenario. If anything, my two flags above net mildly *downward* within the window.

**Scoring gaps (partial).** I accept the reading. The gap decomposition in `_shared/anchoring/FINDINGS.md` is genuinely informative — showing the SIPP-vs-IRS difference is population, not income concept (median worker non-earnings income: ~$15), retires my proxy-validation worry more cheaply than the tax-data linkage I proposed. D6's six-month forfeiture supersedes the §6433(d)(2) modeling request; bounding it (Tier 2.3) is second-order at my altitude. The self-employed rails are now specified. The take-up sensitivity remains open and remains my residual condition — it is the largest scoring wildcard (4.4M eligibles with no payroll rail) and the one item JCT will independently stress.

## 2. The declined financing recommendation (D8)

I asked for financing inside the $323B DC-exclusion envelope (PWBM-style). Declined; debt-financed with a directional RAND safety-net-offset note. **I concede half and hold half.**

The half I concede: my first-round question — does deficit financing forfeit the program's national-saving rationale? — is answered *in part* by my own decomposition, re-run on the current base. At the 80 percent central case, the universal account carries an $18.0B policy-induced default contribution flow plus $11.2B of match; under Chetty et al. (2014) passive-saver pass-through, new private saving runs $24.3–33.3B against $19.1B of public dissaving, for **net national saving of +$5.2B to +$14.2B per year (central +$9.7B, +$0.51 per federal dollar)** even when every federal dollar is borrowed. The default architecture, not the financing, carries the saving result. So no, the program does not forfeit its rationale outright — borrowing does not flip the sign. And the D8 note is honestly drafted: RAND's offset (RSAA cumulatively net-positive after 30–45 years via delayed SSI/Medicaid eligibility) is cited as directional, with the correct warning that magnitudes do not transfer from an uncapped percent-of-pay match to a $1,000-capped one.

The half I hold: **the objection stands as an enactability and magnitude condition.** First, magnitude: financing within the envelope would eliminate the $19.1B annual public dissaving, lifting central net national saving from roughly +$9.7B toward +$28.8B — call it a tripling of the program's saving payoff, purchased by trimming the least efficient tail of a $567B stack of which the top quintile takes 63 percent. Borrowing forgoes two-thirds of the achievable saving effect; "positive" is not "optimized." Second, the budget window: the RAND offset materializes over 20–45 years and will be credited by no conventional JCT or CBO score. Inside the ten-year window this is a ~$216B gross cost against a baseline of 101→120 percent debt-to-GDP and $16.2 trillion of net interest. A directional footnote about decades three and four does not move a markup in decade one. The proposal does not need to *adopt* my pay-for; it needs to *name one* — even as an option set — or accept that the financing question will be answered for it, on worse terms.

## 3. Fresh eyes — the five focus questions and new concerns

**The 200 percent floor (D3).** Defensible at my altitude. The $1,000 per-individual cap — not the rate — bounds fiscal exposure, and the synthesis put the floor's incremental cost near 9 percent. Since the model assumes match-invariant participation, it cannot adjudicate the floor either way; the S2 evaluation (randomized 50/100/200 arms) is the right resolution mechanism. One addition: carry a **priced 100-percent-floor fallback** in the scoring package, so the floor is a severable line item rather than a take-it-or-leave-it feature in negotiation.

**The federal account (D2).** Keep it. My round-one decomposition is the fiscal argument: the default contribution flow only a statutory account creates ($18.0B/yr at the central case) is what makes this program saving-positive; an EO-marketplace alternative with no default architecture delivers the match as a pure price subsidy — approximately saving-negative dollar-for-dollar under Chetty et al. The political cost Liu flagged is real, but it buys the entire mechanism.

**The anchor population (D1).** The ⅔ calibration is honest reverse-engineering — it is openly chosen to reproduce coverage on a stable administrative basis, and ~3–4 percent reproduction error is tolerable. My new concern is **decennial re-anchor risk**: the all-single-filer median moves with filer composition (retirees, students, filing-threshold changes, the growth of 1099 filers), not just with worker wages, so each re-anchor imports a population-composition shock into the frontier. Recommend a statutory corridor on the re-anchor (e.g., the new anchor may move the C-CPI-U-projected prior anchor by at most ±x percent), which also caps the second-decade cost jump.

**The 80-percent-as-central framing.** Fine for the brief; wrong rung for JCT. JCT's enacted-match score implies effective participation far below this model's conventions (FY2028 $2.1B ≈ 23 percent of the repo's own $9.2B full-participation figure). Foregrounding $19.09B in external scoring invites a headline "JCT scores it at barely half the claimed cost participation" story in one direction or a cost-overrun story in the other. **The conservative $14.15B rung should face JCT as the author's central, with the full ladder disclosed**; 80 percent is a defensible design-intent case for communications.

**Debt financing.** Covered in §2: name a pay-for.

**New concerns beyond the focus list:** (i) the fiscal-year deposit-lag presentation gap (§1, ~11 percent of the window); (ii) the **sawtooth**: the year-ten annual ($24.3B) walks directly into the first re-anchor at year eleven, so the second decade opens with a discrete upward step that naive extrapolation of the published path misses — show the FY2037 re-anchored year in the table.

## 4. Updated verdict

**Support with modifications — unchanged from round one, with materially narrowed conditions.** Two of my three first-round conditions are substantially resolved (indexing fully; scoring gaps mostly). Conditions now:

1. **Name a pay-for, even as an option set.** Debt financing forgoes roughly two-thirds of the achievable national-saving effect and is unenactable on the current debt path; the RAND offset is fine as context, insufficient as an answer.
2. **Publish the ten-year path in fiscal-year convention** (deposit lag, and a phase-in if one is ever specified) alongside the tax-year path, and show the FY2037 re-anchor step.
3. **Complete the self-employed/rail-specific take-up sensitivity before any score-seeking** — the last open scoring gap from my first round.

---

*Re-review addendum; AI persona; sources and computations real.*
