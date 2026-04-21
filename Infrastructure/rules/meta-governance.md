# Meta-Governance: This Repository's Dual Nature

**This repository is both a working project shell and a reusable template.**

Use this guide to decide what belongs in shared infrastructure vs. local/project-specific execution context.

## The Two Identities

### Identity 1: Active Project Workspace
- The repo is used to run real research tasks.
- Session decisions, assumptions, and handoffs must be recoverable.
- Workflow should stay practical and low-friction.

### Identity 2: Reusable Template
- Others should be able to copy this structure into new projects.
- Guidance should be domain-flexible and adapter-neutral.
- Avoid embedding one institution, stack, or personal setup as a requirement.

## Decision Framework

Ask: **Is this generic or specific?**

### Generic (commit to template)
- Shared workflow patterns
- Guardrails and verification standards
- Reusable templates and checklists
- Path conventions under `Infrastructure/`

### Specific (keep local or project-only)
- Machine-specific paths and local tooling quirks
- Credentials, local environment workarounds, private notes
- Temporary experiments not worth carrying forward

## Memory and Context Management

### Shared Context (committed)
- `PROJECT.md` for project framing and scope
- `Infrastructure/session_logs/` for recorded session history
- `Infrastructure/plans/` for active plans
- `Infrastructure/specs/` for approved requirement specs

### Local Context (not committed)
- Personal reminders and machine-specific setup notes
- Temporary scratch notes outside shared project docs

## Cross-Machine Principle

Anything required for another agent to resume work should be in shared context files, not only in chat history or local-only notes.

## Dogfooding Rules

### Plan-First
- Do: plan non-trivial work and save plans to `Infrastructure/plans/`.
- Do not: begin large multi-file changes without an approved plan.

### Spec-Then-Plan
- Do: create a spec for ambiguous/high-effort tasks in `Infrastructure/specs/`.
- Do not: assume unclear requirements without documenting assumptions.

### Verification
- Do: verify outputs before claiming completion.
- Do not: ship unverified changes.

### Session Logging
- Do: keep `Infrastructure/session_logs/` current.
- Do not: leave major decisions undocumented.

## Template Maintenance Principles

### Keep It Generic
Bad: "Always use tool X and layout Y."
Good: "Use project-specific tooling; document chosen commands in repo docs."

### Prefer Frameworks Over Prescriptions
Bad: "File must be named exactly `some_fixed_name.ext`."
Good: "Define one authoritative source and keep derivatives synchronized."

### Keep Adapters Thin
- `.claude/` and `.codex/` should point to `Infrastructure/`.
- Shared logic should live once in `Infrastructure/`.

## Amendment Process

When a principle is challenged:
1. Decide whether change is permanent or task-specific.
2. Document rationale and tradeoffs in session log.
3. Update governance docs if permanent.

## Quick Reference

| Content Type | Commit? | Location |
|--------------|---------|----------|
| Project framing | Yes | `PROJECT.md` |
| Shared guardrails and workflow | Yes | `Infrastructure/` |
| Plans | Yes | `Infrastructure/plans/` |
| Specs | Yes | `Infrastructure/specs/` |
| Session logs | Yes | `Infrastructure/session_logs/` |
| Local machine notes | No | local-only files |

## Summary

When in doubt, prioritize portability, recoverability, and minimal adapter-specific logic.
