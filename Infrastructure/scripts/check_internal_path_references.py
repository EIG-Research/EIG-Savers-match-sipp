#!/usr/bin/env python3
"""Validate internal markdown path references used by template docs."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable


CODE_SPAN_RE = re.compile(r"`([^`\n]+)`")
MD_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
LINE_SUFFIX_RE = re.compile(r":\d+(?::\d+)?$")

ALLOWED_INTERNAL_PREFIXES = (
    "Infrastructure/",
    ".codex/",
    ".claude/",
    "PROJECT.md",
    "README.md",
    "Makefile",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check internal markdown path references.")
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root path. Defaults to script-derived root.",
    )
    return parser.parse_args()


def iter_markdown_files(repo_root: Path) -> Iterable[Path]:
    top_level = ["README.md", "PROJECT.md"]
    for name in top_level:
        path = repo_root / name
        if path.exists():
            yield path

    infra_root = repo_root / "Infrastructure"
    if infra_root.exists():
        yield from sorted(infra_root.rglob("*.md"))


def normalize_candidate(raw: str) -> str:
    candidate = raw.strip().strip("<>").strip("\"'").rstrip(".,;:")
    if "#" in candidate:
        candidate = candidate.split("#", 1)[0]
    if "?" in candidate:
        candidate = candidate.split("?", 1)[0]
    candidate = LINE_SUFFIX_RE.sub("", candidate)
    return candidate


def should_check(candidate: str) -> bool:
    if not candidate:
        return False
    if " " in candidate:
        return False
    if any(ch in candidate for ch in ("*", "{", "}", "$", "|")):
        return False
    if any(token in candidate for token in ("YYYY-", "[", "]", "<", ">", "TBD")):
        return False
    if candidate.startswith(("http://", "https://", "mailto:", "tel:", "data:")):
        return False
    return candidate.startswith(ALLOWED_INTERNAL_PREFIXES)


def resolve_candidate(repo_root: Path, source_file: Path, candidate: str) -> Path:
    if candidate.startswith("./"):
        return (source_file.parent / candidate[2:]).resolve()
    if candidate.startswith("../"):
        return (source_file.parent / candidate).resolve()
    return (repo_root / candidate).resolve()


def collect_candidates(line: str) -> list[str]:
    candidates: list[str] = []
    candidates.extend(MD_LINK_RE.findall(line))
    candidates.extend(CODE_SPAN_RE.findall(line))
    return candidates


def main() -> int:
    args = parse_args()
    script_root = Path(__file__).resolve().parents[2]
    repo_root = Path(args.repo_root).resolve() if args.repo_root else script_root

    if not repo_root.exists():
        print(f"ERROR: repo root does not exist: {repo_root}", file=sys.stderr)
        return 1

    missing: list[str] = []
    checked_count = 0

    for md_file in iter_markdown_files(repo_root):
        try:
            lines = md_file.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            lines = md_file.read_text(encoding="latin-1").splitlines()

        for idx, line in enumerate(lines, start=1):
            for raw in collect_candidates(line):
                candidate = normalize_candidate(raw)
                if not should_check(candidate):
                    continue

                checked_count += 1
                resolved = resolve_candidate(repo_root, md_file, candidate)
                if not resolved.exists():
                    relative_md = md_file.relative_to(repo_root)
                    missing.append(f"{relative_md}:{idx} -> {candidate}")

    if missing:
        print(
            f"Internal path reference check failed: {len(missing)} missing reference(s) "
            f"across {checked_count} checked reference(s).",
            file=sys.stderr,
        )
        for item in missing:
            print(f"- {item}", file=sys.stderr)
        return 1

    print(f"Internal path reference check passed: {checked_count} reference(s) validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
