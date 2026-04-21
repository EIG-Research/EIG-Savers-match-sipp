# Constitutional Governance Template

**Define immutable principles vs. user preferences for this project.**

## Why Constitutional Governance?

As projects grow, some decisions should stay non-negotiable (quality, reproducibility, collaboration). Others should remain flexible.

Making this explicit prevents:
- repeated debates on settled decisions
- inconsistent rule application
- uncertainty about when to ask vs. decide

## How to Use This Template

1. Copy this file to `Infrastructure/rules/constitutional-governance.md`.
2. Replace bracketed examples with your project's non-negotiables.
3. Remove articles that do not apply.
4. Add new articles when stable patterns emerge.
5. Keep it to 3-7 articles.

## Example Articles (Customize for Your Domain)

### Article I: [Your Primary Artifact Principle]

Examples:
- Source notebooks are authoritative; exports are derived.
- Analysis scripts are authoritative; reports derive from them.
- Source docs (`.qmd`, `.Rmd`, `.md`) are authoritative; output artifacts are derived.

Why this matters: prevents circular dependencies and merge conflicts.

Your version:
[Replace with your primary artifact principle]

### Article II: Plan-First Threshold

Enter plan mode for tasks requiring [YOUR THRESHOLD: e.g., >3 files, >30 minutes, multi-step work].

Why this matters: reduces mid-implementation pivots.

Your exceptions:
[e.g., fast-track exploration, trivial edits, emergencies]

Your version:
[Replace with threshold and exceptions]

### Article III: Quality Gate

Nothing is considered complete below [YOUR THRESHOLD: e.g., 80/100, all tests passing, or explicit reviewer approval].

Why this matters: controls technical and analytical debt.

Your exceptions:
[e.g., exploratory work marked as draft]

Your version:
[Replace with quality threshold and exceptions]

### Article IV: Verification Standard

All artifacts must [YOUR STANDARD: e.g., run/build/render successfully and pass core checks] before completion.

Why this matters: broken outputs block downstream work.

Your exceptions:
[e.g., known issues explicitly documented]

Your version:
[Replace with verification standard and exceptions]

### Article V: [Your File Organization Principle]

Example (structured projects): keep all session documentation in `Infrastructure/session_logs/`.

Why this matters: consistent structure improves handoffs and automation.

Your exceptions:
[e.g., temporary scratch work in a clearly named sandbox]

Your version:
[Replace with your file organization principle]

## User Preferences (Override Anytime)

List flexible patterns that can vary by context:
- naming conventions
- tolerance thresholds
- review depth and style
- report verbosity
- plot/table styling
- citation style

## Requesting Amendment

When a user asks to deviate from an article, ask:

"Are you amending Article X (permanent) or overriding for this task (one-time)?"

Amendment process:
1. user proposes change and rationale
2. discuss implications
3. update governance doc if approved
4. record amendment in session log

## When Not to Use Articles

Do not create articles for:
- personal preferences that do not affect reproducibility/collaboration
- one-off decisions unlikely to recur
- patterns that have not stabilized
- external constraints better documented elsewhere

## Maintenance

Review cadence: quarterly (or every 10 sessions)

Review questions:
- are all articles still relevant?
- are any repeatedly violated?
- are new stable patterns emerging?
- are articles enabling or blocking progress?

## Template Checklist

Before finalizing:
- [ ] 3-7 articles
- [ ] each article has principle, rationale, version, and exceptions
- [ ] user preferences section is populated
- [ ] amendment process is clear
- [ ] review cadence is set
- [ ] file saved at `Infrastructure/rules/constitutional-governance.md`
