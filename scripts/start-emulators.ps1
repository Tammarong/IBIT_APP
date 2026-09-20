param([switch]$IncludeFirestoreForMigration)
$ErrorActionPreference = 'Stop'
$ibitRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    $ibitJava = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path -LiteralPath "$ibitJava\bin\java.exe") {
        $env:JAVA_HOME = $ibitJava
        $env:PATH = "$ibitJava\bin;$env:PATH"
    } else {
        throw 'Install Java 21 or newer and add java to PATH before starting Firebase emulators.'
    }
}
Push-Location $ibitRoot
try {
    npm --prefix functions run build
    if ($LASTEXITCODE -ne 0) { throw 'Functions build failed.' }
    $ibitData = Join-Path $ibitRoot '.emulator-data'
    $ibitServices = if ($IncludeFirestoreForMigration) { 'auth,firestore,database,functions' } else { 'auth,database,functions' }
    $ibitArguments = @('emulators:start', '--project', 'demo-ibit-reservations', '--only', $ibitServices, '--export-on-exit', $ibitData)
    if (Test-Path -LiteralPath (Join-Path $ibitData 'firebase-export-metadata.json')) {
        $ibitArguments += @('--import', $ibitData)
    }
    firebase @ibitArguments
    if ($LASTEXITCODE -ne 0) { throw 'Firebase emulators failed to start.' }
} finally { Pop-Location }
