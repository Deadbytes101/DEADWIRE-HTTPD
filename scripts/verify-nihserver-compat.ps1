$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Doc=Join-Path $R 'docs/benchmarks/nihserver-compat.md'
$WslDoc=Join-Path $R 'docs/benchmarks/wsl-nihserver.md'
if(!(Test-Path $Doc)){throw "missing $Doc"}
if(!(Test-Path $WslDoc)){throw "missing $WslDoc"}
$D=Get-Content -Raw -Encoding UTF8 $Doc
$W=Get-Content -Raw -Encoding UTF8 $WslDoc
function Has([string]$Text,[string]$Needle,[string]$Label){if(!$Text.Contains($Needle)){throw "missing $Label"}}
Has $D 'nihserver WSL compatibility note' 'doc title'
Has $D 'SIGSEGV' 'failure signature'
Has $D 'syscall_stat' 'trace frame'
Has $D 'src/nihserver/start.s:131' 'caller frame'
Has $D 'section .data' 'source marker'
Has $D 'section .text' 'compatibility marker'
Has $D 'NIHSERVER_PATCHED_SECTION' 'target label'
Has $D 'Claim discipline' 'claim section'
Has $W 'nihserver-compat.md' 'cross reference'
Write-Output 'verify-nihserver-compat: ok'
