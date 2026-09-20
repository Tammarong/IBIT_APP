param([string]$Device = '')
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
    if (-not $Device) {
        $ibitDevices = flutter devices --machine | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Could not list Flutter devices.' }
        $ibitAndroid = @($ibitDevices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($ibitAndroid.Count -ne 1) {
            throw 'Start one Android emulator, or pass -Device with an ID from flutter devices.'
        }
        $Device = $ibitAndroid[0].id
    }
    flutter run -d $Device --dart-define-from-file=firebase.cloud.json
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not run the cloud build.' }
} finally { Pop-Location }
