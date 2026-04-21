# Skill: /review-style

Audit a document or passage against EIG writing, citation, and figure-style rules.

## Trigger

User runs `/review-style <file-path-or-text>`

## Steps

1. Read input from file path or direct text.
2. Apply:
   - `.codex/rules/style-writing-rules.md`
   - `.codex/rules/style-citation-rules.md`
   - `.codex/rules/style-figure-rules.md`
3. Use `.codex/agents/eig-reviewer.md` behavior.
4. Format results with `.codex/templates/style-review-report.md`.

## Notes

- If input exceeds 2,000 words, fully review the first 500 words and summarize recurring patterns for the remainder.
- Always include fixes for every `ERROR`.
