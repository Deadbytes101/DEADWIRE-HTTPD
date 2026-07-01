$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Bench=Join-Path $R 'scripts/bench-score.ps1'
if(!(Test-Path $Bench)){throw "missing $Bench"}
$S=Get-Content -Raw -Encoding UTF8 $Bench
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
Has '[string] $LeftName' 'left name parameter'
Has '[string] $RightName' 'right name parameter'
Has '[string] $LeftServerExePath' 'left server executable parameter'
Has '[string] $RightServerExePath' 'right server executable parameter'
Has '[string[]] $LeftServerArgs' 'left server args parameter'
Has '[string[]] $RightServerArgs' 'right server args parameter'
Has '[int] $LeftPort' 'left port parameter'
Has '[int] $RightPort' 'right port parameter'
Has '[switch] $LeftExistingServer' 'left existing server switch'
Has '[switch] $RightExistingServer' 'right existing server switch'
Has 'scripts/bench-external-server.ps1' 'external bench harness'
Has 'function Run-OneServerBench' 'bench runner'
Has 'native-bench: .*median_rps=([0-9.]+).*median_avg_ms=([0-9.]+)' 'summary parser'
Has 'winner=' 'winner output'
Has 'rps_ratio=' 'rps ratio output'
Has 'latency_ratio=' 'latency ratio output'
Write-Output 'verify-scorebench: ok'
