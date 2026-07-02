$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Doc=Join-Path $R 'docs/benchmarks/nihserver-patched-section-runbook.md'
if(!(Test-Path $Doc)){throw "missing $Doc"}
$D=Get-Content -Raw -Encoding UTF8 $Doc
function Has([string]$Needle,[string]$Label){if(!$D.Contains($Needle)){throw "missing $Label"}}
Has 'nihserver patched-section benchmark runbook' 'doc title'
Has 'DEADWIRE Linux vs nihserver patched-section' 'required label'
Has 'syscall.s.bak' 'backup step'
Has 'section \.data' 'source section marker'
Has 'section .text' 'patched section marker'
Has 'curl -v http://127.0.0.1:19096/style.css' 'curl style probe'
Has 'NIHSERVER_PATCHED_SECTION' 'target name'
Has '--left-port 18080' 'deadwire linux port'
Has '--right-port 19096' 'right port'
Has 'Result capture template' 'result template'
Has 'Claim discipline' 'claim discipline'
Write-Output 'verify-nihserver-patched-section: ok'
