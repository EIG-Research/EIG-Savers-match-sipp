---
paths:
  - "**/*.R"
  - "**/*.py"
---

# Replication-First Protocol

**Core principle:** Replicate original results as closely as possible before extending.

## Phase 1: Inventory and Baseline

Before writing replication code:
- [ ] Read the source replication README and methodology notes.
- [ ] Inventory code, data files, scripts, and expected outputs.
- [ ] Record target values from the source paper/output.

Store targets in:

`Infrastructure/session_logs/YYYY-MM-DD_replication_targets.md`

## Phase 2: Translate and Execute

- [ ] Follow project coding standards and `Infrastructure/GUARDRAILS.md`.
- [ ] Translate line-by-line initially; do not optimize early.
- [ ] Match original specification exactly (sample, covariates, clustering, SE method).
- [ ] Save intermediate outputs for traceability.

## Phase 3: Verify Match

### Suggested Tolerance Thresholds

| Type | Tolerance | Rationale |
|------|-----------|-----------|
| Integers (N, counts) | Exact match | Deterministic quantities should match |
| Point estimates | < 0.01 | Rounding/display differences |
| Standard errors | < 0.05 | Method and finite-sample variation |
| P-values | Same significance level | Small numeric drift may occur |
| Percentages | < 0.1pp | Display rounding |

### If Mismatch

Do not proceed to extensions. Isolate where divergence starts, document likely causes, and log the investigation even if unresolved.

### Replication Report

Save to:

`Infrastructure/session_logs/YYYY-MM-DD_replication_report.md`

Report should include: targets checked, pass/fail counts, discrepancy notes, and execution environment.

## Phase 4: Only Then Extend

After baseline replication passes:
- [ ] Commit or snapshot the verified baseline.
- [ ] Add project-specific extensions in separate steps.
- [ ] Keep each extension traceable back to the verified baseline.
