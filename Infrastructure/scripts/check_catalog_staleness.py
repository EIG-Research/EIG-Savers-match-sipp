#!/usr/bin/env python3
"""Report stale literature catalog entries based on verification recency."""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path
from typing import Any

# Reuse parser helpers from the catalog validator script in the same folder.
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from validate_literature_catalog import load_catalog  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check staleness of literature catalog entries.")
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
    parser.add_argument(
        "--warning-days",
        default=180,
        type=int,
        help="Warn when an entry has not been verified in this many days.",
    )
    parser.add_argument(
        "--fail-on-warning",
        action="store_true",
        help="Exit with status 1 if stale entries are found.",
    )
    return parser.parse_args()


def parse_date(value: Any) -> dt.date | None:
    if isinstance(value, dt.datetime):
        return value.date()
    if isinstance(value, dt.date):
        return value
    if isinstance(value, str):
        try:
            return dt.date.fromisoformat(value)
        except ValueError:
            return None
    return None


def main() -> int:
    args = parse_args()

    repo_root = Path(args.repo_root).resolve() if args.repo_root else Path(__file__).resolve().parents[2]
    catalog_path = (repo_root / args.catalog).resolve()

    if not catalog_path.exists():
        print(f"ERROR: catalog file does not exist: {catalog_path}", file=sys.stderr)
        return 1

    try:
        catalog = load_catalog(catalog_path)
    except RuntimeError as exc:
        print(f"ERROR: unable to load catalog: {exc}", file=sys.stderr)
        return 1

    entries = catalog.get("entries", []) if isinstance(catalog, dict) else []
    if not isinstance(entries, list):
        print("ERROR: catalog `entries` must be a list.", file=sys.stderr)
        return 1

    today = dt.date.today()
    warnings: list[str] = []
    info: list[str] = []
    checked = 0

    for entry in entries:
        if not isinstance(entry, dict):
            continue

        entry_id = entry.get("id", "<missing-id>")
        status = entry.get("status")
        if status == "archived":
            continue

        added_on = parse_date(entry.get("added_on"))
        last_verified = parse_date(entry.get("last_verified_on"))

        if added_on is None:
            info.append(f"{entry_id}: `added_on` is missing or invalid; cannot compute staleness.")
            continue

        checked += 1
        reference_date = last_verified if last_verified is not None else added_on
        age_days = (today - reference_date).days

        if age_days > args.warning_days:
            if last_verified is None:
                warnings.append(
                    f"{entry_id}: stale ({age_days} days since added_on={added_on.isoformat()}); "
                    "set `last_verified_on` after refresh."
                )
            else:
                warnings.append(
                    f"{entry_id}: stale ({age_days} days since last_verified_on={last_verified.isoformat()})."
                )

    if warnings:
        print(
            f"Catalog staleness check found {len(warnings)} stale entr"
            f"{'y' if len(warnings) == 1 else 'ies'} (threshold: {args.warning_days} days)."
        )
        for item in warnings:
            print(f"- WARNING: {item}")
    else:
        print(
            f"Catalog staleness check passed: no stale entries above {args.warning_days} days "
            f"across {checked} checked entr{'y' if checked == 1 else 'ies'}."
        )

    for item in info:
        print(f"- INFO: {item}")

    if warnings and args.fail_on_warning:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
