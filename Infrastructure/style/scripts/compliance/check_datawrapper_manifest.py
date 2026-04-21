#!/usr/bin/env python3
"""Validate required Datawrapper publish manifest fields for EIG compliance."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


REQUIRED_FIELDS = [
    "run_timestamp_utc",
    "figure_key",
    "chart_id",
    "chart_url",
    "rows_uploaded",
    "palette_mode",
    "token_source_path",
    "token_version",
    "legacy_metadata_path",
]

VALID_PALETTE_MODES = {"primary_2022", "legacy"}


def _load_rows(path: Path) -> list[dict[str, str]]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            return [dict(row) for row in reader]

    if suffix == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            if "rows" in data and isinstance(data["rows"], list):
                return [dict(r) for r in data["rows"] if isinstance(r, dict)]
            return [dict(data)]
        if isinstance(data, list):
            return [dict(r) for r in data if isinstance(r, dict)]
        raise ValueError("JSON manifest must be an object or list of objects.")

    raise ValueError("Unsupported manifest format. Use .csv or .json.")


def _is_blank(value: object) -> bool:
    return value is None or str(value).strip() == ""


def _validate_row(row: dict[str, str], index: int) -> list[str]:
    errors: list[str] = []
    prefix = f"row {index}"

    for field in REQUIRED_FIELDS:
        if field not in row:
            errors.append(f"{prefix}: missing required field '{field}'")
            continue
        if _is_blank(row.get(field)):
            if field == "legacy_metadata_path":
                continue
            errors.append(f"{prefix}: field '{field}' must be non-empty")

    palette_mode = str(row.get("palette_mode", "")).strip()
    if palette_mode and palette_mode not in VALID_PALETTE_MODES:
        errors.append(
            f"{prefix}: field 'palette_mode' must be one of {sorted(VALID_PALETTE_MODES)}"
        )

    rows_uploaded = str(row.get("rows_uploaded", "")).strip()
    if rows_uploaded:
        try:
            val = int(rows_uploaded)
            if val < 0:
                errors.append(f"{prefix}: field 'rows_uploaded' must be >= 0")
        except ValueError:
            errors.append(f"{prefix}: field 'rows_uploaded' must be an integer")

    chart_url = str(row.get("chart_url", "")).strip()
    if chart_url and not (chart_url.startswith("http://") or chart_url.startswith("https://")):
        errors.append(f"{prefix}: field 'chart_url' must start with http:// or https://")

    legacy_path = str(row.get("legacy_metadata_path", "")).strip()
    if palette_mode == "legacy" and not legacy_path:
        errors.append(
            f"{prefix}: field 'legacy_metadata_path' is required when palette_mode=legacy"
        )
    if palette_mode == "primary_2022" and legacy_path:
        errors.append(
            f"{prefix}: field 'legacy_metadata_path' must be empty when palette_mode=primary_2022"
        )

    return errors


def validate(path: Path) -> list[str]:
    try:
        rows = _load_rows(path)
    except (json.JSONDecodeError, ValueError) as exc:
        return [f"Invalid manifest: {exc}"]

    if not rows:
        return ["Manifest contains no data rows."]

    errors: list[str] = []
    for idx, row in enumerate(rows, start=1):
        errors.extend(_validate_row(row, idx))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest_path", help="Path to Datawrapper manifest (.csv or .json)")
    args = parser.parse_args()

    manifest_path = Path(args.manifest_path)
    if not manifest_path.exists():
        print(f"ERROR: Manifest file not found: {manifest_path}", file=sys.stderr)
        return 2

    errors = validate(manifest_path)
    if errors:
        print("FAIL: Datawrapper manifest validation errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("PASS: Datawrapper manifest validation successful.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
