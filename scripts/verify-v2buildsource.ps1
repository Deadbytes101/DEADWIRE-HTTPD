$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
if(!(Test-Path $Build)){throw "missing $Build"}
$S=Get-Content -Raw -Encoding UTF8 $Build
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
function Lacks([string]$Needle,[string]$Label){if($S.Contains($Needle)){throw "forbidden $Label"}}
Has 'scripts/gen-v2-runtime-hot.ps1' 'generator path'
Has 'deadwire_v2_runtime_hot.s' 'generated source path'
Has '& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RuntimeGenScriptPath' 'generator invocation'
Has '& as --64 -o $RuntimeObjectPath $RuntimePath' 'generated runtime assembly'
Has 'src/runtime/runtime_route_windows.s' 'route object source'
Has '& as --64 -o $RouteObjectPath $RoutePath' 'route object assembly'
Lacks 'RuntimeBasePath' 'old map variable'
Lacks 'src/runtime/runtime_windows.s' 'old map input dependency'
Write-Output 'verify-v2buildsource: ok'
