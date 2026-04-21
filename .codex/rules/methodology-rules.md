# Methodology Review Rules

These are binding rules for the `methodology-reviewer` sub-agent. Follow them exactly.

---

## Scope

**Err on the side of flagging.** Unlike the code review, this report should surface concerns even when the author may have a valid justification. The goal is to prompt the author to confirm their choices are deliberate, not to accuse them of errors.

A methodology concern is any aspect of the empirical design that:

- Threatens the validity of the causal identification strategy
- Could materially affect the magnitude or sign of the estimates
- Represents a common robustness check that is absent from the code
- Involves assumptions that are untestable but should be disclosed

**Do NOT flag:**

- Issues that are definitively a code bug (those belong in code-error-report.html)
- Matters of pure writing or presentation (no data implications)
- Extremely speculative concerns with no plausible causal pathway
- Issues the author has explicitly addressed in visible comments

---

## Research Design Inference

The agent must infer the identification strategy from the code, variable names, and comments. Use these heuristics:

| Signal | Inferred Design |
|--------|----------------|
| Variables named `post`, `treat`, `treated`, `did`, interaction terms | Difference-in-Differences |
| `running`, `forcing`, `bandwidth`, `rd_plot`, `rddensity`, `rdrobust` | Regression Discontinuity |
| Variables named `iv`, `instrument`, `first_stage`, `tsls`, `ivreg` | Instrumental Variables |
| `pscore`, `propensity`, `MatchIt`, `teffects`, `psmatch2` | Matching / Propensity Score |
| `fe`, `feols`, `felm`, `xtreg`, entity/time fixed effects without DiD | Panel Fixed Effects |

If the design cannot be inferred, flag this explicitly as a concern under "Sample & Data" (the reviewer cannot assess identification threats without knowing the design).

---

## DiD-Specific Rules

Always check when DiD is detected:

1. **Parallel trends** — Is there an event study / pre-trend test in the code? If not, flag as HIGH.
2. **Staggered treatment timing** — If treatment varies across units AND time (not a single sharp cutoff), flag any use of standard two-way fixed effects (`feols(y ~ treat | unit + time)`) without a modern staggered DiD estimator (Callaway & Sant'Anna, de Chaisemartin & D'Haultfœuille, Sun & Abraham, Roth et al.). Flag as HIGH.
3. **Anticipation effects** — If treatment assignment was publicly known before it took effect, check whether pre-treatment periods close to treatment are excluded or handled. Flag if absent.
4. **Contamination / spillovers** — If treated and control units could interact (geographic proximity, supply chains, social networks), flag the absence of any discussion. Flag as MEDIUM.

---

## Regression Discontinuity Rules

Always check when RD is detected:

1. **Continuity of the running variable** — Is a density/manipulation test (`rddensity`, `DCdensity`) present? If not, flag as HIGH.
2. **Bandwidth selection** — Is bandwidth chosen optimally (e.g., `rdbwselect`) or hard-coded? Hard-coded bandwidths without sensitivity checks = MEDIUM.
3. **Polynomial degree** — Polynomials of degree > 1 are generally discouraged (Gelman & Imbens 2019). Flag use of degree ≥ 2 without justification as MEDIUM.
4. **Covariate balance at threshold** — Are baseline covariates checked for discontinuities at the cutoff? If not, flag as MEDIUM.
5. **Donut hole** — If the running variable is measured with error near the threshold, is a donut hole specification used or tested? Flag absence as LOW.

---

## Instrumental Variables Rules

Always check when IV is detected:

1. **First-stage F-statistic** — Is the first-stage F reported? F < 10 (or Kleibergen-Paap F < 10 for robust) is the conventional weak instruments threshold. Flag absence of first-stage reporting as HIGH; flag weak instruments if F is visible and low.
2. **Exclusion restriction** — Is there any discussion (in comments or variable naming) of why the instrument affects the outcome only through the treatment? If not, flag as HIGH.
3. **LATE interpretation** — IV estimates the Local Average Treatment Effect for compliers. Flag if the code or comments imply IV estimates ATE for the full population without qualification. MEDIUM.
4. **Many weak instruments** — If more than one instrument is used, flag the absence of LIML or other many-weak-instrument robust methods. LOW.

---

## Matching / Propensity Score Rules

Always check when matching is detected:

1. **Common support** — Is overlap/common support checked and enforced? Flag absence as HIGH.
2. **Covariate balance** — Are post-matching balance statistics reported (`love.plot`, `bal.tab`, standardized differences)? Flag absence as HIGH.
3. **Estimand clarity** — Is the target estimand (ATT, ATE, ATU) explicitly specified? Propensity score matching estimates ATT by default; flag if the interpretation implies ATE. MEDIUM.
4. **Caliper or nearest-neighbor choice** — Are matching parameters (caliper width, k nearest neighbors) justified or sensitivity-tested? Flag if hard-coded without discussion. LOW.

---

## Regression Specification Rules

Check for these in all regression-heavy files:

1. **Omitted variable bias (OVB)** — Are key confounders controlled for? Infer from the context; flag if obvious confounders (e.g., industry, firm size in labor econ) are absent. MEDIUM.
2. **Bad controls** — Are any outcome-mediating variables included as controls (post-treatment variables controlled for in DiD; outcome proxies in IV)? Flag as HIGH if detected.
3. **Functional form** — Is the relationship assumed linear when non-linearity is plausible (e.g., log transformation of income, wages)? Flag if outcome is strictly positive and untransformed. LOW.
4. **Multicollinearity** — Flag if VIF is not checked when many correlated controls are included, or if a correlation matrix of regressors is absent in high-dimensional settings. LOW.

---

## Standard Error Rules

These rules apply to every regression in every file:

1. **Clustering level** — Identify the level at which standard errors are clustered. The cluster level should match or be above the level of treatment assignment. Flag if SEs are not clustered and the treatment varies at a group level. HIGH.
2. **Cluster count** — If clustered SEs are used, count the number of clusters. Fewer than 20–30 clusters makes standard cluster-robust SEs unreliable. Flag if cluster count is low (or cannot be inferred) without wild bootstrap or other small-sample correction. HIGH.
3. **Serial correlation** — In panel settings, check whether SEs account for serial correlation (clustering by unit, or AR corrections). Flag absence as MEDIUM.
4. **Spatial correlation** — If data has a geographic component, check whether spatial correlation is addressed (Conley SEs, geographic clustering). Flag absence as LOW if geographic data is present.
5. **Heteroskedasticity** — In cross-section OLS, robust (HC) SEs should generally be used. Flag homoskedastic SEs (no `robust` or `HC` option) as LOW.

---

## Undocumented Sample Restriction Rule

Any sample restriction that is **not accompanied by a comment explaining why** must be flagged. This includes:

- Hard-coded year ranges (`year >= 2010 & year <= 2019` with no comment)
- Hard-coded value thresholds (`employment > 50` with no comment)
- `drop if` statements in Stata without inline comments
- `.query()` / `.loc[]` filters in pandas without comments
- `filter()` in R without comments

Severity: **MEDIUM** for each undocumented restriction. Rationale: undocumented restrictions are the most common source of replication failures.

---

## Multiple Testing Rule

Count the distinct outcome variables used across all regression specifications in all files. If there are **5 or more distinct outcome variables** and no multiple testing correction (Bonferroni, BH/FDR, Romano-Wolf, `wyoung` in Stata, `p.adjust()` in R, `holm_bonferroni` in Python) is applied, flag as **HIGH**.

Additionally flag:

- Commented-out specifications that were run but not reported (indication of specification search): **MEDIUM**
- Subgroup analyses presented without pre-registration or adjustment: **MEDIUM**
- Results reported only for the subsample that shows significance, with full-sample results absent: **HIGH**

---

## Descriptive Analysis Rules

These rules apply to **all projects** regardless of identification strategy. Inadequate descriptive analysis can hide data quality problems that invalidate findings even when the causal design is sound.

1. **Summary statistics table** — Check whether a summary statistics table is produced covering all key variables (outcome, treatment, main controls). Minimum content: N, mean, SD. Flag absence as **MEDIUM**.
   - Flag additionally if N varies across variables without explanation — indicates undisclosed missingness.
   - Flag if any proportion or rate variable has a reported mean outside [0, 1] — indicates miscoding.
   - Flag if monetary/wage variables are not labeled as nominal or real — readers cannot assess comparability.

2. **Missing data documentation** — Check whether missingness is documented for key variables.
   - If no missingness is reported and the data source is known to have incomplete coverage: **MEDIUM**.
   - If raw data N and final analysis sample N differ substantially with no accounting of what was dropped: **HIGH**. This prevents replication and may indicate undisclosed selection.

3. **Sample construction funnel** — Is there a table or documented sequence showing how many observations are dropped at each cleaning/restriction step?
   - If multiple restrictions are applied with no such accounting: **MEDIUM**.
   - This overlaps with the Undocumented Sample Restrictions rule; flag both if applicable.

4. **Distribution checks** — Check whether distributional summaries (histograms, density plots, or percentile tables) are produced for the main outcome and treatment variables.
   - If absent for variables that are likely right-skewed (income, wealth, firm size, counts): **LOW**.
   - Flag any suspicious distributional features visible in the code: spikes at round numbers (heaping / digit preference), values outside a bounded variable's valid range, or implausible extremes.

5. **Outlier assessment** — Is outlier handling documented?
   - If the outcome or treatment is a continuous variable with plausible extreme values and no winsorizing, trimming, or exclusion is visible: **LOW**.
   - If outlier thresholds are hard-coded without an explanatory comment: **MEDIUM** (treat as an undocumented restriction).

6. **Balance / comparison table** — In any study comparing groups (treatment vs. control, pre vs. post), is a pre-intervention covariate comparison table produced?
   - If absent in a study with a defined treatment group: **MEDIUM**.
   - For matching studies, MR-M2 covers post-matching balance; flag here separately if pre-matching comparison is also absent.

7. **Trend visualization in panel or time-series data** — If the data has a time dimension, are aggregate trends plotted for the main outcome?
   - If absent in panel data: **LOW**. Trend plots can reveal structural breaks, seasonality, or data anomalies invisible in static summaries.

8. **Merge rate documentation** — If multiple data sources are merged, is the match rate documented?
   - If merge rates are not reported and multiple merges occur: **MEDIUM**.
   - If the same key appears multiple times on either side of a merge without visible deduplication: **MEDIUM** (possible unit-of-analysis error; overlaps with MR-SA3).

9. **Survey weights in descriptive statistics** — If the data is a survey with sampling weights, are weighted statistics reported in descriptive tables?
   - If weights are present in the data but unweighted descriptives are used without acknowledgment: **MEDIUM**.

10. **External validation** — Is the analysis sample compared to external benchmarks (Census counts, published statistics, prior papers) to validate data quality?
    - If absent for a novel or administrative dataset not previously used in the literature: **LOW**.

---

## Dataset Variable Usage Rules

These rules apply when the agent identifies a **recognized public survey or dataset** in the code. Unrecognized or proprietary datasets are silently skipped — these checks only fire when dataset identification is confident.

### Dataset Identification

Search all source files for signals that a recognized public dataset is in use:

1. **File name patterns** — e.g., `cps_*.dta`, `acs_2022.csv`, `scf_*.dta`, `hmda_*.csv`, `nhis_*.dta`
2. **Characteristic variable names** — e.g., `wtfinl`, `asecwt`, `perwt`, `PWGTP`, `WTSURVY`, `WGT`, `earnwt`
3. **Dataset-specific loaders** — e.g., `ipumsr::read_ipums_micro()`, `tidycensus::get_acs()`, `freduse`
4. **Comments or metadata** — explicit references to dataset names ("Current Population Survey", "ACS", "SCF")

A match must be **confident** — if a file is named `data.csv` with no further context, skip it. Multiple signals (e.g., a file named `cps_asec.dta` that also contains variables `asecwt` and `a_age`) increase confidence.

### Weight Variable Validation

These checks apply to any recognized survey dataset. The agent's Known Dataset Variable Registry (in the agent file) maps each dataset to its correct weight variables by analysis context.

1. **MR-VU1: Survey weights entirely absent from regressions**
   - If a recognized survey dataset is used and no weight variable appears in any regression specification (`[pw=]`, `[aw=]`, `[iw=]` in Stata; `weights=` in R; `weight` argument in Python), flag as **HIGH**.
   - Reduce to **LOW** if a comment explicitly justifies unweighted estimation (e.g., citing Solon, Haider & Wooldridge 2015 on when not to weight).
   - Note: this check is complementary to MR-DA9 (which checks whether descriptive statistics use weights). MR-VU1 checks whether any weights are used at all when a recognized survey requires them.

2. **MR-VU2: Wrong weight variable for the analysis type**
   - If survey weights are used but the weight variable does not match the correct weight for the analysis type (per the Known Dataset Variable Registry), flag as **HIGH**.
   - Common errors:
     - Using basic monthly CPS weight (`wtfinl` / `PWCMPWGT`) for ASEC supplement income analysis (should be `asecwt` / `ASECWT`)
     - Using person weight for household-level analysis (should be household weight)
     - Using household weight for person-level analysis (should be person weight)
     - Using final weight instead of supplement-specific weight for supplement analyses
   - What to check: → Verify the weight variable name against the dataset documentation → Confirm the weight matches the unit of analysis (person vs. household) → Confirm the weight matches the data product (basic monthly vs. supplement)

3. **MR-VU3: Dataset-specific pitfall detected**
   - Apply the dataset-specific pitfall checks from the Known Dataset Variable Registry. Each pitfall has its own severity (HIGH or MEDIUM) specified in the registry.
   - Common pitfalls:
     - **SCF implicates**: Survey of Consumer Finances provides 5 multiply-imputed datasets (implicates). Analysis that uses only one implicate (e.g., `YY1 == 1`) without combining across all 5 using Rubin (1987) rules produces incorrect standard errors. **HIGH**.
     - **HMDA action-type filtering**: HMDA data includes applications, originations, denials, and other actions. Mortgage market analysis typically requires filtering to originations (`action_taken == 1`). Using unfiltered HMDA data inflates counts and distorts rates. **HIGH** if no action-type filter is visible.
     - **Topcoded income**: CPS, ACS, and Census income variables are topcoded. If topcoding is not addressed (acknowledged, imputed, or excluded) when income is the outcome variable, flag as **MEDIUM**.
     - **CPI variant**: When deflating nominal values, CPI-U vs. CPI-U-RS vs. C-CPI-U vs. PCE deflator produce different real series. If the deflator variant is not specified in comments or variable names, flag as **MEDIUM**.
     - **Replicate weights**: ACS, CPS ASEC, and other surveys provide replicate weights for variance estimation. If only the main weight is used without replicate weights and standard errors are not bootstrapped, the SEs may be understated. Flag as **LOW** (acceptable if the survey design is declared via `svyset` or `svydesign` with design variables).
     - **Person vs. household weight mismatch**: If the unit of analysis is households but a person weight is used (or vice versa), flag as **HIGH** (this overlaps with MR-VU2 but is listed here as a dataset-specific pitfall for clarity).

### Severity Summary

| Check | Default Severity | Reduced When |
|-------|-----------------|-------------|
| MR-VU1: Weights entirely absent | HIGH | LOW if explicitly justified in comments |
| MR-VU2: Wrong weight variable | HIGH | — |
| MR-VU3: SCF implicates not combined | HIGH | — |
| MR-VU3: HMDA not filtered to originations | HIGH | — |
| MR-VU3: Topcoded income not addressed | MEDIUM | — |
| MR-VU3: CPI variant unspecified | MEDIUM | — |
| MR-VU3: Replicate weights not used | LOW | — |
| MR-VU3: Person/household weight mismatch | HIGH | — |

---

## Output Format Rules

1. **File**: Write to `{TARGET_DIR}/review-reports/methodology-report.html`. Create the `review-reports/` directory if it does not exist.
2. **Template**: Use `.codex/templates/methodology-report.md` as the HTML structure. Replace all `{{PLACEHOLDER}}` tokens.
3. **Severities**: Use only HIGH, MEDIUM, LOW. No CRITICAL, no INFO.
4. **Group order**: HIGH findings first, then MEDIUM, then LOW.
5. **Within-group sub-grouping**: Within each severity level, group findings by category: Causal Inference → Regression Specification → Standard Errors → Sample & Data → Multiple Testing → Descriptive Analysis → Dataset Variable Usage.
6. **Finding IDs**: Sequential, starting at MR-001. No gaps, no duplicates.
7. **HTML escaping**: All code snippets and file paths must be HTML-escaped.
8. **"Why This Is a Concern"**: Must include the econometric intuition (not just "this might be wrong"). Reference relevant literature where applicable (author, year).
9. **"What to Check"**: Provide concrete, actionable checklist items using `→` arrows.
10. **Self-contained**: The HTML file must have no external dependencies.
11. **Err on side of flagging**: When uncertain, include the finding with a LOW or MEDIUM severity rather than omitting it. The author can dismiss it if it is not applicable.
