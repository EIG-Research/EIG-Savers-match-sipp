# Document Number Verification Report — HTML Template

This file defines the HTML template for the number verification report produced by the `data-consistency-reviewer` sub-agent. When writing the report, replace all `{{PLACEHOLDER}}` tokens with actual content and escape user-derived strings for HTML.

Severities for this report are **CRITICAL / HIGH / MEDIUM / LOW / INFO** (same as code error report). The report uses a dark indigo header (`#312e81`) to distinguish it visually from the other reports.

---

## Pre-Write Checklist

Before writing `doc-number-report.html`, verify:

- [ ] All `{{PLACEHOLDER}}` tokens are replaced (grep for `{{` in final output — none should remain)
- [ ] User-supplied strings (variable names, file paths, document excerpts) are HTML-escaped
- [ ] Finding IDs are sequential: DN-001, DN-002, … (no gaps, no duplicates)
- [ ] Every reviewed file (document and code) appears in the Reviewed Files table
- [ ] Number Inventory Table includes every extracted number
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
  <title>Number Verification Report — {{PROJECT_NAME}}</title>
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

    /* ── Header (dark indigo — distinct from code navy and methodology teal) ── */
    .report-header {
      background: #312e81;
      color: #eef2ff;
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
      color: #a5b4fc;
    }
    .report-header .meta {
      margin-top: 1rem;
      display: flex;
      gap: 2rem;
      flex-wrap: wrap;
      font-size: 0.85rem;
      color: #c7d2fe;
    }
    .report-header .meta span strong { color: #eef2ff; }

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

    /* ── Verification summary row ── */
    .verify-row {
      display: flex;
      gap: 1.5rem;
      flex-wrap: wrap;
      margin-bottom: 1.5rem;
    }
    .verify-stat {
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 0.75rem 1.25rem;
      text-align: center;
      flex: 1;
      min-width: 140px;
    }
    .verify-stat .num {
      font-size: 1.6rem;
      font-weight: 700;
      line-height: 1;
    }
    .verify-stat .lbl {
      font-size: 0.72rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-top: 0.25rem;
      color: #64748b;
    }
    .verify-stat.extracted .num { color: #312e81; }
    .verify-stat.verified  .num { color: #16a34a; }
    .verify-stat.flagged   .num { color: #dc2626; }

    /* ── Stat grid (5 severities) ── */
    .stat-grid {
      display: grid;
      grid-template-columns: repeat(5, 1fr);
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

    /* ── Number Inventory Table ── */
    .inventory-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.84rem;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: hidden;
      margin-bottom: 2rem;
    }
    .inventory-table th {
      background: #f1f5f9;
      text-align: left;
      padding: 0.6rem 0.75rem;
      font-weight: 600;
      color: #475569;
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border-bottom: 1px solid #e2e8f0;
    }
    .inventory-table td {
      padding: 0.5rem 0.75rem;
      border-bottom: 1px solid #f1f5f9;
      color: #334155;
      vertical-align: top;
    }
    .inventory-table tr:last-child td { border-bottom: none; }
    .inventory-table .mono { font-family: monospace; font-size: 0.8rem; }
    .inventory-table .context { font-size: 0.78rem; color: #64748b; max-width: 220px; }

    /* Status badges for inventory table */
    .status-badge {
      font-size: 0.68rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 0.15rem 0.45rem;
      border-radius: 3px;
      white-space: nowrap;
    }
    .status-verified     { background: #f0fdf4; color: #16a34a; }
    .status-mismatch     { background: #fef2f2; color: #dc2626; }
    .status-unverifiable { background: #fefce8; color: #ca8a04; }
    .status-approximate  { background: #eff6ff; color: #2563eb; }

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
    .finding.info     .finding-header { border-left-color: #94a3b8; }

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
    .badge-info     { background: #f1f5f9; color: #64748b; }

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

    /* Document excerpt (blockquote style) */
    .doc-excerpt {
      background: #faf5ff;
      border-left: 3px solid #312e81;
      padding: 0.65rem 1rem;
      margin: 0.5rem 0;
      font-size: 0.88rem;
      color: #334155;
      border-radius: 0 6px 6px 0;
    }
    .doc-excerpt .highlight {
      background: #fde68a;
      padding: 0.05rem 0.25rem;
      border-radius: 2px;
      font-weight: 600;
    }

    /* Value comparison box */
    .value-compare {
      display: flex;
      gap: 1rem;
      margin: 0.5rem 0;
      font-size: 0.88rem;
    }
    .value-box {
      flex: 1;
      padding: 0.6rem 0.85rem;
      border-radius: 6px;
      font-family: monospace;
      font-weight: 600;
    }
    .value-claimed {
      background: #fef2f2;
      color: #dc2626;
      border: 1px solid #fecaca;
    }
    .value-actual {
      background: #f0fdf4;
      color: #16a34a;
      border: 1px solid #bbf7d0;
    }
    .value-label {
      font-size: 0.68rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-weight: 600;
      margin-bottom: 0.2rem;
    }

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
  <h1>Number Verification Report</h1>
  <div class="subtitle">Every number in the document checked against the code and data</div>
  <div class="meta">
    <span><strong>Project:</strong> {{PROJECT_NAME}}</span>
    <span><strong>Reviewed:</strong> {{REVIEW_DATE}}</span>
    <span><strong>Document:</strong> {{DOCUMENT_FILES}}</span>
    <span><strong>Code files:</strong> {{CODE_FILE_COUNT}} across {{LANGUAGE_LIST}}</span>
    <span><strong>Reviewer:</strong> Claude Code (data-consistency-reviewer agent)</span>
  </div>
</div>

<div class="container">

  <!-- ═══════════════ EXECUTIVE SUMMARY ═══════════════ -->
  <h2>Executive Summary</h2>

  <!-- Verification stats -->
  <div class="verify-row">
    <div class="verify-stat extracted">
      <div class="num">{{NUMBERS_EXTRACTED}}</div>
      <div class="lbl">Numbers Extracted</div>
    </div>
    <div class="verify-stat verified">
      <div class="num">{{NUMBERS_VERIFIED}}</div>
      <div class="lbl">Verified Correct</div>
    </div>
    <div class="verify-stat flagged">
      <div class="num">{{NUMBERS_FLAGGED}}</div>
      <div class="lbl">Flagged</div>
    </div>
  </div>

  <div class="summary-box">
    {{EXECUTIVE_SUMMARY_TEXT}}
    <!-- Example: "Extracted 47 numerical claims from manuscript.tex and verified them
         against 6 source code files. 38 numbers were confirmed correct, 4 could not be
         traced to any code output, and 5 show discrepancies. 2 CRITICAL mismatches affect
         headline results reported in the abstract." -->
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
  </div>

  <!-- ═══════════════ NUMBER INVENTORY TABLE ═══════════════ -->
  <h2>Number Inventory</h2>
  <table class="inventory-table">
    <thead>
      <tr>
        <th>#</th>
        <th>Claimed Value</th>
        <th>Document Location</th>
        <th>Code Source</th>
        <th>Verified Value</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per extracted number -->
      <tr>
        <td class="mono">{{ROW_NUMBER}}</td>
        <td class="mono"><strong>{{CLAIMED_VALUE}}</strong></td>
        <td class="context">{{DOC_LOCATION}}</td>
        <td class="mono">{{CODE_SOURCE}}</td>
        <td class="mono">{{VERIFIED_VALUE}}</td>
        <td><span class="status-badge {{STATUS_CLASS}}">{{STATUS_LABEL}}</span></td>
      </tr>
      <!--
        STATUS_CLASS / STATUS_LABEL combinations:
          status-verified     / Verified
          status-mismatch     / Mismatch
          status-unverifiable / Unverifiable
          status-approximate  / Approximate
      -->
    </tbody>
  </table>

  <!-- ═══════════════ FINDINGS ═══════════════ -->
  <!-- Findings are sorted: CRITICAL first, then HIGH, MEDIUM, LOW, INFO -->
  <!-- Only numbers with Mismatch or Unverifiable status get detailed finding cards -->
  <h2>Findings</h2>

  <!-- ─── FINDING CARD TEMPLATE (repeat for each finding) ─── -->
  <!--
    CSS class on .finding controls the left-border colour:
      critical | high | medium | low | info
    Badge class:
      badge-critical | badge-high | badge-medium | badge-low | badge-info
  -->

  <div class="finding {{SEVERITY_CLASS}}">
    <div class="finding-header">
      <div class="finding-id">{{FINDING_ID}}</div>
      <div class="finding-title-block">
        <div class="finding-title">{{FINDING_TITLE}}</div>
        <div class="finding-meta">
          <span class="file">{{DOC_FILE}}</span>
          <span> · {{DOC_SECTION}}</span>
        </div>
      </div>
      <span class="severity-badge {{BADGE_CLASS}}">{{SEVERITY_LABEL}}</span>
    </div>
    <div class="finding-body">

      <div class="finding-section-label">In the Document</div>
      <div class="doc-excerpt">
        {{DOCUMENT_CONTEXT_WITH_HIGHLIGHT}}
        <!-- Use <span class="highlight">NUMBER</span> to highlight the number in context -->
        <!-- Example: "Moreover, <span class="highlight">40,321</span> new firms were born in 2000." -->
      </div>

      <div class="finding-section-label">Claimed vs. Actual</div>
      <div class="value-compare">
        <div class="value-box value-claimed">
          <div class="value-label">Document says</div>
          {{CLAIMED_VALUE}}
        </div>
        <div class="value-box value-actual">
          <div class="value-label">Code produces</div>
          {{ACTUAL_VALUE}}
          <!-- Use "Not found" if unverifiable -->
        </div>
      </div>

      <div class="finding-section-label">Source in Code</div>
      <div class="code-label">{{CODE_FILE_PATH}}:{{CODE_LINE}}</div>
      <pre><code>{{CODE_SNIPPET}}</code></pre>
      <!-- If unverifiable, show the search steps attempted instead -->

      <div class="finding-section-label">Explanation</div>
      <div class="finding-text">{{EXPLANATION}}</div>

      <div class="finding-section-label">Recommendation</div>
      <div class="finding-text">{{RECOMMENDATION}}</div>
    </div>
  </div>

  <!-- Repeat the above .finding block for each flagged number -->
  <!-- If no findings: -->
  <!--
  <div class="summary-box" style="color: #16a34a; border-color: #bbf7d0;">
    All {{NUMBERS_EXTRACTED}} numbers verified successfully. No mismatches found.
  </div>
  -->

  <!-- ═══════════════ REVIEWED FILES TABLE ═══════════════ -->
  <h2>Reviewed Files</h2>
  <table class="files-table">
    <thead>
      <tr>
        <th>File</th>
        <th>Type</th>
        <th>Language</th>
        <th style="text-align:center">Lines</th>
        <th style="text-align:center">Numbers / Errors</th>
        <th style="text-align:center">Highest Severity</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per reviewed file (documents and code) -->
      <tr>
        <td>{{FILE_PATH}}</td>
        <td>{{FILE_TYPE}}</td>
        <!-- FILE_TYPE: "Document" or "Code" -->
        <td>{{LANGUAGE}}</td>
        <td class="count-cell">{{LINE_COUNT}}</td>
        <td class="count-cell {{HAS_ISSUES_CLASS}}">{{COUNT}}</td>
        <!-- For documents: count of numbers extracted. For code: count of errors traced to this file. -->
        <td class="count-cell">{{HIGHEST_SEVERITY}}</td>
      </tr>
    </tbody>
  </table>

</div>

<!-- ═══════════════ FOOTER ═══════════════ -->
<div class="report-footer">
  Generated by Claude Code · data-consistency-reviewer agent · {{REVIEW_DATE}}<br>
  Scope: document number verification — see code-error-report.html for code bugs, methodology-report.html for design concerns
</div>

</body>
</html>
```

---

## Severity Reference (for filling in badge/class values)

| Severity | `SEVERITY_CLASS` | `BADGE_CLASS`    | `SEVERITY_LABEL` |
|----------|-----------------|-----------------|-----------------|
| CRITICAL | `critical`      | `badge-critical` | `CRITICAL`      |
| HIGH     | `high`          | `badge-high`     | `HIGH`          |
| MEDIUM   | `medium`        | `badge-medium`   | `MEDIUM`        |
| LOW      | `low`           | `badge-low`      | `LOW`           |
| INFO     | `info`          | `badge-info`     | `INFO`          |

## Status Reference (for Number Inventory Table)

| Status | `STATUS_CLASS` | `STATUS_LABEL` |
|--------|---------------|----------------|
| Verified | `status-verified` | `Verified` |
| Mismatch | `status-mismatch` | `Mismatch` |
| Unverifiable | `status-unverifiable` | `Unverifiable` |
| Approximate | `status-approximate` | `Approximate` |

## HAS_ISSUES_CLASS Reference

| Condition       | Class         |
|-----------------|---------------|
| Count > 0       | `has-issues`  |
| Count = 0       | `ok`          |
