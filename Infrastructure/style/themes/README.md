# EIG Theme Assets

## Canonical Source
All generated token files come from:
`tokens/eig-style-tokens.v1.json`

## Sync Tokens Across Languages
Run from repo root:

```bash
python3 scripts/sync_tokens.py
```

This regenerates:
- `themes/python/eig_tokens.py`
- `themes/r/eig_tokens.R`
- `themes/stata/eig_tokens.do`

## Python Usage
```python
from themes.python.eig_theme import assert_eig_fonts, set_eig_theme, eig_plotly_template

assert_eig_fonts(allow_fallback=False)
set_eig_theme()
```

## R Usage
```r
source("themes/r/eig_theme.R")
tokens <- eig_load_tokens("themes/r/eig_tokens.R")
eig_assert_fonts(tokens, allow_fallback = FALSE)
```

## Stata Usage
```stata
do themes/stata/eig_theme.do
eig_load_tokens "themes/stata/eig_tokens.do"
eig_assert_fonts
eig_graph_defaults
```

## Datawrapper Integration
- Source-of-truth token usage:
Use `tokens/eig-style-tokens.v1.json` (or language token files synced from it) as the only color source for Datawrapper publishing scripts. Do not introduce net-new hex literals when token equivalents exist.
- Legacy palette constraints:
Default Datawrapper outputs to 2022 primary tokens. Legacy semantic sets are exception-only and must satisfy `docs/eig-legacy-palette-policy.md`.
- Repo links: [docs/eig-legacy-palette-policy.md](../docs/eig-legacy-palette-policy.md), [docs/datawrapper-integration.md](../docs/datawrapper-integration.md)
- Metadata and governance behavior:
Datawrapper publishers must always emit run manifests with token/governance fields. If a Datawrapper output uses legacy colors, require metadata fields (`legacy_palette_used`, `legacy_set_id`, `legacy_palette_justification`, `approver`, `approval_date`), validate with `scripts/compliance/check_legacy_metadata.py`, and keep the validation evidence with publish manifest artifacts.
- CI enforcement:
Run `python3 scripts/compliance/check_datawrapper_manifest.py <manifest_path>` in CI and fail on validation errors.
- Reference workflow template:
`docs/ci/datawrapper-compliance.workflow.template.yml`
- Default downstream workflow filename/location:
`.github/workflows/datawrapper-compliance.yml` (alternate path allowed only if documented in the downstream repo README/CONTRIBUTING).
- Downstream adoption checklist:
`docs/datawrapper-downstream-adoption-checklist.md`

## Legacy Metadata Compliance Check
If an output uses a legacy palette:

```bash
python3 scripts/compliance/check_legacy_metadata.py docs/legacy-metadata.template.json
```
