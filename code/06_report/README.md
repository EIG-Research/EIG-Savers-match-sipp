# code/06_report/

The only stage that produces an external-audience deliverable: a roughly two-page, policy-maker-ready
HTML brief on the Universal Saver's Match hybrid proposal.

## `06_universal_hybrid_brief.R`

A thin render driver. Resolves the project root, confirms `rmarkdown` and `pandoc` are available,
checks that the upstream universal-hybrid artifacts exist, then knits `universal_hybrid_brief.Rmd` to
`output/reports/universal_sm_hybrid/universal_hybrid_brief.html`. If `pandoc` is unavailable the stage
warns and skips rather than failing the pipeline; if a required upstream artifact is missing it stops
with an actionable message. Invoked from `run_all.R` via the `RUN_06_UNIVERSAL_HYBRID_BRIEF` flag, after
stage 04.

## `universal_hybrid_brief.Rmd`

The brief itself. It reads the **live** universal-hybrid outputs at knit time — the scenario results,
pivot/eligibility-band table, per-worker simulation, universe funnel, the three schedule/incidence
figures, and the current-law baseline table — so every number in the document tracks the most recent
pipeline run and cannot drift from the model.

The brief is written for a reader with no access to, or knowledge of, this repository: it names no
files, code, variables, or statutes, embeds its figures (self-contained HTML), and frames the design,
reach, generosity, cost, and method in plain language. It covers the data and sample, the policy design
and eligibility band, who the policy reaches, how generous it is, the cost range across participation
assumptions, a current-law contrast, and the modeling assumptions and caveats that should travel with
the numbers.
