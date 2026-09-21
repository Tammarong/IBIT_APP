param([string]$Device = '')
$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    & (Join-Path $PSScriptRoot 'prepare-hybrid-config.ps1') | Out-Null
    $ibitPort = Get-NetTCPConnection -LocalPort 5001 -State Listen -ErrorAction SilentlyContinue
    if (-not $ibitPort) {
        throw 'Start scripts/start-hybrid-functions.ps1 in another terminal first.'
    }
    try {
        $ibitHealth = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:5001/ibit-rooms-20260914/asia-southeast1/bookingServiceStatus' -ContentType 'application/json' -Body '{"data":{}}' -TimeoutSec 12
    } catch {
        throw 'The local booking server cannot read the live database. Check scripts/start-hybrid-functions.ps1 output.'
    }
    if ($ibitHealth.result.ready -ne $true) {
        throw 'The local booking server is not ready to use the live database.'
    }
    if (-not $Device) {
        $ibitDevices = flutter devices --machine | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Could not list Flutter devices.' }
        $ibitAndroid = @($ibitDevices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($ibitAndroid.Count -ne 1) {
            throw 'Start one Android emulator, or pass -Device with an ID from flutter devices.'
        }
        $Device = $ibitAndroid[0].id
    }
    flutter run -d $Device --dart-define-from-file=firebase.hybrid.json
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not run the hybrid build.' }
} finally { Pop-Location }
