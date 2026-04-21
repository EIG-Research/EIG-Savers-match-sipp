# Code Quality Rules

These are binding rules for the `code-reviewer` sub-agent. Follow them exactly.

---

## Scope

**Review definitive code errors AND efficiency/readability suggestions.**

A **definitive code error** is a bug that:

- Produces incorrect results (wrong values, wrong data, wrong model estimates)
- Silently corrupts data without raising an exception
- Crashes or halts execution in a way that blocks the analysis
- Introduces non-determinism that makes results irreproducible

An **efficiency/readability suggestion** is an opportunity to:

- Make the pipeline run materially faster (not micro-optimizations)
- Reduce memory usage on large datasets
- Replace convoluted logic with a clearer, more readable alternative
- Use a more idiomatic or standard approach for the language/framework

**Do NOT flag:**

- Pure style preferences (variable naming conventions, indentation, comment density)
- Methodology or design concerns (those belong in methodology-report.html)
- Hypothetical bugs that require specific unknown inputs to trigger
- Deprecation warnings that do not affect current behavior
- Trivial micro-optimizations with no measurable impact

**When in doubt about errors:** omit the finding. The error portion of this report is for definitive errors, not concerns.

**When in doubt about suggestions:** include them. Suggestions are low-cost for the author to review and dismiss if not applicable.

---

## File Coverage

Every file discovered must appear in the Reviewed Files table. No file may be silently skipped.

If a file is unreadable (encoding error, binary, etc.), include it in the table with a note in the "Errors Found" column: `unreadable`.

Reviewed file extensions: `*.py`, `*.R`, `*.Rmd`, `*.qmd`, `*.do`, `*.ado`

---

## Severity Assignment

Assign severity based on the **worst realistic outcome** if the bug is not fixed:

| Severity | Criteria | Examples |
|----------|----------|---------|
| **CRITICAL** | Bug silently produces wrong numerical results that would appear in the paper | pandas SettingWithCopyWarning that silently no-ops; merge that silently drops all rows; Stata `. > 0` comparison always true |
| **HIGH** | Bug crashes the analysis or corrupts the dataset, but failure is detectable | KeyError that halts execution; wrong merge key that raises a shape mismatch |
| **MEDIUM** | Bug affects a secondary calculation or produces a warning users may ignore | `inplace=True` ignored on a copy; `na.rm=FALSE` on a non-critical summary stat |
| **LOW** | Bug is present but unlikely to affect results given typical data | Hard-coded path that works on the author's machine but will fail elsewhere |
| **INFO** | Potential issue that needs author confirmation to classify | Ambiguous column name that may or may not collide |
| **SUGGESTION** | Efficiency or readability improvement that does not affect correctness | Vectorizable loop over DataFrame rows; redundant data reload; opaque one-liner replaceable with named steps |

**Never inflate severity.** If the bug would only affect results under unusual data conditions, use LOW or INFO.

**Never classify a suggestion as an error.** If the code produces correct results but could be faster, clearer, or more memory-efficient, use SUGGESTION.

---

## Language-Specific Must-Always-Check Items

These items must be actively checked for every file in the corresponding language. Do not rely on them appearing obviously — search for the patterns.

### Python (pandas/numpy/statsmodels/linearmodels)

1. **Copy vs. view** — Any assignment to a slice of a DataFrame (e.g., `df[condition]['col'] = val`) is a potential silent no-op. Check all chained indexing patterns.
2. **Merge key dtype mismatch** — If a merge joins on an integer column and a string column (or int64 vs object), the merge will silently produce zero or wrong rows. Check dtypes at every `merge()` / `join()`.
3. **`inplace=True` on a copy** — Operations on a slice with `inplace=True` silently fail. Check all `inplace=True` usages.
4. **Formula strings** — In `statsmodels`/`linearmodels`, check that formula strings reference actual column names. Typos produce `KeyError` or wrong omitted-variable behavior.
5. **NA propagation** — Check that `NaN` values are intentionally handled (or not) at aggregation steps. An accidental `skipna=True` default can hide missing data.
6. **Boolean indexing after reset_index** — After `reset_index()`, old index-based boolean masks are invalid. Check for masks created before `reset_index()` applied after.
7. **Hard-coded absolute paths** — Flag all `open('/Users/...')`, `pd.read_csv('/home/...')`, etc.
8. **`groupby` followed by transform vs. agg confusion** — Assigning a `.groupby().agg()` result back to the original DataFrame column silently misaligns if the index differs.
9. **`append()` in a loop** — `DataFrame.append()` was removed in pandas 2.0; still-present calls will crash.
10. **Seed not set before random operations** — If randomness is used (e.g., bootstrap, train/test split), absence of a seed makes results irreproducible.

### R (base R / tidyverse / fixest / lfe / haven)

1. **Factor vs. numeric coercion** — `as.numeric(factor_var)` returns factor level codes (1, 2, 3…), not the underlying values. Check all `as.numeric()` calls on factor or labelled columns.
2. **`na.rm` omission** — `mean()`, `sum()`, `sd()`, `var()` return `NA` silently if any `NA` is present and `na.rm` is not set. Check every summary function call.
3. **`[` vs `[[` on data frames** — `df['col']` returns a data frame; `df[['col']]` returns a vector. Passing a data frame where a vector is expected produces wrong results or silent recycling.
4. **`I()` in formula strings** — Arithmetic in formulas requires `I()`. `lm(y ~ x + x^2)` does NOT square x; `lm(y ~ x + I(x^2))` does. Check all polynomial/interaction formulas.
5. **dplyr grouping not removed** — After `group_by()`, the data frame remains grouped. Operations downstream (mutate, summarise) may aggregate unexpectedly. Check that `ungroup()` is called when grouping is no longer intended.
6. **`haven` labelled class** — Columns read via `haven::read_dta()` are class `labelled`, not numeric. Direct arithmetic on labelled columns may work but produces `labelled` output; regression packages may handle it unexpectedly. Check for `as.numeric()` or `zap_labels()` conversion.
7. **Recycling in base R** — Assigning a shorter vector to a data frame column silently recycles. Check all column assignments where the RHS length is not obviously equal to `nrow(df)`.
8. **Hard-coded absolute paths** — Flag all `read.csv('/Users/...')`, `setwd('/home/...')`, etc.
9. **Seed not set before random operations** — If `sample()`, `set.seed()` should precede. Check for `rnorm`, `sample`, `boot`, `replicate` without a prior `set.seed()`.
10. **`merge()` default `all = FALSE`** — Base R `merge()` performs an inner join by default without warning. Check that the join type is intentional and rows dropped are expected.

### Stata (.do and .ado files)

1. **`_merge` variable handling** — After `merge`, the `_merge` variable must be checked and then dropped (or the merge must use `keep()` + `assert()`). An unchecked merge that drops non-matches silently loses data.
2. **Scalar vs. variable name collision** — If a scalar and a variable share a name, Stata may silently use one when you intend the other. Check all `scalar` definitions against variable names in the dataset.
3. **Missing value comparisons** — In Stata, missing (`.`) is treated as positive infinity; `.` > 0 is TRUE. Any comparison like `if var > 0` silently includes missing observations. Check all inequality conditions on variables that may have missings.
4. **`preserve` / `restore` balance** — Every `preserve` must have a matching `restore`. An unmatched `preserve` leaves the dataset in a modified state for subsequent do-file sections.
5. **Hard-coded absolute paths** — Flag all `use "C:\Users\..."`, `insheet using "/home/..."` etc.
6. **Loop macro confusion** — Local macros in loops (`forvalues`, `foreach`) are lost after the loop. Accessing `\`i'' outside the loop returns empty string. Check for macro references outside their defining scope.
7. **`egen` function misuse** — `egen` functions have specific requirements (e.g., `rowmean` ignores missings but `mean` does not). Check that the right `egen` function is used for the intended computation.
8. **`xtset` not declared before panel commands** — `xtreg`, `xtlogit`, etc., require `xtset panelvar timevar`. Running panel commands without `xtset` causes an error; running after an incorrect `xtset` produces wrong FE structure.
9. **`quietly` suppressing errors** — `quietly` suppresses all output including errors in some contexts. Check that `quietly` does not mask a failing command.
10. **Encoding issues** — Non-ASCII characters in string variables can cause silent comparison failures. Check string comparisons involving user-supplied data.

---

## Efficiency & Readability Suggestions

These items are checked in addition to the error checklists. All findings from this section use the **SUGGESTION** severity. They never affect correctness — they improve speed, memory usage, or readability.

### Python Efficiency (apply to every `.py` file)

1. **Row-wise iteration over DataFrames** — `for index, row in df.iterrows()` or `df.apply(func, axis=1)` on large DataFrames is orders of magnitude slower than vectorized operations. Flag when the loop body could be expressed with vectorized pandas/numpy operations.
2. **Repeated file reads** — The same CSV/Parquet/DTA file read multiple times across scripts (or within the same script) when a single read and pass-through would suffice.
3. **Unnecessary `.copy()` chains** — Excessive defensive copying (`df.copy()`) when the original is never modified afterward wastes memory on large datasets.
4. **String concatenation in loops** — Building strings or DataFrames with `+=` or `pd.concat()` inside a loop instead of collecting into a list and concatenating once at the end.
5. **Unneeded intermediate DataFrames** — Large temporary DataFrames assigned to variables but used only once; could be chained or piped to avoid holding two copies in memory.
6. **Opaque one-liners** — Complex chained operations spanning multiple transformations that would be clearer as named intermediate steps with comments.
7. **CSV where Parquet/Feather would be faster** — Large datasets (>100MB) read/written as CSV when a columnar format would dramatically reduce I/O time.
8. **Unfiltered data loaded then immediately filtered** — Reading an entire dataset and then dropping most rows, when the filter could be applied at read time (e.g., `usecols`, `dtype` specification, or query-based loading).

### R Efficiency (apply to every `.R`, `.Rmd`, `.qmd` file)

1. **Row-wise loops over data frames** — `for (i in 1:nrow(df))` with element-wise operations that could be vectorized or replaced with `dplyr::mutate()` / `data.table` operations.
2. **Growing objects in loops** — `result <- c(result, new_value)` or `rbind(result, new_row)` inside a loop instead of pre-allocating or using `lapply()` + `do.call(rbind, ...)`.
3. **Repeated file reads** — Same data file read multiple times when it could be read once and reused.
4. **`data.frame` operations on large data that would benefit from `data.table`** — Very large datasets (millions of rows) processed with base R or tidyverse when `data.table` would be substantially faster. Flag only when the performance gap is likely material.
5. **Unnecessary `as.data.frame()` conversions** — Converting tibbles to data.frames and back without a clear reason.
6. **Deeply nested `ifelse()` chains** — Multiple nested `ifelse()` calls that would be clearer as `dplyr::case_when()` or `data.table::fcase()`.
7. **`sapply()` with complex return types** — `sapply()` that silently simplifies to unexpected structures; `vapply()` or `map_*()` with explicit types is clearer and safer.
8. **Unreadable pipe chains** — Pipe chains (`%>%` or `|>`) spanning more than 8–10 steps without intermediate assignments or comments explaining the logic.

### Stata Efficiency (apply to every `.do`, `.ado` file)

1. **Repeated `use` of the same dataset** — Loading the same `.dta` file multiple times when `preserve`/`restore` or `frame` commands could avoid redundant disk I/O.
2. **Row-by-row loops via `forvalues` over `_N`** — Looping observation-by-observation when `replace`, `egen`, or `by` would be faster and clearer.
3. **Unnecessary `sort` before `merge`** — `merge` and `joinby` sort automatically; explicit `sort` beforehand is redundant.
4. **Long `generate`/`replace` chains for a single categorical recode** — Multiple `replace ... if ...` lines that could be a single `recode` or `label define` + `encode`.
5. **Opaque nested macros** — Deeply nested local macro references (``` ``x'_``y''' ```) that are difficult to read; clearer alternatives using `tempvar` or explicit variable construction.
6. **Repeatedly collapsing and restoring** — Multiple `collapse` + `merge` cycles where a single `egen` or `by:` prefix would achieve the same result without data loss.
7. **String operations in large loops** — String matching (`strpos`, `regexm`) applied observation-by-observation when a vectorized approach is available.

---

## Data Currency Rules

The code reviewer checks whether recognized public datasets used in the project are up to date. This is **informational only** — outdated data is not an error or suggestion.

### Scope

- **Check only recognized public datasets** from well-known economics/policy data sources (Census Bureau, BLS, Federal Reserve, BEA, NBER, international organizations, academic repositories).
- **Silently skip** proprietary, unrecognized, or project-specific data files. If a file name or data-loading call cannot be confidently matched to a known public dataset, do not include it in the Data Currency table.
- **Do not flag outdated data as an error or suggestion.** Researchers may deliberately use a specific vintage for replication or comparability. The Data Currency table is purely advisory.

### Detection

Scan all source files for data-loading operations and extract dataset identifiers:

**Python:**
- `pd.read_csv()`, `pd.read_stata()`, `pd.read_parquet()`, `pd.read_excel()`, `pd.read_sas()` — extract file name arguments
- API calls: `fredapi` / `Fred()`, `census` package, `requests.get()` to known data URLs
- Comments or variable names referencing known dataset names (e.g., `acs_2022`, `cpi_data`, `bfs_`)

**R:**
- `read.csv()`, `read_csv()`, `read_dta()`, `haven::read_dta()`, `read.dta13()`, `read_excel()`, `read_parquet()` — extract file name arguments
- API calls: `fredr()`, `tidycensus::get_acs()`, `tidycensus::get_decennial()`, `download.file()` to known URLs
- `load()`, `readRDS()` — extract file name arguments

**Stata:**
- `use`, `import delimited`, `import excel`, `insheet using` — extract file name arguments
- `freduse` — extract series identifiers

From these, extract:
- File names and paths (e.g., `bfs_2023q4.csv`, `acs_2022_5yr.dta`)
- Dataset identifiers from variable names, comments, or API parameters
- URL endpoints for data downloads

### Identification

Match extracted file names, paths, and identifiers against the Known Public Dataset Registry (defined in the agent file). Use these signals:

- File name patterns (e.g., `acs_*`, `cps_*`, `cpi_*`, `bfs_*`, `qcew_*`)
- Known API function calls (e.g., `fredr()`, `get_acs()`, `freduse`)
- URL domains (e.g., `data.census.gov`, `download.bls.gov`, `fred.stlouisfed.org`)
- Comments or variable names that explicitly name a dataset

A match must be **confident** — do not guess. If a file is named `data.csv` with no further context, skip it.

### Verification

For each confidently identified dataset:

1. Use `WebSearch` to find the latest available release, vintage, or update date for that specific dataset.
2. Compare the version in the code (inferred from file names, year suffixes, API parameters, or comments) against the latest available version.
3. Record the result in the Data Currency table.

### Status Values

| Status | Meaning | Display Color |
|--------|---------|---------------|
| **Current** | The code uses the latest available release | Green |
| **Update Available** | A newer release exists | Amber |
| **Unable to Verify** | The dataset was recognized but the latest version could not be confirmed via web search | Gray |

### Output

Populate the Data Currency table in the report template with one row per recognized dataset. If no recognized public datasets are found, display the note: "No recognized public datasets detected."

---

## Output Format Rules

1. **File**: Write to `{TARGET_DIR}/review-reports/code-error-report.html`. Create the `review-reports/` directory if it does not exist.
2. **Template**: Use `.claude/templates/code-error-report.md` as the HTML structure. Replace all `{{PLACEHOLDER}}` tokens.
3. **Sort order**: Findings must be sorted CRITICAL → HIGH → MEDIUM → LOW → INFO → SUGGESTION.
4. **Finding IDs**: Sequential, starting at CE-001. No gaps, no duplicates. Error findings and suggestion findings share the same sequence.
5. **HTML escaping**: All code snippets and file paths must be HTML-escaped.
6. **Code blocks**: Use `<pre><code>` tags. Show the problematic code as it appears in the file, then the recommended fix.
7. **Self-contained**: The HTML file must have no external dependencies (no CDN links, no external fonts).
8. **No pure style issues**: Do not include findings about code style (naming, spacing, comments) unless they meaningfully affect readability.
9. **Accuracy over completeness for errors**: If unsure whether something is a bug, omit it. False positives undermine trust in the report.
10. **Inclusion over omission for suggestions**: If an efficiency or readability improvement is plausible and material, include it. The author can dismiss it easily.
11. **Data Currency table**: The report includes a Data Currency section between Findings and Reviewed Files. Populate one row per recognized public dataset. If no recognized datasets are found, display: "No recognized public datasets detected." Data currency results are informational — they do not appear as findings and do not receive finding IDs.
