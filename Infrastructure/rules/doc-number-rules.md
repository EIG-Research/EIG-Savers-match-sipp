# Document Number Verification Rules

These are binding rules for the `data-consistency-reviewer` sub-agent. Follow them exactly.

---

## Scope

**Verify every numerical claim.** Every number in the written document that derives from the analysis must be traced to its source in the code or data and checked for correctness.

A numerical claim is any number that:

- Reports a result from the analysis (coefficient, test statistic, p-value, R²)
- Describes the data or sample (observation count, mean, percentage, date range)
- Appears in a table or figure produced by the code
- Is derived from other analysis numbers (percentage changes, ratios, differences)

**Do NOT verify:**

- Structural references (Section 3, Table 2, Column (4), Equation 1)
- Citation years (Angrist & Pischke (2009))
- General knowledge not from the analysis ("the US has 50 states", "minimum wage was $7.25 in 2009")
- Page numbers, line numbers, footnote markers
- Version or specification labels ("Model 1", "Specification A")

**When in doubt:** extract and trace the number. It is better to verify a number that turns out to be general knowledge than to skip a number that turns out to be wrong.

---

## Document Format Support

The agent reviews documents in these formats:

| Format | Extension(s) | Notes |
|--------|-------------|-------|
| LaTeX | `.tex` | Follow `\input{}` and `\include{}` directives. Parse number macros (`\num{}`, `\SI{}`). |
| Markdown | `.md` | Standard markdown prose. |
| Quarto | `.qmd` | Extract prose sections. Treat code chunks as source code. Check inline expressions. |
| R Markdown | `.Rmd` | Extract prose sections. Treat code chunks as source code. Check inline R expressions (`` `r ...` ``). |
| HTML | `.html` | Parse through tags to extract text content. |
| PDF | `.pdf` | Read directly. |

For `.Rmd` and `.qmd`, inline code expressions (e.g., `` `r nrow(data)` ``) are numbers generated from code — trace them like any other number.

---

## Number Extraction Rules

### Mandatory extraction (always check)

1. **Point estimates and coefficients** — regression coefficients, treatment effects, marginal effects, elasticities. These are the most important numbers in any paper.
2. **Standard errors, CIs, and p-values** — parenthetical SEs, confidence interval bounds, p-values, significance stars.
3. **Sample sizes** — total N, subgroup N, panel dimensions (number of units, number of periods).
4. **Summary statistics** — means, medians, SDs, percentiles, min/max values.
5. **Counts and frequencies** — unique entity counts, category sizes, frequency distributions.
6. **Percentages and shares** — sample composition, treatment/control shares, rate variables.
7. **Year ranges and time periods** — start/end dates, number of time periods, event windows.
8. **Test statistics** — F-statistics, chi-squared, t-statistics, Wald tests, Hausman tests.
9. **Model fit** — R², adjusted R², AIC, BIC, log-likelihood.
10. **Table and figure values** — every cell in a results table, every labeled value in a figure.

### Extract but classify as borderline

- Round approximations ("approximately 40,000", "roughly half")
- Numbers from prior literature cited for comparison
- Numbers appearing only in appendices or online supplements

---

## Source Tracing Requirements

Every extracted number must be traced through a three-level search:

**Level 1 — Direct code output.** Search for the number in print/display/export statements and in generated output files (`.csv`, `.tex`, `.log`, `.html`, `.rtf` tables). If found, record the exact code location.

**Level 2 — Computed values.** Search for the computation that produces the number: variable assignments, summary statistics calls, regression output objects, aggregation operations. If found, record the computation.

**Level 3 — Raw data.** If the number might come from the data directly (e.g., a row count or date range), create a temporary verification script in `./temp/` to compute the value from the data. Never modify files in the target directory.

If the number cannot be traced after all three levels, classify it as **unverifiable** (MEDIUM severity).

---

## Verification Criteria

A number is **verified** if the value in the document matches the value produced by the code, accounting for:

- **Formatting differences** — "40,321" vs "40321" vs "40.3 thousand" (same number, different format)
- **Acceptable rounding** — text says "4.2%" and code produces 0.04217 (rounds correctly to one decimal)
- **Unit conversions** — 0.042 in code reported as "4.2%" in text (proportion → percentage)

A number is a **mismatch** if:

- The value is wrong beyond rounding (text says "4.2%" but code produces 3.89%)
- The sign is wrong (text says "increased" but coefficient is negative)
- The units are inconsistent (text says "4.2 percentage points" but value is 4.2 log points)
- A significance claim is wrong (text says "significant at 5%" but p = 0.07)
- A derived number's arithmetic is incorrect (text says "12% increase" but (11400-10200)/10200 = 11.8%)
- The number in the text contradicts the same number in a table, or vice versa

---

## Severity Assignment

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | A key result number (main coefficient, headline finding, abstract statistic) is definitively wrong. This would directly mislead the reader about the paper's conclusions. |
| **HIGH** | A non-headline number is definitively wrong (intermediate count, control variable statistic, secondary outcome). Or: a table-text inconsistency where the same number differs between prose and tables. |
| **MEDIUM** | Number cannot be traced to any code or output (unverifiable). Or: minor discrepancy attributable to ambiguous rounding or unit labeling. |
| **LOW** | Number is approximately correct but not exact (text uses a round number for a precise value). Or: source is ambiguous but value is plausible. |
| **INFO** | Number needs author clarification — multiple possible sources in the code, unclear which computation produced it. |

**Never inflate severity.** A rounding difference is MEDIUM at most. An unverifiable number from an appendix is MEDIUM, not HIGH.

---

## Internal Consistency Rules

Beyond verifying numbers against code, check for internal consistency within the document:

1. **Table-text agreement** — every number cited in the prose from a table must exactly match the corresponding table cell. If the text says "Column 3 shows a coefficient of 0.034" and the table shows 0.037, flag as HIGH regardless of which is correct.

2. **Cross-table consistency** — sample sizes that should be identical across tables must match. Outcome variable means in a summary statistics table should be consistent with regression table sample descriptors.

3. **Derived number consistency** — if the text computes a value from other numbers ("an increase from 10,200 to 11,400, or 12%"), verify the arithmetic internally.

4. **Abstract-body agreement** — numbers in the abstract must match the corresponding numbers in the body text and tables.

---

## Number Inventory Table Rules

The report must include a **Number Inventory Table** listing every extracted number. Each row contains:

| Column | Content |
|--------|---------|
| # | Sequential row number |
| Claimed Value | The number as it appears in the document |
| Document Location | File, section/page, and brief context |
| Code Source | File and line where the number is computed, or "Not found" |
| Verified Value | The value the code actually produces, or "—" |
| Status | Verified / Mismatch / Unverifiable / Approximate |

Status definitions:
- **Verified**: Number matches code output (exact or acceptable rounding)
- **Mismatch**: Number does not match code output
- **Unverifiable**: Number cannot be traced to any code
- **Approximate**: Number is a stated approximation that is directionally correct

Numbers with Mismatch status must have a corresponding finding card. Numbers with Unverifiable status should have a finding if they are important enough (key results, sample sizes).

---

## Output Format Rules

1. **File**: Write to `{TARGET_DIR}/review-reports/doc-number-report.html`. Create the `review-reports/` directory if it does not exist.
2. **Template**: Use `Infrastructure/templates/doc-number-report.md` as the HTML structure. Replace all `{{PLACEHOLDER}}` tokens.
3. **Sort order**: Findings must be sorted CRITICAL → HIGH → MEDIUM → LOW → INFO.
4. **Finding IDs**: Sequential, starting at DN-001. No gaps, no duplicates.
5. **HTML escaping**: All code snippets, file paths, and document excerpts must be HTML-escaped.
6. **Code blocks**: Use `<pre><code>` tags for code snippets.
7. **Document excerpts**: Quote the relevant sentence from the document with the number highlighted or bolded.
8. **Self-contained**: The HTML file must have no external dependencies.
9. **Number Inventory Table**: Must appear before individual findings. Every extracted number gets a row.
10. **Accuracy over speculation**: If you cannot determine whether a number is correct, classify it as MEDIUM (unverifiable) rather than guessing.
