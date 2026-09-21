$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
$ibitGoogleServicesPath = Join-Path $ibitRoot 'android/app/google-services.json'
$ibitConfigPath = Join-Path $ibitRoot 'firebase.cloud.json'
$ibitProject = 'ibit-rooms-20260914'
$ibitDatabaseUrl = 'https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app'

if (-not (Test-Path -LiteralPath $ibitGoogleServicesPath)) {
    throw 'android/app/google-services.json is missing. Restore it from the project checkout.'
}
$ibitGoogleServices = Get-Content -LiteralPath $ibitGoogleServicesPath -Raw | ConvertFrom-Json
if ($ibitGoogleServices.project_info.project_id -ne $ibitProject) {
    throw 'The Android Firebase file does not belong to the IBIT Rooms project.'
}
$ibitClients = @($ibitGoogleServices.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq 'com.ibit.rooms'
})
if ($ibitClients.Count -ne 1) { throw 'Expected one com.ibit.rooms Android Firebase app.' }
$ibitClient = $ibitClients[0]
$ibitWebClients = @($ibitClient.oauth_client | Where-Object { $_.client_type -eq 3 })
if ($ibitWebClients.Count -ne 1 -or -not $ibitClient.api_key[0].current_key) {
    throw 'The Android Firebase file is missing its Web OAuth client or API key.'
}

$ibitExpected = [ordered]@{
    FIREBASE_MODE = 'cloud'
    FIREBASE_PROJECT_ID = $ibitProject
    FIREBASE_API_KEY = $ibitClient.api_key[0].current_key
    FIREBASE_APP_ID = $ibitClient.client_info.mobilesdk_app_id
    FIREBASE_MESSAGING_SENDER_ID = [string]$ibitGoogleServices.project_info.project_number
    FIREBASE_DATABASE_URL = $ibitDatabaseUrl
    GOOGLE_SERVER_CLIENT_ID = $ibitWebClients[0].client_id
}
if (Test-Path -LiteralPath $ibitConfigPath) {
    $ibitExisting = Get-Content -LiteralPath $ibitConfigPath -Raw | ConvertFrom-Json
    foreach ($ibitField in $ibitExpected.Keys) {
        if ($ibitExisting.$ibitField -ne $ibitExpected[$ibitField]) {
            throw "firebase.cloud.json already exists but $ibitField does not match the included Android Firebase configuration. Review it before continuing."
        }
    }
    Write-Host 'firebase.cloud.json already matches the IBIT Rooms Firebase project.'
} else {
    $ibitExpected | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ibitConfigPath -Encoding utf8
    Write-Host 'Created firebase.cloud.json for the existing IBIT Rooms Firebase project.'
}
Write-Output $ibitConfigPath
