#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is required. Install Homebrew first: https://brew.sh" >&2
  exit 1
fi

echo "Installing required EIG fonts on macOS..."
# Fonts are available directly from homebrew-cask; the old homebrew/cask-fonts tap is deprecated.
brew install --cask font-open-sans font-source-serif-4

echo "Verifying installed fonts..."
fonts_report="$(system_profiler SPFontsDataType 2>/dev/null || true)"

open_sans_ok=false
if echo "$fonts_report" | grep -Eqi "Open Sans|OpenSans"; then
  open_sans_ok=true
elif ls "$HOME/Library/Fonts"/OpenSans*.ttf >/dev/null 2>&1; then
  open_sans_ok=true
elif ls "/Library/Fonts"/OpenSans*.ttf >/dev/null 2>&1; then
  open_sans_ok=true
fi

if [ "$open_sans_ok" != "true" ]; then
  echo "ERROR: Open Sans was not detected after installation." >&2
  exit 2
fi

source_serif_ok=false
if echo "$fonts_report" | grep -Eqi "Source Serif Pro|Source Serif 4|SourceSerif4"; then
  source_serif_ok=true
elif ls "$HOME/Library/Fonts"/SourceSerif4*.ttf >/dev/null 2>&1; then
  source_serif_ok=true
elif ls "$HOME/Library/Fonts"/SourceSerifPro*.otf >/dev/null 2>&1; then
  source_serif_ok=true
elif ls "/Library/Fonts"/SourceSerif4*.ttf >/dev/null 2>&1; then
  source_serif_ok=true
elif ls "/Library/Fonts"/SourceSerifPro*.otf >/dev/null 2>&1; then
  source_serif_ok=true
fi

if [ "$source_serif_ok" != "true" ]; then
  echo "ERROR: Source Serif Pro/4 was not detected after installation." >&2
  exit 3
fi

echo "Font installation complete. Restart R/Python/Stata sessions before running plots."
