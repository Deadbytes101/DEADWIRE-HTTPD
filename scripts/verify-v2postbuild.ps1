$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Final=Join-Path $R 'scripts/verify-v2final.ps1'
if(!(Test-Path $Final)){throw "missing $Final"}
$S=Get-Content -Raw -Encoding UTF8 $Final
$Lines=Get-Content -Encoding UTF8 $Final
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
function LineIndex([string]$Needle){for($I=0;$I -lt $Lines.Count;$I++){if($Lines[$I] -eq $Needle){return $I}} return -1}
function BeforeLine([string]$Left,[string]$Right,[string]$Label){$L=LineIndex $Left;$RR=LineIndex $Right;if($L -lt 0 -or $RR -lt 0 -or $L -ge $RR){throw "bad order $Label"}}
Has "`$HotExeProbe=Join-Path `$R 'scripts/verify-v2hotexe.ps1'" 'hot exe binding'
Has "`$BudgetProbe=Join-Path `$R 'scripts/verify-v2budget.ps1'" 'budget binding'
Has "`$SizeProbe=Join-Path `$R 'scripts/verify-v2size.ps1'" 'size binding'
Has "`$CallBudgetProbe=Join-Path `$R 'scripts/verify-v2callbudget.ps1'" 'call budget binding'
Has "`$BranchBudgetProbe=Join-Path `$R 'scripts/verify-v2branchbudget.ps1'" 'branch budget binding'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'build execution'
Has 'if(!(Test-Path $Program)){throw "missing $Program"}' 'program existence check'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe' 'hot exe execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BudgetProbe' 'budget execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SizeProbe' 'size execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CallBudgetProbe' 'call budget execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BranchBudgetProbe' 'branch budget execution'
Has '& $Program' 'program execution'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'if(!(Test-Path $Program)){throw "missing $Program"}' 'build before program exists'
BeforeLine 'if(!(Test-Path $Program)){throw "missing $Program"}' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe' 'program exists before hot exe'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BudgetProbe' 'hot exe before budget'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BudgetProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SizeProbe' 'budget before size'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SizeProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CallBudgetProbe' 'size before call budget'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CallBudgetProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BranchBudgetProbe' 'call budget before branch budget'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BranchBudgetProbe' '& $Program' 'branch budget before program run'
Write-Output 'verify-v2postbuild: ok'
