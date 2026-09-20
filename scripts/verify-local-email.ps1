param(
    [Parameter(Mandatory = $true)]
    [string]$Email
)

$ErrorActionPreference = 'Stop'
$ibitEmail = $Email.Trim()
if (-not $ibitEmail) { throw 'Enter the email address used to create your account.' }

$ibitCodes = Invoke-RestMethod -Uri 'http://127.0.0.1:9099/emulator/v1/projects/demo-ibit-reservations/oobCodes'
$ibitMatches = @($ibitCodes.oobCodes | Where-Object {
    $_.requestType -eq 'VERIFY_EMAIL' -and $_.email -ieq $ibitEmail
})
if ($ibitMatches.Count -eq 0) {
    throw 'No pending verification link exists for this address. In the app, tap "Resend verification email" and run this command again.'
}

$ibitLink = [Uri]$ibitMatches[-1].oobLink
if ($ibitLink.Scheme -ne 'http' -or
    $ibitLink.Host -notin @('127.0.0.1', 'localhost') -or
    $ibitLink.Port -ne 9099 -or
    $ibitLink.AbsolutePath -ne '/emulator/action') {
    throw 'The emulator returned an unexpected verification URL; no request was made.'
}

$ibitResult = Invoke-RestMethod -Uri $ibitLink.AbsoluteUri
if (-not $ibitResult.authEmulator.success) {
    throw 'The emulator did not confirm verification. Try resending the link in the app.'
}

Write-Host "Verified $ibitEmail in the local Firebase Authentication emulator. Return to the app and tap 'I’ve verified my email'."
