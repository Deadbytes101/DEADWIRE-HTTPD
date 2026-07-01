$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Bench=Join-Path $R 'scripts/bench-score.sh'
$Doc=Join-Path $R 'docs/benchmarks/wsl-nihserver.md'
if(!(Test-Path $Bench)){throw "missing $Bench"}
if(!(Test-Path $Doc)){throw "missing $Doc"}
$S=Get-Content -Raw -Encoding UTF8 $Bench
$D=Get-Content -Raw -Encoding UTF8 $Doc
function Has([string]$Text,[string]$Needle,[string]$Label){if(!$Text.Contains($Needle)){throw "missing $Label"}}
Has $S '#!/usr/bin/env sh' 'shell script shebang'
Has $S 'set -eu' 'strict shell mode'
Has $S 'tools/deadwire_bench.c' 'native client source'
Has $S 'cc_bin=${CC:-cc}' 'compiler selection'
Has $S '-D_POSIX_C_SOURCE=200809L' 'posix compile definition'
Has $S 'run_one_side()' 'side runner'
Has $S '--left-exe' 'left executable argument'
Has $S '--right-exe' 'right executable argument'
Has $S '--left-args' 'left args argument'
Has $S '--right-args' 'right args argument'
Has $S '--keepalive' 'keepalive argument'
Has $S 'median_rps=' 'rps parser'
Has $S 'median_avg_ms=' 'latency parser'
Has $S 'winner=' 'winner output'
Has $S 'rps_ratio=' 'rps ratio output'
Has $S 'latency_ratio=' 'latency ratio output'
Has $D 'WSL / Linux benchmark lane' 'doc title'
Has $D 'DEADWIRE Linux build' 'linux lane contract'
Has $D 'target/nihserver/nihserver' 'linux server binary path'
Has $D 'sh scripts/bench-score.sh' 'shell score command'
Has $D '--left-port 18080' 'left port in docs'
Has $D '--right-name NIHSERVER' 'score target'
Has $D '--path /style.css' 'shared static path'
Write-Output 'verify-linux-scorebench: ok'
