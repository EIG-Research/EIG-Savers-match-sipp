# Skill: /cite

Format a citation from natural-language source information using EIG citation rules.

## Trigger

User runs `/cite <source-description>`

## Steps

1. Parse authors, title, outlet, date, URL, and access date if present.
2. Infer source type (article, report, book, webpage, press release, podcast, law).
3. Apply `.codex/rules/style-citation-rules.md`.
4. Return output using `.codex/templates/style-citation-output.md`.

## Minimum Output

- Formatted citation
- Inferred source type
- Missing required fields (`[MISSING]`)
