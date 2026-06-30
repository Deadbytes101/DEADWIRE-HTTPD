$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
$HotExeProbe=Join-Path $R 'scripts/verify-v2hotexe.ps1'
$BudgetProbe=Join-Path $R 'scripts/verify-v2budget.ps1'
$Program=Join-Path $R 'build/deadwire_v2_runtime.exe'
if(!(Test-Path $Build)){throw "missing $Build"}
if(!(Test-Path $HotExeProbe)){throw "missing $HotExeProbe"}
if(!(Test-Path $BudgetProbe)){throw "missing $BudgetProbe"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build
if($LASTEXITCODE){throw "v2 final build $LASTEXITCODE"}
if(!(Test-Path $Program)){throw "missing $Program"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe
if($LASTEXITCODE){throw "v2 hot exe $LASTEXITCODE"}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BudgetProbe
if($LASTEXITCODE){throw "v2 budget $LASTEXITCODE"}
& $Program
if($LASTEXITCODE){throw "v2 final run $LASTEXITCODE"}
Write-Output 'verify-v2final: ok'
