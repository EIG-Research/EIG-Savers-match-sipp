# Infrastructure

Shared operating system for AI work in this repo.

## Purpose
- Keep core workflow and guardrails in one place used by all agent adapters.
- Keep one canonical AI brain (review + style) shared across `.claude/` and `.codex/`.

## Files
- `GUARDRAILS.md`: Non-negotiable behavior and safety rules.
- `AI_WORKFLOW.md`: Session process from intake to handoff.
- `agents/`: Canonical agent specs (review + EIG style roles) used to generate adapter copies.
- `commands/`: Canonical command playbooks (review + EIG style commands) used to generate adapter copies.
- `rules/`: Shared governance plus canonical review/style rule files.
- `templates/`: Shared template files plus canonical review/style templates.
- `references/`: Canonical reusable references (including literature catalogs and source stores).
- `skills/`: Canonical non-style skills used to generate adapter skill copies.
- `style/`: EIG style subsystem (docs, tokens, themes, scripts, assets, examples, skills).
- `scripts/manage_generated_copies.sh`: Generates `.claude/` and `.codex/` copies (including Infrastructure and style skills) and checks drift.
- `scripts/validate_literature_catalog.py`: Validates literature catalog entries (required fields, IDs, and file paths).
- `scripts/check_internal_path_references.py`: Validates internal markdown path references to canonical repo files.
- `scripts/check_catalog_staleness.py`: Flags literature entries that have not been verified recently.
- `scripts/simulate_cps_review_smoke_test.sh`: CPS-themed smoke test for adapter content and discovery logic.
- `session_logs/`: Storage folder for all recorded session logs.
- `plans/`: Saved plans for non-trivial work.
- `specs/`: Requirements specifications for complex/ambiguous tasks.
- `explorations/`: Sandbox space for early experiments.

## Update policy
- Change shared logic here first.
- Update review/style logic in canonical Infrastructure files; regenerate adapter copies (including skills) with `make brain-sync`.
- Enforce no-drift with `make brain-check`.
- Non-style skills are canonicalized under `Infrastructure/skills/` and style skills under `Infrastructure/style/skills/`, with copies in `.codex/skills/` and `.claude/skills/`.
