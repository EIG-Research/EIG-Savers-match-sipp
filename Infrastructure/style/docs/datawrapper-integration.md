# Datawrapper Integration for R Pipelines

## Purpose
Define a single, auditable contract for applying EIG styling to Datawrapper outputs produced by R pipelines.

## Canonical Inputs
Use these files as the only authoritative sources:

1. Token source of truth:
`tokens/eig-style-tokens.v1.json`
2. Design rules:
`docs/agent-01-design-spec.md`
3. R implementation patterns:
`docs/agent-02-r-implementation.md`
4. Legacy palette policy:
`docs/eig-legacy-palette-policy.md`
5. Signoff/governance checklist:
`docs/eig-design-signoff-checklist.md`

## Required Integration Contract

### 1) Token loading and color selection
- Load Datawrapper colors from token IDs, not hardcoded hex values.
- Preferred source is the JSON token file above; generated R tokens are acceptable only when they were synced from the same repo state.
- Persist `token_source_path` and token `meta.version` in publish manifests.

Example (token-derived color map):

```r
eig_load_datawrapper_colors <- function(
  token_json_path = "tokens/eig-style-tokens.v1.json"
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required.", call. = FALSE)
  }
  token_doc <- jsonlite::read_json(token_json_path, simplifyVector = TRUE)
  brand_df <- token_doc$colors$brand
  brand_hex <- stats::setNames(brand_df$hex, brand_df$id)

  list(
    token_version = token_doc$meta$version,
    discrete = unname(c(
      brand_hex[["eig_teal_900"]],
      brand_hex[["eig_blue_800"]],
      brand_hex[["eig_green_500"]],
      brand_hex[["eig_gold_600"]],
      brand_hex[["eig_purple_800"]],
      brand_hex[["eig_cyan_700"]],
      brand_hex[["eig_tan_500"]]
    ))
  )
}
```

### 2) Palette policy gate (2022 primary by default)
- Set `palette_mode = "primary_2022"` for all new outputs unless a legacy exception is explicitly valid.
- Legacy semantic palettes are allowed only under `docs/eig-legacy-palette-policy.md`.
- Never mix legacy semantic colors with 2022 categorical colors in the same legend without documented rationale.

### 3) Legacy metadata and validation
If `palette_mode = "legacy"`, metadata is mandatory:

1. `legacy_palette_used: true`
2. `legacy_set_id`
3. `legacy_palette_justification`
4. `approver`
5. `approval_date` (`YYYY-MM-DD`)

Use:
- Template:
`docs/legacy-metadata.template.json`
- Validator:
`scripts/compliance/check_legacy_metadata.py`

Validation command:

```bash
python3 "scripts/compliance/check_legacy_metadata.py" "<metadata_json_path>"
```

### 4) Datawrapper API behavior guardrails
- Use `DatawRappr::dw_data_to_chart(x = data_frame, chart_id = chart_id)`.
- Do not rely on a fixed return type from `DatawRappr::dw_test_key()`; treat object/list success responses as valid and fail only on explicit errors.
- Keep auth material outside tracked code and load `DATAWRAPPER_API_KEY` from a gitignored local secret file.

### 5) Chart identity and auditable manifests
- Publish manifests are mandatory for all Datawrapper R pipelines.
- Persist `figure_key -> chart_id` mapping so reruns update existing charts rather than creating replacements.
- Emit one publish manifest per run with at least:
  - `run_timestamp_utc`
  - `figure_key`
  - `chart_id`
  - `chart_url`
  - `rows_uploaded`
  - `palette_mode`
  - `token_source_path`
  - `token_version`
  - `legacy_metadata_path` (empty when primary palette is used)
- Pipelines that do not emit this required manifest schema are non-compliant with EIG style-system governance.

### 5.1) Required CI enforcement
- CI must fail if any Datawrapper publish manifest is missing required fields or contains invalid values.
- Required validator:
`scripts/compliance/check_datawrapper_manifest.py`
- Required CI command (per manifest):

```bash
python3 "scripts/compliance/check_datawrapper_manifest.py" "<manifest_path>"
```
- Reference workflow template to copy into downstream repositories:
`docs/ci/datawrapper-compliance.workflow.template.yml`
- Repo link: [docs/ci/datawrapper-compliance.workflow.template.yml](ci/datawrapper-compliance.workflow.template.yml)
- Default downstream workflow location/name (recommended standard):
`.github/workflows/datawrapper-compliance.yml`
- Exception rule:
If a downstream repo cannot use the default path/name, it must document the alternate workflow path in that repo's README or CONTRIBUTING guide.

### 6) Applying token colors to Datawrapper line charts
Use token-derived colors when updating chart visualization settings:

```r
apply_eig_line_colors <- function(chart_id, series_names, series_colors) {
  line_config <- Map(
    f = function(label, color_hex) list(name = label, color = color_hex, width = 2),
    label = series_names,
    color_hex = series_colors
  )
  DatawRappr::dw_edit_chart(
    chart_id = chart_id,
    visualize = list(lines = line_config)
  )
}
```

## Pre-Publish Checklist (Required)
1. Tokens loaded from canonical source path.
2. `palette_mode` recorded for each chart.
3. Legacy exception justification and metadata captured (if applicable).
4. Legacy metadata validator passes (if applicable).
5. `figure_key -> chart_id` config updated and committed where required.
6. Publish manifest written with token and governance fields.
7. Manifest validator passes in CI:
`python3 scripts/compliance/check_datawrapper_manifest.py <manifest_path>`

## Related Docs
- Entry point:
`DATAWRAPPER_PIPELINE_AGENT_HANDOFF.md`
- Theme assets overview:
`themes/README.md`
- Downstream setup checklist:
`docs/datawrapper-downstream-adoption-checklist.md`
- Repo links: [DATAWRAPPER_PIPELINE_AGENT_HANDOFF.md](../DATAWRAPPER_PIPELINE_AGENT_HANDOFF.md), [themes/README.md](../themes/README.md)
- Repo link: [docs/datawrapper-downstream-adoption-checklist.md](datawrapper-downstream-adoption-checklist.md)
