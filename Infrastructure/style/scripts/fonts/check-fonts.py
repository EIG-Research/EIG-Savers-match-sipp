#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


def load_tokens() -> dict:
    repo_root = Path(__file__).resolve().parents[2]
    token_path = repo_root / "tokens" / "eig-style-tokens.v1.json"
    if not token_path.exists():
        print(f"ERROR: Token file not found: {token_path}", file=sys.stderr)
        sys.exit(2)
    return json.loads(token_path.read_text(encoding="utf-8"))


def _installed_via_matplotlib() -> set[str]:
    try:
        import matplotlib.font_manager as fm  # type: ignore
    except Exception:
        return set()
    return {f.name for f in fm.fontManager.ttflist if getattr(f, "name", None)}


def _installed_via_fc_list() -> set[str]:
    try:
        proc = subprocess.run(
            ["fc-list", ":", "family"],
            capture_output=True,
            check=False,
            text=True,
        )
    except FileNotFoundError:
        return set()
    if proc.returncode != 0:
        return set()
    out: set[str] = set()
    for line in proc.stdout.splitlines():
        for part in line.split(","):
            name = part.strip()
            if name:
                out.add(name)
    return out


def _installed_via_system_profiler() -> set[str]:
    try:
        proc = subprocess.run(
            ["system_profiler", "SPFontsDataType"],
            capture_output=True,
            check=False,
            text=True,
        )
    except FileNotFoundError:
        return set()
    if proc.returncode != 0:
        return set()
    out: set[str] = set()
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.endswith(":") and line and not line.startswith("Fonts:"):
            out.add(line[:-1].strip())
    return out


def installed_families() -> set[str]:
    found = _installed_via_matplotlib()
    if found:
        return found
    found = _installed_via_fc_list()
    if found:
        return found
    found = _installed_via_system_profiler()
    if found:
        return found
    print(
        "ERROR: Unable to enumerate installed fonts. Install matplotlib or fontconfig tools.",
        file=sys.stderr,
    )
    sys.exit(2)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate required EIG fonts.")
    parser.add_argument(
        "--allow-fallback",
        action="store_true",
        help="Allow fallback stacks from the token file instead of strict primary fonts."
    )
    args = parser.parse_args()

    tokens = load_tokens()
    families = installed_families()

    primary_headline = tokens["typography"]["headline"]["primary_family"]
    primary_body = tokens["typography"]["body"]["primary_family"]
    headline_stack = tokens["typography"]["headline"]["fallback_stack"]
    body_stack = tokens["typography"]["body"]["fallback_stack"]

    if not args.allow_fallback:
        missing = [f for f in [primary_headline, primary_body] if f not in families]
        if missing:
            print("ERROR: Required primary fonts are missing:", file=sys.stderr)
            for font in missing:
                print(f"  - {font}", file=sys.stderr)
            print("Run an install script in scripts/fonts/ and restart the session.", file=sys.stderr)
            return 1
        print("PASS: Primary EIG fonts are installed.")
        return 0

    headline_ok = primary_headline in families or any(f in families for f in headline_stack)
    body_ok = primary_body in families or any(f in families for f in body_stack)

    if not headline_ok or not body_ok:
        print("ERROR: No valid font found for one or more required stacks.", file=sys.stderr)
        print(f"  headline primary: {primary_headline}", file=sys.stderr)
        print(f"  headline fallback stack: {headline_stack}", file=sys.stderr)
        print(f"  body primary: {primary_body}", file=sys.stderr)
        print(f"  body fallback stack: {body_stack}", file=sys.stderr)
        return 1

    print("PASS: Required EIG font stacks are available (primary or fallback).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
