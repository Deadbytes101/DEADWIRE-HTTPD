$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$MakefilePath = Join-Path $RepoRoot 'Makefile'
$ExePath = Join-Path $RepoRoot 'build/deadwire_v2_runtime.exe'

if (-not (Test-Path $MakefilePath)) {
    throw "missing Makefile: $MakefilePath"
}

$Makefile = Get-Content -Raw -Encoding UTF8 $MakefilePath
$RequiredNeedles = @(
    'BUILD_V2_RUNTIME_CMD',
    'scripts/build-v2-runtime.ps1',
    'build-v2-runtime:',
    '$(BUILD_V2_RUNTIME_CMD)'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Makefile.Contains($Needle)) {
        throw "missing V2 make target rule: $Needle"
    }
}

& make build-v2-runtime
if ($LASTEXITCODE -ne 0) {
    throw "make build-v2-runtime failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ExePath)) {
    throw "missing V2 runtime executable after make target: $ExePath"
}

Write-Output 'verify-v2make: ok'
