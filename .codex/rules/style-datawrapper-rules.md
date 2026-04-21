# Style Datawrapper Rules

Binding rules for Datawrapper publishing compliance under EIG style governance.

## Canonical Sources

- `Infrastructure/style/docs/datawrapper-integration.md`
- `Infrastructure/style/docs/datawrapper-downstream-adoption-checklist.md`
- `Infrastructure/style/docs/eig-legacy-palette-policy.md`
- `Infrastructure/style/scripts/compliance/check_datawrapper_manifest.py`
- `Infrastructure/style/scripts/compliance/check_legacy_metadata.py`

## Manifest Requirements

Required manifest fields:

- `run_timestamp_utc`
- `figure_key`
- `chart_id`
- `chart_url`
- `rows_uploaded`
- `palette_mode`
- `token_source_path`
- `token_version`
- `legacy_metadata_path`

## Validation Commands

- `python3 Infrastructure/style/scripts/compliance/check_datawrapper_manifest.py <manifest_path>`
- `python3 Infrastructure/style/scripts/compliance/check_legacy_metadata.py <metadata_json_path>`

If `palette_mode=legacy`, metadata sidecar fields are mandatory per policy.
