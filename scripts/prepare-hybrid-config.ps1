$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
$ibitCloudPath = Join-Path $ibitRoot 'firebase.cloud.json'
$ibitHybridPath = Join-Path $ibitRoot 'firebase.hybrid.json'
if (-not (Test-Path -LiteralPath $ibitCloudPath)) {
    throw 'firebase.cloud.json is missing. Set up the live Firebase project first.'
}
$ibitConfig = Get-Content -LiteralPath $ibitCloudPath -Raw | ConvertFrom-Json
if ($ibitConfig.FIREBASE_PROJECT_ID -ne 'ibit-rooms-20260914' -or
    $ibitConfig.FIREBASE_DATABASE_URL -ne 'https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app') {
    throw 'Hybrid mode is restricted to the configured IBIT Rooms live project and database.'
}
$ibitConfig.FIREBASE_MODE = 'hybrid'
$ibitConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ibitHybridPath -Encoding utf8
Write-Output $ibitHybridPath
