$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir=Join-Path $R 'src/runtime'
if(!(Test-Path $RuntimeDir)){throw "missing $RuntimeDir"}
$Files=@(
  'runtime_boot_windows.c',
  'runtime_accept_windows.s',
  'runtime_bridge_windows.s',
  'runtime_bound_windows.s',
  'runtime_handle_windows.s',
  'runtime_http_engine_entry_windows.s',
  'runtime_join_windows.s',
  'runtime_live_windows.s',
  'runtime_live_close_windows.s',
  'runtime_live_cycle_windows.s',
  'runtime_mode_windows.s',
  'runtime_route_windows.s',
  'runtime_run_windows.s',
  'runtime_spawn_set_windows.s',
  'runtime_tick_windows.s'
)
$Forbidden=@('CreateThread','_beginthread','QueueUserWorkItem','ThreadPool','malloc','calloc','realloc','HeapAlloc','HeapCreate','VirtualAlloc')
foreach($Name in $Files){
  $Path=Join-Path $RuntimeDir $Name
  if(!(Test-Path $Path)){throw "missing V2 topology source $Name"}
  $S=Get-Content -Raw -Encoding UTF8 $Path
  foreach($Needle in $Forbidden){
    if($S.Contains($Needle)){throw "forbidden V2 topology token $Needle in $Name"}
  }
}
Write-Output 'verify-v2topology: ok'
