$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Make=Join-Path $R 'Makefile'
$Run=Join-Path $R 'scripts/verify-v2run.ps1'
$Final=Join-Path $R 'scripts/verify-v2final.ps1'
foreach($P in @($Make,$Run,$Final)){if(!(Test-Path $P)){throw "missing $P"}}
$M=Get-Content -Raw -Encoding UTF8 $Make
$V2=Get-Content -Raw -Encoding UTF8 $Run
$F=Get-Content -Raw -Encoding UTF8 $Final
function Has([string]$Haystack,[string]$Needle,[string]$Label){if(!$Haystack.Contains($Needle)){throw "missing $Label"}}
Has $M 'VERIFY_TRIPLE_THREAD_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2modeprobe.ps1' 'v2 mode probe make binding'
Has $M 'verify-triple-thread:' 'verify triple thread target'
Has $M "`t`$(VERIFY_TRIPLE_THREAD_CMD)" 'verify triple thread command'
Has $V2 '$NextProbe = Join-Path $RepoRoot ''scripts/verify-v2final.ps1''' 'run-to-final binding'
Has $V2 '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NextProbe' 'run-to-final execution'
Has $F '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $FinalGateProbe' 'final gate execution'
Has $F '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RequestProbe' 'request gate execution'
Has $F '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LivePathProbe' 'live path execution'
Has $F '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AssetsProbe' 'asset execution'
Write-Output 'verify-v2makepath: ok'
