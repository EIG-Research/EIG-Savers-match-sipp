---
name: eig-publication-figure-style
description: Compatibility redirect for legacy style-skill entrypoints. Canonical style skill policy now lives in split skills under Infrastructure/style/skills/.
---

# EIG Style Skill (Compatibility Redirect)

This file is retained for backward compatibility with older workflows that look for a single style skill at `Infrastructure/style/SKILL.md`.

## Canonical Skill Ownership

All style-skill policy is canonicalized in split skill bodies under `Infrastructure/style/skills/`:

1. `Infrastructure/style/skills/eig-style-apply.md`
2. `Infrastructure/style/skills/eig-style-datawrapper.md`
3. `Infrastructure/style/skills/eig-style-review.md`

Adapter-invokable copies are:

1. `.codex/skills/eig-style-*/SKILL.md`
2. `.claude/skills/eig-style-*/SKILL.md`

## Routing Guidance

1. Implementation or style application requests -> `eig-style-apply`
2. Datawrapper publish/compliance requests -> `eig-style-datawrapper`
3. Style audit/review requests -> `eig-style-review`

Do not duplicate or extend policy in this compatibility file. Update the canonical split skills instead.
