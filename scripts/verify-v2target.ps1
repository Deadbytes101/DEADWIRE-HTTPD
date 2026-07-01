$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Make=Join-Path $R 'Makefile'
$Final=Join-Path $R 'scripts/verify-v2final.ps1'
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
foreach($P in @($Make,$Final,$Build)){if(!(Test-Path $P)){throw "missing $P"}}
$M=Get-Content -Raw -Encoding UTF8 $Make
$F=Get-Content -Raw -Encoding UTF8 $Final
$B=Get-Content -Raw -Encoding UTF8 $Build
function Has([string]$Haystack,[string]$Needle,[string]$Label){if(!$Haystack.Contains($Needle)){throw "missing $Label"}}
function Lacks([string]$Haystack,[string]$Needle,[string]$Label){if($Haystack.Contains($Needle)){throw "forbidden $Label"}}
Has $M 'TARGET := build/deadwire.exe' 'main exe target'
Has $M 'SRC_INPUT := src/deadwire_windows.s' 'main server source'
Has $M 'BUILD_V2_RUNTIME_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build-v2-runtime.ps1' 'v2 build command'
Has $F '$Program=Join-Path $R ''build/deadwire_v2_runtime.exe''' 'v2 proof exe path'
Has $B '$ExePath = Join-Path $BuildDir ''deadwire_v2_runtime.exe''' 'v2 build exe path'
Lacks $B '$ExePath = Join-Path $BuildDir ''deadwire.exe''' 'v2 build main exe output'
Lacks $F '$Program=Join-Path $R ''build/deadwire.exe''' 'final main exe path'
Write-Output 'verify-v2target: ok'
