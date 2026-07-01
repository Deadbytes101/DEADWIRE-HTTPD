$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Bench=Join-Path $R 'scripts/bench-v2-live.ps1'
if(!(Test-Path $Bench)){throw "missing $Bench"}
$S=Get-Content -Raw -Encoding UTF8 $Bench
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
Has 'param(' 'params'
Has '[int]$Rounds = 7' 'rounds'
Has '[int]$SmokeRequests = 8' 'smoke count'
Has 'scripts/build-v2-runtime.ps1' 'build script'
Has 'build/deadwire_v2_runtime.exe' 'program path'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScript' 'build call'
Has '[System.Diagnostics.Stopwatch]::StartNew()' 'timer'
Has '& $Program' 'program call'
Has '$ExitCode = $LASTEXITCODE' 'exit capture'
Has 'bench-v2-live:' 'round output'
Has 'bench-v2-live-summary:' 'summary output'
Has 'median-ms/run' 'median ms'
Has 'median-us/request' 'median request'
Write-Output 'verify-v2livebench: ok'
