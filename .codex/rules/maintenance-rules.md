# Maintenance Rules

Use these rules for periodic repository hygiene checks.

## Purpose

1. Keep canonical and generated AI files synchronized.
2. Catch broken internal references before they block users.
3. Surface stale dependencies and stale dataset references early.

## Severity Definitions

| Severity | Meaning |
|---|---|
| HIGH | Immediate workflow risk or guaranteed breakage |
| MEDIUM | Staleness or drift that can degrade quality soon |
| LOW | Cleanup/improvement that is not currently blocking |
| INFO | Observations requiring monitoring or human context |

## Required Check Families

### MT-1 Generated Copy Drift

- Run `make brain-check`.
- HIGH if drift exists between `Infrastructure/` and generated copies in `.claude/` or `.codex/`.

### MT-2 Internal Path Integrity

- Run `python3 Infrastructure/scripts/check_internal_path_references.py`.
- HIGH for missing referenced files that break documented workflows.
- LOW for cosmetic/path wording issues that do not affect execution.

### MT-3 Literature Catalog Integrity

- Run `make literature-check`.
- HIGH for schema or missing-path failures.

### MT-4 Catalog Staleness

- Run `python3 Infrastructure/scripts/check_catalog_staleness.py`.
- MEDIUM for non-archived entries that have not been verified recently.
- INFO when freshness cannot be determined from available metadata.

### MT-5 Dependency Freshness Signals

- Run applicable checks based on stack files present.
- MEDIUM when critical dependencies are outdated or unsupported.
- INFO when automated freshness checks are unavailable in the current environment.

## Reporting Standard

1. List every check run, even if it passes.
2. Include exact command, pass/fail status, and key output.
3. Provide concrete fix actions for every HIGH or MEDIUM finding.
4. Include a rerun plan that verifies fixes end to end.
