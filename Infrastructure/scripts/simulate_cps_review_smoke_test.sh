#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

"$SCRIPT_DIR/manage_generated_copies.sh" check

SIM_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cps_unemployment_smoke_test.XXXXXX")"
REPORT_PATH="$SIM_ROOT/cps_smoke_test_report.md"
mkdir -p "$SIM_ROOT/code" "$SIM_ROOT/paper" "$SIM_ROOT/review-reports" "$SIM_ROOT/.claude/tmp" "$SIM_ROOT/.codex/tmp"

cat > "$SIM_ROOT/runall.R" <<'EOF'
message("Simulated pipeline for CPS unemployment-rate project")
EOF

cat > "$SIM_ROOT/code/01_load_cps.R" <<'EOF'
library(ipumsr)
library(dplyr)

# Simulated CPS load for smoke test only.
cps <- tibble(
  year = c(2023, 2023, 2023, 2023),
  race_eth = c("White, non-Hispanic", "Black, non-Hispanic", "Hispanic", "Asian, non-Hispanic"),
  labor_force = c(1000, 900, 800, 700),
  unemployed = c(40, 72, 56, 21)
)
EOF

cat > "$SIM_ROOT/code/02_estimate_unemployment_by_race_ethnicity.R" <<'EOF'
library(dplyr)

unemployment_rates <- cps %>%
  mutate(unemployment_rate = unemployed / labor_force) %>%
  select(year, race_eth, unemployment_rate)

print(unemployment_rates)
EOF

cat > "$SIM_ROOT/paper/manuscript.md" <<'EOF'
# Research project looking to estimate unemployment rates by race/ethnicity using CPS data

We estimate annual unemployment rates by race/ethnicity from CPS microdata.
EOF

cat > "$SIM_ROOT/review-reports/doc-number-report.md" <<'EOF'
This file should be excluded by review discovery rules.
EOF

CODE_FILES=()
while IFS= read -r line; do
  CODE_FILES+=("$line")
done < <(
  find "$SIM_ROOT" -type f \( -name "*.py" -o -name "*.R" -o -name "*.Rmd" -o -name "*.qmd" -o -name "*.do" -o -name "*.ado" \) \
    ! -path "*/.git/*" \
    ! -path "*/.claude/*" \
    ! -path "*/.codex/*" \
    ! -path "*/review-reports/*" \
    | sort
)

DOC_FILES=()
while IFS= read -r line; do
  DOC_FILES+=("$line")
done < <(
  find "$SIM_ROOT" -type f \( -name "*.tex" -o -name "*.md" -o -name "*.qmd" -o -name "*.Rmd" -o -name "*.pdf" \) \
    ! -name "README.md" \
    ! -name "CHANGELOG.md" \
    ! -name "LICENSE.md" \
    ! -name "doc-number-report.pdf" \
    ! -name "doc-consistency-report.pdf" \
    ! -path "*/.git/*" \
    ! -path "*/.claude/*" \
    ! -path "*/.codex/*" \
    ! -path "*/review-reports/*" \
    | sort
)

if [[ "${#CODE_FILES[@]}" -ne 3 ]]; then
  echo "Smoke test failed: expected 3 code files, found ${#CODE_FILES[@]}" >&2
  exit 1
fi

if [[ "${#DOC_FILES[@]}" -ne 1 ]]; then
  echo "Smoke test failed: expected 1 document file, found ${#DOC_FILES[@]}" >&2
  exit 1
fi

{
  echo "# Research project looking to estimate unemployment rates by race/ethnicity using CPS data"
  echo
  echo "## Smoke Test Result"
  echo "- Status: PASS"
  echo "- Simulated project root: \`$SIM_ROOT\`"
  echo "- Code files discovered: ${#CODE_FILES[@]}"
  echo "- Document files discovered: ${#DOC_FILES[@]}"
  echo
  echo "## Discovered Code Files"
  for f in "${CODE_FILES[@]}"; do
    echo "- \`$f\`"
  done
  echo
  echo "## Discovered Document Files"
  for f in "${DOC_FILES[@]}"; do
    echo "- \`$f\`"
  done
} > "$REPORT_PATH"

echo "Smoke test passed. Report written to $REPORT_PATH"
