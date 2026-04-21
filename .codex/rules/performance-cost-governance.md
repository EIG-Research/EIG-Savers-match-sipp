# Performance and Cost Governance Rules

Use these rules whenever work may be computationally expensive, slow, or costly in analyst time/tool usage.

## Objectives

1. Keep execution predictable and affordable.
2. Prevent runaway jobs and silent retries.
3. Preserve reproducibility while minimizing waste.

## Job Tiers

| Tier | Expected Runtime | Typical Examples | Governance Level |
|---|---|---|---|
| Tier 1 | Under 2 minutes | Lint/check scripts, small transforms | Standard |
| Tier 2 | 2-15 minutes | Medium analysis runs, document renders | Managed |
| Tier 3 | 15-60 minutes | Full rebuilds, heavy joins, large regressions | Controlled |
| Tier 4 | Over 60 minutes | Multi-stage pipelines on large data | Human-gated |

## Required Controls by Tier

1. Tier 1: run normally, log command and result.
2. Tier 2: include expected runtime and output path before execution.
3. Tier 3: require checkpoints (intermediate outputs/logging), explicit timeout, and resume strategy.
4. Tier 4: pause for explicit human confirmation before execution.

## Retry and Timeout Policy

1. Set a timeout for any Tier 3+ command.
2. Retry at most 2 times, and only for clearly transient failures.
3. Do not retry deterministic errors (syntax, missing file, failed assertion) without a code/config change.
4. Record each retry reason.

## Caching and Incrementalism

1. Prefer incremental runs over full reruns when outputs are unchanged.
2. Reuse validated intermediates when assumptions still hold.
3. Document cache keys/invalidators when caching affects correctness.
4. Force a clean rerun when inputs, versions, or core assumptions changed.

## Escalation Triggers

Pause and ask for direction if any trigger is met:

1. Estimated runtime exceeds 60 minutes.
2. Estimated output exceeds 1 GB.
3. Two consecutive failures occur on the same step.
4. Unexpected resource growth is observed (runtime, file size, or memory).
5. Proposed run would block other critical work for extended time.

## What We Should Add vs. Should Not Add

### Should Add

1. Runtime estimates and explicit job tier labels in plans.
2. Checkpoint/resume guidance for long-running pipelines.
3. Clear timeout/retry defaults.
4. Lightweight usage logs in session notes for expensive steps.

### Should Not Add

1. Hard-coded, one-size-fits-all limits disconnected from task value.
2. Silent automatic retries that hide instability.
3. Provider- or machine-specific billing assumptions inside core template rules.
4. Complex optimization frameworks before basic checkpoints/timeouts exist.

## Minimum Reporting for Expensive Runs

For Tier 3 or Tier 4 work, report:

1. Estimated vs. actual runtime.
2. Retries performed and why.
3. Outputs produced (paths and sizes when relevant).
4. Recommendation to keep current approach or adjust.
