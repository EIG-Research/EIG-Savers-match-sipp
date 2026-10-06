# Universal Saver's Match — Policy Summary (designated-endpoint design)

**Run date:** 2026-08-04 · **Branch:** `asec-median-anchor` · **Spec:** `Infrastructure/specs/2026-08-04_asec-median-anchor-respecification.md`

---

## 1. The policy, in full

> **A 200 percent match at $0 of income, declining in a straight line to a 0 percent match at the designated endpoint.**

Two numbers describe the entire schedule. There is no interior reference point, no derivation rule, and no external index to explain.

```
match rate = 200% x (1 - income / endpoint),   floored at 0%, capped at 200%
```

| Parameter | Value | Basis |
|---|---|---|
| Maximum match rate | **200 percent**, at $0 of income | Policy choice (unchanged) |
| **Designated endpoint — single filers** | **$44,045** | Median total personal income of single filers, CPS ASEC |
| Designated endpoint — married filing jointly | **$88,090** | 2.0 x single, statutory IRC §6433 ratio |
| Designated endpoint — head of household | **$66,068** | 1.5 x single, statutory IRC §6433 ratio |
| Slope (single filer) | −0.00454 percentage points per dollar | Implied: −200 / endpoint |
| Maximum match per person | $1,000 | Policy choice (unchanged) |
| Income concept scored | Total personal income, filer-level (joint for MFJ) | Matches §6433's filer-level operation |
| Dollar basis | Nominal 2024 dollars, unprojected | See §2 |

### Not policy parameters — modeling assumptions and untested options

These are frequently confused with the design. They are not part of it.

| Item | What it actually is |
|---|---|
| **Three percent of earnings** | A **behavioral assumption**, not a cap. The model assumes every worker contributes exactly three percent of their own earnings, then matches that amount. Nobody is limited to three percent — a worker contributing more would receive a larger match, up to the $1,000 ceiling. The rate is borrowed from RSAA §104(a)(2)'s statutory auto-enrollment default and adopted as the headline assumption under design decision D4. **Enacted §6433 contains no three-percent concept.** |
| **$100 automatic seed** | A **hypothetical scenario add-on** (2026-07-28), not part of the design. Reported separately below and excluded from headline cost. |
| Matchable-contribution limit | Enacted §6433 caps matchable contributions at $2,000 (50 percent of $2,000 = its $1,000 maximum). Stage 04 applies **only** the $1,000 credit cap, not a $2,000 contribution cap. Under a three percent contribution assumption the two rarely diverge, but if the design retains a matchable-contribution limit it is **not currently modeled**. |

**Why the endpoint is a total-income median.** The schedule scores filers on total personal income, so the endpoint is a total-income statistic. That makes the headline claim literally true rather than approximately true: the median single filer's income *equals* the endpoint, so that filer sits exactly at the 0 percent point. A wage-based endpoint would have sat below the total-income median and pushed the median filer outside the band while the headline still said "at the median."

---

## 2. Data sources

| Input | Source | Vintage | Role |
|---|---|---|---|
| Designated endpoint | **IPUMS CPS ASEC**, variables `INCTOT`, `FILESTAT`, `ASECWT`, `AGE` | ASEC 2025 (**income year 2024**) | Sets the endpoint: weighted median `INCTOT` among single filers age 15+, all values |
| Simulated population | **SIPP**, `pu2025.dta` | 2025 collection year (**reference year 2024**) | Who falls where against the schedule; earnings, plan access, filing status |
| Filing-status ratios | Enacted IRC §6433 | Statutory | MFJ 2.0x, HoH 1.5x ($41,000 / $20,500 and $30,750 / $20,500) |
| Participation | SIPP-observed conditional DC participation | 2025 SIPP | 61.93 percent headline take-up |

**The vintage contract.** ASEC income year must equal the SIPP reference year, so eligibility is scored nominal-on-nominal with **no projection on either side**. Both are calendar 2024. `01d_asec_income_medians.R` asserts this and stops on a mismatch.

This is a change of basis from the prior design, which projected SIPP income to TY2027 in order to meet the *fixed* statutory §6433 2027 thresholds. Those thresholds still govern stages 02 and 03, which continue to use projected income. Stage 04's endpoint is a contemporaneous median, so projecting it would move eligibility for no reason.

**What is no longer used.** IRS SOI Table 1.2 is no longer read at runtime. It is retained as an external calibration check.

---

## 3. Cost estimate

Nominal 2024 dollars, annual. **Cost of the policy as designed is the match column.** The $100 seed is a hypothetical add-on and is shown separately, not summed into the headline.

| Scenario | Take-up | Eligible (M) | Participants (M) | Avg match | **Match cost (the policy)** |
|---|---|---|---|---|---|
| **Headline** — SIPP-observed conditional participation | 61.9% | 49.78 | 30.83 | $529 | **$16.30B** |
| Auto-enrollment sensitivity | 80.0% | 49.78 | 39.83 | $530 | **$21.09B** |
| Full-participation ceiling | 100% | 49.78 | 49.78 | $530 | **$26.37B** |

All three rest on the assumption that every participant contributes three percent of earnings. That assumption, not a statutory limit, is what sets the match amount — see §1.

*If* the $100 automatic seed were adopted, it would add **$4.98B** in every scenario. Its cost is invariant to take-up, because it is paid to all 49.78M eligible workers whether or not they contribute. Three phased seed variants were also costed ($1.88B pro-rata, $4.03B flat-then-taper, $5.84B extended-taper); see `scenario_diagnostics.md`.

By delivery rail (full participation):

| Rail | Eligible (M) | Mean match rate | Match cost | Seed cost |
|---|---|---|---|---|
| Existing employer plan | 19.86 | 60.8% | $10.21B | $1.99B |
| Federal universal account | 29.92 | 85.4% | $16.16B | $2.99B |

The universal-account rail carries the larger share of both count and cost, and its recipients sit lower in the income distribution (mean income $35,150 versus $45,113), so their match rates are higher.

### Movement versus the prior design

| | Prior (IRS-anchored, TY2027 basis) | This design | Change |
|---|---|---|---|
| Eligible workers | 44.47M | 49.78M | +11.9% |
| Headline match cost | $14.15B | $16.30B | +15.2% |
| Full-participation ceiling | $23.87B | $26.37B | +10.5% |

**This comparison mixes three changes and should not be read as the effect of the endpoint alone:** (i) the endpoint level moved (the prior single endpoint was $39,323 in 2024 dollars versus $44,045 now, +12.0 percent); (ii) the data moved from the 2024 SIPP to the 2025 SIPP; (iii) the basis moved from TY2027-projected to nominal. Isolating (i) would require re-running the prior endpoint on the new data.

Cost rises faster than the eligible count, as expected. Because the 200 percent intercept is fixed while the endpoint moved out, the line also **flattens** — so workers already inside the old band receive a higher rate, on top of new workers entering. Both margins push the same direction.

---

## 4. Impact across the familiar bins

### By income decile (full universe, full participation, federal dollars including seed)

| Decile | Median income | Share eligible | Share of federal dollars |
|---|---|---|---|
| 1 | $16,732 | 100% | **33.4%** |
| 2 | $33,468 | 100% | **30.3%** |
| 3 | $45,519 | 59.6% | 15.6% |
| 4 | $59,735 | 39.7% | 12.3% |
| 5 | $76,299 | 41.5% | 8.2% |
| 6 | $96,780 | 4.5% | 0.2% |
| 7–10 | $122,388+ | 0% | 0% |

**Bottom two deciles receive 63.7 percent of federal dollars; bottom three receive 79.3 percent; bottom five receive 99.8 percent.** Nothing reaches the top four deciles.

Deciles 4 and 5 are non-monotonic in eligibility share (39.7 then 41.5 percent). That is not an error: deciles are cut on pooled income, but eligibility depends on a filing-group-specific endpoint, and the MFJ endpoint is twice the single endpoint. Higher-income joint households therefore remain eligible where single filers at the same income do not.

### By filing group

| Filing group | Universe (M) | Eligible (M) | Share eligible | Mean match rate | Match cost (full) |
|---|---|---|---|---|---|
| Single / MFS | 61.52 | 25.26 | 41.1% | 77.1% | $11.79B |
| Married filing jointly | 70.93 | 16.90 | 23.8% | 68.8% | $9.26B |
| Head of household | 11.76 | 7.62 | 64.8% | 85.6% | $5.32B |

Head-of-household filers have by far the highest eligibility rate, because the imposed 1.5x ratio sits well above where their income distribution actually falls. The endpoint diagnostics quantify this: against the endpoint's own income concept, the **observed** MFJ-to-single ratio is 1.36 and the observed HoH-to-single ratio is 1.02, versus the **imposed** statutory 2.0 and 1.5. Holding the statutory ratios (decision S1) is therefore materially more generous to joint and head-of-household filers than their income distributions would imply.

---

## 5. Two findings that constrain how this is described

**The $1,000 cap is rarely reached under the assumed contribution, but it is not unreachable in principle.** Only 11.5 percent of eligible workers reach it, and a single filer contributing three percent of earnings cannot reach $1,000 at any income — that would require an endpoint of roughly $67,000 or more. The cap binds only for joint filers in the bottom decile of their own group. Crucially, this is a property of the **three percent contribution assumption, not of the policy**: because three percent is not a statutory limit, a worker who contributed more could reach the cap at a much lower income. So "up to $1,000" is a truthful description of the ceiling; what the model shows is that the *default* contribution rarely gets anyone there. If the intent is for the cap to bind for a meaningful share of workers, the lever is the assumed or defaulted contribution rate, not the endpoint.

**Married-filing-separately cannot be identified in the data that sets the endpoint.** `FILESTAT` — in IPUMS and in the underlying Census tax model alike — has no MFS category (codes are 1/2/3 Joint, 4 HoH, 5 Single, 6 Nonfiler), because the tax model assigns married couples to joint filing. The endpoint population is therefore **single filers only**, while the SIPP group it scores is Single + MFS pooled. MFS is roughly 2–3 percent of returns, so the bias is small and one-directional, but it is not correctable from this source and should be stated wherever the endpoint is described.

---

## 6. Evidence

**Sources**
- Policy parameters: `data/processed/universal_sm_hybrid/endpoint_table.rds`; `output/reports/universal_sm_hybrid/endpoint_diagnostics.md`
- Endpoint derivation and full median grid: `output/reports/asec_endpoint_diagnostics.md`; `data/processed/asec_income_medians.csv`
- Cost and scenarios: `data/processed/universal_sm_hybrid/scenario_results.parquet`; `output/reports/universal_sm_hybrid/scenario_diagnostics.md`
- Incidence by bin: `output/tables/universal_sm_hybrid/hybrid_distributional_incidence.xlsx` (three sheets); `hybrid_by_route.xlsx`
- Schedule implementation: `code/_shared/calibration_cells.R::compute_match_rate()`
- Prior-design comparison figures: `output/reports/universal_sm_hybrid/` (pre-2026-08-04 run, IRS-anchored)

**Confidence**
- **High** — policy parameters, endpoint value, eligible counts, cost by scenario, incidence by decile and filing group. All computed from the run, and all six automated benchmarks in `04_03` passed (universe 144.21M, eligible 49.78M, conditional DC rate 0.6193, median earnings by filing group all in band).
- **High** — the schedule reparameterization is numerically identical to the retired form. Verified by unit test across a ten-point income grid for two filing groups, plus NA-propagation and defensive-stop checks.
- **Medium** — the prior-design comparison in §3, because it confounds three simultaneous changes (endpoint level, SIPP vintage, nominal versus projected basis).
- **Medium** — participation. The 61.9 percent headline is SIPP-observed conditional DC participation applied to the universal-account rail as a uniform assumption; the model assumes participation is invariant to the match rate.
- **Low** — nothing in this summary rests on a low-confidence input.

**Assumptions**
1. Participation does not respond to the match rate. The model cannot credit the 200 percent maximum with any behavioral effect; this is a known structural limitation, not a finding.
2. Every participating worker contributes exactly three percent of personal earnings. This is a **behavioral assumption, not a policy parameter or cap** — it drives the match amount directly and therefore drives the cost estimate. A different assumed contribution rate would move every cost figure roughly proportionally, up to the $1,000 ceiling. The $100 seed is a hypothetical add-on and is excluded from headline cost.
3. Statutory 2.0x / 1.5x filing-status ratios are imposed, not estimated (decision S1), and are more generous than the observed distribution implies.
4. Endpoint population is single filers only; MFS is not identifiable and is excluded.
5. SIPP total personal income is a proxy for §6433 MAGI. It includes non-taxable transfers AGI excludes and omits realized capital gains; residual divergence is unquantified.
6. Costs are one-year, nominal 2024 dollars. No ten-year path, no behavioral feedback, no administrative cost.
