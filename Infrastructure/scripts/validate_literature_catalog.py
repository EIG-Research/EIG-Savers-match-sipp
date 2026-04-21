#!/usr/bin/env python3
"""Validate literature catalog structure and entry metadata."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "id",
    "title",
    "type",
    "topic_tags",
    "path",
    "source_url",
    "added_on",
    "status",
    "relevance_note",
}

ALLOWED_TYPES = {"paper", "data_dictionary", "codebook", "technical_note", "other"}
ALLOWED_STATUS = {"raw", "parsed", "summarized", "verified", "archived"}


def _load_with_pyyaml(path: Path) -> Any:
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError("PyYAML is not installed") from exc

    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _load_with_ruby(path: Path) -> Any:
    cmd = [
        "ruby",
        "-rjson",
        "-ryaml",
        "-rdate",
        "-e",
        (
            "data = YAML.safe_load("
            "File.read(ARGV[0]), permitted_classes: [Date, Time], aliases: true"
            "); puts JSON.generate(data)"
        ),
        str(path),
    ]

    try:
        output = subprocess.check_output(cmd, text=True)
    except FileNotFoundError as exc:
        raise RuntimeError("Ruby is not available") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"Ruby YAML parse failed: {exc}") from exc

    return json.loads(output)


def load_catalog(path: Path) -> Any:
    try:
        return _load_with_pyyaml(path)
    except RuntimeError:
        try:
            return _load_with_ruby(path)
        except RuntimeError as exc:
            raise RuntimeError(
                "Unable to parse YAML catalog. Install PyYAML (`pip install pyyaml`) "
                "or run with Ruby available."
            ) from exc


def is_iso_date(value: Any) -> bool:
    if isinstance(value, dt.date):
        return True
    if not isinstance(value, str):
        return False
    try:
        dt.date.fromisoformat(value)
        return True
    except ValueError:
        return False


def validate_catalog(catalog: Any, repo_root: Path, catalog_path: Path) -> tuple[list[str], list[str], int]:
    errors: list[str] = []
    warnings: list[str] = []

    if not isinstance(catalog, dict):
        return ["Catalog root must be a YAML mapping."], warnings, 0

    version = catalog.get("version")
    if not isinstance(version, int):
        errors.append("Top-level `version` must be an integer.")

    last_updated = catalog.get("last_updated")
    if not is_iso_date(last_updated):
        errors.append("Top-level `last_updated` must be an ISO date (`YYYY-MM-DD`).")

    entries = catalog.get("entries")
    if entries is None:
        errors.append("Top-level `entries` key is missing.")
        return errors, warnings, 0
    if not isinstance(entries, list):
        errors.append("Top-level `entries` must be a list.")
        return errors, warnings, 0

    seen_ids: set[str] = set()

    for index, entry in enumerate(entries, start=1):
        label = f"entry #{index}"

        if not isinstance(entry, dict):
            errors.append(f"{label}: entry must be a mapping.")
            continue

        missing = REQUIRED_FIELDS - set(entry.keys())
        if missing:
            missing_keys = ", ".join(sorted(missing))
            errors.append(f"{label}: missing required keys: {missing_keys}.")

        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id.strip():
            errors.append(f"{label}: `id` must be a non-empty string.")
            entry_id = None
        else:
            if entry_id in seen_ids:
                errors.append(f"{label}: duplicate `id` value `{entry_id}`.")
            seen_ids.add(entry_id)
            label = f"entry `{entry_id}`"

        title = entry.get("title")
        if not isinstance(title, str) or not title.strip():
            errors.append(f"{label}: `title` must be a non-empty string.")

        entry_type = entry.get("type")
        if entry_type not in ALLOWED_TYPES:
            allowed_types = ", ".join(sorted(ALLOWED_TYPES))
            errors.append(f"{label}: `type` must be one of: {allowed_types}.")

        topic_tags = entry.get("topic_tags")
        if not isinstance(topic_tags, list) or not topic_tags:
            errors.append(f"{label}: `topic_tags` must be a non-empty list.")
        else:
            for tag in topic_tags:
                if not isinstance(tag, str) or not tag.strip():
                    errors.append(f"{label}: each `topic_tags` value must be a non-empty string.")
                    break

        rel_path = entry.get("path")
        if not isinstance(rel_path, str) or not rel_path.strip():
            errors.append(f"{label}: `path` must be a non-empty repository-relative path string.")
        else:
            if rel_path.startswith("/"):
                errors.append(f"{label}: `path` must be repository-relative, not absolute.")
            else:
                path_obj = (repo_root / rel_path).resolve()
                if not path_obj.exists():
                    errors.append(f"{label}: `path` does not exist: `{rel_path}`.")
                elif path_obj.is_dir():
                    errors.append(f"{label}: `path` points to a directory, expected a file: `{rel_path}`.")

        source_url = entry.get("source_url")
        if source_url is not None:
            if not isinstance(source_url, str) or not source_url.strip():
                errors.append(f"{label}: `source_url` must be null or a non-empty URL string.")
            elif not (source_url.startswith("http://") or source_url.startswith("https://")):
                errors.append(f"{label}: `source_url` must start with `http://` or `https://`.")

        added_on = entry.get("added_on")
        if not is_iso_date(added_on):
            errors.append(f"{label}: `added_on` must be an ISO date (`YYYY-MM-DD`).")

        status = entry.get("status")
        if status not in ALLOWED_STATUS:
            allowed_status = ", ".join(sorted(ALLOWED_STATUS))
            errors.append(f"{label}: `status` must be one of: {allowed_status}.")

        relevance_note = entry.get("relevance_note")
        if not isinstance(relevance_note, str) or not relevance_note.strip():
            errors.append(f"{label}: `relevance_note` must be a non-empty string.")

        summary_path = entry.get("summary_path")
        if summary_path is not None:
            if not isinstance(summary_path, str) or not summary_path.strip():
                errors.append(f"{label}: `summary_path` must be null or a non-empty path string.")
            elif summary_path.startswith("/"):
                errors.append(f"{label}: `summary_path` must be repository-relative, not absolute.")
            else:
                summary_obj = (repo_root / summary_path).resolve()
                if not summary_obj.exists():
                    errors.append(f"{label}: `summary_path` does not exist: `{summary_path}`.")
                elif summary_obj.is_dir():
                    errors.append(
                        f"{label}: `summary_path` points to a directory, expected a file: `{summary_path}`."
                    )

    if not entries:
        warnings.append("Catalog has no entries yet.")

    if not catalog_path.exists():
        errors.append(f"Catalog file not found: `{catalog_path}`.")

    return errors, warnings, len(entries)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Infrastructure literature catalog entries.")
    parser.add_argument(
        "--catalog",
        default="Infrastructure/references/literature/catalog.yaml",
        help="Repository-relative path to catalog YAML.",
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root path. Defaults to script-derived root.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    script_root = Path(__file__).resolve().parents[2]
    repo_root = Path(args.repo_root).resolve() if args.repo_root else script_root
    catalog_path = (repo_root / args.catalog).resolve()

    if not catalog_path.exists():
        print(f"ERROR: catalog file does not exist: {catalog_path}", file=sys.stderr)
        return 1

    try:
        catalog = load_catalog(catalog_path)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    errors, warnings, entry_count = validate_catalog(catalog, repo_root, catalog_path)

    if errors:
        print(
            f"Literature catalog validation failed with {len(errors)} error(s) "
            f"and {len(warnings)} warning(s).",
            file=sys.stderr,
        )
        for err in errors:
            print(f"- ERROR: {err}", file=sys.stderr)
        for warn in warnings:
            print(f"- WARNING: {warn}", file=sys.stderr)
        return 1

    print(
        f"Literature catalog validation passed for {entry_count} entr"
        f"{'y' if entry_count == 1 else 'ies'} with {len(warnings)} warning(s)."
    )
    for warn in warnings:
        print(f"- WARNING: {warn}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
