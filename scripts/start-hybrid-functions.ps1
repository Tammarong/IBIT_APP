$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    $ibitConfigPath = & (Join-Path $PSScriptRoot 'prepare-hybrid-config.ps1')
    $ibitConfig = Get-Content -LiteralPath $ibitConfigPath -Raw | ConvertFrom-Json
    $ibitAdcPath = if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
        $env:GOOGLE_APPLICATION_CREDENTIALS
    } else {
        Join-Path $env:APPDATA 'gcloud/application_default_credentials.json'
    }
    if (-not (Test-Path -LiteralPath $ibitAdcPath)) {
        throw 'Application Default Credentials are missing. Install Google Cloud CLI and run gcloud auth application-default login with your IBIT Firebase project account.'
    }
    if ($env:FIREBASE_AUTH_EMULATOR_HOST -or $env:FIREBASE_DATABASE_EMULATOR_HOST) {
        throw 'Close local Auth and Database emulator environment settings before hybrid mode.'
    }
    if (Test-Path -LiteralPath 'functions/.env.local') {
        throw 'functions/.env.local may override the hybrid target. Move it aside before starting this server.'
    }
    @(
        "IBIT_DATABASE_URL=$($ibitConfig.FIREBASE_DATABASE_URL)"
        'IBIT_HYBRID_MODE=1'
    ) | Set-Content -LiteralPath 'functions/.env.ibit-rooms-20260914' -Encoding utf8
    $env:IBIT_DATABASE_URL = $ibitConfig.FIREBASE_DATABASE_URL
    $env:IBIT_HYBRID_MODE = '1'
    node functions/scripts/check-live-access.cjs
    if ($LASTEXITCODE -ne 0) { throw 'The local booking server cannot access the live database.' }
    npm --prefix functions run build
    if ($LASTEXITCODE -ne 0) { throw 'Functions build failed.' }
    firebase emulators:start --project ibit-rooms-20260914 --only functions
    if ($LASTEXITCODE -ne 0) { throw 'Functions emulator failed to start.' }
} finally {
    Pop-Location
}
