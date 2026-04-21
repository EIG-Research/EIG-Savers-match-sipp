# Document Consistency Rules

These are binding rules for the `conceptual-consistency-reviewer` sub-agent. Follow them exactly.

---

## Scope

**Err on the side of flagging.** Every empirical claim in the written document should be cross-referenced against the code. If a claim does not clearly correspond to what the code does, flag it. The author can dismiss the finding if justified — the cost of a false positive is low (30 seconds to confirm), while the cost of a false negative is high (published paper with an incorrect description of the analysis).

An empirical claim is any statement in the document that:

- Describes the sample (who is included, what is excluded, time period, geography)
- Describes a variable (how it is measured, constructed, or transformed)
- Describes the methodology (estimation method, fixed effects, clustering, weights)
- Describes a data source (name, vintage, frequency)
- Interprets a result (direction, magnitude, significance)
- Claims a robustness check was performed
- Describes what a table or figure contains

**Do NOT flag:**

- Pure theory or literature review passages with no empirical claims
- Opinions or policy recommendations not tied to specific analysis
- Claims about external facts verifiable from public sources (e.g., "the ACA was enacted in 2010")
- Writing style, grammar, or presentation quality

**Consistency goes both directions.** Flag both:
- Claims in the text that the code does not support
- Things the code does that the text does not mention (undisclosed restrictions, transformations, or choices)

---

## Document Format Support

The agent reviews documents in these formats:

| Format | Extension(s) | Notes |
|--------|-------------|-------|
| LaTeX | `.tex` | Follow `\input{}` and `\include{}` directives. Check table notes and figure captions. |
| Markdown | `.md` | Standard markdown prose. |
| Quarto | `.qmd` | Extract prose sections. Treat code chunks as source code for cross-referencing. |
| R Markdown | `.Rmd` | Extract prose sections. Treat code chunks as source code for cross-referencing. |
| HTML | `.html` | Parse through tags to extract text content. |
| PDF | `.pdf` | Read directly. |

For every document, check all sections including: abstract, introduction, data section, methodology section, results, robustness, conclusion, footnotes, appendices, table notes, and figure captions.

---

## Claim Categories

### Sample Definition (CC-SD)

Flag any mismatch between the sample described in text and the sample constructed in code:

1. **Age, income, or threshold restrictions** — watch for off-by-one errors ("20 or older" vs. `> 20` vs. `>= 20`)
2. **Geographic scope** — state/country lists, "contiguous US" definitions, DC inclusion
3. **Time period** — start/end years, fiscal vs. calendar year, inclusive vs. exclusive bounds
4. **Industry or sector** — SIC/NAICS codes, sector definitions
5. **Inclusion/exclusion criteria** — every stated criterion must have code; every code filter should have a text description
6. **Unit of observation** — "firm-year" vs. "individual-level" vs. aggregated
7. **Sample size and panel structure** — "balanced panel" must be actually balanced

### Variable Construction (CC-VC)

Flag any mismatch between variable descriptions and code:

1. **Outcome variable** — log vs. level, weekly vs. annual, nominal vs. real, per-capita vs. total
2. **Treatment variable** — timing, definition, binary vs. continuous
3. **Control variable list** — every control mentioned must be in the regression, and vice versa
4. **Fixed effects** — entity type, time granularity, interactions
5. **Transformations** — winsorizing, log, standardization, scaling
6. **Composite indices** — components, weights, aggregation

### Methodology (CC-ME)

Flag any mismatch between methodological descriptions and code:

1. **Estimation method** — OLS vs. IV vs. probit vs. matching, etc.
2. **Identification strategy** — DiD, RD, IV; does the code implement what the text claims?
3. **Standard error specification** — cluster level, robust, bootstrap
4. **Bandwidth or tuning parameters** — hard-coded vs. optimal selection
5. **Weights** — weighted vs. unweighted, which weight variable
6. **Bootstrap/simulation parameters** — number of replications, seed

### Data Sources (CC-DS)

Flag any mismatch between data source descriptions and code:

1. **Named data sources** — does the code load the claimed dataset?
2. **Data vintage/version** — correct year, wave, or release
3. **Merge descriptions** — correct merge keys and sources
4. **Data frequency** — monthly vs. quarterly vs. annual

### Results and Interpretation (CC-RI)

Flag any mismatch between stated results and code output:

1. **Direction of effect** — "positive" must match a positive coefficient
2. **Significance claims** — "significant at 5%" must match p < 0.05
3. **Magnitude interpretation** — correct unit interpretation for the specification type
4. **Subsample claims** — "larger for women" must match the code
5. **Heterogeneity claims** — must have supporting code

### Robustness (CC-RB)

Flag any robustness claim without supporting code:

1. **Claimed robustness checks** — every described check must exist in code. **Flag missing code as HIGH.**
2. **Placebo tests** — claimed tests must have code and consistent results
3. **Alternative specifications** — claimed alternatives must exist

### Tables and Figures (CC-TF)

Flag any mismatch between table/figure descriptions and code:

1. **Column descriptions** — what each column represents
2. **Figure content** — what is plotted
3. **Table note specifications** — FE, SE, sample claimed in notes
4. **Sample described in table notes** — restrictions stated in notes

### Omissions (CC-OM)

Flag things the code does that the text does not mention:

1. **Undisclosed sample restrictions** — code filters not described in text
2. **Undisclosed transformations** — code transforms not described in text
3. **Undisclosed methodological choices** — clustering, weights, FE not described
4. **Unreported analyses** — regression specifications with no corresponding text discussion

---

## Severity Assignment

| Severity | Criteria | Examples |
|----------|----------|---------|
| **HIGH** | Direct contradiction — the text says one thing, the code does another | Text says "ages 25–64" but code filters `age >= 20 & age <= 65`; text says "clustered at state" but code clusters at county; text claims a robustness check that has no code |
| **MEDIUM** | Claim not clearly supported — omission, ambiguity, or incomplete description that could mislead | Text says "we control for demographics" without specifying which; code applies a filter not mentioned in text; text describes "OLS" but code uses WLS |
| **LOW** | Minor inconsistency — imprecise language unlikely to mislead a careful reader | Text says "about 15,000 observations" when N = 15,234; text says "annual" data that is technically fiscal-year |

**When in doubt between two levels, choose the higher one.** The author can always downgrade.

---

## Cross-Reference Protocol

For each claim extracted from the document:

1. **Locate the relevant code** — search for variable names, function calls, or operations that correspond to the claim
2. **Read the full context** — understand the complete code block, not just a single line
3. **Compare claim to code** — assess whether the claim accurately describes what the code does
4. **Check all specifications** — a claim about "our regression" should be true for all reported regressions
5. **Record the assessment**:
   - **Consistent**: claim accurately describes the code → no finding
   - **Inconsistent**: claim contradicts the code → finding with appropriate severity
   - **Unsupported**: no corresponding code found → finding (HIGH for results/robustness, MEDIUM for methodology)
   - **Ambiguous**: claim is vague enough that consistency cannot be determined → finding at MEDIUM or LOW

---

## Output Format Rules

1. **File**: Write to `{TARGET_DIR}/review-reports/doc-consistency-report.html`. Create the `review-reports/` directory if it does not exist.
2. **Template**: Use `.codex/templates/doc-consistency-report.md` as the HTML structure. Replace all `{{PLACEHOLDER}}` tokens.
3. **Severities**: Use only HIGH, MEDIUM, LOW. No CRITICAL, no INFO.
4. **Group order**: HIGH findings first, then MEDIUM, then LOW.
5. **Within-group sub-grouping**: Within each severity level, group findings by category: Sample Definition → Variable Construction → Methodology → Data Sources → Results & Interpretation → Robustness → Tables & Figures → Omissions.
6. **Finding IDs**: Sequential, starting at CC-001. No gaps, no duplicates.
7. **HTML escaping**: All code snippets, file paths, and document excerpts must be HTML-escaped.
8. **Document excerpts**: Quote the exact text from the document that makes the claim. Use block quotes or highlighted text.
9. **Code snippets**: Show the relevant code that contradicts or fails to support the claim.
10. **"Why This Is Inconsistent"**: Explain what the document says vs. what the code does. Be specific.
11. **"What to Check"**: Provide concrete, actionable items using `→` arrows.
12. **Self-contained**: The HTML file must have no external dependencies.
13. **Err on side of flagging**: When uncertain, include the finding at MEDIUM or LOW rather than omitting it.
