#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-sync}"

if [[ "$MODE" != "sync" && "$MODE" != "check" ]]; then
  echo "Usage: $0 [sync|check]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_ROOT="$REPO_ROOT/Infrastructure"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

AGENT_FILES=(
  "code-reviewer.md"
  "conceptual-consistency-reviewer.md"
  "data-consistency-reviewer.md"
  "eig-data-viz.md"
  "eig-reviewer.md"
  "eig-style-guide-agent.md"
  "eig-writer.md"
  "maintenance-agent.md"
  "methodology-reviewer.md"
  "orchestrator.md"
)

COMMAND_FILES=(
  "cite.md"
  "cover-sheet.md"
  "full-review.md"
  "literature-intake.md"
  "maintenance-check.md"
  "orchestrate.md"
  "review-code.md"
  "review-consistency.md"
  "review-methodology.md"
  "review-numbers.md"
  "review-style.md"
  "smart-brevity.md"
)

RULE_FILES=(
  "code-quality-rules.md"
  "constitutional-governance.md"
  "doc-consistency-rules.md"
  "doc-number-rules.md"
  "maintenance-rules.md"
  "methodology-rules.md"
  "performance-cost-governance.md"
  "style-citation-rules.md"
  "style-datawrapper-rules.md"
  "style-figure-rules.md"
  "style-writing-rules.md"
)

TEMPLATE_FILES=(
  "code-error-report.md"
  "doc-consistency-report.md"
  "doc-number-report.md"
  "maintenance-report.md"
  "methodology-report.md"
  "orchestration-plan.md"
  "smart-brevity-output.md"
  "style-citation-output.md"
  "style-cover-sheet.md"
  "style-review-report.md"
)

STYLE_SKILL_FILES=(
  "eig-style-apply.md"
  "eig-style-datawrapper.md"
  "eig-style-review.md"
)

INFRA_SKILL_FILES=(
  "literature-intake.md"
)

files_for_part() {
  local part="$1"
  case "$part" in
    agents) printf '%s\n' "${AGENT_FILES[@]}" ;;
    commands) printf '%s\n' "${COMMAND_FILES[@]}" ;;
    rules) printf '%s\n' "${RULE_FILES[@]}" ;;
    templates) printf '%s\n' "${TEMPLATE_FILES[@]}" ;;
    *) return 1 ;;
  esac
}

skill_frontmatter_for_claude() {
  local skill_name="$1"

  case "$skill_name" in
    eig-style-apply)
      cat <<'EOF'
---
name: eig-style-apply
description: Apply EIG style tokens/themes to figures and tables in R, Python, or Stata using vendored style assets in this repository.
argument-hint: "[target files or output type]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

EOF
      ;;
    eig-style-datawrapper)
      cat <<'EOF'
---
name: eig-style-datawrapper
description: Enforce EIG Datawrapper style and governance compliance using vendored validators and policy docs.
argument-hint: "[manifest path]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

EOF
      ;;
    eig-style-review)
      cat <<'EOF'
---
name: eig-style-review
description: Review figures, tables, and style-relevant code for EIG style-system compliance.
argument-hint: "[target files or outputs]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

EOF
      ;;
    literature-intake)
      cat <<'EOF'
---
name: literature-intake
description: Find, ingest, index, and reuse papers or data dictionaries using the repository literature catalog and intake playbook.
argument-hint: "[topic, source, or document]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

EOF
      ;;
    *)
      cat <<EOF
---
name: ${skill_name}
description: Run the ${skill_name} skill from canonical Infrastructure style guidance.
argument-hint: "[task scope]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

EOF
      ;;
  esac
}

generate_infra_skills_for_adapter() {
  local adapter="$1"
  local out_root="$2"
  local src_file dest_file skill_name base

  mkdir -p "$out_root/skills"

  for base in "${INFRA_SKILL_FILES[@]}"; do
    src_file="$INFRA_ROOT/skills/$base"
    if [[ ! -f "$src_file" ]]; then
      echo "Missing canonical skill file: $src_file" >&2
      exit 1
    fi

    skill_name="${base%.md}"
    mkdir -p "$out_root/skills/$skill_name"
    dest_file="$out_root/skills/$skill_name/SKILL.md"

    if [[ "$adapter" == ".claude" ]]; then
      {
        skill_frontmatter_for_claude "$skill_name"
        cat "$src_file"
      } > "$dest_file"
    else
      cp "$src_file" "$dest_file"
    fi
  done
}

generate_for_adapter() {
  local adapter="$1"
  local out_root="$2"
  local part src_file dest_file base

  mkdir -p "$out_root/agents" "$out_root/commands" "$out_root/rules" "$out_root/templates"

  for part in agents commands rules templates; do
    while IFS= read -r base; do
      src_file="$INFRA_ROOT/$part/$base"
      if [[ ! -f "$src_file" ]]; then
        echo "Missing canonical file: $src_file" >&2
        exit 1
      fi
      dest_file="$out_root/$part/$base"
      sed \
        -e "s#Infrastructure/agents/#${adapter}/agents/#g" \
        -e "s#Infrastructure/commands/#${adapter}/commands/#g" \
        -e "s#Infrastructure/rules/#${adapter}/rules/#g" \
        -e "s#Infrastructure/templates/#${adapter}/templates/#g" \
        "$src_file" > "$dest_file"
    done < <(files_for_part "$part")
  done
}

generate_style_skills_for_adapter() {
  local adapter="$1"
  local out_root="$2"
  local src_file dest_file skill_name base

  mkdir -p "$out_root/skills"

  for base in "${STYLE_SKILL_FILES[@]}"; do
    src_file="$INFRA_ROOT/style/skills/$base"
    if [[ ! -f "$src_file" ]]; then
      echo "Missing canonical skill file: $src_file" >&2
      exit 1
    fi

    skill_name="${base%.md}"
    mkdir -p "$out_root/skills/$skill_name"
    dest_file="$out_root/skills/$skill_name/SKILL.md"

    if [[ "$adapter" == ".claude" ]]; then
      {
        skill_frontmatter_for_claude "$skill_name"
        cat "$src_file"
      } > "$dest_file"
    else
      cp "$src_file" "$dest_file"
    fi
  done
}

compare_or_sync() {
  local adapter="$1"
  local generated_root="$2"
  local live_root="$REPO_ROOT/$adapter"
  local part live_part live_skills
  local has_diff=0

  if [[ "$MODE" == "check" ]]; then
    for part in agents commands rules templates; do
      live_part="$live_root/$part"
      if [[ ! -d "$live_part" ]]; then
        echo "Missing directory: $live_part" >&2
        has_diff=1
        continue
      fi
      if ! diff -ru "$generated_root/$part" "$live_part" >/dev/null; then
        echo "Drift detected in $adapter/$part" >&2
        diff -ru "$generated_root/$part" "$live_part" || true
        has_diff=1
      fi
    done

    live_skills="$live_root/skills"
    if [[ ! -d "$live_skills" ]]; then
      echo "Missing directory: $live_skills" >&2
      has_diff=1
    elif ! diff -ru "$generated_root/skills" "$live_skills" >/dev/null; then
      echo "Drift detected in $adapter/skills" >&2
      diff -ru "$generated_root/skills" "$live_skills" || true
      has_diff=1
    fi

    return "$has_diff"
  fi

  # sync mode
  for part in agents commands rules templates; do
    live_part="$live_root/$part"
    if [[ -L "$live_part" ]]; then
      rm "$live_part"
    elif [[ -e "$live_part" ]]; then
      rm -rf "$live_part"
    fi
    if [[ -e "$live_part" || -L "$live_part" ]]; then
      echo "Unable to replace $live_part" >&2
      exit 1
    fi
    mkdir -p "$live_part"
    cp "$generated_root/$part"/*.md "$live_part/"
  done

  live_skills="$live_root/skills"
  if [[ -L "$live_skills" ]]; then
    rm "$live_skills"
  elif [[ -e "$live_skills" ]]; then
    rm -rf "$live_skills"
  fi
  if [[ -e "$live_skills" || -L "$live_skills" ]]; then
    echo "Unable to replace $live_skills" >&2
    exit 1
  fi
  mkdir -p "$live_skills"
  cp -R "$generated_root/skills/." "$live_skills/"
}

generate_for_adapter ".claude" "$TMP_DIR/.claude"
generate_for_adapter ".codex" "$TMP_DIR/.codex"
generate_infra_skills_for_adapter ".claude" "$TMP_DIR/.claude"
generate_infra_skills_for_adapter ".codex" "$TMP_DIR/.codex"
generate_style_skills_for_adapter ".claude" "$TMP_DIR/.claude"
generate_style_skills_for_adapter ".codex" "$TMP_DIR/.codex"

check_exit=0
compare_or_sync ".claude" "$TMP_DIR/.claude" || check_exit=1
compare_or_sync ".codex" "$TMP_DIR/.codex" || check_exit=1

if [[ "$MODE" == "check" ]]; then
  if [[ "$check_exit" -eq 0 ]]; then
    echo "No drift detected: generated adapter copies match canonical Infrastructure sources."
  fi
  exit "$check_exit"
fi

echo "Generated copies refreshed in .claude/{agents,commands,rules,templates,skills} and .codex/{...}."
