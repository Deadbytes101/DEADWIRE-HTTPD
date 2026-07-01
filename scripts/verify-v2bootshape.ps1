$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Boot=Join-Path $R 'src/runtime/runtime_boot_windows.c'
$Build=Join-Path $R 'scripts/build-v2-runtime.ps1'
if(!(Test-Path $Boot)){throw "missing $Boot"}
if(!(Test-Path $Build)){throw "missing $Build"}
$S=Get-Content -Raw -Encoding UTF8 $Boot
$Needles=@(
    'extern int dw_runtime_select_client_response',
    'static uint64_t health_response_context[6];',
    'static uint64_t root_response_context[6];',
    'static uint64_t css_response_context[6];',
    'static uint64_t missing_response_context[6];',
    'static void deadwire_prepare_responses(void)',
    'client_context[3] = 0;',
    'selected_route = dw_runtime_select_client_response(client_context, request, request_length',
    'client_context[3] != expected_response',
    'deadwire_prepare_responses();'
)
foreach($Needle in $Needles){
    if(!$S.Contains($Needle)){throw "missing boot shape: $Needle"}
}
if($S.Contains('static uint64_t response_context[6];')){throw 'single response context found'}
if($S.Contains('client_context[3] = (uint64_t)response_context;')){throw 'preloaded response context found'}
if($S.Contains('selected_route = dw_runtime_select_route(request, request_length);')){throw 'split route selector path found'}
if($S.Contains('dw_runtime_client_select_response(client_context, selected_route')){throw 'split client response path found'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Build
if($LASTEXITCODE){throw "build $LASTEXITCODE"}
Write-Output 'verify-v2bootshape: ok'
