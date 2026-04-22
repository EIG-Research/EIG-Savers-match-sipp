---
name: eig-style-apply
description: Apply EIG style tokens/themes to figures and tables in R, Python, or Stata using vendored style assets in this repository.
argument-hint: "[target files or output type]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
disable-model-invocation: true
---

# EIG Style Apply

Use this skill when implementing or updating figure/table styling in project code.

## Source Priority

1. `Infrastructure/style/docs/README.md`
2. `Infrastructure/style/tokens/eig-style-tokens.v1.json`
3. `Infrastructure/style/themes/README.md`
4. Language-specific references:
   - R: `Infrastructure/style/docs/agent-02-r-implementation.md`
   - Python: `Infrastructure/style/docs/agent-04-python-implementation.md`
   - Stata: `Infrastructure/style/docs/agent-03-stata-implementation.md`
5. Policy: `Infrastructure/style/docs/eig-legacy-palette-policy.md`

## Workflow

1. Detect active language from the files or user request.
2. Apply vendored helpers:
   - R: `source("Infrastructure/style/themes/r/eig_theme.R")`
   - Python: use helpers in `Infrastructure/style/themes/python/eig_theme.py`
   - Stata: `do Infrastructure/style/themes/stata/eig_theme.do`
3. Use token-derived colors and typography only.
4. Run font checks when needed:
   - `Rscript Infrastructure/style/scripts/fonts/check-fonts.R`
   - `python3 Infrastructure/style/scripts/fonts/check-fonts.py`
   - `do Infrastructure/style/scripts/fonts/check-fonts.do`

## Non-Negotiables

1. Do not invent net-new hex values when token equivalents exist.
2. Do not edit `Infrastructure/style/tokens/eig-style-tokens.v1.json` unless explicitly requested.
3. Default to 2022 primary palette usage.
4. Legacy palettes require policy justification per `Infrastructure/style/docs/eig-legacy-palette-policy.md`.
