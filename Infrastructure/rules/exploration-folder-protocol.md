---
paths:
  - "Infrastructure/explorations/**"
---

# Exploration Folder Protocol

**All experimental work goes into `Infrastructure/explorations/` first.** Never mix early experiments into production work.

## Folder Structure

```
Infrastructure/explorations/
├── ACTIVE_PROJECTS.md
├── [project]/
│   ├── README.md
│   ├── code/
│   ├── notes/
│   ├── output/
│   └── SESSION_LOG.md
└── ARCHIVE/
    ├── completed_[project]/
    └── abandoned_[project]/
```

## Lifecycle

1. **Create** -- `mkdir -p Infrastructure/explorations/[name]/{code,notes,output}` and initialize `README.md` + `SESSION_LOG.md`.
2. **Develop** -- work entirely inside the exploration folder.
3. **Decide:**
   - **Graduate** -- promote validated outputs to production locations used by the active project; record destination in the exploration README.
   - **Keep exploring** -- document next steps in README.
   - **Abandon** -- move to `ARCHIVE/abandoned_[project]/` with a short explanation.

## Graduate Checklist

- [ ] Quality threshold for production is met
- [ ] Verification checks pass
- [ ] Results replicate within tolerance (if applicable)
- [ ] Code and notes are understandable without hidden context
- [ ] README explains approach, findings, and final disposition
