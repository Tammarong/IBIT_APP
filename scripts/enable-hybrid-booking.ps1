$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
$ibitProject = 'ibit-rooms-20260914'
$ibitInstance = 'ibit-rooms-20260914-default-rtdb'
Push-Location $ibitRoot
try {
    & (Join-Path $PSScriptRoot 'prepare-hybrid-config.ps1') | Out-Null
    try {
        $ibitHealth = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:5001/$ibitProject/asia-southeast1/bookingServiceStatus" -ContentType 'application/json' -Body '{"data":{}}' -TimeoutSec 12
    } catch {
        throw 'Start scripts/start-hybrid-functions.ps1 and verify that it can read the live database first.'
    }
    if ($ibitHealth.result.ready -ne $true) {
        throw 'The local booking server is not ready to use the live database.'
    }

    $ibitCatalog = Get-Content -LiteralPath 'assets/rooms/itd_catalog.json' -Raw | ConvertFrom-Json
    $ibitEligible = @($ibitCatalog | Where-Object { $_.bookingEnabled -eq $true })
    if ($ibitEligible.Count -ne 13) { throw 'Expected exactly 13 bookable catalog rooms.' }
    $ibitExistingJson = firebase database:get /appData/rooms --project $ibitProject --instance $ibitInstance
    if ($LASTEXITCODE -ne 0) { throw 'Could not read live room records.' }
    $ibitExisting = $ibitExistingJson | ConvertFrom-Json
    $ibitPatch = [ordered]@{}
    foreach ($ibitRoom in $ibitEligible) {
        if (-not $ibitExisting.PSObject.Properties[$ibitRoom.id]) {
            throw "Live room $($ibitRoom.id) is missing. Seed rooms first."
        }
        $ibitPatch["$($ibitRoom.id)/bookingEnabled"] = $true
    }
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    $ibitPatchPath = Join-Path $ibitRoot 'artifacts/hybrid-booking-flags.json'
    $ibitPatch | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ibitPatchPath -Encoding utf8
    firebase database:update /appData/rooms $ibitPatchPath --project $ibitProject --instance $ibitInstance --force
    if ($LASTEXITCODE -ne 0) { throw 'Could not enable eligible live rooms.' }
    Write-Host 'Enabled booking for 13 classrooms and computer rooms in live Realtime Database.'
} finally {
    Pop-Location
}
