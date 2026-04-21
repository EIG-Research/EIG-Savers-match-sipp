# AI Skeptic Report — HTML Template

This file defines the HTML template for the AI skeptic report produced by the `ai-skeptic` sub-agent. When writing the report, replace all `{{PLACEHOLDER}}` tokens with actual content and escape user-derived strings for HTML.

The report uses a dark maroon header (`#7f1d1d`) to distinguish it visually from other review reports (navy for code, teal for methodology, etc.).

Severities for this report: **CRITICAL / HIGH / MEDIUM / LOW / INFO**.

---

## Pre-Write Checklist

Before writing `review-reports/ai-skeptic-report.html`, verify:

- [ ] All `{{PLACEHOLDER}}` tokens are replaced (grep for `{{` in final output — none should remain)
- [ ] User-supplied strings (variable names, file paths, code snippets, citations) are HTML-escaped
- [ ] Finding IDs are sequential: AS-001, AS-002, … (no gaps, no duplicates)
- [ ] Every reviewed file appears in the Reviewed Files table
- [ ] Trust Assessment pill colour matches the assessed trust level
- [ ] Assumption Inventory Table is populated (or marked empty)
- [ ] Edge-Case Test Results Table is populated (or marked empty)
- [ ] Severity counts in the stat grid match the actual findings below
- [ ] Findings are grouped by severity, then by check family within each severity
- [ ] Each finding has "What Was Claimed", "What Was Found", and "How It Was Verified" sections
- [ ] The report is self-contained (no external CSS/JS links)

---

## HTML Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Skeptic Report — {{PROJECT_NAME}}</title>
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

    /* ── Header (dark maroon — distinct from code navy and methodology teal) ── */
    .report-header {
      background: #7f1d1d;
      color: #fef2f2;
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
      color: #fca5a5;
    }
    .report-header .meta {
      margin-top: 1rem;
      display: flex;
      flex-wrap: wrap;
      gap: 2rem;
      font-size: 0.85rem;
      color: #fecaca;
    }
    .report-header .meta span strong { color: #fef2f2; }

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

    /* ── Trust assessment pill ── */
    .trust-row {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin-bottom: 1.5rem;
    }
    .trust-label { font-size: 0.9rem; font-weight: 600; color: #475569; }
    .trust-pill {
      font-size: 0.85rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      padding: 0.3rem 0.9rem;
      border-radius: 9999px;
    }
    .trust-suspect  { background: #fef2f2; color: #dc2626; border: 1px solid #fca5a5; }
    .trust-caution  { background: #fff7ed; color: #ea580c; border: 1px solid #fdba74; }
    .trust-verified { background: #f0fdf4; color: #16a34a; border: 1px solid #86efac; }

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
    .sev-critical .count, .sev-critical .label { color: #dc2626; }
    .sev-high .count, .sev-high .label         { color: #ea580c; }
    .sev-medium .count, .sev-medium .label     { color: #ca8a04; }
    .sev-low .count, .sev-low .label           { color: #2563eb; }
    .sev-info .count, .sev-info .label         { color: #64748b; }

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
      color: #7f1d1d;
      font-weight: 700;
    }

    /* ── Assumption Inventory table ── */
    .inventory-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: hidden;
      margin-bottom: 1.5rem;
    }
    .inventory-table th {
      background: #f1f5f9;
      text-align: left;
      padding: 0.65rem 0.75rem;
      font-weight: 600;
      color: #475569;
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border-bottom: 1px solid #e2e8f0;
    }
    .inventory-table td {
      padding: 0.55rem 0.75rem;
      border-bottom: 1px solid #f1f5f9;
      color: #334155;
      vertical-align: top;
    }
    .inventory-table tr:last-child td { border-bottom: none; }
    .inventory-table td:first-child { font-family: monospace; font-size: 0.8rem; text-align: center; }
    .impact-high   { color: #dc2626; font-weight: 600; }
    .impact-medium { color: #ca8a04; font-weight: 600; }
    .impact-low    { color: #2563eb; font-weight: 600; }
    .disclosed-yes     { color: #16a34a; }
    .disclosed-no      { color: #dc2626; font-weight: 600; }
    .disclosed-partial { color: #ca8a04; }

    /* ── Edge-case test results table ── */
    .test-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
      background: #fff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: hidden;
      margin-bottom: 1.5rem;
    }
    .test-table th {
      background: #f1f5f9;
      text-align: left;
      padding: 0.65rem 0.75rem;
      font-weight: 600;
      color: #475569;
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      border-bottom: 1px solid #e2e8f0;
    }
    .test-table td {
      padding: 0.55rem 0.75rem;
      border-bottom: 1px solid #f1f5f9;
      color: #334155;
      vertical-align: top;
    }
    .test-table tr:last-child td { border-bottom: none; }
    .test-pass        { color: #16a34a; font-weight: 600; }
    .test-fail-crash  { color: #dc2626; font-weight: 600; }
    .test-fail-silent { color: #7f1d1d; font-weight: 700; background: #fef2f2; }
    .test-fail-na     { color: #ea580c; font-weight: 600; }

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
    .ai-known    { color: #7f1d1d; font-weight: 600; }
    .ai-suspected { color: #ca8a04; }
    .ai-unknown  { color: #64748b; }

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
  <h1>AI Skeptic Report</h1>
  <div class="subtitle">Fabrication detection · assumption audit · edge-case stress tests · confidence calibration</div>
  <div class="meta">
    <span><strong>Project:</strong> {{PROJECT_NAME}}</span>
    <span><strong>Reviewed:</strong> {{REVIEW_DATE}}</span>
    <span><strong>Files:</strong> {{FILE_COUNT}} files across {{LANGUAGE_LIST}}</span>
    <span><strong>AI-Authored:</strong> {{AI_AUTHORED_COUNT}} files (known/suspected)</span>
    <span><strong>Reviewer:</strong> Claude Code (ai-skeptic agent)</span>
  </div>
</div>

<div class="container">

  <!-- ═══════════════ EXECUTIVE SUMMARY ═══════════════ -->
  <h2>Executive Summary</h2>

  <!-- Trust assessment pill (choose one) -->
  <div class="trust-row">
    <span class="trust-label">Overall Trust Assessment:</span>
    <!-- Use exactly one of these: -->
    <span class="trust-pill trust-suspect">SUSPECT</span>
    <!-- <span class="trust-pill trust-caution">CAUTION</span> -->
    <!-- <span class="trust-pill trust-verified">VERIFIED</span> -->
  </div>

  <!--
    TRUST_LEVEL meanings:
      VERIFIED — No fabrications found, assumptions are disclosed, edge cases handled.
                 This is rare. Use only when all checks pass.
      CAUTION  — No fabrications found, but undisclosed assumptions or untested edge
                 cases exist. The work is probably correct but needs human confirmation.
      SUSPECT  — Fabrications detected, or multiple high-severity findings across
                 check families. Do not trust this output without thorough manual review.
  -->

  <div class="summary-box">
    {{EXECUTIVE_SUMMARY_TEXT}}
    <!-- Example: "Review of 6 files found 3 fabricated function arguments, 8 undisclosed
         analytical assumptions (4 high-impact), and 2 edge-case failures. The most
         concerning finding is a hallucinated argument to fixest::feols() that silently
         changes the variance-covariance estimator. Overall trust level: SUSPECT —
         manual verification required before any results from this codebase can be cited." -->
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

  <!-- ═══════════════ ASSUMPTION INVENTORY ═══════════════ -->
  <h2>Assumption Inventory</h2>
  <p style="font-size:0.9rem; color:#64748b; margin-bottom:0.75rem;">
    Every implicit analytical choice identified in the code. Undisclosed high-impact assumptions generate individual findings below.
  </p>

  <!-- If assumptions were found, render the table: -->
  <table class="inventory-table">
    <thead>
      <tr>
        <th>#</th>
        <th>Code Location</th>
        <th>Assumption</th>
        <th>Alternatives</th>
        <th>Impact</th>
        <th>Disclosed?</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per identified assumption -->
      <tr>
        <td>{{ASSUMPTION_NUM}}</td>
        <td><span style="font-family:monospace; font-size:0.8rem;">{{ASSUMPTION_FILE}}:{{ASSUMPTION_LINE}}</span></td>
        <td>{{ASSUMPTION_DESCRIPTION}}</td>
        <td>{{ASSUMPTION_ALTERNATIVES}}</td>
        <td><span class="{{IMPACT_CLASS}}">{{IMPACT_LEVEL}}</span></td>
        <td><span class="{{DISCLOSED_CLASS}}">{{DISCLOSED_STATUS}}</span></td>
      </tr>
      <!--
        IMPACT_CLASS:    "impact-high" | "impact-medium" | "impact-low"
        DISCLOSED_CLASS: "disclosed-yes" | "disclosed-no" | "disclosed-partial"
      -->
    </tbody>
  </table>

  <!-- If NO assumptions found (unlikely): -->
  <!--
  <div class="summary-box" style="color: #64748b;">
    No implicit analytical assumptions detected. (This is suspicious in itself.)
  </div>
  -->

  <!-- ═══════════════ EDGE-CASE TEST RESULTS ═══════════════ -->
  <h2>Edge-Case Test Results</h2>
  <p style="font-size:0.9rem; color:#64748b; margin-bottom:0.75rem;">
    Adversarial inputs applied to fragile operations. FAIL-SILENT is the most dangerous outcome — wrong results with no error.
  </p>

  <!-- If tests were run, render the table: -->
  <table class="test-table">
    <thead>
      <tr>
        <th>Test ID</th>
        <th>Target Operation</th>
        <th>Edge Case</th>
        <th>File</th>
        <th>Result</th>
        <th>Detail</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per test -->
      <tr>
        <td style="font-family:monospace;">{{TEST_ID}}</td>
        <td>{{TEST_TARGET}}</td>
        <td>{{TEST_EDGE_CASE}}</td>
        <td style="font-family:monospace; font-size:0.8rem;">{{TEST_FILE}}</td>
        <td><span class="{{TEST_RESULT_CLASS}}">{{TEST_RESULT}}</span></td>
        <td>{{TEST_DETAIL}}</td>
      </tr>
      <!--
        TEST_RESULT_CLASS:
          "test-pass"        — edge case handled correctly
          "test-fail-crash"  — unhandled error
          "test-fail-silent" — wrong result, no error (MOST DANGEROUS)
          "test-fail-na"     — unexpected NA propagation
      -->
    </tbody>
  </table>

  <!-- If no tests were run: -->
  <!--
  <div class="summary-box" style="color: #64748b;">
    No edge-case tests were generated. (Data files were not accessible in the sandbox.)
  </div>
  -->

  <!-- ═══════════════ FINDINGS ═══════════════ -->
  <!--
    Findings are sorted: CRITICAL first, then HIGH, MEDIUM, LOW, INFO.
    Within each severity group, sub-group by check family:
      - Fabrication Detection (AS-1)
      - Comment-Code Fidelity (AS-2)
      - Undisclosed Assumptions (AS-3)
      - Edge-Case Stress Tests (AS-4)
      - Confidence Calibration (AS-5)
      - Pattern-Match Detection (AS-6)

    CSS class on .finding: critical | high | medium | low | info
    Badge class: badge-critical | badge-high | badge-medium | badge-low | badge-info
  -->
  <h2>Findings</h2>

  <!-- ── Severity group heading ── -->
  <div class="category-heading">CRITICAL — {{COUNT_CRITICAL}} finding(s)</div>

  <!-- ── Check family sub-heading (repeat as needed) ── -->
  <div class="category-heading" style="font-size:0.78rem; color:#94a3b8; border-color:#e2e8f0;">
    Fabrication Detection
  </div>

  <!-- ─── FINDING CARD (repeat for each finding) ─── -->
  <div class="finding {{SEVERITY_CLASS}}">
    <div class="finding-header">
      <div class="finding-id">{{FINDING_ID}}</div>
      <div class="finding-title-block">
        <div class="finding-title">{{FINDING_TITLE}}</div>
        <div class="finding-meta">
          <span class="file">{{FILE_PATH}}</span>
          <span> · {{CHECK_FAMILY}}</span>
        </div>
      </div>
      <span class="severity-badge {{BADGE_CLASS}}">{{SEVERITY_LABEL}}</span>
    </div>
    <div class="finding-body">
      <div class="finding-section-label">What Was Claimed</div>
      <div class="finding-text">{{WHAT_CLAIMED}}</div>
      <!--
        The specific claim, function call, variable reference, citation, or assumption.
        Quote exactly from the code or document.
      -->

      <div class="finding-section-label">What Was Found</div>
      <div class="finding-text">{{WHAT_FOUND}}</div>
      <!--
        The verification result: confirmed, fabricated, unverifiable, contradicted.
        Be specific about what is wrong and how it is wrong.
      -->

      <div class="finding-section-label">How It Was Verified</div>
      <div class="finding-text">{{HOW_VERIFIED}}</div>
      <!--
        The verification method: web search query and result, package documentation check,
        data inspection, test script execution, codebook cross-reference.
      -->

      <!-- Optional: code snippet if relevant -->
      <div class="finding-section-label">Relevant Code</div>
      <div class="code-label">{{FILE_PATH}}:{{LINE_NUMBER}}</div>
      <pre><code>{{CODE_SNIPPET}}</code></pre>

      <!-- Optional: what to check / recommended action -->
      <div class="finding-section-label">What to Check</div>
      <ul class="check-list">
        <li>{{CHECK_ITEM_1}}</li>
        <li>{{CHECK_ITEM_2}}</li>
      </ul>
    </div>
  </div>

  <!-- Repeat severity group + check family + finding cards for all findings -->

  <!-- If no findings (very rare for this agent): -->
  <!--
  <div class="summary-box" style="color: #16a34a; border-color: #bbf7d0;">
    No AI-specific concerns identified. All fabrication checks passed, assumptions
    are disclosed, and edge cases are handled. Trust level: VERIFIED.
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
        <th style="text-align:center">AI Authorship</th>
        <th style="text-align:center">Findings</th>
        <th style="text-align:center">Highest Severity</th>
      </tr>
    </thead>
    <tbody>
      <!-- Repeat one <tr> per reviewed file -->
      <tr>
        <td>{{FILE_PATH}}</td>
        <td>{{LANGUAGE}}</td>
        <td class="count-cell">{{LINE_COUNT}}</td>
        <td class="count-cell"><span class="{{AI_STATUS_CLASS}}">{{AI_STATUS}}</span></td>
        <td class="count-cell {{HAS_ISSUES_CLASS}}">{{FINDING_COUNT}}</td>
        <td class="count-cell">{{HIGHEST_SEVERITY}}</td>
      </tr>
      <!--
        AI_STATUS_CLASS: "ai-known" | "ai-suspected" | "ai-unknown"
        AI_STATUS: "Known" | "Suspected" | "Unknown"
        HAS_ISSUES_CLASS: "has-issues" if findings > 0, "ok" if 0
      -->
    </tbody>
  </table>

</div>

<!-- ═══════════════ FOOTER ═══════════════ -->
<div class="report-footer">
  Generated by Claude Code · ai-skeptic agent · {{REVIEW_DATE}}<br>
  Scope: AI-specific failure modes — fabrication, assumptions, edge cases, confidence calibration<br>
  See also: code-error-report.html · methodology-report.html · doc-consistency-report.html · doc-number-report.html
</div>

</body>
</html>
```

---

## Severity Reference

| Severity | `SEVERITY_CLASS` | `BADGE_CLASS` | `SEVERITY_LABEL` |
|----------|-----------------|---------------|-----------------|
| CRITICAL | `critical` | `badge-critical` | `CRITICAL` |
| HIGH | `high` | `badge-high` | `HIGH` |
| MEDIUM | `medium` | `badge-medium` | `MEDIUM` |
| LOW | `low` | `badge-low` | `LOW` |
| INFO | `info` | `badge-info` | `INFO` |

## Trust Level Reference

| Trust Level | `TRUST_CLASS` | When to use |
|-------------|--------------|-------------|
| VERIFIED | `trust-verified` | All checks pass, no fabrication, assumptions disclosed |
| CAUTION | `trust-caution` | No fabrication, but undisclosed assumptions or untested edges |
| SUSPECT | `trust-suspect` | Fabrication detected, or multiple high-severity findings |

## Check Family Names (for `{{CHECK_FAMILY}}`)

| ID | Name |
|----|------|
| AS-1 | `Fabrication Detection` |
| AS-2 | `Comment-Code Fidelity` |
| AS-3 | `Undisclosed Assumptions` |
| AS-4 | `Edge-Case Stress Tests` |
| AS-5 | `Confidence Calibration` |
| AS-6 | `Pattern-Match Detection` |
