$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    $ibitConfigPath = Join-Path $ibitRoot 'firebase.cloud.json'
    if (-not (Test-Path -LiteralPath $ibitConfigPath)) {
        throw 'firebase.cloud.json is missing. See the live Firebase section of README.md.'
    }
    $ibitConfig = Get-Content -LiteralPath $ibitConfigPath -Raw | ConvertFrom-Json
    if ($ibitConfig.FIREBASE_MODE -ne 'cloud' -or -not $ibitConfig.FIREBASE_DATABASE_URL) {
        throw 'Cloud mode and FIREBASE_DATABASE_URL must be set in firebase.cloud.json.'
    }
    flutter build apk --debug --dart-define-from-file=firebase.cloud.json
    if ($LASTEXITCODE -ne 0) { throw 'Cloud APK build failed.' }
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination 'artifacts/ibit-rooms-live-debug.apk' -Force
    Write-Host 'Cloud APK: artifacts/ibit-rooms-live-debug.apk'
} finally { Pop-Location }
