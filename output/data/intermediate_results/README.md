# output/data/intermediate_results/

Numerical snapshots of the cost pipeline's core runs, for inspection and QA without re-running.

## Files

### `sm_simulation_snapshot.json`
Written by `code/03_cost_simulation/03a_jct_replication.R`. Per-scenario cost estimates and the
assumption set for the eight headline scenarios.

### `sm_robustness_snapshot.json`
Written by `code/03_cost_simulation/03b_robustness_sweep.R`. The 20-scenario robustness sweep.

Both are regenerated on every run of their producing stage, small, and tracked in git so the headline
numbers are inspectable without re-running the full pipeline.
