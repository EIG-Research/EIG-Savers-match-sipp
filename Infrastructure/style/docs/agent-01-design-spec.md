# Agent 01: Design Professional

## Purpose
Create a single, code-ready style specification that can be implemented in R, Stata, and Python outputs (figures and tables).

## Source Priority
1. Primary source: `2022 Style Guide.pdf` (brand identity system).
2. Secondary source: `2020 EIG Design Style Guide.docx` (data-viz specific rules and semantic palettes).
3. Conflict rule: if 2022 and 2020 disagree, use 2022 unless the 2022 guide is silent for a data-viz use case.

## Implementation Contract (For Programmers)
Use this spec as design tokens and behavior rules.

### 1) Color Tokens
#### 1.1 Core Brand Palette (2022, primary)
| Token | Hex | RGB | Role |
|---|---|---|---|
| `eig_teal_900` | `#024140` | `4,65,64` | Primary dark brand color, headers, key lines |
| `eig_green_700` | `#19644D` | `26,101,77` | Secondary dark green |
| `eig_green_500` | `#5E9C86` | `94,156,134` | Secondary mid green |
| `eig_blue_800` | `#194F8B` | `25,79,139` | Primary blue for emphasis |
| `eig_blue_200` | `#B3D6DD` | `179,214,221` | Light blue tint, subtle fills |
| `eig_cream_100` | `#FEECD6` | `254,236,214` | Warm neutral background accent |
| `eig_purple_800` | `#39274F` | `57,39,79` | Accent color |
| `eig_gold_600` | `#E1AD28` | `225,173,40` | Accent color |
| `eig_cyan_700` | `#176F96` | `23,111,150` | Accent color |
| `eig_tan_500` | `#D6936F` | `214,147,111` | Accent color |
| `eig_tan_300` | `#F0B799` | `240,183,153` | Accent tint |
| `eig_black` | `#000000` | `0,0,0` | Text, strokes |
| `eig_white` | `#FFFFFF` | `255,255,255` | Background, reversed text |

Note: PDF text extraction showed one swatch as `#00000`; this is interpreted as black (`#000000`) based on context.

#### 1.2 Data Semantic Palette (2020, use when semantics matter)
Use these only for legacy/semantic comparability in data products.

| Semantic Set | Category | Hex |
|---|---|---|
| `dci_quintile` | Distressed | `#97310E` |
| `dci_quintile` | At risk | `#F97D1E` |
| `dci_quintile` | Mid-tier | `#9FD2C0` |
| `dci_quintile` | Comfortable | `#419EF1` |
| `dci_quintile` | Prosperous | `#164C87` |
| `educ_attainment` | No HS diploma | `#F97D1E` |
| `educ_attainment` | HS diploma | `#FDD7A8` |
| `educ_attainment` | Some college | `#C1DCFD` |
| `educ_attainment` | Bachelors plus | `#164C87` |
| `urban_rural` | Suburban | `#254F85` |
| `urban_rural` | Urban | `#79C5FD` |
| `urban_rural` | Small Town | `#008080` |
| `urban_rural` | Rural | `#274653` |
| `occupation` | Professional | `#FFC0CB` |
| `occupation` | Sales | `#79C5FD` |
| `occupation` | Services | `#008080` |
| `occupation` | Production | `#776FD6` |
| `occupation` | Natural Resources and Construction | `#FBA94F` |
| `race` | Black | `#FBA94F` |
| `race` | White | `#79C5FD` |
| `race` | Hispanic | `#776FD6` |
| `race` | Asian | `#236BB7` |
| `race` | Native American | `#DD88CF` |

#### 1.3 Sequential Scales (2020 maps)
- Blue gradient: `#164C87`, `#236BB7`, `#419EF1`, `#79C5FD`, `#C1DCFD`
- Red/orange gradient: `#97310E`, `#D34917`, `#F97D1E`, `#FBA94F`, `#FDD7A8`

### 2) Typography Tokens
#### 2.1 Primary (2022)
- Headline family: `Source Serif Pro` (Bold/Semibold preferred).
- Body/UI family: `Open Sans` (Regular/Semibold/Bold; Condensed Light allowed when space constrained).

#### 2.2 Legacy (2020)
- `Galaxie Polaris` and `Tiempos Text` appear in 2020 guidance. Treat as legacy only. New implementations should default to 2022 typography.

#### 2.3 Type Hierarchy (code defaults)
- Chart title: `Source Serif Pro Semibold`, 14-16 px equivalent.
- Subtitle/section labels: `Open Sans Semibold`, 11-12 px.
- Axis/legend/ticks/table cells: `Open Sans`, 9-10 px.
- Notes/citations: `Open Sans`, 8 px.

### 3) Chart System Rules
#### 3.1 Universal Figure Rules
- Background: white (`#FFFFFF`).
- Gridlines: light, minimal, major y-grid only by default.
- Spines/borders: minimal; remove top/right where possible.
- Default categorical sequence: start from core brand colors (`eig_teal_900`, `eig_blue_800`, `eig_green_500`, `eig_gold_600`, `eig_purple_800`, `eig_cyan_700`, `eig_tan_500`).
- Data labels: show when low clutter; if labels shown for all marks, y-axis/grid may be reduced (2020 rule).

#### 3.2 Chart Sizing Baseline (from 2020)
- Standard static figure target: `6.5 in x 3.5 in`.
- Web-native charts can scale up title size relative to static.

#### 3.3 Chart Components
- Title alignment: left.
- Legend text color: black on light background, white on dark fills.
- Citation/footer: include source line in small text.

### 4) Table System Rules
#### 4.1 Structure
- Table body: no heavy boxes by default.
- Header row: dark brand fill (`eig_teal_900`) with white text.
- Row separators: light gray horizontal separators only.
- Avoid dense vertical borders.

#### 4.2 Typography
- Header: `Open Sans Semibold` or `Source Serif Pro Semibold` (choose one per package and keep consistent).
- Body: `Open Sans`.
- Numeric alignment: right-align numeric columns.

### 5) Logo and Brand-Safe Usage Rules (Non-code guardrails)
- Never rotate, warp, recolor, outline, or rearrange logo.
- Do not place logo on low-contrast backgrounds.
- Use full-color logo by default; use black/white one-color versions only for constrained production contexts.

### 6) Output Type Coverage Matrix
| Output | Required Tokens | Optional Tokens |
|---|---|---|
| Line/Bar/Scatter charts | Color, typography, axis, grid, legend | Caption token |
| Map/Choropleth | Sequential scales, legend, typography | Semantic palettes |
| Small multiples | Typography, spacing, shared axis rules | Panel header color |
| Regression/event-study plots | Neutral baseline + accent highlights | CI fill tint |
| Summary tables | Header style, row separators, numeric alignment | Stripe rows |
| Model output tables | Header style, decimal format, notes style | Significance annotation styling |

### 7) Engineering Notes
- Build language-specific theme wrappers around token dictionaries rather than hardcoding styles in each chart call.
- Keep token names identical across R/Stata/Python when possible.
- Reserve semantic palettes for domain-specific charts to preserve comparability with legacy products.

### 8) Datawrapper Output Rules
- Datawrapper charts generated from R pipelines must follow:
`docs/datawrapper-integration.md`
- Repo link: [docs/datawrapper-integration.md](datawrapper-integration.md)
- Color assignment in Datawrapper must be token-derived (no net-new hardcoded hex values when token equivalents exist).
- Default mode is 2022 primary palette; legacy palettes require explicit policy trigger and metadata under:
`docs/eig-legacy-palette-policy.md`
- Repo link: [docs/eig-legacy-palette-policy.md](eig-legacy-palette-policy.md)
