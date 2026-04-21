$ErrorActionPreference = "Stop"

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
$tmpDir = Join-Path $env:TEMP "eig-fonts"

New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$fonts = @(
  @{
    Display = "Open Sans Regular"
    File = "OpenSans-Regular.ttf"
    Urls = @(
      "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-Regular.ttf"
    )
  },
  @{
    Display = "Open Sans SemiBold"
    File = "OpenSans-SemiBold.ttf"
    Urls = @(
      "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-SemiBold.ttf"
    )
  },
  @{
    Display = "Source Serif Pro SemiBold"
    File = "SourceSerifPro-Semibold.ttf"
    Urls = @(
      "https://github.com/adobe-fonts/source-serif-pro/raw/release/TTF/SourceSerifPro-Semibold.ttf",
      "https://github.com/adobe-fonts/source-serif/raw/release/TTF/SourceSerif4-Semibold.ttf"
    )
  }
)

function Download-WithFallback {
  param(
    [string[]]$Urls,
    [string]$OutFile
  )

  foreach ($url in $Urls) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
      return
    } catch {
      Write-Host "Download failed from $url, trying next source..."
    }
  }
  throw "All download URLs failed for $OutFile"
}

foreach ($font in $fonts) {
  $tmpFile = Join-Path $tmpDir $font.File
  $destFile = Join-Path $fontDir $font.File

  Download-WithFallback -Urls $font.Urls -OutFile $tmpFile
  Copy-Item $tmpFile $destFile -Force

  New-ItemProperty `
    -Path $regPath `
    -Name "$($font.Display) (TrueType)" `
    -Value $font.File `
    -PropertyType String `
    -Force | Out-Null
}

Write-Host "Fonts installed. Restart R/Python/Stata sessions before running plots."
