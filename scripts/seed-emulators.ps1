$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ibitRoot
try {
    npm --prefix functions run seed
    if ($LASTEXITCODE -ne 0) { throw 'Emulator seed failed. Check that Firestore is running on port 8080.' }
} finally { Pop-Location }
