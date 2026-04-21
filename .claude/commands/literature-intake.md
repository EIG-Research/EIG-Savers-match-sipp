# Literature Intake Playbook

Use this playbook whenever a paper, data dictionary, codebook, or related reference is found and should be reusable in future sessions.

## Canonical Locations

- Catalog: `Infrastructure/references/literature/catalog.yaml`
- Papers: `Infrastructure/references/literature/papers/`
- Data dictionaries and codebooks: `Infrastructure/references/literature/data_dictionaries/`
- Agent-written summaries and extraction notes: `Infrastructure/references/literature/summaries/`

## Required Catalog Fields

Every new item must include:

- `id`: stable slug (`YYYY-short-title`)
- `title`: document title
- `type`: `paper`, `data_dictionary`, `codebook`, `technical_note`, or `other`
- `topic_tags`: short tag list for retrieval (for example `labor-markets`, `occupation-codes`)
- `path`: repository-relative file path to the stored artifact
- `source_url`: original source URL if available (`null` if unavailable)
- `added_on`: ISO date (`YYYY-MM-DD`)
- `status`: `raw`, `parsed`, `summarized`, `verified`, or `archived`
- `relevance_note`: 1-2 sentence reason this matters for the project/template

## Intake Workflow

1. Save the artifact into the correct folder.
2. Use deterministic file naming:
   - Paper: `YYYY_author_short-title.pdf`
   - Data dictionary/codebook: `YYYY_dataset_dictionary.ext`
3. Add or update an entry in `catalog.yaml`.
4. If text extraction or a summary is created, save it in `summaries/` and add `summary_path` in the catalog entry.
5. If the item supersedes an older version, keep both files and set the older entry `status` to `archived` with a short note.
6. Run `python3 Infrastructure/scripts/validate_literature_catalog.py` and fix any errors.

## Retrieval Rules For Agents

1. Search `catalog.yaml` first before broad repository scans.
2. Filter by `type`, `topic_tags`, and keyword match in `title`/`relevance_note`.
3. Cite exact file paths used in final outputs.
4. Do not make claim-level assertions from catalog metadata alone; read the underlying source file first.

## Quality Check Before Handoff

- [ ] Artifact path exists and is readable
- [ ] Catalog entry contains all required fields
- [ ] `topic_tags` are specific enough for future retrieval
- [ ] Any summary/extract path resolves correctly
