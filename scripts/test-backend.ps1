param([switch]$UseRunningEmulators)
$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    $ibitJava = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path -LiteralPath "$ibitJava\bin\java.exe") {
        $env:JAVA_HOME = $ibitJava
        $env:PATH = "$ibitJava\bin;$env:PATH"
    }
}
Push-Location $ibitRoot
try {
    npm --prefix functions test
    if ($LASTEXITCODE -ne 0) { throw 'Backend unit tests failed.' }
    if ($UseRunningEmulators) {
        npm --prefix functions run test:integration
    } else {
        firebase emulators:exec --project demo-ibit-reservations --only 'auth,firestore,functions' 'npm --prefix functions run test:integration'
    }
    if ($LASTEXITCODE -ne 0) { throw 'Backend integration tests failed.' }
} finally { Pop-Location }
