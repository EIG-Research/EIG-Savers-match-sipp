# EIG Design Signoff Checklist

## Purpose
Resolve all provisional or ambiguous design decisions before locking language themes as `v1.0.0`.

## Effective Date
Current checklist drafted on February 15, 2026.

## Source of Truth
- Token file: `tokens/eig-style-tokens.v1.json`
- Primary guide: `2022 Style Guide.pdf`
- Secondary guide: `2020 EIG Design Style Guide.docx`

## Blocking Signoff Items
| Item ID | Description | Current State | Required Decision | Owner | Status |
|---|---|---|---|---|---|
| `a-2022-black-swatch` | 2022 extracted swatch appears as `#00000` in text extraction | Provisionally set to `#000000` | Confirm exact intended black token | Design lead | Pending |
| `font-source-serif-variant` | `Source Serif Pro` availability varies by environment | Fallback stack defined | Confirm whether fallback to `Source Serif 4` is approved equivalence | Design lead | Pending |
| `legacy-palette-trigger` | Legacy 2020 semantic sets can be overused | Policy + metadata validator implemented | Confirm strict trigger criteria and required metadata fields | Research/data viz lead | Pending |

## Non-Blocking Signoff Items
| Item ID | Description | Current State | Owner | Status |
|---|---|---|---|---|
| `photo-icon-illustration-codification` | Visual guidance exists but is not fully codified for programmatic outputs | Documented as non-code guardrail | Design lead | Pending |
| `accessibility-thresholds` | Contrast and minimum text rules not yet formalized in tokens | Tracked for next phase | Accessibility owner | Pending |

## Approval Record
| Role | Name | Date | Signature/Initials |
|---|---|---|---|
| Design Lead |  |  |  |
| Data Viz Lead |  |  |  |
| Engineering Lead |  |  |  |

## Exit Criteria
All blocking items must be `Approved`, and provisional token statuses must be updated in `tokens/eig-style-tokens.v1.json`.
