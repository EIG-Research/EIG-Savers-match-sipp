# Session Logging

**Location:** `Infrastructure/session_logs/YYYY-MM-DD_description.md`
**Template:** `Infrastructure/templates/session_log.md`

## Frequency Setting

- Ask the user for a cadence for full session-summary logs (for example: every session, daily, milestone-based).
- This cadence controls full template-style summaries only.
- It does **not** waive incremental decision/blocker logging.

## Three Triggers (all proactive)

### 1. Post-Plan Log

After plan approval for non-trivial work, capture goal, approach, rationale, and key context.

### 2. Incremental Logging

Append 1-3 lines whenever a design decision is made, a blocker is resolved, the user corrects something, or the approach changes. Do not batch.

### 3. End-of-Session Log

When wrapping up, record high-level summary, evidence standard status, open questions, and blockers whenever the chosen full-log cadence is met or a major handoff is needed.

## Merge-Time Reports (Optional)

If merge reports are used, save them to:

`Infrastructure/session_logs/merges/YYYY-MM-DD_[branch-name].md`
