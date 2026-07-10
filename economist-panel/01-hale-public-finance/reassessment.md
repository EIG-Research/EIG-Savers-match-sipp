# Re-Review — Marcus Hale, Public Finance

**Reviewer:** Dr. Marcus Hale (conservative public-finance economist, Chicago price-theory tradition)
**Date:** 2026-06-11
**Prior verdict:** Oppose as designed (round one, `assessment.md`, preserved unchanged)
**Basis:** Current canonical numbers per `_shared/data-guide.md` (44.47M eligible; $14.15B / $19.09B / $23.87B ladder; pivots $32,235 / $48,353 / $64,471). Spot-check computations in `code/02_reassessment_checks.R`, run against `data/processed/universal_sm_hybrid/simulation_results.parquet`.

---

## 1. Disposition check

**CPI-index instead of median-anchoring → Adopted.** I accept the reading. The D1 package — IRS administrative anchor, C-CPI-U indexing, decennial re-anchor — delivers most of what I asked for. The corrected ten-year path (`_shared/anchoring/ten_year_path.md`) shows the indexing switch cutting the ten-year growth premium from roughly 19.5 percent to 13 percent. The decennial re-anchor preserves a slow ratchet, but a ratchet with a ten-year circuit-breaker and a published administrative base is a different fiscal animal from continuous wage-indexing-in-disguise. This was my first-order structural objection and it is substantially resolved.

**Decouple access from the rate increase → Declined.** The reading is accurate; I contest the rationale below.

**Model §6433(d)(2) before any rate above 100 percent → Superseded.** I accept "superseded" as a description of what happened: D6 replaces the three-year recapture with the RSAA six-month match-forfeiture, so there is no longer a (d)(2) to model. But supersession is not resolution — the substitution makes the underlying concern *worse*, not moot. See §3.

## 2. The decline: the 200 percent floor

The stated rationale is that the simulation assumes match-invariant participation, so its "no new savers" result cannot adjudicate the floor, and that a built-in evaluation (S2) is the honest resolution. Half of that answers me; half does not.

The half that lands: my round-one decomposition was indeed run through a model that mechanically cannot credit the floor with a participation response. Fair. I concede that the model's internal result is not evidence against the floor.

The half that does not land: **my objection was never primarily the model's**. It rests on the external evidence — Chetty et al. (2014, *QJE*): roughly one cent of net new saving per subsidy dollar on the price margin; Duflo et al. (2006, *QJE*): a 50 percent match moved take-up from 3 to 14 percent at the point of filing. When the model is silent, the burden of proof falls on the best outside evidence, and that evidence says match-rate elasticities are small and defaults do the work. D3 inverts the burden: it treats the model's silence as a license to launch the most expensive parameter in the design and evaluate afterward. That is backwards. You do not buy the $12 billion option first and run the experiment second.

And the dollars at stake are unchanged by the re-anchoring. Rerunning my round-one decomposition on the current base: of the $14.68 billion full-participation increment over the $9.19 billion current-law baseline, **$12.07 billion (82.3 percent) is a rate increase for the 33.08 million workers already eligible under current law**, and only $2.60 billion (17.7 percent) buys the 11.39 million newly eligible frontier workers — a slightly *worse* split than the 79.8 percent I reported in round one, because the lower IRS-anchored pivots shaved the frontier (12.98M → 11.39M) while leaving the infra-frontier rate increase intact. Each incremental eligible worker now costs $1,289 against current law's $278 average. Inframarginality is likewise intact: 8.98 million eligibles (20.2 percent) already participate in a DC plan and collect $4.71 billion of the ceiling; another 6.25 million hold idle DC accounts and collect $3.15 billion — one-third of ceiling dollars still land on workers who already own the account infrastructure, and the participating slice remains the richest (mean MAGI $45,453 versus $34,357 for those with no account).

**The objection stands.** But I will say precisely what would dissolve it, because the S2 instinct is correct: launch the floor at 50–100 percent, legislate randomized match-generosity arms (50/100/200 — Mwangi's structure), and make escalation to 200 percent *statutorily contingent* on the evaluation finding a participation or persistence response. Evaluation-gated escalation is good policy; evaluation-after-purchase is a $12-billion-a-year bet against the Danish evidence.

## 3. Fresh eyes

**(a) The D6 six-month hold opens a cycling margin §6433(d)(2) was built to close.** This is my principal new concern. Under D6, own contributions are Roth-liquid and the match forfeits only if the matched contribution is withdrawn within six months. So a worker with any liquid savings can contribute $500 in January, harvest the $1,000 federal deposit, withdraw the $500 in July, and repeat annually — zero net new saving, maximum match, every year. The match dollars stay retirement-locked, so this is not cash arbitrage; it is Chetty-style reshuffling at its purest, converting the program into a $1,000 annual deposit for anyone holding six months of $500 float. The three-year testing period was a crude but real friction against exactly this; six months at a 2:1 rate is a thin gate. On the open Tier 2.3 parameter: the *cost* correction from forfeiture is trivial — bound the share of matched contributions withdrawn inside six months at 5–10 percent (early-horizon leakage in Argento/Bryant/Sabelhaus-style evidence is far below long-run leakage), implying a cost overstatement under 2 percent. Do not spend modeling effort there. The first-order fix is design, not estimation: lengthen the hold to 12 months, or key the match to *net* annual contributions.

**(b) Anchor population (focus Q3).** The ⅔-of-median rule is presented as legislator-legible, but be honest about its genealogy: ⅔ was reverse-engineered to reproduce the old SIPP-based coverage within 3–4 percent. The filer-vs-worker gap it papers over (~$40.3k filer median vs. ~$54.8k worker median) is composition, and that composition drifts — as the retiree and part-year-filer share of single filers grows, the decennial re-anchor imports demographic noise unrelated to worker earnings. Cleaner: anchor to the IRS median AGI of **single filers with positive wage or self-employment income**, which SOI can tabulate, and recalibrate the fraction once. If that is unavailable, keep ⅔ but disclose the drift exposure and the predictable re-anchor-year coverage step, which legislators will be lobbied to pull forward.

**(c) The 80 percent central framing (focus Q4).** Not defensible as stated. The auto-enrollment stickiness evidence (85–90 percent participation) comes from *employer 401(k)* settings; 58.4 percent of eligibles here route to the federal account, including ~4.4 million self-employed with no payroll at all. State auto-IRA programs — the closest analog for the W-2 federal-account branch — run nearer 65–70 percent after opt-outs, and the H&R Block result is the relevant prior for the self-employed rails (generously, 25 percent). A rail-weighted blend (85 percent employer-plan, 70 percent W-2 federal account, 25 percent self-employed, on the 41.6/48.5/9.9 routing weights) gives roughly 72 percent — about **$17.1 billion**, not $19.09 billion. My advice on Tier 2.1: publish rail-specific rungs at those values, make the blend the central case, and keep $14.15B as the conservative anchor. Foregrounding the top-of-evidence rung as "central" is precision theater on the most uncertain parameter in the exercise.

**(d) The federal account (focus Q2).** I am more sympathetic here than my priors suggest. The access architecture is the one instrument the evidence supports, worker-level portability is a genuine answer to vesting/churn erosion, and the EO-marketplace alternative fixes deposit destination but cannot do auto-enrollment. I accept D2 — *conditional* on the employer crowd-out scenario (Tier 2.7) being run before any score is published. Advise a small-employer plan-drop band of 5/10/15 percent over a decade; Morningstar's RSAA modeling shows the displacement margin is real for younger cohorts.

**(e) Debt financing (focus Q5).** The RAND offset is not an answer; it is a hope with a 30-to-45-year maturity, entirely outside any budget window, and it evaporates if Congress excludes account balances from SSI/Medicaid asset tests — which it will be lobbied to do, since counting them penalizes the very savers the program creates. Meanwhile the national-saving arithmetic is unforgiving: a debt-financed $216 billion ten-year commitment (the 80 percent rung) reduces public saving dollar-for-dollar against roughly a penny of private-saving gain per rate-margin dollar. Only the default channel plausibly raises net national saving. Minimum condition: pay for the access component (~$9–10 billion at the current-law-parameter counterfactual) inside the retirement tax-expenditure envelope, and state the asset-test treatment explicitly.

**(f) Remaining Tier 2 advice.** Persistence (2.2): keep the state auto-IRA 0.59 as the central anchor; a match-salience uplift is speculation, cap it at 0.70 in sensitivity. Ten-year path (2.4): the 2.7 percent C-CPI-U-plus-workforce assumption is defensible; flag the re-anchor step if the window straddles year ten. The phaseout slope on the new pivots is marginally steeper (4.65pp of match rate per $1,000 of Single MAGI vs. 4.56 before), but D7's prior-year basis converts it from a contemporaneous wedge to a lagged one — I accept that reframing.

## 4. Updated verdict

**Oppose as designed — unchanged in label, materially narrowed in substance.** Round one I opposed a wage-indexed, unscored, rate-dominated expansion. The indexing fix (D1) and the prior-year basis (D7) remove two of my structural objections, and I now affirmatively support the federal-account architecture (D2). What remains is the same core defect, slightly aggravated: 82 percent of the incremental dollar is still a rate increase the best evidence says buys a penny of saving, now paired with a six-month hold that invites annual contribute-withdraw cycling at a 2:1 rate. I would move to **support with modifications** on three conditions:

1. **Launch the floor at 50–100 percent with statutorily evaluation-gated escalation** to 200 percent via the S2 randomized arms (50/100/200). The $12.07 billion rate component should be bought on evidence, not on the model's silence.
2. **Close the cycling margin**: extend the match hold to 12 months or key the match to net annual contributions.
3. **Pay for at least the access component** inside the retirement tax-expenditure envelope, and specify the SSI/Medicaid asset-test treatment before citing the RAND offset.

---

**Files produced for this re-review:** `code/02_reassessment_checks.R` (decomposition rerun on the current base; output reproduced in §2–3 above).

*Re-review addendum; AI persona; sources and computations real.*
