# Re-Review Plan — Hybrid Format

**Date:** 2026-06-11
**Status:** Ready to launch on the author's go. Not yet launched.
**Format (decided):** **Hybrid** — a targeted pass anchored to each panelist's first-round recommendations and their dispositions, *plus* a fresh-eyes license to raise anything new regardless of the prior round.

## Roster
The same ten personas (`economist-panel/01-…` through `10-…`), each re-reviewing within their own subfolder.

## Inputs each panelist reads (in order)
1. `economist-panel/RE-REVIEW-CHANGELOG.md` — what changed, the recommendation→disposition mapping, the open methodological questions, the focus questions.
2. `economist-panel/_shared/data-guide.md` — the **CURRENT DESIGN** block (authoritative numbers).
3. `Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md` — the updated proposal.
4. Their own first-round `NN-*/assessment.md` (the prior round; **do not edit it**).
5. As needed: the companion brief, `DESIGN-DECISIONS.md`, `_shared/anchoring/` (incl. `ten_year_path.md`), and the regenerated outputs/figures.

## Output convention
Each panelist writes a **new** file `NN-name-field/reassessment.md` (the first-round `assessment.md` is preserved unchanged as the historical record). Optional supporting code goes in their existing `code/`; they may spot-check numbers against the regenerated parquet but need not re-run the full pipeline.

## Per-persona prompt template
> You are [persona], who reviewed this proposal in the first round (your assessment is in `NN-*/assessment.md`). The design has since changed materially — read `economist-panel/RE-REVIEW-CHANGELOG.md` first, then the CURRENT DESIGN block in `_shared/data-guide.md` and the updated spec. Write `NN-*/reassessment.md` (do NOT edit your original assessment) covering, in this order:
>
> 1. **Disposition check.** The changelog records how each of your first-round recommendations was dispositioned (adopted / partial / deferred / declined / open). For each, state whether you accept that reading.
> 2. **Declines.** Where a recommendation of yours was *declined* (with a stated rationale), say whether the rationale answers your objection or whether the objection stands — and why. Be specific; this is where your continued dissent (or assent) matters most.
> 3. **Fresh eyes.** Independently of your prior round, raise any *new* concern the current design introduces — including on the five focus questions in the changelog (the 200% floor and its evaluation, the federal account vs. marketplace, the IRS-filer-vs-worker anchor population, the 80%-as-central framing, and debt financing). Treat the open Tier-2 items as known methodological questions to *advise on*, not to re-flag as oversights.
> 4. **Updated verdict.** State your current verdict (support / support with modifications / oppose) and whether it moved from the first round, with your top one-to-three conditions.
>
> Ground every quantitative claim in the CURRENT numbers; do not cite the superseded figures except to note a change. Keep it to ~800–1,500 words. Footer: "*Re-review addendum; AI persona; sources and computations real.*"

## Launch mechanics
- Run in foreground waves of ≤5 (background subagents are auto-denied shell here; see `MEMORY.md`).
- After all ten return, update `PANEL-SYNTHESIS.md` with a new "Re-review" section: the updated scoreboard, which declines were conceded vs. held, and any new convergent findings.

## Not yet done (the author's remaining pre-launch calls)
- Optional git commit of the current state as the re-review baseline (Strongly-recommended/Your-call item #8).
