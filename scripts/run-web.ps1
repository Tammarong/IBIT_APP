# Runs IBIT Rooms in a browser against the local Firebase emulators.
# No Android Studio or phone needed. Start .\scripts\start-emulators.ps1 in
# another terminal first.
param(
    [ValidateSet('', 'chrome', 'edge', 'web-server')]
    [string]$Browser = '',
    [int]$Port = 8686
)
$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    if (-not $Browser) {
        $ibitDevices = flutter devices --machine | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Could not list Flutter devices.' }
        if ($ibitDevices.id -contains 'chrome') {
            $Browser = 'chrome'
        } elseif ($ibitDevices.id -contains 'edge') {
            $Browser = 'edge'
        } else {
            throw 'Install Google Chrome or Microsoft Edge, or pass -Browser web-server and open the printed address yourself.'
        }
    }
    npm --prefix functions run seed
    if ($LASTEXITCODE -ne 0) { throw 'Start Firebase emulators with scripts/start-emulators.ps1 first.' }
    # Firebase Auth on the web only keeps using the emulator after a page
    # reload when the app is served from "localhost" (not 127.0.0.1).
    flutter run -d $Browser --web-hostname localhost --web-port $Port --dart-define=FIREBASE_MODE=emulator
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not start the web app.' }
} finally { Pop-Location }
