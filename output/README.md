# output/

Generated artifacts for the Saver's Match eligibility and cost analysis.

## Folder map

```
output/
├── figures/
│   ├── main/                                       cost-memo figures (from 05a)
│   │   ├── sm_cost_comparison.png                  Figure 1
│   │   ├── sm_cost_comparison_data.csv             data companion
│   │   └── sm_robustness_grouped.png               Figure 2
│   ├── appendix/                                   simple-saver illustration (from 03c)
│   └── universal_sm_hybrid/                         hybrid figures + phaseout lenses (from 04)
├── tables/
│   ├── main/
│   │   ├── sm_jct_replication_scenarios.xlsx       headline cost scenarios (03a)
│   │   └── sm_robustness_scenarios.xlsx            robustness sweep (03b)
│   ├── appendix/                                   simple-saver illustration tables (03c)
│   ├── universal_sm_hybrid/                         hybrid headline / incidence / by-route (04)
│   ├── savers_match_eligibility_buckets*.{rds,parquet}        eligibility buckets, worker + filer basis (02a)
│   └── answers_eligibility_*.{rds,parquet,xlsx}              filing x match decomposition (02b)
├── reports/
│   ├── savers_match_eligibility_buckets.md         eligibility coverage counts (02a)
│   └── universal_sm_hybrid/                          hybrid diagnostics (04)
└── data/
    ├── figure_data/                                 chart-input CSVs
    └── intermediate_results/                        QA snapshots (sm_*_snapshot.json)
```

## Which artifact supports which element

| Element | Artifact | Producer |
|---|---|---|
| Cost Figure 1 / Figure 2 | `figures/main/sm_cost_comparison.png`, `sm_robustness_grouped.png` | `05a` |
| Headline cost scenarios | `tables/main/sm_jct_replication_scenarios.xlsx` | `03a` |
| Robustness sweep | `tables/main/sm_robustness_scenarios.xlsx` | `03b` |
| Simple-saver illustration | `tables/appendix/simple_saver_illustration*`, `figures/appendix/*` | `03c` |
| Universal hybrid | `tables/universal_sm_hybrid/*`, `figures/universal_sm_hybrid/*`, `reports/universal_sm_hybrid/*` | `04` |
| Eligibility counts (worker + filer basis) | `tables/savers_match_*`, `reports/savers_match_eligibility_buckets.md` | `02a` |
| Filing × match decomposition | `tables/answers_eligibility_*` | `02b` |
| QA snapshots | `data/intermediate_results/sm_*_snapshot.json` | `03a` / `03b` |
