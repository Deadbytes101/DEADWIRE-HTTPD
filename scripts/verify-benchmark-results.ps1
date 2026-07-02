$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Doc=Join-Path $R 'docs/benchmarks/results/2026-07-02-wsl-nihserver-patched-section.md'
if(!(Test-Path $Doc)){throw "missing $Doc"}
$D=Get-Content -Raw -Encoding UTF8 $Doc
function Has([string]$Needle,[string]$Label){if(!$D.Contains($Needle)){throw "missing $Label"}}
Has 'DEADWIRE Linux vs nihserver patched-section' 'benchmark label'
Has 'host: WSL' 'host label'
Has 'mode: close' 'mode label'
Has 'path: /style.css' 'path label'
Has 'requests: 1024' 'request count'
Has 'rounds: 5' 'round count'
Has 'warmup: 16' 'warmup count'
Has 'DEADWIRE_LINUX 14417.28 0.069' 'left summary'
Has 'NIHSERVER_PATCHED_SECTION 4710.15 0.212' 'right summary'
Has 'winner=DEADWIRE_LINUX' 'winner summary'
Has 'rps_ratio=3.061' 'rps ratio'
Has 'latency_ratio=3.072' 'latency ratio'
Has 'patched-section' 'patched label discipline'
Write-Output 'verify-benchmark-results: ok'
