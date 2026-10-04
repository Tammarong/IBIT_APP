# Renders every main screen with fake data to build/design_preview/*.png.
# Used by the design skill (.claude/skills/design) to review UI changes.
param(
    [string]$OutDir = 'build/design_preview'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
flutter test test/design_preview_test.dart `
    --dart-define=DESIGN_PREVIEW=true `
    "--dart-define=DESIGN_PREVIEW_DIR=$OutDir"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-ChildItem $OutDir -Filter *.png | ForEach-Object { $_.FullName }
