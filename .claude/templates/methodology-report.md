# Methodology Report — HTML Template

This file defines the HTML template for the methodology report produced by the `methodology-reviewer` sub-agent. When writing the report, replace all `{{PLACEHOLDER}}` tokens with actual content and escape user-derived strings for HTML.

Severities for this report are **HIGH / MEDIUM / LOW** only (no CRITICAL, no INFO). The report uses a dark teal header (`#134e4a`) to distinguish it visually from the navy code error report.

---

## Pre-Write Checklist

Before writing `review-reports/methodology-report.html`, verify:

- [ ] All `{{PLACEHOLDER}}` tokens are replaced (grep for `{{` in final output — none should remain)
- [ ] User-supplied strings (variable names, file paths, descriptions) are HTML-escaped
- [ ] Finding IDs are sequential: MR-001, MR-002, … (no gaps, no duplicates)
- [ ] Every reviewed file appears in the Reviewed Files table
- [ ] Overall Risk pill colour matches the assessed risk level
- [ ] Design Assessment box is filled in (or marked "Not specified" where unknown)
- [ ] Findings are grouped by severity (HIGH first), then by category within each severity
- [ ] Each finding has both "Why This Is a Concern" and "What to Check" sections
- [ ] The report is self-contained (no external CSS/JS links)
- [ ] Severity counts in the stat grid match the actual findings below

---

## HTML Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Methodology Report — {{PROJECT_NAME}}</title>
  <style>
    /* ── Reset & base ── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 15px;
      line-height: 1.6;
      color: #1e293b;
      background: #f8fafc;
    }

    /* ── Header (dark teal — distinct from code report navy) ── */
    .report-header {
      background: #134e4a;
      color: #f0fdfa;
      padding: 2rem 2.5rem;
    }
    .report-header h1 {
      font-size: 1.6rem;
      font-weight: 700;
      letter-spacing: -0.02em;
      margin-bottom: 0.25rem;
    }
    .report-header .subtitle {
      font-size: 0.9rem;
      color: #99f6e4;
    }
    .report-header .meta {
      margin-top: 1rem;
      display: flex;
      gap: 2rem;
      font-size: 0.85rem;
      color: #ccfbf1;
    }
    .report-header .meta span strong { color: #f0fdfa; }

    /* ── Main container ── */
    .container { max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }

    /* ── Section headings ── */
    h2 {
      font-size: 1.15rem;
      font-weight: 600;
      color: #1e293b;
      margin: 2rem 0 1rem;
      padding-bottom: 0.4rem;
      border-bottom: 2px solid #e2e8f0;
    }

    /* ── Executive summary box ── */
    .summary-box {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 1.25rem 1.5rem;
      margin-bottom: 1.5rem;
      font-size: 0.95rem;
      color: #334155;
      line-height: 1.7;
    }

    /* ── Overall risk pill ── */
    .risk-row {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin-bottom: 1.5rem;
    }
    .risk-label { font-size: 0.9rem; font-weight: 600; color: #475569; }
    .risk-pill {
      font-size: 0.85rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      padding: 0.3rem 0.9rem;
      border-radius: 9999px;
    }
    .risk-high   { background: #fef2f2; color: #dc2626; border: 1px solid #fca5a5; }
    .risk-medium { background: #fff7ed; color: #ea580c; border: 1px solid #fdba74; }
    .risk-low    { background: #f0fdf4; color: #16a34a; border: 1px solid #86efac; }

    /* ── Design assessment box ── */
    .design-box {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-left: 4px solid #134e4a;
      border-radius: 8px;
      padding: 1.25rem 1.5rem;
      margin-bottom: 2rem;
    }
    .design-box h3 {
      font-size: 0.85rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #134e4a;
      margin-bottom: 0.85rem;
    }
    .design-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.6rem 2rem;
      font-size: 0.88rem;
    }
    .design-item { display: flex; gap: 0.5rem; }
    .design-key  { font-weight: 600; color: #475569; min-width: 10rem; }
    .design-val  { color: #1e293b; }

    /* ── Stat grid (3 severities) ── */
    .stat-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.75rem;
      margin-bottom: 2rem;
    }
    .stat-card {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 1rem;
      text-align: center;
    }
    .stat-card .count {
      font-size: 2rem;
      font-weight: 700;
      line-height: 1;
    }
    .stat-card .label {
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-top: 0.3rem;
    }
    .sev-high   .count, .sev-high   .label { color: #dc2626; }
    .sev-medium .count, .sev-medium .label { color: #ea580c; }
    .sev-low    .count, .sev-low    .label { color: #2563eb; }

    /* ── Category group headings ── */
    .category-heading {
      font-size: 0.85rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: #64748b;
      margin: 1.5rem 0 0.75rem;
      padding: 0.4rem 0;
      border-bottom: 1px dashed #cbd5e1;
    }

    /* ── Finding cards ── */
    .finding {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      margin-bottom: 1.25rem;
      overflow: hidden;
    }
    .finding-header {
      display: flex;
      align-items: flex-start;
      gap: 1rem;
      padding: 1rem 1.25rem;
      border-left: 5px solid transparent;
    }
    .finding.high   .finding-header { border-left-color: #dc2626; }
    .finding.medium .finding-header { border-left-color: #ea580c; }
    .finding.low    .finding-header { border-left-color: #2563eb; }

    .finding-id {
      font-size: 0.75rem;
      font-weight: 700;
      font-family: monospace;
      color: #64748b;
      min-width: 4.5rem;
      padding-top: 0.15rem;
    }
    .finding-title-block { flex: 1; }
    .finding-title {
      font-weight: 600;
      font-size: 1rem;
      color: #1e293b;
    }
    .finding-meta {
      font-size: 0.8rem;
      color: #64748b;
      margin-top: 0.2rem;
    }
    .finding-meta .file { font-family: monospace; }

    .severity-badge {
      font-size: 0.7rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      padding: 0.2rem 0.55rem;
      border-radius: 4px;
    }
    .badge-high   { background: #fef2f2; color: #dc2626; }
    .badge-medium { background: #fff7ed; color: #ea580c; }
    .badge-low    { background: #eff6ff; color: #2563eb; }

    .finding-body { padding: 0 1.25rem 1.25rem 3.75rem; }

    .finding-section-label {
      font-size: 0.75rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: #94a3b8;
      margin: 0.85rem 0 0.35rem;
    }
    .finding-text { font-size: 0.9rem; color: #334155; }

    /* Code blocks */
    pre {
      background: #0f172a;
      color: #e2e8f0;
      border-radius: 6px;
      padding: 1rem;
      overflow-x: auto;
      font-size: 0.82rem;
      line-height: 1.55;
      margin: 0.5rem 0;
    }
    code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; }

    /* "What to Check" checklist */
    .check-list {
      list-style: none;
      padding: 0;
      margin: 0.5rem 0;
      font-size: 0.9rem;
      color: #334155;
    }
    .check-list li {
      padding: 0.25rem 0 0.25rem 1.5rem;
      position: relative;
    }
    .check-list li::before {
      content: "→";
      position: absolute;
      left: 0;
      color: #134e4a;
      font-weight: 700;
    }

    /* ── Files table ── */
    .files-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.88rem;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: hidden;
    }
    .files-table th {
      background: #f1f5f9;
      text-align: left;
      padding: 0.65rem 1rem;
      font-weight: 600;
      color: #475569;
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border-bottom: 1px solid #e2e8f0;
    }
    .files-table td {
      padding: 0.6rem 1rem;
      border-bottom: 1px solid #f1f5f9;
      color: #334155;
    }
    .files-table tr:last-child td { border-bottom: none; }
    .files-table td:first-child { font-family: monospace; font-size: 0.82rem; color: #1e293b; }
    .files-table .count-cell { text-align: center; font-weight: 600; }
    .files-table .ok { color: #16a34a; }
    .files-table .has-issues { color: #dc2626; }

    /* ── Footer ── */
    .report-footer {
      margin-top: 3rem;
      padding: 1.5rem;
      text-align: center;
      font-size: 0.8rem;
      color: #94a3b8;
      border-top: 1px solid #e2e8f0;
    }
  </style>
</head>
<body>

<!-- ═══════════════ HEADER ═══════════════ -->
<div class="report-header">
  <h1>Methodology Report</h1>
  <div class="subtitle">Econometric design concerns — err on side of flagging</div>
  <div class="meta">
    <span><strong>Project:</strong> {{PROJECT_NAME}}</span>
    <span><strong>Reviewed:</strong> {{REVIEW_DATE}}</span>
    <span><strong>Files:</strong> {{FILE_COUNT}} files across {{LANGUAGE_LIST}}</span>
    <span><strong>Reviewer:</strong> Claude Code (methodology-reviewer agent)</span>
  </div>
</div>

<div class="container">

  <!-- ═══════════════ EXECUTIVE SUMMARY ═══════════════ -->
  <h2>Executive Summary</h2>

  <!-- Overall risk pill (choose one) -->
  <div class="risk-row">
    <span class="risk-label">Overall Methodological Risk:</span>
    <!-- Use exactly one of these: -->
    <span class="risk-pill risk-high">HIGH</span>
    <!-- <span class="risk-pill risk-medium">MEDIUM</span> -->
    <!-- <span class="risk-pill risk-low">LOW</span> -->
  </div>

  <div class="summary-box">
    {{EXECUTIVE_SUMMARY_TEXT}}
    <!-- Example: "Review identified 7 methodology concerns across 3 categories.
         The most significant issues relate to standard error clustering and
         undocumented sample restrictions that could affect the validity of
         the DiD estimates. Recommend addressing HIGH-severity items before submission." -->
  </div>

  <!-- ═══════════════ DESIGN ASSESSMENT ═══════════════ -->
  <h2>Research Design Assessment</h2>
  <div class="design-box">
    <h3>Inferred Research Design</h3>
    <div class="design-grid">
      <div class="design-item">
        <span class="design-key">Identification Strategy:</span>
        <span class="design-val">{{DESIGN_STRATEGY}}</span>
        <!-- e.g., "Difference-in-Differences (DiD)" or "Not specified" -->
      </div>
      <div class="design-item">
        <span class="design-key">Treatment Variable:</span>
        <span class="design-val">{{DESIGN_TREATMENT}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Outcome Variable(s):</span>
        <span class="design-val">{{DESIGN_OUTCOME}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Unit of Analysis:</span>
        <span class="design-val">{{DESIGN_UNIT}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Standard Errors:</span>
        <span class="design-val">{{DESIGN_SE}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Fixed Effects:</span>
        <span class="design-val">{{DESIGN_FE}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Sample Period:</span>
        <span class="design-val">{{DESIGN_PERIOD}}</span>
      </div>
      <div class="design-item">
        <span class="design-key">Key Packages:</span>
        <span class="design-val">{{DESIGN_PACKAGES}}</span>
      </div>
    </div>
  </div>

  <!-- ═══════════════ SEVERITY STAT GRID ═══════════════ -->
  <div class="stat-grid">
    <div class="stat-card sev-high">
      <div class="count">{{COUNT_HIGH}}</div>
      <div class="label">High</div>
    </div>
    <div class="stat-card sev-medium">
      <div class="count">{{COUNT_MEDIUM}}</div>
      <div class="label">Medium</div>
    </div>
    <div class="stat-card sev-low">
      <div class="count">{{COUNT_LOW}}</div>
      <div class="label">Low</div>
    </div>
  </div>

  <!-- ═══════════════ FINDINGS ═══════════════ -->
  <!--
    Findings are grouped: HIGH first, then MEDIUM, then LOW.
    Within each severity group, sub-group by category:
      - Causal Inference
      - Regression Specification
      - Standard Errors
      - Sample & Data
      - Multiple Testing
      - Descriptive Analysis
      - Dataset Variable Usage

    CSS class on .finding: high | medium | low
    Badge class: badge-high | badge-medium | badge-low
  -->
  <h2>Findings</h2>

  <!-- ── HIGH severity group ── -->
  <div class="category-heading">HIGH — {{COUNT_HIGH}} finding(s)</div>

  <!-- ─── Category sub-heading (repeat as needed) ─── -->
  <div class="category-heading" style="font-size:0.78rem; color:#94a3b8; border-color:#e2e8f0;">
    Causal Inference
  </div>

  <!-- ─── FINDING CARD (repeat for each finding) ─── -->
  <div class="finding high">
    <div class="finding-header">
      <div class="finding-id">{{FINDING_ID}}</div>
      <div class="finding-title-block">
        <div class="finding-title">{{FINDING_TITLE}}</div>
        <div class="finding-meta">
          <span class="file">{{FILE_PATH}}</span>
          <span> · {{CATEGORY}}</span>
        </div>
      </div>
      <span class="severity-badge badge-high">HIGH</span>
    </div>
    <div class="finding-body">
      <div class="finding-section-label">Relevant Code</div>
      <pre><code>{{RELEVANT_CODE_SNIPPET}}</code></pre>

      <div class="finding-section-label">Why This Is a Concern</div>
      <div class="finding-text">{{ECONOMETRIC_EXPLANATION}}</div>
      <!--
        Explain the econometric/statistical reason this is a concern.
        Reference the relevant literature or intuition.
        Example: "TWFE with staggered treatment timing is biased when treatment
        effects are heterogeneous across cohorts (Callaway & Sant'Anna 2021;
        de Chaisemartin & D'Haultfœuille 2020). The negative weights problem
        can cause the DiD estimate to have the opposite sign from the true ATT."
      -->

      <div class="finding-section-label">What to Check</div>
      <ul class="check-list">
        <li>{{CHECK_ITEM_1}}</li>
        <li>{{CHECK_ITEM_2}}</li>
        <li>{{CHECK_ITEM_3}}</li>
        <!-- Add as many → items as needed -->
      </ul>
    </div>
  </div>

  <!-- ── MEDIUM severity group ── -->
  <div class="category-heading">MEDIUM — {{COUNT_MEDIUM}} finding(s)</div>

  <!-- (finding cards as above but with class="finding medium" and badge-medium) -->

  <!-- ── LOW severity group ── -->
  <div class="category-heading">LOW — {{COUNT_LOW}} finding(s)</div>

  <!-- (finding cards as above but with class="finding low" and badge-low) -->

  <!-- If no findings: -->
  <!--
  <div class="summary-box" style="color: #16a34a; border-color: #bbf7d0;">
    No significant methodology concerns identified. All reviewed files
    appear consistent with standard econometric practice for this design.
  </div>
  -->

  <!-- ═══════════════ REVIEWED FILES TABLE ═══════════════ -->
  <h2>Reviewed Files</h2>
  <table class="files-table">
    <thead>
      <tr>
        <th>File</th>
        <th>Language</th>
        <th style="text-align:center">Lines</th>
        <th style="text-align:center">Concerns Found</th>
        <th style="text-align:center">Highest Severity</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per reviewed file -->
      <tr>
        <td>{{FILE_PATH}}</td>
        <td>{{LANGUAGE}}</td>
        <td class="count-cell">{{LINE_COUNT}}</td>
        <td class="count-cell {{HAS_ISSUES_CLASS}}">{{CONCERN_COUNT}}</td>
        <td class="count-cell">{{HIGHEST_SEVERITY}}</td>
      </tr>
      <!-- HAS_ISSUES_CLASS: "has-issues" if concerns > 0, "ok" if 0 -->
    </tbody>
  </table>

</div>

<!-- ═══════════════ FOOTER ═══════════════ -->
<div class="report-footer">
  Generated by Claude Code · methodology-reviewer agent · {{REVIEW_DATE}}<br>
  Scope: methodology &amp; design concerns — see code-error-report.html for definitive code bugs
</div>

</body>
</html>
```

---

## Category Reference

Use these exact category names in `{{CATEGORY}}` and sub-group headings:

| Category | Typical Issues |
|----------|---------------|
| `Causal Inference` | DiD, RD, IV, parallel trends, exclusion restriction |
| `Regression Specification` | OVB, bad controls, functional form, multicollinearity |
| `Standard Errors` | Clustering level, cluster count, serial/spatial correlation |
| `Sample & Data` | Restrictions, attrition, unit of analysis, outliers |
| `Multiple Testing` | 5+ outcomes, commented-out specs, subgroup analyses |
| `Descriptive Analysis` | Summary stats, missing data, merge rates, balance tables, outlier handling, distribution checks |
| `Dataset Variable Usage` | Survey weight validation, dataset-specific pitfalls, weight-type matching |

## Severity Reference

| Severity | `SEVERITY_CLASS` | `BADGE_CLASS`  | When to use |
|----------|-----------------|---------------|-------------|
| HIGH     | `high`          | `badge-high`  | Core threat to identification validity |
| MEDIUM   | `medium`        | `badge-medium`| Weakens but doesn't invalidate results |
| LOW      | `low`           | `badge-low`   | Worth checking; unlikely to change conclusions |
