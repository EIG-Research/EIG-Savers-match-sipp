# Skill: /review-code

Runs the code error review only. Executes the RA's pipeline, discovers all source files in the target project, spawns the `code-reviewer` sub-agent, and writes `code-error-report.html` to the `review-reports/` subdirectory of the target directory.

---

## Trigger

User runs `/review-code <target_dir>`

Example: `/review-code ~/ra-project`

---

## Execution Steps

### Step 1 — Parse target directory

Extract `target_dir` from the command argument. Expand `~` to the full home directory path.

If no argument is provided, stop and respond:

> Usage: `/review-code <path-to-project>`
> Example: `/review-code ~/ra-project`

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
> Fix the pipeline errors before running a code review.

**Stop. Do not proceed to the review.**

If the script succeeds (exit code 0):

> Pipeline completed successfully.

### Step 3 — Discover files

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

If zero files are found, stop and respond:

> No reviewable source files found in `<target_dir>`. Expected `.py`, `.R`, `.Rmd`, `.qmd`, `.do`, or `.ado` files.

### Step 4 — Report discovery

List the discovered files, grouped by language:

> Found **N** files to review in `<target_dir>`:
>
> **Python (n):** `path/to/file.py`, …
> **R (n):** `path/to/file.R`, …
> **Stata (n):** `path/to/file.do`, …
>
> Proceeding with code error review.

### Step 5 — Create output directory

Create the output directory `<target_dir>/review-reports/` if it does not already exist:

```
mkdir -p <target_dir>/review-reports
```

### Step 6 — Spawn the code-reviewer sub-agent

Spawn the `code-reviewer` sub-agent with the following context:

```
Agent: code-reviewer
Target directory: <target_dir>
Files to review: [full list of absolute file paths]
Rules: Infrastructure/rules/code-quality-rules.md
Template: Infrastructure/templates/code-error-report.md
Output: <target_dir>/review-reports/code-error-report.html
```

The sub-agent will read each file, apply the checklists, and write the HTML report into `<target_dir>/review-reports/`.

### Step 7 — Wait and monitor

Wait for the sub-agent to complete. If the sub-agent reports an error (file unreadable, template missing, write failure), surface the error to the user with the specific message.

### Step 8 — Confirm output and summarize

Verify that `<target_dir>/review-reports/code-error-report.html` exists and is non-empty.

Report to the user:

> Code review complete. Report written to `<target_dir>/review-reports/code-error-report.html`.
>
> **Summary:** N findings — X CRITICAL, X HIGH, X MEDIUM, X LOW, X INFO

If CRITICAL or HIGH findings are present, add:

> ⚑ **Attention:** [X] CRITICAL and [X] HIGH severity errors were found. Review these before running the analysis.

If no findings:

> No definitive code errors found across all N files.
