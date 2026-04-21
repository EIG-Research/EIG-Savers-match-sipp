# EIG Style Porting Inventory

## Source Repositories Reviewed

- `/Users/benjamin/Documents/GitHub/eig-style-guide`
- `/Users/benjamin/Documents/GitHub/eig-baseline-shell`

## Identified Style Elements

### Core style system (from `eig-style-guide`)

- Tokens: `tokens/eig-style-tokens.v1.json`
- Themes: `themes/{python,r,stata}`
- Compliance scripts: `scripts/compliance/`
- Font scripts: `scripts/fonts/`
- Datawrapper handoff: `DATAWRAPPER_PIPELINE_AGENT_HANDOFF.md`
- Canonical style docs: `docs/`
- Style examples: `examples/`
- Source guides (PDF/DOCX): `2022 Style Guide.pdf`, `2020 EIG Design Style Guide.docx`
- Legacy compatibility skill wrapper: `SKILL.md` (redirects to canonical split skills)

### Style-adjacent governance and AI operating assets (from `eig-baseline-shell`)

- Hidden adapter style agents:
  - `INFRA/.codex/agents/eig-{style-guide-agent,data-viz,reviewer,writer}.md`
  - `INFRA/.claude/agents/eig-{style-guide-agent,data-viz,reviewer,writer}.md`
- Hidden adapter style commands:
  - `INFRA/.codex/commands/{review-style,cite,cover-sheet,smart-brevity}.md`
  - `INFRA/.claude/commands/{review-style,cite,cover-sheet,smart-brevity}.md`
- Root adapter style skills:
  - `.codex/skills/eig-style-{apply,review,datawrapper}/SKILL.md`
  - `.claude/skills/eig-style-{apply,review,datawrapper}/SKILL.md`
- Editorial style docs:
  - `INFRA/docs/eig-{writing-style,citation-style,document-process,brand-guidelines,figure-style}.md`
- Brand assets:
  - `INFRA/assets/fonts/`
  - `INFRA/assets/logo/`

## Porting Approach Chosen

1. Keep a single canonical style subsystem under `Infrastructure/style/`.
2. Keep canonical AI behavior in `Infrastructure/{agents,commands,rules,templates}/`.
3. Auto-generate `.codex/` and `.claude/` copies from canonical Infrastructure files using existing sync tooling.
4. Keep adapter-invokable style skills in root adapter folders (`.codex/skills`, `.claude/skills`) with canonical bodies under `Infrastructure/style/skills/`.

## Destination Mapping

- Core style system -> `Infrastructure/style/`
- Source PDFs/DOCX -> `Infrastructure/style/sources/`
- Editorial style docs -> `Infrastructure/style/docs/eig-*.md`
- Canonical style agents -> `Infrastructure/agents/eig-*.md`
- Canonical style commands -> `Infrastructure/commands/{review-style,cite,cover-sheet,smart-brevity}.md`
- Canonical style rules -> `Infrastructure/rules/style-*.md`
- Canonical style templates -> `Infrastructure/templates/style-*.md` and `Infrastructure/templates/smart-brevity-output.md`
- Adapter style skills (Codex) -> `.codex/skills/eig-style-*/SKILL.md`
- Adapter style skills (Claude) -> `.claude/skills/eig-style-*/SKILL.md`

## Why this structure

- One source of truth for maintainability.
- Adapter parity for commands/rules/templates/agents via `make brain-sync`.
- Full style payload available locally (tokens/themes/docs/scripts/assets/sources/examples).
- Style skills remain directly invokable in each adapter while still anchored to canonical skill bodies.
