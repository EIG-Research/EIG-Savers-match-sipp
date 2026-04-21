# Skill: /review-consistency

Runs the conceptual consistency review. Executes the RA's pipeline, discovers all source and document files in the target project, spawns the `conceptual-consistency-reviewer` sub-agent, and writes `doc-consistency-report.html` to the `review-reports/` subdirectory of the target directory.

---

## Trigger

User runs `/review-consistency <target_dir>` or `/review-consistency <target_dir> <document_path>`

Examples:
- `/review-consistency ~/ra-project`
- `/review-consistency ~/ra-project ~/ra-project/paper/manuscript.tex`

---

## Execution Steps

### Step 1 — Parse arguments

Extract `target_dir` from the first argument. Expand `~` to the full home directory path.

If no argument is provided, stop and respond:

> Usage: `/review-consistency <path-to-project> [path-to-document]`
> Example: `/review-consistency ~/ra-project`
> Example: `/review-consistency ~/ra-project ~/ra-project/paper/manuscript.tex`

Verify that `target_dir` exists and is a directory. If not:

> `<target_dir>` does not exist or is not a directory. Check the path and try again.

**Stop.**

If a second argument is provided, treat it as the document path. Verify the file exists. If not:

> `<document_path>` does not exist. Check the path and try again.

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
> Fix the pipeline errors before running a consistency review.

**Stop. Do not proceed to the review.**

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

Exclude files under `.git/`.

Collect the full absolute path of each discovered file.

### Step 4 — Discover or confirm document files

**If a document path was provided in Step 1:** use that file as the document to review.

**If no document path was provided:** search for document files in `target_dir` (recursively). Match these extensions:
- `*.tex`
- `*.md` (excluding files named `README.md`, `CHANGELOG.md`, `LICENSE.md`, and any files inside `.claude/` or `.codex/`)
- `*.qmd`
- `*.Rmd`
- `*.pdf` (excluding `doc-number-report.pdf`, `doc-consistency-report.pdf`)

Exclude files under `.git/`, `.claude/`, and `.codex/`.

Also exclude the `review-reports/` directory.

If zero document files are found, stop and respond:

> No document files found in `<target_dir>`. Expected `.tex`, `.md`, `.qmd`, `.Rmd`, or `.pdf` files.
>
> Specify the document path explicitly: `/review-consistency <target_dir> <document_path>`

**Stop.**

If one document file is found, use it automatically.

If multiple document files are found, list them and ask the user to select:

> Found multiple document files in `<target_dir>`:
>
> 1. `path/to/manuscript.tex`
> 2. `path/to/appendix.tex`
> 3. `path/to/paper.qmd`
>
> Which document(s) should I review? (Enter numbers separated by commas, or "all")

Wait for the user's response.

### Step 5 — Report discovery and gather optional context

List the discovered files and ask for optional context:

> **Document(s) to review:** `manuscript.tex` (and any others selected)
>
> Found **N** source code files in `<target_dir>`:
>
> **Python (n):** `path/to/file.py`, …
> **R (n):** `path/to/file.R`, …
> **Stata (n):** `path/to/file.do`, …
>
> **Optional context** — helps the reviewer give more targeted feedback (say "skip" to proceed):
>
> 1. **Identification strategy** (e.g., DiD, RD, IV, Matching) — or blank to infer
> 2. **Treatment variable** name
> 3. **Primary outcome variable(s)**

Wait for the user's response. Record any context provided.

### Step 6 — Create output directory

Create the output directory `<target_dir>/review-reports/` if it does not already exist:

```
mkdir -p <target_dir>/review-reports
```

### Step 7 — Spawn the conceptual-consistency-reviewer sub-agent

Spawn the `conceptual-consistency-reviewer` sub-agent with the following context:

```
Agent: conceptual-consistency-reviewer
Target directory: <target_dir>
Document files: [list of document file paths]
Code files to review: [full list of source code file paths]
Rules: .claude/rules/doc-consistency-rules.md
Template: .claude/templates/doc-consistency-report.md
Output: <target_dir>/review-reports/doc-consistency-report.html

Research context (if provided by user):
  Identification strategy: [user input or "Infer from code"]
  Treatment variable: [user input or "Infer from code"]
  Outcome variable(s): [user input or "Infer from code"]
```

The sub-agent will read the document(s) and code, extract and cross-reference claims, and write the HTML report into `<target_dir>/review-reports/`.

### Step 8 — Wait and monitor

Wait for the sub-agent to complete. If the sub-agent reports an error, surface it to the user with the specific message.

### Step 9 — Confirm output and summarize

Verify that `<target_dir>/review-reports/doc-consistency-report.html` exists and is non-empty.

Report to the user:

> Consistency review complete. Report written to `<target_dir>/review-reports/doc-consistency-report.html`.
>
> **Summary:** N claims examined — X consistent, X flagged
> **Findings:** X HIGH, X MEDIUM, X LOW
> **Overall Risk:** [HIGH / MEDIUM / LOW]

If HIGH findings are present, add:

> ⚑ **Attention:** [X] HIGH severity inconsistencies were found. The document may contain descriptions that contradict what the code actually does.

If no findings:

> No inconsistencies identified. All examined claims appear consistent with the code.
