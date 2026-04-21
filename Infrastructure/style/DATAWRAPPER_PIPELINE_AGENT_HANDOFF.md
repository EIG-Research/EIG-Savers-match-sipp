# Datawrapper Pipeline Agent Handoff (R)

## Status
This file is the entrypoint for Datawrapper guidance in this repo. Canonical implementation policy now lives in:

- [docs/datawrapper-integration.md](docs/datawrapper-integration.md)

## Read in Order
1. Datawrapper contract (required):
`docs/datawrapper-integration.md`
2. Design source rules:
`docs/agent-01-design-spec.md`
3. R implementation baseline:
`docs/agent-02-r-implementation.md`
4. Legacy palette exception policy:
`docs/eig-legacy-palette-policy.md`
5. Theme/token distribution:
`themes/README.md`

Repository links:
- [docs/README.md](docs/README.md)
- [docs/datawrapper-integration.md](docs/datawrapper-integration.md)
- [docs/datawrapper-downstream-adoption-checklist.md](docs/datawrapper-downstream-adoption-checklist.md)
- [docs/agent-01-design-spec.md](docs/agent-01-design-spec.md)
- [docs/agent-02-r-implementation.md](docs/agent-02-r-implementation.md)
- [docs/eig-legacy-palette-policy.md](docs/eig-legacy-palette-policy.md)
- [themes/README.md](themes/README.md)

## What This Handoff Still Captures
- The Datawrapper API behaviors that matter operationally:
1. `DatawRappr::dw_data_to_chart()` should use `x = <data.frame>`.
2. `dw_test_key()` return type can vary across package versions.
- The governance expectation:
1. 2022 primary palette is default.
2. Legacy palette usage requires metadata and approval.

## External Reference Implementation (Non-Canonical)
This style-guide repository does not contain Datawrapper publish scripts. A working example exists at:

- `housing-ownership-generation/code/70_publish_datawrapper_key_figures.R`

Treat that project as an implementation example, not a policy source. Policy source remains:
- `docs/datawrapper-integration.md`
