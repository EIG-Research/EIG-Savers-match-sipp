# Skill: /cover-sheet

Generate an EIG publication cover sheet from project description text.

## Trigger

User runs `/cover-sheet <project-description>`

## Steps

1. Extract known fields from the input.
2. Infer reasonable defaults where safe.
3. Mark unresolved fields as `[TO FILL]`.
4. Use `Infrastructure/templates/style-cover-sheet.md` for output.
5. List unresolved pre-draft questions and immediate next steps.

## Reference

- `Infrastructure/style/docs/eig-document-process.md`
