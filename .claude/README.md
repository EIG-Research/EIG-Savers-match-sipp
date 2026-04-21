# Claude Adapter

Claude-facing adapter to the shared AI brain.

## Startup order
1. `../PROJECT.md`
2. If title is missing, request title and pause other work.
3. Ask for remaining `PROJECT.md` sections as optional inputs.
4. `../Infrastructure/GUARDRAILS.md`
5. `../Infrastructure/AI_WORKFLOW.md`
6. Review relevant files in `../Infrastructure/rules/`.
7. Ask for full session-summary log frequency and follow it.
8. Keep incremental decision logs current, and use `../Infrastructure/templates/session_log.md` for full logs in `../Infrastructure/session_logs/`.

## Shared brain links
- `agents/`, `commands/`, `rules/`, `templates/` are generated copies from canonical files in `../Infrastructure/`.
- Canonical review content lives in `../Infrastructure/agents/`, `../Infrastructure/commands/`, `../Infrastructure/rules/`, and `../Infrastructure/templates/`.
- Canonical style-system assets live in `../Infrastructure/style/`.
- Invokable style skills live in `skills/` and map to canonical skill bodies in `../Infrastructure/style/skills/`.
- Refresh local copies (including skills) with `make brain-sync`; verify drift with `make brain-check`.

## Adapter rules
- Treat `../Infrastructure/` as source of truth for core workflow and guardrails.
- Use canonical review files in `../Infrastructure/` as source of truth for review workflows.
- Evidence standard is enforced through `../Infrastructure/GUARDRAILS.md` (no separate slash command or agent needed).
- Do not fork review logic in `.claude/`; update canonical files in `../Infrastructure/` and regenerate.
