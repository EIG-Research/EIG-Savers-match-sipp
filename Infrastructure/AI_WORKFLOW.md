# AI Workflow

Use this workflow for every meaningful session.

## 1) Load context
- Read `PROJECT.md`.
- Read `Infrastructure/GUARDRAILS.md`.
- Identify objective, constraints, and in-scope data.
- If `PROJECT.md` has no title, request it first and pause other work.
- Ask for remaining `PROJECT.md` fields as optional inputs.
- Ask the human to choose full session-summary log frequency for this project.
- Record the chosen full-log frequency in the current session summary.

## 2) Frame the task
- State the task in one sentence.
- Propose a short plan.
- Confirm assumptions if risk is high.

## 3) Execute
- Make the smallest change that moves the task forward.
- Keep files and structure clean.
- Reuse `Infrastructure/` guidance instead of duplicating rules.
- For expensive or long-running jobs, apply `Infrastructure/rules/performance-cost-governance.md` before execution.

## 4) Validate
- Check that output answers the task and aligns with `PROJECT.md`.
- Verify no guardrail violations.
- Classify the output as claim-based or purely mechanical.
- If claim-based, include an `Evidence` section with `Sources`, `Confidence`, and `Assumptions`.
- If purely mechanical, evidence is optional.
- Note any limitations.

## 5) Handoff
- Summarize: what changed, why, and what remains.
- Confirm whether evidence standard was applied and why.
- Always append incremental decision/blocker notes per `Infrastructure/rules/session-logging.md`.
- If this session matches the chosen full-log frequency, add a full session log using `Infrastructure/templates/session_log.md`.
- Save recorded logs in `Infrastructure/session_logs/`.
