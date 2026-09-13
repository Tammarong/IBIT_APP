param([string]$Device = '')
$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    if (-not $Device) {
        $ibitDevices = flutter devices --machine | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Could not list Flutter devices.' }
        $ibitAndroid = @($ibitDevices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($ibitAndroid.Count -ne 1) {
            throw 'Start one Android emulator, or pass -Device with an ID from flutter devices.'
        }
        $Device = $ibitAndroid[0].id
    }
    npm --prefix functions run seed
    if ($LASTEXITCODE -ne 0) { throw 'Start Firebase emulators with scripts/start-emulators.ps1 first.' }
    flutter run -d $Device --dart-define=FIREBASE_MODE=emulator
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not run. Check flutter devices and pass -Device with the Android device ID.' }
} finally { Pop-Location }
