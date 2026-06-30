$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Build)){throw "missing $Build"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build
if($LASTEXITCODE){throw "v2 final build $LASTEXITCODE"}
if(!(Test-Path $Program)){throw "missing $Program"}
& $Program
if($LASTEXITCODE){throw "v2 final run $LASTEXITCODE"}
Write-Output 'verify-v2final: ok'
