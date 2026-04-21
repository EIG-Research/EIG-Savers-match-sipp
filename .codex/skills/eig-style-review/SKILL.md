# EIG Style Review

Use this skill when auditing outputs/code for EIG style compliance.

## Source Priority

1. `Infrastructure/style/docs/agent-01-design-spec.md`
2. `Infrastructure/style/docs/eig-legacy-palette-policy.md`
3. `Infrastructure/style/tokens/eig-style-tokens.v1.json`
4. `Infrastructure/style/docs/eig-design-signoff-checklist.md`
5. Language implementation references under `Infrastructure/style/docs/agent-0{2,3,4}-*.md`

## Review Workflow

1. Identify artifact type: figure, table, dashboard, or mixed output set.
2. Check color usage against style tokens.
3. Check typography/layout against style baseline.
4. Confirm legacy-palette usage has required justification.
5. Report concrete findings with path-specific fixes.

## Required Findings Format

1. Severity (`Critical`, `Medium`, `Optional`)
2. Evidence (path + relevant code/output element)
3. Risk
4. Recommended fix
5. Verification step
