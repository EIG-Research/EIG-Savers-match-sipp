# Skill: /maintenance-check

Run a periodic maintenance sweep for template drift, internal path integrity, and freshness signals.

## Trigger

User runs `/maintenance-check`

## Steps

1. Run generated-copy drift check:

```bash
make brain-check
```

2. Run literature catalog validation:

```bash
make literature-check
```

3. Run internal path reference validation:

```bash
python3 Infrastructure/scripts/check_internal_path_references.py
```

4. Run catalog staleness scan:

```bash
python3 Infrastructure/scripts/check_catalog_staleness.py
```

5. Run dependency freshness checks if relevant files exist:
   - Python (`requirements*.txt` or `pyproject.toml`): `python3 -m pip list --outdated`
   - R (`renv.lock`): `Rscript -e "if (requireNamespace('renv', quietly = TRUE)) renv::status() else cat('renv not installed\n')"`
   - Node (`package.json`): `npm outdated`

6. Compile findings using `.codex/templates/maintenance-report.md`.

## Output

A maintenance report with:

1. Findings grouped by severity per `.codex/rules/maintenance-rules.md`
2. Exact remediation commands
3. "Do now" vs. "Do later" action list
4. Rerun commands for verification
