# Datawrapper Downstream Adoption Checklist

## Purpose
Provide a fast, repeatable setup checklist for downstream repositories that publish Datawrapper charts with EIG-compliant styling and governance.

## Canonical Sources
1. Integration contract:
`docs/datawrapper-integration.md`
2. Workflow template:
`docs/ci/datawrapper-compliance.workflow.template.yml`
3. Manifest validator:
`scripts/compliance/check_datawrapper_manifest.py`
4. Legacy metadata validator:
`scripts/compliance/check_legacy_metadata.py`

## Required Steps
1. Copy workflow template into downstream repo as:
`.github/workflows/datawrapper-compliance.yml`
2. Set `MANIFEST_GLOB` and `LEGACY_METADATA_GLOB` values to match downstream artifact paths.
3. Ensure publish pipeline emits required manifest fields:
`run_timestamp_utc`, `figure_key`, `chart_id`, `chart_url`, `rows_uploaded`, `palette_mode`, `token_source_path`, `token_version`, `legacy_metadata_path`.
4. Ensure Datawrapper colors are token-derived from:
`tokens/eig-style-tokens.v1.json`
5. Enforce 2022-primary default and legacy exception policy:
`docs/eig-legacy-palette-policy.md`
6. If legacy palette is used, create sidecar metadata and validate it in CI.
7. Confirm CI fails on validator errors.

## Exception Rule
If downstream repo cannot use `.github/workflows/datawrapper-compliance.yml`, it must document the alternate workflow path in that repo's README or CONTRIBUTING file.

## Quick Verification Commands
```bash
python3 "scripts/compliance/check_datawrapper_manifest.py" "<manifest_path>"
python3 "scripts/compliance/check_legacy_metadata.py" "<metadata_json_path>"
```
