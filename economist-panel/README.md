# Economist Panel Review — Universal Account, Targeted Saver's Match Hybrid

**Date convened:** 2026-06-10
**Charge:** Ten distinct economists and policy analysts, spanning the political and methodological spectrum, independently evaluate the *Universal Account, Targeted Saver's Match* hybrid proposal (`Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md`) in the context of:

1. The political economy of the enacted Saver's Match (SECURE 2.0 §103 / IRC §6433, effective TY2027).
2. The Trump White House executive order targeting the retirement access gap and the TrumpIRA.gov initiative.
3. The proposed Retirement Savings for Americans Act (RSAA).

Each panelist works in their own subfolder, writes and runs their own code against the repository's model outputs, builds figures and tables, downloads the sources they rely on, and writes a brief assessment that lands on a clear verdict: **support / support with modifications / oppose**, from their own intellectual vantage point.

## Panel roster

| # | Folder | Panelist | Orientation and field |
|---|--------|----------|----------------------|
| 1 | `01-hale-public-finance/` | Dr. Marcus Hale | Conservative public-finance economist (Chicago price-theory tradition). Fiscal cost, crowd-out of private saving, inframarginal windfalls. |
| 2 | `02-vasquez-cole-labor/` | Dr. Renata Vásquez-Cole | Progressive labor economist. Coverage gaps, racial and gender wealth disparities, gig and part-time workers. |
| 3 | `03-lindqvist-behavioral/` | Dr. Owen Lindqvist | Behavioral economist (defaults and choice-architecture tradition of Madrian–Shea, Thaler–Benartzi). Take-up assumptions, auto-enrollment design. |
| 4 | `04-raghunathan-optimal-tax/` | Dr. Priya Raghunathan | Public economics / optimal tax theorist. Phaseout geometry, effective marginal tax rates, marriage treatment, benefit-cliff interactions. |
| 5 | `05-calloway-libertarian/` | Dr. Jack Calloway | Libertarian free-market economist (Cato tradition). Skeptic of federal account architecture, mandate costs, political risk of government asset management. |
| 6 | `06-brandt-retirement-institutions/` | Dr. Eleanor Brandt | Centrist retirement-policy institutionalist (ERISA, plan design, recordkeeping). Implementation feasibility, employer responses, state auto-IRA interactions. |
| 7 | `07-okafor-macro-fiscal/` | Dr. Sam Okafor | Macro-fiscal economist. National saving, budget-window scoring, tax-expenditure comparisons, debt-trajectory context. |
| 8 | `08-liu-political-economy/` | Dr. Grace Liu | Political economist / public choice. Coalition durability, why the Saver's Match passed and the RSAA stalled, what the executive order changes. |
| 9 | `09-bridger-state-programs/` | Dr. Tom Bridger | State auto-IRA empiricist (CalSavers / OregonSaves evaluation tradition). Observed opt-out, contribution persistence, lessons for a federal account. |
| 10 | `10-mwangi-program-evaluation/` | Dr. Aisha Mwangi | Empirical microeconomist / program evaluation (RCT tradition). Evidence on matches vs. defaults, Saver's Credit take-up failure, administrative frictions. |

## Folder conventions

Each panelist subfolder contains:

```
NN-name-field/
  assessment.md      # the panelist's written brief, with verdict and citations
  code/              # runnable R scripts (Rscript, run from repo root)
  figures/           # PNG figures produced by the code
  tables/            # CSV/markdown tables produced by the code
  sources/           # downloaded primary/secondary sources (PDF/HTML) + sources.md manifest
```

Shared inputs live in `_shared/`:

- `_shared/policy-context.md` — common factual brief on the three policy contexts (so panelists disagree about interpretation, not facts).
- `_shared/data-guide.md` — data dictionary for the repository model outputs and how to run R.
- `_shared/sources/` — primary sources common to all panelists (statute, EO, bill text).

A cross-panel synthesis is in `PANEL-SYNTHESIS.md`.

## Ground rules given to all panelists

1. Engage with the actual model outputs in this repository — do not invent numbers. Recompute and visualize from the row-level parquet files where possible.
2. Cite sources; download what you rely on into `sources/` with a `sources.md` manifest (title, author, year, URL, access date).
3. The assessment must take a position. Hedged neutrality is not a verdict.
4. Panelists write only inside their own subfolder. Repository pipeline code and outputs are read-only.
5. Disagreement among panelists is expected and is the point of the exercise.
