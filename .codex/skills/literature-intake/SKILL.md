# Literature Intake Skill

Use this skill when the task involves finding, adding, indexing, or reusing papers, data dictionaries, codebooks, or methodology references.

## Source Priority

1. `Infrastructure/references/literature/catalog.yaml`
2. `Infrastructure/commands/literature-intake.md`
3. Files referenced by matching catalog entries
4. `Infrastructure/references/literature/summaries/` notes

## Workflow

1. Start from the catalog and identify candidate entries using `topic_tags`, `title`, and `relevance_note`.
2. Read the underlying source file(s) before producing claim-level outputs.
3. If the needed source is missing, ingest it using the literature intake playbook and update the catalog.
4. For new summaries, save them in `Infrastructure/references/literature/summaries/` and record `summary_path` in the catalog entry.
5. In deliverables, cite exact repository paths for every source used.

## Minimum Metadata Standard

Each catalog entry should include:

- `id`
- `title`
- `type`
- `topic_tags`
- `path`
- `source_url`
- `added_on`
- `status`
- `relevance_note`

`summary_path` is optional but recommended once an item has been processed.

## Guardrails

- Treat `catalog.yaml` as the discovery index, not as evidence by itself.
- Never invent citations or findings not present in source material.
- Preserve prior entries; do not delete history when new versions are added.
