$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Boot=Join-Path $R 'src/runtime/runtime_boot_windows.c'
$RouteFlow=Join-Path $R 'scripts/verify-v2routeflowprobe.ps1'
$Handle=Join-Path $R 'scripts/verify-v2handleprobe.ps1'
$SelectClient=Join-Path $R 'scripts/verify-v2selectclientprobe.ps1'
foreach($P in @($Boot,$RouteFlow,$Handle,$SelectClient)){if(!(Test-Path $P)){throw "missing $P"}}
$BootS=Get-Content -Raw -Encoding UTF8 $Boot
$RouteFlowS=Get-Content -Raw -Encoding UTF8 $RouteFlow
$HandleS=Get-Content -Raw -Encoding UTF8 $Handle
$SelectClientS=Get-Content -Raw -Encoding UTF8 $SelectClient
function Need([string]$Name,[string]$Text,[string]$Needle){
    if(!$Text.Contains($Needle)){throw "missing ${Name}: $Needle"}
}
function Forbid([string]$Name,[string]$Text,[string]$Needle){
    if($Text.Contains($Needle)){throw "forbidden ${Name}: $Needle"}
}
Need 'boot' $BootS 'extern int dw_runtime_select_client_response'
Need 'boot' $BootS 'selected_route = dw_runtime_select_client_response(client_context, request, request_length'
Need 'routeflow' $RouteFlowS 'extern int dw_runtime_select_client_response'
Need 'routeflow' $RouteFlowS 'int route = dw_runtime_select_client_response(client, request, request_length'
Need 'handle' $HandleS 'extern int dw_runtime_select_client_response'
Need 'handle' $HandleS 'if(!dw_runtime_select_client_response(client,req,(int)(sizeof(req)-1)'
Need 'selectclient' $SelectClientS 'dw_runtime_select_client_response'
Forbid 'boot' $BootS 'selected_route = dw_runtime_select_route(request, request_length);'
Forbid 'boot' $BootS 'dw_runtime_client_select_response(client_context, selected_route'
Forbid 'routeflow' $RouteFlowS 'int route = dw_runtime_select_route(request, request_length);'
Forbid 'routeflow' $RouteFlowS 'dw_runtime_client_select_response(client, route'
Forbid 'handle' $HandleS 'client[3]=(uint64_t)resp;'
Forbid 'handle' $HandleS 'client[3] = (uint64_t)resp;'
Write-Output 'verify-v2selectchain: ok'
