---
name: eig-style-datawrapper
description: Enforce EIG Datawrapper style and governance compliance using vendored validators and policy docs.
argument-hint: "[manifest path]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

# EIG Style Datawrapper Compliance

Use this skill when Datawrapper publishing is in scope.

## Source Priority

1. `Infrastructure/style/docs/datawrapper-integration.md`
2. `Infrastructure/style/docs/datawrapper-downstream-adoption-checklist.md`
3. `Infrastructure/style/docs/eig-legacy-palette-policy.md`
4. `Infrastructure/style/scripts/compliance/check_datawrapper_manifest.py`
5. `Infrastructure/style/scripts/compliance/check_legacy_metadata.py`
6. `Infrastructure/style/docs/legacy-metadata.template.json`

## Workflow

1. Ensure colors are token-derived from `Infrastructure/style/tokens/eig-style-tokens.v1.json`.
2. Validate publish manifest:
   - `python3 Infrastructure/style/scripts/compliance/check_datawrapper_manifest.py <manifest_path>`
3. If `palette_mode=legacy`, validate metadata:
   - `python3 Infrastructure/style/scripts/compliance/check_legacy_metadata.py <metadata_json_path>`
4. For downstream CI setup, use:
   - `Infrastructure/style/docs/ci/datawrapper-compliance.workflow.template.yml`

## Required Manifest Fields

- `run_timestamp_utc`
- `figure_key`
- `chart_id`
- `chart_url`
- `rows_uploaded`
- `palette_mode`
- `token_source_path`
- `token_version`
- `legacy_metadata_path`
