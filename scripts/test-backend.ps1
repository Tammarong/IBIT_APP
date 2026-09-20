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
    if ($UseRunningEmulators) {
        npm --prefix functions run test:unit:compiled
        if ($LASTEXITCODE -ne 0) { throw 'Backend unit tests failed.' }
        npm --prefix functions run test:integration
    } else {
        npm --prefix functions test
        if ($LASTEXITCODE -ne 0) { throw 'Backend unit tests failed.' }
        firebase emulators:exec --project demo-ibit-reservations --only 'auth,database,functions' 'npm --prefix functions run test:integration'
    }
    if ($LASTEXITCODE -ne 0) { throw 'Backend integration tests failed.' }
} finally { Pop-Location }
