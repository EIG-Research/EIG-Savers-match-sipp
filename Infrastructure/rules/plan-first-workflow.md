# Plan-First Workflow

**For any non-trivial task, plan before implementation.**

## The Protocol

1. **Load context** -- read `PROJECT.md`, `Infrastructure/GUARDRAILS.md`, and `Infrastructure/AI_WORKFLOW.md`.
2. **Check recent context** -- review relevant entries in `Infrastructure/session_logs/`.
3. **Requirements specification (for complex/ambiguous tasks)** -- see below.
4. **Draft the plan** -- define changes, files, order, and verification.
5. **Save to disk** -- write to `Infrastructure/plans/YYYY-MM-DD_short-description.md`.
6. **Present to user** -- wait for approval.
7. **Begin implementation** -- only after approval.
8. **Start session logging** -- capture goal and key context while fresh, then keep incremental decision logs current.
9. **Execute and verify** -- follow `Infrastructure/AI_WORKFLOW.md`.

## Step 3: Requirements Specification (For Complex/Ambiguous Tasks)

**When to use:**
- Task is high-level or vague (for example: "improve this analysis")
- Multiple valid interpretations exist
- Significant effort required (>1 hour or >3 files)

**When to skip:**
- Task is clear and specific (for example: "fix typo in line 42")
- Simple single-file edit
- User already provided detailed requirements

**Protocol:**
1. Ask direct clarification questions in chat (max 3-5 concise questions).
2. Create `Infrastructure/specs/YYYY-MM-DD_description.md` using `Infrastructure/templates/requirements-spec.md`.
3. Mark each requirement:
   - **MUST** (non-negotiable)
   - **SHOULD** (preferred)
   - **MAY** (optional)
4. Declare clarity status for each major aspect:
   - **CLEAR:** Fully specified
   - **ASSUMED:** Reasonable assumption (user can override)
   - **BLOCKED:** Cannot proceed until answered
5. Get user approval on the spec.
6. Then proceed to plan drafting with the approved spec as input.

**Template:** `Infrastructure/templates/requirements-spec.md`

## Plans on Disk

Plans survive context changes. Save every plan to:

```
Infrastructure/plans/YYYY-MM-DD_short-description.md
```

Format: Status (DRAFT/APPROVED/COMPLETED), approach, files to modify, verification steps.

## Context Management

### General Principles
- Preserve important context on disk.
- Keep incremental session logs current during active work; add full session summaries per chosen cadence.
- Avoid relying only on chat history for project continuity.

### Context Survival Strategy
Before long or complex sessions end, ensure:
1. Current plan is saved to `Infrastructure/plans/`.
2. Open decisions are captured in `Infrastructure/session_logs/`.
3. Key assumptions are reflected in `PROJECT.md` or the current session log.

## Session Recovery

After a new session starts:
1. Read `PROJECT.md` and the most recent plan in `Infrastructure/plans/`.
2. Read the most recent session log in `Infrastructure/session_logs/`.
3. Check `git status`, `git log --oneline -10`, and `git diff`.
4. State what you understand the current task to be before continuing.
