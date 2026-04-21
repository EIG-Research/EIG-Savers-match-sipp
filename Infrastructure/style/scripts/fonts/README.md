# Font Setup and Validation

## Required Font Families
- Headline: `Source Serif Pro` (fallback permitted if explicitly allowed)
- Body/UI: `Open Sans`

Fallback stacks are defined in:
`tokens/eig-style-tokens.v1.json`

## Install Scripts
- macOS: `scripts/fonts/install-fonts-macos.sh`
- Linux: `scripts/fonts/install-fonts-linux.sh`
- Windows: `scripts/fonts/install-fonts-windows.ps1`

## Startup Checks (Fail Fast)
- Python strict primary:
  `python3 scripts/fonts/check-fonts.py`
- Python allow fallback:
  `python3 scripts/fonts/check-fonts.py --allow-fallback`
- R strict primary:
  `Rscript scripts/fonts/check-fonts.R`
- R allow fallback:
  `Rscript scripts/fonts/check-fonts.R --allow-fallback`
- Stata strict primary:
  `do scripts/fonts/check-fonts.do`
- Stata allow fallback:
  `do scripts/fonts/check-fonts.do allow_fallback`

## Integration Recommendation
Run the language-specific check at project startup and fail pipeline execution on non-zero exit codes.
