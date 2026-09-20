$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
$ibitProject = 'ibit-rooms-20260914'
$ibitInstance = 'ibit-rooms-20260914-default-rtdb'
$ibitUrl = 'https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app'
Push-Location $ibitRoot
try {
    $ibitConfig = Get-Content -LiteralPath 'firebase.cloud.json' -Raw | ConvertFrom-Json
    if ($ibitConfig.FIREBASE_PROJECT_ID -ne $ibitProject -or $ibitConfig.FIREBASE_DATABASE_URL -ne $ibitUrl) {
        throw 'Cloud configuration does not match the IBIT Rooms Realtime Database.'
    }
    $ibitExisting = firebase database:get /appData/rooms --project $ibitProject --instance $ibitInstance
    if ($LASTEXITCODE -ne 0) { throw 'Could not read live room records.' }
    if ($ibitExisting.Trim() -ne 'null') {
        Write-Host 'Live rooms already exist; preserving them without changes.'
        return
    }

    $ibitCatalog = Get-Content -LiteralPath 'assets/rooms/itd_catalog.json' -Raw | ConvertFrom-Json
    $ibitRooms = [ordered]@{}
    foreach ($ibitEntry in $ibitCatalog) {
        $ibitRoom = [ordered]@{}
        foreach ($ibitField in $ibitEntry.PSObject.Properties) {
            if ($ibitField.Name -ne 'id') { $ibitRoom[$ibitField.Name] = $ibitField.Value }
        }
        # The live booking function is not deployed on the Spark plan.
        $ibitRoom['bookingEnabled'] = $false
        $ibitRoom['listed'] = $true
        $ibitRoom['subtitle'] = "Floor $($ibitEntry.floor) · ITD, KMUTNB"
        $ibitRoom['description'] = ''
        $ibitRoom['assetPath'] = 'assets/rooms/room-01.png'
        $ibitRoom['facilities'] = @()
        $ibitRooms[$ibitEntry.id] = $ibitRoom
    }
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    $ibitSeed = Join-Path $ibitRoot 'artifacts/cloud-room-seed.json'
    $ibitRooms | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ibitSeed -Encoding utf8
    firebase database:set /appData/rooms $ibitSeed --project $ibitProject --instance $ibitInstance --force
    if ($LASTEXITCODE -ne 0) { throw 'Could not seed live room records.' }
    Write-Host "Seeded $($ibitRooms.Count) live room records. Booking remains disabled until the secure backend is deployed."
} finally {
    Pop-Location
}
