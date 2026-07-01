$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Final=Join-Path $R 'scripts/verify-v2final.ps1'
if(!(Test-Path $Final)){throw "missing $Final"}
$S=Get-Content -Raw -Encoding UTF8 $Final
$Lines=Get-Content -Encoding UTF8 $Final
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
function LineIndex([string]$Needle){for($I=0;$I -lt $Lines.Count;$I++){if($Lines[$I] -eq $Needle){return $I}} return -1}
function BeforeLine([string]$Left,[string]$Right,[string]$Label){$L=LineIndex $Left;$R=LineIndex $Right;if($L -lt 0 -or $R -lt 0 -or $L -ge $R){throw "bad order $Label"}}
Has "`$SelectChainProbe=Join-Path `$R 'scripts/verify-v2selectchain.ps1'" 'select chain probe binding'
Has "`$SelectClientProbe=Join-Path `$R 'scripts/verify-v2selectclientprobe.ps1'" 'select client probe binding'
Has "`$BuildSourceProbe=Join-Path `$R 'scripts/verify-v2buildsource.ps1'" 'build source probe binding'
Has "`$RequestProbe=Join-Path `$R 'scripts/verify-v2requestprobe.ps1'" 'request coverage probe binding'
Has "`$LivePathProbe=Join-Path `$R 'scripts/verify-v2livepath.ps1'" 'network path probe binding'
Has "`$AssetsProbe=Join-Path `$R 'scripts/verify-v2assets.ps1'" 'asset probe binding'
Has "`$HotExeProbe=Join-Path `$R 'scripts/verify-v2hotexe.ps1'" 'hot exe probe binding'
Has "`$BudgetProbe=Join-Path `$R 'scripts/verify-v2budget.ps1'" 'budget probe binding'
Has "`$SizeProbe=Join-Path `$R 'scripts/verify-v2size.ps1'" 'size probe binding'
Has "`$CallBudgetProbe=Join-Path `$R 'scripts/verify-v2callbudget.ps1'" 'call budget probe binding'
Has "`$BranchBudgetProbe=Join-Path `$R 'scripts/verify-v2branchbudget.ps1'" 'branch budget probe binding'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelectChainProbe' 'select chain execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildSourceProbe' 'build source execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RequestProbe' 'request coverage execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LivePathProbe' 'network path execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AssetsProbe' 'asset execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'build execution'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HotExeProbe' 'hot exe execution'
Has '& $Program' 'proof executable run'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SelectChainProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'select chain before build'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildSourceProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'build source before build'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RequestProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'request coverage before build'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LivePathProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'network path before build'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AssetsProbe' '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' 'asset before build'
BeforeLine '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build' '& $Program' 'build before executable run'
Write-Output 'verify-v2finalgate: ok'
