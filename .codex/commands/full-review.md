# Skill: /full-review

Runs all four reviews: code errors, methodology concerns, document number verification, and document–code consistency. Executes the RA's pipeline, discovers all source and document files in the target project, spawns all four sub-agents concurrently, and writes all four HTML reports to the `review-reports/` subdirectory of the target directory.

---

## Trigger

User runs `/full-review <target_dir>`

Example: `/full-review ~/ra-project`

---

## Execution Steps

### Step 1 — Parse target directory

Extract `target_dir` from the command argument. Expand `~` to the full home directory path.

If no argument is provided, stop and respond:

> Usage: `/full-review <path-to-project>`
> Example: `/full-review ~/ra-project`

Verify that `target_dir` exists and is a directory. If not:

> `<target_dir>` does not exist or is not a directory. Check the path and try again.

**Stop.**

### Step 2 — Detect and run the pipeline

Search for a runall script at the **top level** of `target_dir` only (not recursively). Match these filenames exactly (case-insensitive), in priority order:

| Priority | Filename(s) | Interpreter |
|----------|-------------|-------------|
| 1 | `runall.sh`, `run_all.sh` | `bash <script>` |
| 2 | `runall.do`, `run_all.do` | `stata -b do <script>` |
| 3 | `runall.R`, `run_all.R` | `Rscript <script>` |
| 4 | `runall.py`, `run_all.py` | `python <script>` |

If no matching file is found, stop and respond:

> No runall script found in `<target_dir>`. Expected one of:
> `runall.sh`, `run_all.sh`, `runall.do`, `run_all.do`, `runall.R`, `run_all.R`, `runall.py`, `run_all.py`
>
> Add a runall script and try again.

**Stop.**

Tell the user which script was found and is being executed:

> Found `<script_name>`. Running pipeline…

Execute the script using its interpreter, with `target_dir` as the working directory. Capture stdout and stderr.

**If the script exits with a non-zero exit code:**

> Pipeline failed (exit code N).
>
> ```
> [last 50 lines of combined stdout/stderr]
> ```
>
> Fix the pipeline errors before running a full review.

**Stop. Do not proceed to the review. Do not spawn any sub-agents.**

If the script succeeds (exit code 0):

> Pipeline completed successfully.

### Step 3 — Discover source code files

Recursively find all files matching these extensions inside `target_dir`:
- `*.py`
- `*.R`
- `*.Rmd`
- `*.qmd`
- `*.do`
- `*.ado`

Exclude files under these subdirectories (relative to `target_dir`):
- `.git/`

Collect the full absolute path of each discovered file.

If zero code files are found, stop and respond:

> No reviewable source files found in `<target_dir>`. Expected `.py`, `.R`, `.Rmd`, `.qmd`, `.do`, or `.ado` files.

### Step 4 — Discover document files

Search for document files in `target_dir` (recursively). Match these extensions:
- `*.tex`
- `*.md` (excluding files named `README.md`, `CHANGELOG.md`, `LICENSE.md`, and any files inside `.claude/` or `.codex/`)
- `*.qmd`
- `*.Rmd`
- `*.pdf` (excluding `doc-number-report.pdf`, `doc-consistency-report.pdf`)

Exclude files under `.git/`, `.claude/`, and `.codex/`.

Also exclude the `review-reports/` directory.

Record whether document files were found. If none are found, the document-review agents will be skipped (see Step 6).

### Step 5 — Report discovery and gather context

List the discovered files and ask for optional context in a single message:

> Found **N** source code files to review in `<target_dir>`:
>
> **Python (n):** `path/to/file.py`, …
> **R (n):** `path/to/file.R`, …
> **Stata (n):** `path/to/file.do`, …

If document files were found:

> Found **M** document file(s):
> `path/to/manuscript.tex`, `path/to/appendix.tex`, …

If multiple document files were found:

> Which document(s) should the number and consistency reviewers check? (Enter numbers separated by commas, "all", or "skip" to run only code and methodology reviews)

If no document files were found:

> No document files found (`.tex`, `.md`, `.qmd`, `.Rmd`, `.pdf`). Code and methodology reviews will proceed; number verification and consistency reviews will be skipped.

Always ask for optional research context:

> **Optional context** — helps the methodology and consistency reviewers give more targeted feedback (say "skip" to proceed):
>
> 1. **Identification strategy** (e.g., DiD, RD, IV, Matching) — or blank to infer
> 2. **Treatment variable** name
> 3. **Primary outcome variable(s)**
> 4. **Clustering level** (e.g., county, state, firm)

Wait for the user's response. Record any context provided and any document selection.

### Step 6 — Create output directory

Create the output directory `<target_dir>/review-reports/` if it does not already exist:

```
mkdir -p <target_dir>/review-reports
```

### Step 7 — Spawn sub-agents concurrently

**Spawn all applicable sub-agents at the same time (parallel).** Do not wait for one to finish before starting another.

**Always spawn these two:**

**Sub-agent 1 — code-reviewer:**
```
Agent: code-reviewer
Target directory: <target_dir>
Files to review: [full list of source code file paths]
Rules: .codex/rules/code-quality-rules.md
Template: .codex/templates/code-error-report.md
Output: <target_dir>/review-reports/code-error-report.html
```

**Sub-agent 2 — methodology-reviewer:**
```
Agent: methodology-reviewer
Target directory: <target_dir>
Files to review: [full list of source code file paths]
Rules: .codex/rules/methodology-rules.md
Template: .codex/templates/methodology-report.md
Output: <target_dir>/review-reports/methodology-report.html

Research context:
  Identification strategy: [user input or "Infer from code"]
  Treatment variable: [user input or "Infer from code"]
  Outcome variable(s): [user input or "Infer from code"]
  Clustering level: [user input or "Infer from code"]
```

**Spawn these two only if document files were found and selected:**

**Sub-agent 3 — data-consistency-reviewer:**
```
Agent: data-consistency-reviewer
Target directory: <target_dir>
Document files: [list of selected document file paths]
Code files to review: [full list of source code file paths]
Rules: .codex/rules/doc-number-rules.md
Template: .codex/templates/doc-number-report.md
Output: <target_dir>/review-reports/doc-number-report.html
```

**Sub-agent 4 — conceptual-consistency-reviewer:**
```
Agent: conceptual-consistency-reviewer
Target directory: <target_dir>
Document files: [list of selected document file paths]
Code files to review: [full list of source code file paths]
Rules: .codex/rules/doc-consistency-rules.md
Template: .codex/templates/doc-consistency-report.md
Output: <target_dir>/review-reports/doc-consistency-report.html

Research context:
  Identification strategy: [user input or "Infer from code"]
  Treatment variable: [user input or "Infer from code"]
  Outcome variable(s): [user input or "Infer from code"]
```

### Step 8 — Monitor all independently

Monitor all sub-agents independently. One agent's failure does not abort the others.

- If any agent fails, report its error but continue waiting for the others.
- If all fail, report all errors.

Inform the user as each sub-agent completes:

> Code reviewer complete (1/4) — waiting for remaining agents…
> Methodology reviewer complete (2/4) — waiting for remaining agents…
> Number verification complete (3/4) — waiting for consistency reviewer…
> All agents complete.

(Adapt the count to 2 if only code + methodology agents were spawned.)

### Step 9 — Confirm outputs with combined summary

Once all sub-agents complete (or fail), report combined results:

> **Full review complete.**
>
> | Report | Status | Findings |
> |--------|--------|---------|
> | Code Errors (`review-reports/code-error-report.html`) | Complete / Failed | X CRITICAL, X HIGH, X MEDIUM, X LOW, X INFO |
> | Methodology (`review-reports/methodology-report.html`) | Complete / Failed | X HIGH, X MEDIUM, X LOW — Overall Risk: HIGH/MEDIUM/LOW |
> | Number Verification (`review-reports/doc-number-report.html`) | Complete / Failed / Skipped | X numbers extracted, Y verified, Z flagged — X CRITICAL, X HIGH, X MEDIUM, X LOW, X INFO |
> | Consistency (`review-reports/doc-consistency-report.html`) | Complete / Failed / Skipped | X claims examined, Y consistent, Z flagged — X HIGH, X MEDIUM, X LOW — Overall Risk: HIGH/MEDIUM/LOW |
>
> **Combined finding count:** N total across all reports.

If any CRITICAL or HIGH findings exist across any report:

> ⚑ **Action required:** [X] critical/high-severity issues found across [N] reports. Address these before submission.

### Step 10 — Offer key findings summary

Ask the user:

> Would you like me to summarize the most important findings from all reports here in chat? (Yes / No)

If yes, read all output HTML files and extract the CRITICAL and HIGH severity findings as a concise numbered list grouped by report:

**Code Errors — Critical/High:**
1. CE-001: [title] — [one-sentence description] (`file.py:line`)
2. …

**Methodology — High:**
1. MR-001: [title] — [one-sentence econometric concern] (`file.R`)
2. …

**Number Verification — Critical/High:**
1. DN-001: [title] — [one-sentence description] (`manuscript.tex`, Section X)
2. …

**Consistency — High:**
1. CC-001: [title] — [one-sentence inconsistency] (`manuscript.tex` vs `analysis.R`)
2. …

One line per finding. Omit MEDIUM and below (the full reports cover them). Skip any report section that has no Critical/High findings.
