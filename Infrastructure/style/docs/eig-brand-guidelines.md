# EIG Brand Guidelines

Reference for logo usage, color palette, typography, photography, and illustration standards in all EIG publications, presentations, web assets, and external materials. Based on the 2022 EIG Style Guide and the actual logo and font files in `Infrastructure/style/assets/`.

---

## 1. Logo

### Versions

EIG maintains three approved logo versions. All approved files are in `Infrastructure/style/assets/logo/eig/`.

| Version | File Location | Use Case |
|---------|--------------|----------|
| **Full Color** | `Infrastructure/style/assets/logo/eig/svg/EIG_fullcolor.svg` (web); `Infrastructure/style/assets/logo/eig/png/EIG_fullcolor.png` (raster); `Infrastructure/style/assets/logo/eig/eps/EIG_fullcolor.eps` (print) | Default. Use on white or light backgrounds. |
| **Black & White** | `Infrastructure/style/assets/logo/eig/svg/EIG_blackandwhite.svg`; equivalent PNG/EPS | When color printing is unavailable or on light backgrounds requiring a single-color mark. |
| **Reverse (White)** | `Infrastructure/style/assets/logo/eig/svg/EIG_reverse.svg`; equivalent PNG/EPS | On dark or colored backgrounds. |

### Logo Colors (Actual)
- **Full color icon (diamond/chevron element):** `#D6936F` Terra Cotta
- **Full color wordmark:** `#231F20` near-black
- **Reverse:** `#FFFFFF` white (entire logo)

### Format Selection Guide
- **Web / scalable:** SVG — always prefer over raster for web use
- **Presentations / Word / email:** PNG (`@2x` for retina displays)
- **Print publications:** EPS or CMYK JPG (`Infrastructure/style/assets/logo/eig/jpg/EIG_fullcolor_CMYK-100.jpg`)
- **Logo source editing:** AI files in `Infrastructure/style/assets/logo/eig/ai/` — only for the brand designer

See `Infrastructure/style/assets/logo/README.md` for the complete file inventory.

### Logo Rules — What to Do
- Always use an approved logo file from `Infrastructure/style/assets/logo/`. Do not recreate the logo from type.
- Maintain clear space around the logo equal to the height of the "E" in EIG on all sides.
- Scale the logo proportionally. Never distort.
- Use the correct version for the background (see table above).

### Logo Rules — What Never to Do
1. Do not change the logo colors.
2. Do not stretch or compress the logo.
3. Do not add effects (drop shadows, outlines, glows) to the logo.
4. Do not place the logo on a busy photographic background without a clear zone.
5. Do not use an outdated logo version.
6. Do not rearrange logo elements (wordmark, icon, tagline).
7. Do not reduce the logo below the minimum size (1 inch / 72px wide for digital).
8. Do not place the logo in a shape or container that obscures it.
9. Do not use the logo icon alone without the wordmark in external-facing materials unless specifically approved.

---

## 2. Color Palette

### Primary Colors

| Name | Hex | RGB | CMYK | PMS |
|------|-----|-----|------|-----|
| Forest Green | `#19644d` | 25, 100, 77 | 75, 0, 23, 61 | 7728 C |
| Gold | `#E1AD28` | 225, 173, 40 | 0, 23, 82, 12 | 7549 C |
| Medium Blue | `#176F96` | 23, 111, 150 | 85, 26, 0, 41 | 7694 C |
| Navy | `#194F8B` | 25, 79, 139 | 82, 43, 0, 45 | 7686 C |

### Secondary Colors

| Name | Hex | RGB | CMYK | PMS |
|------|-----|-----|------|-----|
| Terra Cotta | `#D6936F` | 214, 147, 111 | 0, 31, 48, 16 | 7526 C |
| Sage Green | `#5E9C86` | 94, 156, 134 | 40, 0, 14, 39 | 7476 C |
| Purple | `#39274F` | 57, 39, 79 | 28, 51, 0, 69 | 7671 C |
| Dark Teal | `#024140` | 2, 65, 64 | 97, 0, 2, 75 | 7717 C |

### Accent / Extended Colors

| Name | Hex | RGB | CMYK | PMS |
|------|-----|-----|------|-----|
| Peach | `#F0B799` | 240, 183, 153 | 0, 24, 36, 6 | 7506 C |
| Light Blue | `#B3D6DD` | 179, 214, 221 | 19, 3, 0, 13 | 551 C |
| Warm Gray | `#A89F94` | 168, 159, 148 | 0, 5, 12, 34 | Warm Gray 7 C |
| Black | `#1A1A1A` | 26, 26, 26 | 0, 0, 0, 90 | Black 6 C |

### Color Usage Rules
- **Forest Green** is the primary EIG brand color. Use for primary calls to action, key data highlights, and primary data series.
- **Gold** is the secondary accent. Use to draw attention to critical data points or key findings — sparingly.
- **Navy** and **Medium Blue** are approved for charts, maps, and supporting data series.
- **Neutrals (Warm Gray, Black):** Body text in Black or near-black. Warm Gray for secondary text, borders, and backgrounds.
- **Never use colors not in this palette** for EIG-branded materials.
- **Accessibility:** Always verify that foreground/background color combinations meet WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text). Use a contrast checker before finalizing layouts.

---

## 3. Typography

EIG uses two proprietary commercial typefaces. Font files are in `Infrastructure/style/assets/fonts/`. Installation instructions are in `Infrastructure/style/assets/fonts/INSTALL.md`.

### Typefaces

| Family | Role | Available Weights / Styles |
|--------|------|---------------------------|
| **Tiempos Headline** | Display headlines, large callout text | Regular Italic, Light Italic |
| **Tiempos Text** | Body text, report prose, subheadings | Regular, Regular Italic, Semibold |
| **Galaxie Polaris** | Captions, axis labels, UI text, figure source lines, secondary prose | Light, Book, Bold |

**Tiempos** is a serif editorial typeface from Klim Type Foundry. **Galaxie Polaris** is a sans-serif typeface from Chester Jenkins / Village Type Foundry. Both are licensed — do not redistribute outside EIG.

### Typography Rules

- **Large display headlines:** Tiempos Headline Regular Italic or Light Italic. Title case for print; sentence case for digital.
- **Body text:** Tiempos Text Regular, 10–12pt print / 16–18px web. Line height: 1.5× font size.
- **Subheadings:** Tiempos Text Semibold or Galaxie Polaris Bold.
- **Captions and source lines:** Galaxie Polaris Light or Book, 8–9pt print / 13–14px web.
- **Pull quotes:** Tiempos Text Regular Italic, larger than body text.
- **Data labels and axis text in charts:** Galaxie Polaris Book, as small as legible (minimum 7pt print / 10px web).
- **Figure titles / chart titles:** Tiempos Text Semibold (or Galaxie Polaris Bold if a sans-serif look is preferred in the layout).
- **Navigation, UI, button text:** Galaxie Polaris Book or Bold.
- **Never use decorative or novelty typefaces** in EIG materials.
- **Never stretch or condense fonts** — use weight variants instead.
- **Font substitution (when brand fonts unavailable):**
  - Tiempos Text / Tiempos Headline → Georgia (serif fallback)
  - Galaxie Polaris → Arial or system sans-serif

---

## 4. Photography Guidelines

- **Subject matter:** Photography should feature real people, real places, and real economic activity — not stock-photo clichÃ©s. Prioritize images that reflect EIG's geographic focus areas (cities, rural communities, workplaces, infrastructure).
- **Diversity:** Photography should reflect the diversity of the American workforce and communities EIG covers. Avoid imagery that stereotypes any group.
- **Tone:** Aspirational but honest. Avoid purely bleak or purely celebratory imagery; EIG's research addresses complex, real challenges.
- **Color treatment:** Photography may be used in full color, duotone (Forest Green + white or Gold + white), or black-and-white. Do not apply filters that alter skin tones unnaturally.
- **Resolution:** Minimum 300 dpi for print; 72 dpi at full display size for web.
- **Licensing:** All photography must be licensed for EIG's use. Document the license for every image in the project file.
- **Attribution:** Credit the photographer in the document if required by license terms.
- **Placement:** Do not crop photographs to circles or arbitrary shapes. Rectangular crops are standard; square crops acceptable for social media thumbnails.

---

## 5. Illustration Guidelines

- **Style:** EIG illustration style is clean, minimal, and data-informed — not cartoonish or overly decorative. Icons and diagrams should aid comprehension, not decorate.
- **Color:** Use EIG palette colors only. Icons should be single-color or two-color maximum.
- **Icons:** Use consistent icon sets throughout a single publication. Do not mix icon families.
- **Maps:** Use EIG color palette for choropleth fills. Start with a light neutral base (Light Blue or Warm Gray at low opacity). Use Forest Green → Gold gradient for positive values; consider diverging schemes for comparative maps.
- **Infographics:** Follow the same figure labeling conventions as charts: "Figure N." label, sentence-case title, source line.
- **File formats:** Export illustrations as SVG (preferred for scalability) or high-resolution PNG (minimum 300 dpi at final size).
- **Accessibility:** Ensure illustrations do not convey information through color alone. Add labels, patterns, or annotations where needed.

---

## 6. Sub-Brand: Agglomerations

Agglomerations is an EIG content brand (publication series, newsletter, or podcast). Its logo files are in `Infrastructure/style/assets/logo/agglomerations/`.

| File | Use |
|------|-----|
| `Agglomerations-Final.png` | Primary logo — default for all Agglomerations materials |
| `Agglomerations-Final-Resized.png` | Smaller/web version for thumbnails and social media |
| `Agglomerations-Alt1.png` | Approved alternative variant 1 |
| `Agglomerations-Alt2.png` | Approved alternative variant 2 |
| `Agglomerations-Alt3.png` | Approved alternative variant 3 |

- Use the Agglomerations logo only on Agglomerations-branded materials. Do not substitute it for the EIG logo or combine them without explicit design approval.
- Apply the same logo usage rules as the EIG logo (no stretching, no recoloring, maintain clear space).
- The Agglomerations brand uses the EIG color palette and Tiempos/Galaxie Polaris fonts.

---

## 7. Asset Directory Reference

```
Infrastructure/style/assets/
â”œâ”€â”€ fonts/
â”‚   â”œâ”€â”€ INSTALL.md                          # Per-tool installation instructions
â”‚   â”œâ”€â”€ GalaxiePolaris-Bold.otf
â”‚   â”œâ”€â”€ GalaxiePolaris-Book.otf
â”‚   â”œâ”€â”€ GalaxiePolaris-Light.otf
â”‚   â”œâ”€â”€ TiemposHeadline-LightItalic.otf
â”‚   â”œâ”€â”€ TiemposHeadline-RegularItalic.otf
â”‚   â”œâ”€â”€ TiemposText-Regular.otf
â”‚   â”œâ”€â”€ TiemposText-RegularItalic.otf
â”‚   â””â”€â”€ TiemposText-Semibold.otf
â””â”€â”€ logo/
    â”œâ”€â”€ README.md                           # Logo inventory + usage guide
    â”œâ”€â”€ eig/
    â”‚   â”œâ”€â”€ svg/   EIG_fullcolor.svg, EIG_blackandwhite.svg, EIG_reverse.svg
    â”‚   â”œâ”€â”€ png/   Full color, B&W, Reverse (1× and @2x)
    â”‚   â”œâ”€â”€ eps/   Full color, B&W, Reverse (for print)
    â”‚   â”œâ”€â”€ jpg/   CMYK versions (for print vendors)
    â”‚   â””â”€â”€ ai/    Master Illustrator source files
    â””â”€â”€ agglomerations/
        Agglomerations-Final.png, -Resized.png, -Alt1/2/3.png
```



