$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildDir = Join-Path $RepoRoot 'build'
$RuntimeGenScriptPath = Join-Path $RepoRoot 'scripts/gen-v2-runtime-hot.ps1'
$RuntimePath = Join-Path $BuildDir 'deadwire_v2_runtime_hot.s'
$LaneSetPath = Join-Path $RepoRoot 'src/runtime/runtime_spawn_set_windows.s'
$HttpEntryPath = Join-Path $RepoRoot 'src/runtime/runtime_http_engine_entry_windows.s'
$ExtraPath = Join-Path $RepoRoot 'src/runtime/runtime_handle_windows.s'
$JoinPath = Join-Path $RepoRoot 'src/runtime/runtime_join_windows.s'
$RunPath = Join-Path $RepoRoot 'src/runtime/runtime_run_windows.s'
$BootPath = Join-Path $RepoRoot 'src/runtime/runtime_boot_windows.c'
$LivePath = Join-Path $RepoRoot 'src/runtime/runtime_live_windows.s'
$LiveClosePath = Join-Path $RepoRoot 'src/runtime/runtime_live_close_windows.s'
$LiveCyclePath = Join-Path $RepoRoot 'src/runtime/runtime_live_cycle_windows.s'
$AcceptPath = Join-Path $RepoRoot 'src/runtime/runtime_accept_windows.s'
$BridgePath = Join-Path $RepoRoot 'src/runtime/runtime_bridge_windows.s'
$TickPath = Join-Path $RepoRoot 'src/runtime/runtime_tick_windows.s'
$BoundPath = Join-Path $RepoRoot 'src/runtime/runtime_bound_windows.s'
$ModePath = Join-Path $RepoRoot 'src/runtime/runtime_mode_windows.s'
$RoutePath = Join-Path $RepoRoot 'src/runtime/runtime_route_windows.s'
$RuntimeObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime.o'
$LaneSetObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_lanes.o'
$HttpEntryObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_http_entry.o'
$ExtraObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_extra.o'
$JoinObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_join.o'
$RunObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_run.o'
$LiveObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_live.o'
$LiveCloseObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_live_close.o'
$LiveCycleObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_live_cycle.o'
$AcceptObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_accept.o'
$BridgeObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_bridge.o'
$TickObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_tick.o'
$BoundObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_bound.o'
$ModeObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_mode.o'
$RouteObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_route.o'
$BootObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_boot.o'
$ExePath = Join-Path $BuildDir 'deadwire_v2_runtime.exe'

foreach ($Path in @($RuntimeGenScriptPath, $LaneSetPath, $HttpEntryPath, $ExtraPath, $JoinPath, $RunPath, $BootPath, $LivePath, $LiveClosePath, $LiveCyclePath, $AcceptPath, $BridgePath, $TickPath, $BoundPath, $ModePath, $RoutePath)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 runtime source: $Path"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RuntimeGenScriptPath
if ($LASTEXITCODE -ne 0) { throw "V2 thin runtime generation failed with exit code $LASTEXITCODE" }
if (-not (Test-Path $RuntimePath)) { throw "missing generated V2 runtime source: $RuntimePath" }

& as --64 -o $RuntimeObjectPath $RuntimePath
if ($LASTEXITCODE -ne 0) { throw "V2 runtime assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $LaneSetObjectPath $LaneSetPath
if ($LASTEXITCODE -ne 0) { throw "V2 lane set assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $HttpEntryObjectPath $HttpEntryPath
if ($LASTEXITCODE -ne 0) { throw "V2 HTTP entry assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $ExtraObjectPath $ExtraPath
if ($LASTEXITCODE -ne 0) { throw "V2 extra assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $JoinObjectPath $JoinPath
if ($LASTEXITCODE -ne 0) { throw "V2 join assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $RunObjectPath $RunPath
if ($LASTEXITCODE -ne 0) { throw "V2 run assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $LiveObjectPath $LivePath
if ($LASTEXITCODE -ne 0) { throw "V2 live assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $LiveCloseObjectPath $LiveClosePath
if ($LASTEXITCODE -ne 0) { throw "V2 live close assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $LiveCycleObjectPath $LiveCyclePath
if ($LASTEXITCODE -ne 0) { throw "V2 live cycle assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $AcceptObjectPath $AcceptPath
if ($LASTEXITCODE -ne 0) { throw "V2 accept assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $BridgeObjectPath $BridgePath
if ($LASTEXITCODE -ne 0) { throw "V2 bridge assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $TickObjectPath $TickPath
if ($LASTEXITCODE -ne 0) { throw "V2 tick assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $BoundObjectPath $BoundPath
if ($LASTEXITCODE -ne 0) { throw "V2 bound assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $ModeObjectPath $ModePath
if ($LASTEXITCODE -ne 0) { throw "V2 mode assembly failed with exit code $LASTEXITCODE" }

& as --64 -o $RouteObjectPath $RoutePath
if ($LASTEXITCODE -ne 0) { throw "V2 route assembly failed with exit code $LASTEXITCODE" }

& gcc -ffreestanding -fno-builtin -fno-stack-protector -c -o $BootObjectPath $BootPath
if ($LASTEXITCODE -ne 0) { throw "V2 runtime boot compile failed with exit code $LASTEXITCODE" }

& gcc -nostdlib '-Wl,-e,mainCRTStartup' '-Wl,--subsystem,console' -o $ExePath $BootObjectPath $RuntimeObjectPath $LaneSetObjectPath $HttpEntryObjectPath $ExtraObjectPath $JoinObjectPath $RunObjectPath $LiveObjectPath $LiveCloseObjectPath $LiveCycleObjectPath $AcceptObjectPath $BridgeObjectPath $TickObjectPath $BoundObjectPath $ModeObjectPath $RouteObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) { throw "V2 runtime link failed with exit code $LASTEXITCODE" }

if (-not (Test-Path $ExePath)) {
    throw "missing V2 runtime executable: $ExePath"
}

Write-Output "build-v2-runtime: ok $ExePath"
