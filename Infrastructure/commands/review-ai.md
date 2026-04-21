# Skill: /review-ai

Runs the AI skeptic review only. Discovers all source and document files in the target project, spawns the `ai-skeptic` sub-agent, and writes `ai-skeptic-report.html` to the `review-reports/` subdirectory of the target directory.

Unlike other review commands, this command does **not** require a successful pipeline run first. The AI skeptic reviews source code and prose statically — it needs the files to exist, not the pipeline to complete. (Edge-case test scripts in AS-4 may need data files, but will degrade gracefully if data is absent.)

---

## Trigger

User runs `/review-ai <target_dir>`

Example: `/review-ai ~/ra-project`

---

## Execution Steps

### Step 1 — Parse target directory

Extract `target_dir` from the command argument. Expand `~` to the full home directory path.

If no argument is provided, stop and respond:

> Usage: `/review-ai <path-to-project>`
> Example: `/review-ai ~/ra-project`

Verify that `target_dir` exists and is a directory. If not:

> `<target_dir>` does not exist or is not a directory. Check the path and try again.

**Stop.**

### Step 2 — Discover source code files

Recursively find all files matching these extensions inside `target_dir`:
- `*.py`
- `*.R`
- `*.Rmd`
- `*.qmd`
- `*.do`
- `*.ado`

Exclude files under these subdirectories (relative to `target_dir`):
- `.git/`
- `temp/`

Collect the full absolute path of each discovered file.

If zero code files are found, stop and respond:

> No reviewable source files found in `<target_dir>`. Expected `.py`, `.R`, `.Rmd`, `.qmd`, `.do`, or `.ado` files.

### Step 3 — Discover document files

Search for document files in `target_dir` (recursively). Match these extensions:
- `*.tex`
- `*.md` (excluding `README.md`, `CHANGELOG.md`, `LICENSE.md`, and files inside `.claude/`, `.codex/`, `Infrastructure/`)
- `*.qmd`
- `*.Rmd`
- `*.pdf` (excluding report files in `review-reports/`)

Exclude files under `.git/`, `.claude/`, `.codex/`, `Infrastructure/`, `review-reports/`.

### Step 4 — Scan git history for AI authorship

If the directory is a git repository:

1. Run `git log --all --format='%H %s' --grep='Co-Authored-By'` to find AI-attributed commits.
2. Run `git log --all --numstat --format='%H' --diff-filter=A` to identify bulk-addition commits.
3. Map files to AI authorship status: Known / Suspected / Unknown.

If not a git repository, mark all files as "Unknown" AI authorship.

### Step 5 — Report discovery

List the discovered files:

> Found **N** source code files and **M** document files in `<target_dir>`:
>
> **Source code:**
> **Python (n):** `path/to/file.py`, …
> **R (n):** `path/to/file.R`, …
> **Stata (n):** `path/to/file.do`, …
>
> **Documents (m):** `path/to/doc.md`, …
>
> **AI authorship:** X files with known AI attribution, Y suspected, Z unknown.
>
> Proceeding with AI skeptic review.

### Step 6 — Create output directory

Create the output directory `<target_dir>/review-reports/` if it does not already exist:

```
mkdir -p <target_dir>/review-reports
```

Also create the test script directory:

```
mkdir -p <target_dir>/temp/ai-skeptic-tests
```

### Step 7 — Spawn the ai-skeptic sub-agent

Spawn the `ai-skeptic` sub-agent with the following context:

```
Agent: ai-skeptic
Target directory: <target_dir>
Source files to review: [full list of source code file paths]
Document files to review: [full list of document file paths]
AI authorship map: [file → Known/Suspected/Unknown]
Rules: Infrastructure/rules/ai-skeptic-rules.md
Template: Infrastructure/templates/ai-skeptic-report.md
Output: <target_dir>/review-reports/ai-skeptic-report.html
Test script directory: <target_dir>/temp/ai-skeptic-tests/
```

The sub-agent will:
1. Read each file
2. Run fabrication checks (AS-1) with web search verification
3. Check comment-code fidelity (AS-2)
4. Build the assumption inventory (AS-3)
5. Generate and run edge-case tests (AS-4)
6. Check confidence calibration in prose (AS-5)
7. Detect pattern-matching artifacts (AS-6)
8. Write the HTML report

### Step 8 — Wait and monitor

Wait for the sub-agent to complete. If the sub-agent reports an error (file unreadable, web search unavailable, template missing), surface the error to the user with the specific message.

### Step 9 — Confirm output and summarize

Verify that `<target_dir>/review-reports/ai-skeptic-report.html` exists and is non-empty.

Report to the user:

> AI skeptic review complete. Report written to `<target_dir>/review-reports/ai-skeptic-report.html`.
>
> **Trust Assessment:** VERIFIED / CAUTION / SUSPECT
> **Summary:** N findings — X CRITICAL, X HIGH, X MEDIUM, X LOW, X INFO
> **Assumption Inventory:** M implicit assumptions surfaced (K undisclosed + high-impact)
> **Edge-Case Tests:** P tests run — Q passed, R failed

If CRITICAL or HIGH findings are present:

> **Attention:** [X] critical/high-severity AI-specific concerns were found. Manual verification required before citing any results from this codebase.

If trust level is SUSPECT:

> **Trust level SUSPECT** — fabricated entities were detected or multiple high-severity findings span check families. Do not treat outputs from this codebase as verified until each flagged item is resolved.
