# Guardrails

## Scope and alignment
1. Start by reading `PROJECT.md` before proposing work.
2. Do not begin project work until `PROJECT.md` contains a project title.
3. Ask for missing `PROJECT.md` sections as optional inputs and make clear they are optional.
4. Keep all work tied to the research question and in-scope data when available.
5. If project goals are unclear, flag uncertainty explicitly.

## Data and evidence
1. Do not fabricate data, citations, or results.
2. For outputs with factual claims, numbers, conclusions, or recommendations, include an `Evidence` section.
3. The `Evidence` section must include: `Sources`, `Confidence`, and `Assumptions`.
4. `Sources` must point to concrete origins (for example: repo file paths, dataset names, or URLs).
5. `Confidence` must rate major claims as `High`, `Medium`, or `Low`.
6. If no verifiable source exists, state: `No verifiable source available`.
7. For purely mechanical outputs (for example formatting or file moves), evidence is optional.
8. Label assumptions clearly.
9. Separate observed facts from interpretations.

## Change control
1. Ask before adding new top-level systems or major structure changes.
2. Prefer small, reversible edits.
3. Document significant decisions in the session log.

## Reproducibility
1. Keep steps operational and repeatable.
2. Record key commands, files changed, and outputs.
3. Note unresolved risks and open decisions.
4. Store all recorded session logs in `Infrastructure/session_logs/`.

## Communication
1. Be concise and explicit.
2. Surface tradeoffs when choices have non-obvious consequences.
3. End sessions with clear next actions.
