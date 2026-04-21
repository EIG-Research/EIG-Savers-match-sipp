# Repository Census: eig-template-version2
**Date:** 2026-04-08  
**Scope:** Full infrastructure audit — directory structure, build system, sync integrity, and cross-reference alignment

---

## Executive Summary

The template is architecturally sound. The 3-tier design (canonical `Infrastructure/` → generated `.claude/` and `.codex/` adapter copies) is coherent, and all adapter files perfectly match their canonical sources after the expected path rewriting. No content drift exists.

There is one blocking issue: **all five shell and Python scripts have Windows CRLF line endings**, which causes `make brain-sync`, `make brain-check`, `make brain-simulate`, and `make maintenance-check` to fail silently or with cryptic errors on Linux/Mac. This must be fixed before the Makefile is usable. Everything else is either correct by design or is a minor cosmetic issue.

---

## 1. Directory Structure Census

### Top-Level Layout

| Path | Purpose | Status |
|------|---------|--------|
| `code/run_all.R` | Pipeline orchestrator placeholder | Present; has placeholder path logic |
| `data/raw/`, `data/processed/` | Data storage | Present and empty (correct for template) |
| `drafts/` | Working text | Present with `.gitkeep` |
| `output/figures/`, `output/tables/` | Analysis outputs | Present and empty (correct for template) |
| `Infrastructure/` | Canonical AI brain and style system | Present, well-populated |
| `.claude/` | Claude adapter copy | Present, synced |
| `.codex/` | Codex adapter copy | Present, synced |
| `Makefile` | Build targets | Present; 5 targets |
| `PROJECT.md` | Project context | Present; all fields `TBD` (unfilled template) |
| `README.md` | Template orientation | Present; accurate |
| `.gitattributes` | Line ending policy | Present; `* text=auto` only |
| `.gitignore` | Ignore rules | Present; minimal (DS_Store, pycache) |

### Infrastructure Subdirectories

| Path | Contents | File Count |
|------|---------|-----------|
| `Infrastructure/agents/` | 10 canonical agent specs | 10 |
| `Infrastructure/commands/` | 12 canonical command playbooks | 12 |
| `Infrastructure/rules/` | 18 rule files (11 synced + 7 Infrastructure-only) | 18 |
| `Infrastructure/templates/` | 13 template files (10 synced + 3 Infrastructure-only) | 13 |
| `Infrastructure/skills/` | 1 skill (literature-intake) | 1 |
| `Infrastructure/style/` | Complete EIG style subsystem | ~40 files |
| `Infrastructure/scripts/` | 5 maintenance scripts | 5 |
| `Infrastructure/references/literature/` | Literature catalog + README | 2 |
| `Infrastructure/session_logs/` | Session log storage | README only |
| `Infrastructure/plans/` | Plan storage | README only |
| `Infrastructure/specs/` | Spec storage | README only |
| `Infrastructure/explorations/` | Sandbox space | README only |

---

## 2. Sync System Alignment

### The 3-Tier Design

The repository uses a source-of-truth pattern:

```
Infrastructure/{agents,commands,rules,templates,skills}
    ↓ manage_generated_copies.sh sync
.claude/{agents,commands,rules,templates,skills}
.codex/{agents,commands,rules,templates,skills}
```

The sync script (`manage_generated_copies.sh`) generates adapter copies by path-rewriting all `Infrastructure/{part}/` references to `.claude/{part}/` or `.codex/{part}/`. For skills, it additionally prepends YAML frontmatter for the `.claude` adapter.

### Drift Status: CLEAN

A full programmatic comparison of all synced files confirms **zero content drift** between `Infrastructure/` and both adapter directories. Every difference is the expected path rewrite and nothing else.

### What Is and Is Not Synced

**Synced to both adapters (by design):**

| Category | File Count | Notes |
|----------|-----------|-------|
| Agents | 10 | All review + style roles |
| Commands | 12 | All review + style commands |
| Rules | 11 | Review, style, and governance rules |
| Templates | 10 | Report and output templates |
| Skills | 4 (via SKILL.md) | literature-intake + 3 style skills |

**Infrastructure-only, NOT synced (by design):**

These files live in `Infrastructure/rules/` but are excluded from the `RULE_FILES` sync list. They are workflow/process governance for human+AI collaboration and don't need to be in adapter-local copies:

- `exploration-fast-track.md` — lightweight exploration workflow
- `exploration-folder-protocol.md` — folder structure for experiments
- `meta-governance.md` — template vs. project dual-identity rules
- `plan-first-workflow.md` — plan-before-coding protocol
- `replication-protocol.md` — replication-first approach
- `session-logging.md` — session log cadence and triggers
- `verification-protocol.md` — task completion verification steps

Similarly, three templates are Infrastructure-only by design:
- `Infrastructure/templates/constitutional-governance.md` — template for project-specific governance (filled into `.claude/rules/constitutional-governance.md`)
- `Infrastructure/templates/requirements-spec.md` — spec template for complex tasks
- `Infrastructure/templates/session_log.md` — session log template

This two-tier rule/template distinction is intentional and correct.

---

## 3. Makefile & Build System

### Targets

| Target | Command | Status |
|--------|---------|--------|
| `brain-sync` | `bash Infrastructure/scripts/manage_generated_copies.sh sync` | **BROKEN — CRLF** |
| `brain-check` | `bash Infrastructure/scripts/manage_generated_copies.sh check` | **BROKEN — CRLF** |
| `brain-simulate` | `bash Infrastructure/scripts/simulate_cps_review_smoke_test.sh` | **BROKEN — CRLF** (calls brain-check internally) |
| `literature-check` | `python3 Infrastructure/scripts/validate_literature_catalog.py` | **BROKEN — CRLF** |
| `maintenance-check` | runs brain-check + literature-check + 2 Python scripts | **BROKEN — CRLF** |

### Script Inventory

| Script | Type | Line Endings | Functional? |
|--------|------|-------------|------------|
| `manage_generated_copies.sh` | bash | CRLF ❌ | No — fails with `$'\r': command not found` |
| `simulate_cps_review_smoke_test.sh` | bash | CRLF ❌ | No — fails at shebang |
| `check_internal_path_references.py` | Python | CRLF ❌ | Yes — Python ignores CRLF |
| `validate_literature_catalog.py` | Python | CRLF ❌ | Yes — Python ignores CRLF |
| `check_catalog_staleness.py` | Python | CRLF ❌ | Yes — Python ignores CRLF |

The Python scripts work despite CRLF because Python's tokenizer handles `\r\n`. The bash scripts fail entirely because the shell interprets the trailing `\r` as a literal character.

---

## 4. Issues Found

### Issue 1 — BLOCKING: CRLF Line Endings in Shell Scripts

**Severity: High**

All five scripts in `Infrastructure/scripts/` were committed with Windows CRLF (`\r\n`) line endings. The bash scripts fail immediately on Linux/Mac:

```
Infrastructure/scripts/manage_generated_copies.sh: line 2: $'\r': command not found
Infrastructure/scripts/manage_generated_copies.sh: line 3: set: pipefail: invalid option name
```

This breaks `make brain-sync`, `make brain-check`, and `make brain-simulate`. The `make maintenance-check` target calls `brain-check` as its first step, so it fails there too.

The `.gitattributes` file only contains `* text=auto`, which tells Git to auto-detect text files but does not force shell scripts to LF on checkout. The fix is to add explicit LF enforcement for script types.

**Fix:**

Add to `.gitattributes`:
```
*.sh    text eol=lf
*.py    text eol=lf
```

Then re-normalize the committed files:
```bash
git add --renormalize .
git commit -m "Normalize script line endings to LF"
```

Alternatively, add a shebang-level workaround for each bash script using `tr -d '\r'` when sourcing, but the `.gitattributes` fix is cleaner and permanent.

---

### Issue 2 — MEDIUM: `manage_generated_copies.sh` Path Resolution Breaks When Piped

**Severity: Medium**

The sync script uses `${BASH_SOURCE[0]}` to find its own location:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

`BASH_SOURCE[0]` is only set when a script is executed as a file, not when its content is piped to `bash -s`. This means the CRLF workaround `sed 's/\r//' script.sh | bash -s check` fails with `unbound variable`. This is a secondary issue that disappears once Issue 1 is fixed and the script runs normally via `make`.

No fix needed beyond fixing the CRLF issue.

---

### Issue 3 — LOW: `code/run_all.R` Placeholder Path Will Fail for Any New User

**Severity: Low**

The starter `run_all.R` uses a user-lookup pattern:
```r
project_directories <- list(
  "name" = "PATH TO GITHUB REPO"
)
current_user <- Sys.info()[["user"]]
if (!current_user %in% names(project_directories)) {
  stop("Root folder for current user is not defined.")
}
```

The only entry in `project_directories` is the literal key `"name"` with a placeholder value. Any researcher running this immediately gets `stop("Root folder for current user is not defined.")`. This is a template placeholder, but a note in the file or `README.md` onboarding steps could make this expectation clearer.

---

### Issue 4 — INFO: Literature Catalog Is Empty

**Severity: Informational**

`Infrastructure/references/literature/catalog.yaml` is a valid YAML file but contains zero entries. `make literature-check` passes with a warning: `"Catalog has no entries yet."` This is correct behavior for a fresh template — noting it here so teams using the template understand they need to populate the catalog before `literature-intake` skills are useful.

---

### Issue 5 — INFO: `PROJECT.md` Is Unfilled

**Severity: Informational**

All fields in `PROJECT.md` are `TBD`. This is the expected state for a template not yet instantiated for a project. The `README.md` onboarding steps correctly instruct the user to fill in the Research Project Title as a first step.

---

## 5. Style Subsystem Assessment

The `Infrastructure/style/` subsystem is well-organized:

| Component | Status |
|-----------|--------|
| Style tokens (`eig-style-tokens.v1.json`) | Present |
| R theme (`eig_theme.R`, `eig_tokens.R`) | Present |
| Python theme (`eig_theme.py`, `eig_tokens.py`) | Present |
| Stata theme (`eig_theme.do`, `eig_tokens.do`) | Present |
| Font assets (Galaxie Polaris, Tiempos families) | Present |
| Compliance scripts (`check_datawrapper_manifest.py`, `check_legacy_metadata.py`) | Present |
| Documentation (brand, figure style, writing style, citation, datawrapper) | Present |
| CI workflow template (`datawrapper-compliance.workflow.template.yml`) | Present |
| Example generators (R, Python, Stata) | Present |
| Style skills (eig-style-apply, eig-style-datawrapper, eig-style-review) | Present, synced |

No issues found in the style subsystem.

---

## 6. Agent & Rule Cross-Reference Map

The following table maps each agent to its governing rule file and output template. All references resolve correctly in both the canonical `Infrastructure/` location and in the adapter copies.

| Agent | Rule File | Output Template |
|-------|----------|----------------|
| `code-reviewer` | `code-quality-rules.md` | `code-error-report.md` |
| `conceptual-consistency-reviewer` | `doc-consistency-rules.md` | `doc-consistency-report.md` |
| `data-consistency-reviewer` | `doc-number-rules.md` | `doc-number-report.md` |
| `methodology-reviewer` | `methodology-rules.md` | `methodology-report.md` |
| `maintenance-agent` | `maintenance-rules.md` | `maintenance-report.md` |
| `orchestrator` | (no dedicated rule; uses `orchestrate.md` command) | `orchestration-plan.md` |
| `eig-writer` | `style-writing-rules.md`, `style-citation-rules.md` | `smart-brevity-output.md`, `style-citation-output.md` |
| `eig-reviewer` | `style-writing-rules.md` | `style-review-report.md` |
| `eig-style-guide-agent` | `style-figure-rules.md`, `style-datawrapper-rules.md` | (via style skills) |
| `eig-data-viz` | `style-figure-rules.md` | (figures/tables) |

All 307 internal path references in `README.md`, `PROJECT.md`, and all `Infrastructure/**/*.md` files pass the path integrity check.

---

## 7. Validation Results Summary

| Check | Command | Result |
|-------|---------|--------|
| Adapter drift (brain-check) | Python simulation of sync logic | **PASS** — zero drift |
| Internal path references | `check_internal_path_references.py` | **PASS** — 307 references |
| Literature catalog integrity | `validate_literature_catalog.py` | **PASS with warning** — 0 entries |
| Catalog staleness | `check_catalog_staleness.py` | **PASS** — 0 entries |
| Shell scripts via make | `make brain-check` | **FAIL** — CRLF line endings |
| Smoke test | `make brain-simulate` | **FAIL** — CRLF line endings |

---

## 8. Recommended Actions

### Priority 1 (Do immediately — blocks all Makefile targets)

Fix CRLF line endings in shell scripts by adding to `.gitattributes`:
```
*.sh    text eol=lf
*.py    text eol=lf
```
Then run `git add --renormalize . && git commit -m "Normalize script line endings to LF"`.

After this fix, run `make maintenance-check` to confirm all checks pass.

### Priority 2 (Before sharing the template with teams)

Clarify the `code/run_all.R` placeholder — either add a comment explaining the user-path pattern, or replace it with a relative-path approach (`here::here()` or working-directory-relative paths) that works immediately without configuration.

### Priority 3 (Optional improvements)

- Add `.gitignore` entries for common R and Python output artifacts (`*.Rdata`, `*.Rhistory`, `*.png`, `*.pdf` in output/) to keep the repo clean as projects accumulate outputs.
- Consider adding `Rscript` or `python3` version pins to a `requirements.txt` or `.Rversion` file to make dependency requirements explicit.
- Populate `Infrastructure/session_logs/` with a first session log capturing the decision to adopt this template, so future agents have bootstrap context on the repo's origin.
