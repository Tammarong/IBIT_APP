$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    & (Join-Path $PSScriptRoot 'prepare-hybrid-config.ps1') | Out-Null
    flutter build apk --debug --dart-define-from-file=firebase.hybrid.json
    if ($LASTEXITCODE -ne 0) { throw 'Hybrid APK build failed.' }
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination 'artifacts/ibit-rooms-hybrid-debug.apk' -Force
    Write-Host 'Hybrid APK: artifacts/ibit-rooms-hybrid-debug.apk'
} finally { Pop-Location }
