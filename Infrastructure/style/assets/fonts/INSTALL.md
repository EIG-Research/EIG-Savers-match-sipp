# EIG Font Installation Guide

EIG uses two proprietary commercial typefaces. The font files are in this directory (`Infrastructure/style/assets/fonts/`). Before generating EIG-branded figures or documents, install or load these fonts in the relevant tool.

---

## Font Inventory

| File | Family | Weight / Style | Primary Use |
|------|--------|----------------|-------------|
| `TiemposText-Regular.otf` | Tiempos Text | Regular | Body text, report prose |
| `TiemposText-RegularItalic.otf` | Tiempos Text | Regular Italic | Emphasis, source lines |
| `TiemposText-Semibold.otf` | Tiempos Text | Semibold | Subheadings, chart titles |
| `TiemposHeadline-RegularItalic.otf` | Tiempos Headline | Regular Italic | Large display headlines |
| `TiemposHeadline-LightItalic.otf` | Tiempos Headline | Light Italic | Large display headlines (light variant) |
| `GalaxiePolaris-Bold.otf` | Galaxie Polaris | Bold | Strong callouts, labels |
| `GalaxiePolaris-Book.otf` | Galaxie Polaris | Book | Axis labels, captions, UI text |
| `GalaxiePolaris-Light.otf` | Galaxie Polaris | Light | Source lines, footnotes, secondary text |

**Font suppliers:**
- Tiempos â€” Klim Type Foundry (klim.co.nz)
- Galaxie Polaris â€” Chester Jenkins / Village Type Foundry (vllg.com)

These are licensed fonts. Do not redistribute outside EIG.

---

## Installation by Tool

### Windows OS (Required for Stata and some R/Python workflows)

1. Select all `.otf` files in this directory.
2. Right-click â†’ **Install for all users** (preferred) or **Install** (current user only).
3. Fonts will be available by their internal names:
   - `Tiempos Text` (Regular, Italic, Semibold)
   - `Tiempos Headline` (variants appear as separate style entries)
   - `Galaxie Polaris` (Bold, Book, Light appear as separate weights)

---

### R â€” systemfonts (Recommended)

The `systemfonts` package allows loading fonts from a path without OS installation. This is the preferred method for reproducible EIG R projects.

```r
library(systemfonts)

# Register all EIG fonts from the assets directory
# Run once per R session (or add to .Rprofile for persistence)

eig_font_path <- here::here("Infrastructure/style/assets/fonts")  # adjust path as needed

systemfonts::register_font(
  name   = "Tiempos Text",
  plain  = file.path(eig_font_path, "TiemposText-Regular.otf"),
  italic = file.path(eig_font_path, "TiemposText-RegularItalic.otf"),
  bold   = file.path(eig_font_path, "TiemposText-Semibold.otf")
)

systemfonts::register_font(
  name  = "Tiempos Headline",
  plain = file.path(eig_font_path, "TiemposHeadline-RegularItalic.otf"),
  bold  = file.path(eig_font_path, "TiemposHeadline-LightItalic.otf")
)

systemfonts::register_font(
  name   = "Galaxie Polaris",
  plain  = file.path(eig_font_path, "GalaxiePolaris-Book.otf"),
  bold   = file.path(eig_font_path, "GalaxiePolaris-Bold.otf"),
  italic = file.path(eig_font_path, "GalaxiePolaris-Book.otf")  # no true italic; Book is used
)
```

After registering, use these names in `theme_eig()`:
```r
theme_eig(base_family = "Galaxie Polaris")
```

**Saving figures with custom fonts:** Use `ragg::agg_png()` or `svglite::svglite()` as the graphics device â€” both honor systemfonts registrations. The default `png()` device does not.

```r
ragg::agg_png("figure1.png", width = 8, height = 5, units = "in", res = 300)
# ... ggplot code ...
dev.off()
```

---

### R â€” extrafont (Alternative)

```r
library(extrafont)
font_import(paths = here::here("Infrastructure/style/assets/fonts"), prompt = FALSE)
loadfonts(device = "win")   # Windows; use device = "pdf" for PDF output
```

After import, use family names: `"Tiempos Text"`, `"Galaxie Polaris"`.

---

### Python â€” Matplotlib

Matplotlib can load fonts directly from a path without OS installation.

```python
import matplotlib.font_manager as fm
from pathlib import Path

# Add all EIG fonts to the Matplotlib font manager
font_dir = Path("Infrastructure/style/assets/fonts")   # adjust path as needed
for f in font_dir.glob("*.otf"):
    fm.fontManager.addfont(str(f))

# Verify they loaded
eig_fonts = [f.name for f in fm.fontManager.ttflist if "Tiempos" in f.name or "Galaxie" in f.name]
print(eig_fonts)

# Then set in rcParams:
import matplotlib as mpl
mpl.rcParams["font.family"] = "Galaxie Polaris"
```

**Note:** After calling `addfont()`, you must set the family name to exactly what appears in the font's metadata (as shown by the `print(eig_fonts)` step above). Common values: `"Galaxie Polaris"`, `"Tiempos Text"`.

**Clearing the cache:** If fonts don't appear after adding them, delete Matplotlib's font cache:
```python
import matplotlib.font_manager as fm
import os
os.remove(fm.get_cachedir() + "/fontlist-*.json")
# Then restart Python
```

---

### Python â€” Plotly

Plotly renders fonts in the browser (for HTML) or via Kaleido (for PNG/PDF export). For web output, fonts must be available via CSS or embedded. For static export:

1. Install the fonts at the OS level (see Windows section above), **or**
2. Use a fallback font (Plotly will use whatever is installed):
   ```python
   # In eig_plotly_template.py, font family is already set to:
   # "Galaxie Polaris, Arial, sans-serif"
   # If Galaxie Polaris is not installed, Arial is used automatically.
   ```

For Plotly web embeds in EIG publications, add the font via CSS:
```css
@font-face {
  font-family: 'Galaxie Polaris';
  src: url('/Infrastructure/style/assets/fonts/GalaxiePolaris-Book.otf') format('opentype');
  font-weight: normal;
}
```

---

### Stata

Stata requires fonts to be installed at the OS level.

1. Install via Windows font manager (see Windows section above).
2. In `eig_style.do`, the font is set with:
   ```stata
   graph set window fontface "Galaxie Polaris Book"
   ```
3. If Galaxie Polaris is not installed, Stata falls back to the default sans-serif. The `eig_style.do` script handles this gracefully with `capture`.

---

## Fallback Strategy

When EIG fonts are unavailable, use these substitutes:

| EIG Font | Best Fallback | Second Fallback |
|----------|--------------|-----------------|
| Tiempos Text | Georgia | Times New Roman |
| Tiempos Headline | Georgia Italic | â€” |
| Galaxie Polaris | Arial | DejaVu Sans (Python) / sans (R) |

All EIG figure templates are pre-configured with these fallbacks.



