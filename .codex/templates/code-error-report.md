# Code Error Report — HTML Template

This file defines the HTML template for the code error report produced by the `code-reviewer` sub-agent. When writing the report, replace all `{{PLACEHOLDER}}` tokens with actual content and escape user-derived strings for HTML.

---

## Pre-Write Checklist

Before writing `review-reports/code-error-report.html`, verify:

- [ ] All `{{PLACEHOLDER}}` tokens are replaced (grep for `{{` in final output — none should remain)
- [ ] User-supplied strings (variable names, file paths, code snippets) are HTML-escaped (`<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;`)
- [ ] Finding IDs are sequential: CE-001, CE-002, … (no gaps, no duplicates)
- [ ] Every reviewed file appears in the Reviewed Files table
- [ ] Code blocks use `<pre><code>` tags, not raw text
- [ ] Severity counts in the stat grid match the actual findings below
- [ ] The report is self-contained (no external CSS/JS links)

---

## HTML Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Code Error Report — {{PROJECT_NAME}}</title>
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

    /* ── Header ── */
    .report-header {
      background: #1e293b;
      color: #f1f5f9;
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
      color: #94a3b8;
    }
    .report-header .meta {
      margin-top: 1rem;
      display: flex;
      gap: 2rem;
      font-size: 0.85rem;
      color: #cbd5e1;
    }
    .report-header .meta span strong { color: #f1f5f9; }

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

    /* ── Stat grid ── */
    .stat-grid {
      display: grid;
      grid-template-columns: repeat(6, 1fr);
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
    /* Severity colours */
    .sev-critical .count { color: #dc2626; }
    .sev-critical .label { color: #dc2626; }
    .sev-high .count    { color: #ea580c; }
    .sev-high .label    { color: #ea580c; }
    .sev-medium .count  { color: #ca8a04; }
    .sev-medium .label  { color: #ca8a04; }
    .sev-low .count     { color: #2563eb; }
    .sev-low .label     { color: #2563eb; }
    .sev-info .count    { color: #64748b; }
    .sev-info .label    { color: #64748b; }
    .sev-suggestion .count { color: #16a34a; }
    .sev-suggestion .label { color: #16a34a; }

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
    .finding.critical .finding-header { border-left-color: #dc2626; }
    .finding.high     .finding-header { border-left-color: #ea580c; }
    .finding.medium   .finding-header { border-left-color: #ca8a04; }
    .finding.low      .finding-header { border-left-color: #2563eb; }
    .finding.info       .finding-header { border-left-color: #94a3b8; }
    .finding.suggestion .finding-header { border-left-color: #16a34a; }

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
    .badge-critical { background: #fef2f2; color: #dc2626; }
    .badge-high     { background: #fff7ed; color: #ea580c; }
    .badge-medium   { background: #fefce8; color: #ca8a04; }
    .badge-low      { background: #eff6ff; color: #2563eb; }
    .badge-info       { background: #f1f5f9; color: #64748b; }
    .badge-suggestion { background: #f0fdf4; color: #16a34a; }

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
    .code-label {
      font-size: 0.7rem;
      color: #64748b;
      font-family: monospace;
      margin-bottom: 0.15rem;
    }

    /* ── Data currency table ── */
    .data-currency-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.88rem;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: hidden;
    }
    .data-currency-table th {
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
    .data-currency-table td {
      padding: 0.6rem 1rem;
      border-bottom: 1px solid #f1f5f9;
      color: #334155;
    }
    .data-currency-table tr:last-child td { border-bottom: none; }
    .data-currency-note {
      font-size: 0.85rem;
      color: #64748b;
      margin-bottom: 0.75rem;
    }
    .status-current {
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 600;
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      background: #f0fdf4;
      color: #16a34a;
    }
    .status-outdated {
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 600;
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      background: #fffbeb;
      color: #d97706;
    }
    .status-unknown {
      display: inline-block;
      font-size: 0.75rem;
      font-weight: 600;
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      background: #f1f5f9;
      color: #64748b;
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
  <h1>Code Error Report</h1>
  <div class="subtitle">Definitive code bugs and efficiency/readability suggestions</div>
  <div class="meta">
    <span><strong>Project:</strong> {{PROJECT_NAME}}</span>
    <span><strong>Reviewed:</strong> {{REVIEW_DATE}}</span>
    <span><strong>Files:</strong> {{FILE_COUNT}} files across {{LANGUAGE_LIST}}</span>
    <span><strong>Reviewer:</strong> Claude Code (code-reviewer agent)</span>
  </div>
</div>

<div class="container">

  <!-- ═══════════════ EXECUTIVE SUMMARY ═══════════════ -->
  <h2>Executive Summary</h2>
  <div class="summary-box">
    {{EXECUTIVE_SUMMARY_TEXT}}
    <!-- Example: "Review of 8 files (4 Python, 3 R, 1 Stata) found 12 definitive code errors.
         2 CRITICAL errors will produce wrong results silently; 3 HIGH errors may corrupt
         the analysis dataset. Immediate attention recommended before submission." -->
  </div>

  <!-- ═══════════════ SEVERITY STAT GRID ═══════════════ -->
  <div class="stat-grid">
    <div class="stat-card sev-critical">
      <div class="count">{{COUNT_CRITICAL}}</div>
      <div class="label">Critical</div>
    </div>
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
    <div class="stat-card sev-info">
      <div class="count">{{COUNT_INFO}}</div>
      <div class="label">Info</div>
    </div>
    <div class="stat-card sev-suggestion">
      <div class="count">{{COUNT_SUGGESTION}}</div>
      <div class="label">Suggestions</div>
    </div>
  </div>

  <!-- ═══════════════ FINDINGS ═══════════════ -->
  <!-- Findings are sorted: CRITICAL first, then HIGH, MEDIUM, LOW, INFO, SUGGESTION -->
  <h2>Findings</h2>

  <!-- ─── FINDING CARD TEMPLATE (repeat for each finding) ─── -->
  <!--
    CSS class on .finding controls the left-border colour:
      critical | high | medium | low | info | suggestion
    Badge class:
      badge-critical | badge-high | badge-medium | badge-low | badge-info | badge-suggestion
  -->

  <div class="finding {{SEVERITY_CLASS}}">
    <div class="finding-header">
      <div class="finding-id">{{FINDING_ID}}</div>
      <div class="finding-title-block">
        <div class="finding-title">{{FINDING_TITLE}}</div>
        <div class="finding-meta">
          <span class="file">{{FILE_PATH}}</span>
          <span> · Line {{LINE_NUMBER}} · {{LANGUAGE}}</span>
        </div>
      </div>
      <span class="severity-badge {{BADGE_CLASS}}">{{SEVERITY_LABEL}}</span>
    </div>
    <div class="finding-body">
      <div class="finding-section-label">Problematic Code</div>
      <div class="code-label">{{FILE_PATH}}:{{LINE_NUMBER}}</div>
      <pre><code>{{PROBLEMATIC_CODE_SNIPPET}}</code></pre>

      <div class="finding-section-label">Why This Is Wrong</div>
      <div class="finding-text">{{WHY_WRONG_EXPLANATION}}</div>

      <div class="finding-section-label">Recommended Fix</div>
      <pre><code>{{RECOMMENDED_FIX_SNIPPET}}</code></pre>
      <div class="finding-text">{{FIX_EXPLANATION}}</div>
    </div>
  </div>

  <!-- Repeat the above .finding block for each error found -->
  <!-- If no findings: -->
  <!--
  <div class="summary-box" style="color: #16a34a; border-color: #bbf7d0;">
    No definitive code errors found. All {{FILE_COUNT}} files passed review.
  </div>
  -->

  <!-- ═══════════════ DATA CURRENCY ═══════════════ -->
  <h2>Data Currency</h2>
  <p class="data-currency-note">Checks whether recognized public datasets are using the latest available release. Informational only — researchers may deliberately use a specific vintage.</p>

  <!-- If recognized public datasets were found, render the table: -->
  <table class="data-currency-table">
    <thead>
      <tr>
        <th>Dataset</th>
        <th>Version in Code</th>
        <th>Latest Available</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per recognized dataset -->
      <tr>
        <td>{{DATASET_NAME}}</td>
        <td>{{VERSION_IN_CODE}}</td>
        <td>{{LATEST_AVAILABLE}}</td>
        <td><span class="{{CURRENCY_STATUS_CLASS}}">{{CURRENCY_STATUS}}</span></td>
      </tr>
      <!--
        CURRENCY_STATUS_CLASS values:
          "status-current"  — dataset is up to date (green)
          "status-outdated" — a newer release exists (amber)
          "status-unknown"  — could not verify latest version (gray)
      -->
    </tbody>
  </table>

  <!-- If NO recognized public datasets were found, replace the table above with: -->
  <!--
  <div class="summary-box" style="color: #64748b; border-color: #e2e8f0;">
    No recognized public datasets detected.
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
        <th style="text-align:center">Errors Found</th>
        <th style="text-align:center">Highest Severity</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per reviewed file -->
      <tr>
        <td>{{FILE_PATH}}</td>
        <td>{{LANGUAGE}}</td>
        <td class="count-cell">{{LINE_COUNT}}</td>
        <td class="count-cell {{HAS_ISSUES_CLASS}}">{{ERROR_COUNT}}</td>
        <td class="count-cell">{{HIGHEST_SEVERITY}}</td>
      </tr>
      <!-- HAS_ISSUES_CLASS: "has-issues" if errors > 0, "ok" if 0 -->
    </tbody>
  </table>

</div>

<!-- ═══════════════ FOOTER ═══════════════ -->
<div class="report-footer">
  Generated by Claude Code · code-reviewer agent · {{REVIEW_DATE}}<br>
  Scope: definitive code errors + efficiency/readability suggestions — see methodology-report.html for design concerns
</div>

</body>
</html>
```

---

## Severity Reference (for filling in badge/class values)

| Severity | `SEVERITY_CLASS` | `BADGE_CLASS`    | `SEVERITY_LABEL` |
|----------|-----------------|-----------------|-----------------|
| CRITICAL   | `critical`   | `badge-critical`   | `CRITICAL`   |
| HIGH       | `high`       | `badge-high`       | `HIGH`       |
| MEDIUM     | `medium`     | `badge-medium`     | `MEDIUM`     |
| LOW        | `low`        | `badge-low`        | `LOW`        |
| INFO       | `info`       | `badge-info`       | `INFO`       |
| SUGGESTION | `suggestion` | `badge-suggestion` | `SUGGESTION` |

## HAS_ISSUES_CLASS Reference

| Condition       | Class         |
|-----------------|---------------|
| Error count > 0 | `has-issues`  |
| Error count = 0 | `ok`          |

## CURRENCY_STATUS_CLASS Reference

| Status             | `CURRENCY_STATUS_CLASS` | `CURRENCY_STATUS`    |
|--------------------|------------------------|---------------------|
| Up to date         | `status-current`       | `Current`           |
| Newer release exists | `status-outdated`    | `Update Available`  |
| Could not verify   | `status-unknown`       | `Unable to Verify`  |
