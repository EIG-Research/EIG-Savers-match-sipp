# Skill: /orchestrate

Create and run a dependency-aware execution plan for a multi-step task using specialist agents and command playbooks.

## Trigger

User runs `/orchestrate <objective>`

## Steps

1. Read:
   - `.codex/agents/orchestrator.md`
   - `Infrastructure/GUARDRAILS.md`
   - `Infrastructure/AI_WORKFLOW.md`
2. Classify the objective into workstreams (code, methodology, numbers, consistency, writing, style, maintenance).
3. Build a dependency graph and execution waves:
   - What can run now
   - What is blocked and by what
4. Route each workstream to the correct specialist agent/command.
5. Run independent workstreams in parallel when safe.
6. Re-plan after each wave and continue until completion criteria are met.
7. Report status and next action using `.codex/templates/orchestration-plan.md`.

## Constraints

1. Respect `.codex/rules/performance-cost-governance.md` for expensive runs.
2. Do not run downstream review steps when upstream pipeline checks fail.
3. Escalate for human confirmation when a Tier 4 run is required.
