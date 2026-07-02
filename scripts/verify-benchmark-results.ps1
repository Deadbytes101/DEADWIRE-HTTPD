$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Doc=Join-Path $R 'docs/benchmarks/results/2026-07-02-wsl-nihserver-patched-section.md'
$Index=Join-Path $R 'docs/benchmarks/results/README.md'
if(!(Test-Path $Doc)){throw "missing $Doc"}
if(!(Test-Path $Index)){throw "missing $Index"}
$D=Get-Content -Raw -Encoding UTF8 $Doc
$I=Get-Content -Raw -Encoding UTF8 $Index
function HasDoc([string]$Needle,[string]$Label){if(!$D.Contains($Needle)){throw "missing $Label"}}
function HasIndex([string]$Needle,[string]$Label){if(!$I.Contains($Needle)){throw "missing index $Label"}}
HasDoc 'DEADWIRE Linux vs nihserver patched-section' 'benchmark label'
HasDoc 'host: WSL' 'host label'
HasDoc 'mode: close' 'mode label'
HasDoc 'path: /style.css' 'path label'
HasDoc 'requests: 1024' 'request count'
HasDoc 'rounds: 5' 'round count'
HasDoc 'warmup: 16' 'warmup count'
HasDoc 'DEADWIRE_LINUX 14417.28 0.069' 'left summary'
HasDoc 'NIHSERVER_PATCHED_SECTION 4710.15 0.212' 'right summary'
HasDoc 'winner=DEADWIRE_LINUX' 'winner summary'
HasDoc 'rps_ratio=3.061' 'rps ratio'
HasDoc 'latency_ratio=3.072' 'latency ratio'
HasDoc 'patched-section' 'patched label discipline'
HasIndex 'Benchmark results index' 'title'
HasIndex '2026-07-02' 'date'
HasIndex 'DEADWIRE_LINUX' 'winner'
HasIndex '3.061x' 'rps ratio'
HasIndex '3.072x' 'latency ratio'
HasIndex '2026-07-02-wsl-nihserver-patched-section.md' 'result link'
Write-Output 'verify-benchmark-results: ok'
