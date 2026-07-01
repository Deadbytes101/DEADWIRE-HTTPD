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
function Has([string]$Text,[string]$Needle,[string]$Label){if(!$Text.Contains($Needle)){throw "missing $Label"}}
function Lacks([string]$Text,[string]$Needle,[string]$Label){if($Text.Contains($Needle)){throw "forbidden $Label"}}
$Select='dw_runtime_'+'select_client_response'
Has $BootS $Select 'boot select boundary'
Has $BootS 'selected_route = dw_runtime_select_client_response(client_context, request, request_length' 'boot boundary call'
Has $RouteFlowS $Select 'routeflow select boundary'
Has $RouteFlowS 'int route = dw_runtime_select_client_response(client, request, request_length' 'routeflow boundary call'
Has $HandleS 'deadwire_v2_runtime_hot.s' 'handle hot source'
Has $HandleS 'client[8]={99,(uint64_t)reqbuf,sizeof(reqbuf),0' 'handle response table client'
Has $HandleS 'if(client[3])return 6;' 'handle starts without selected response'
Has $HandleS 'if(dw_runtime_handle_client(client))return 8;' 'handle hot call'
Has $HandleS 'if(client[3]!=(uint64_t)resp)return 9;' 'handle selected response result'
Has $SelectClientS $Select 'selectclient probe boundary'
Lacks $BootS 'selected_route = dw_runtime_select_route(request, request_length);' 'boot split route'
Lacks $BootS 'dw_runtime_client_select_response(client_context, selected_route' 'boot split setter'
Lacks $RouteFlowS 'int route = dw_runtime_select_route(request, request_length);' 'routeflow split route'
Lacks $RouteFlowS 'dw_runtime_client_select_response(client, route' 'routeflow split setter'
Lacks $HandleS $Select 'handle external preselect'
Lacks $HandleS 'client[3]=(uint64_t)resp;' 'handle direct preload'
Lacks $HandleS 'client[3] = (uint64_t)resp;' 'handle spaced preload'
Write-Output 'verify-v2selectchain: ok'
