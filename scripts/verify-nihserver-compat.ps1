$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Doc=Join-Path $R 'docs/benchmarks/nihserver-compat.md'
if(!(Test-Path $Doc)){throw "missing $Doc"}
$D=Get-Content -Raw -Encoding UTF8 $Doc
function Has([string]$Needle,[string]$Label){if(!$D.Contains($Needle)){throw "missing $Label"}}
Has 'nihserver WSL compatibility note' 'doc title'
Has 'SIGSEGV' 'segfault signature'
Has 'syscall_stat' 'gdb syscall frame'
Has 'src/nihserver/start.s:131' 'gdb caller frame'
Has 'section .data' 'upstream section marker'
Has 'section .text' 'compatibility section marker'
Has 'NIHSERVER_PATCHED_SECTION' 'patched target label'
Has 'Claim discipline' 'claim discipline section'
Write-Output 'verify-nihserver-compat: ok'
