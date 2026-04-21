# Task Completion Verification Protocol

**At the end of every task, verify outputs before declaring completion.**

## For Code and Analysis Scripts
1. Run the relevant script/test command from the project root.
2. Confirm command exits successfully.
3. Verify expected outputs exist and are non-empty.
4. Spot-check key values for plausible ranges and units.
5. Report verification results clearly.

## For Reports, Notebooks, and Rendered Artifacts
1. Rebuild or render using the project's standard command.
2. Check for build warnings/errors.
3. Verify figures/tables render and source paths resolve.
4. Confirm citations/references resolve where applicable.
5. Open the output to confirm usability and formatting.

## For Data Processing Work
1. Validate row counts, schema, and key null checks.
2. Confirm joins/filters changed data as expected.
3. Save a short before/after validation note in the session log.

## For Documentation or Configuration Changes
1. Confirm referenced paths and commands exist.
2. Run any lightweight checks (lint/link check) if available.
3. Ensure onboarding instructions still work end-to-end.

## Common Pitfalls
- Assuming success without running commands.
- Treating generated files as correct without opening/inspecting them.
- Skipping checks on paths after moving files.
- Reporting conclusions without validating source data.

## Verification Checklist
```
[ ] Commands completed successfully
[ ] Expected outputs were created and inspected
[ ] Paths/references resolve correctly
[ ] Key claims match verified evidence
[ ] Results and limitations were reported to the user
```
