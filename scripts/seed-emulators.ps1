$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    npm --prefix functions run seed
    if ($LASTEXITCODE -ne 0) { throw 'Emulator seed failed. Check that Realtime Database is running on port 9000.' }
} finally { Pop-Location }
