#!/usr/bin/env bash
set -euo pipefail

FONT_DIR="${HOME}/.local/share/fonts/eig"
mkdir -p "${FONT_DIR}"

download() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --silent --show-error "${url}" -o "${out}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${out}" "${url}"
  else
    echo "ERROR: curl or wget is required." >&2
    exit 1
  fi
}

echo "Downloading Open Sans..."
download \
  "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-Regular.ttf" \
  "${FONT_DIR}/OpenSans-Regular.ttf"

download \
  "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-SemiBold.ttf" \
  "${FONT_DIR}/OpenSans-SemiBold.ttf"

echo "Downloading Source Serif Pro (or fallback Source Serif 4)..."
if ! download \
  "https://github.com/adobe-fonts/source-serif-pro/raw/release/TTF/SourceSerifPro-Semibold.ttf" \
  "${FONT_DIR}/SourceSerifPro-Semibold.ttf"; then
  echo "Source Serif Pro unavailable from primary URL, trying Source Serif 4 fallback..."
  download \
    "https://github.com/adobe-fonts/source-serif/raw/release/TTF/SourceSerif4-Semibold.ttf" \
    "${FONT_DIR}/SourceSerif4-Semibold.ttf"
fi

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "${FONT_DIR}"
else
  echo "WARNING: fc-cache not found. You may need to refresh font cache manually." >&2
fi

if command -v fc-list >/dev/null 2>&1; then
  if ! fc-list | grep -qi "Open Sans"; then
    echo "ERROR: Open Sans not detected by fontconfig." >&2
    exit 2
  fi
  if ! fc-list | grep -Eqi "Source Serif Pro|Source Serif 4"; then
    echo "ERROR: Source Serif Pro/4 not detected by fontconfig." >&2
    exit 3
  fi
fi

echo "Font installation complete. Restart R/Python/Stata sessions before running plots."
