$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildDir = Join-Path $RepoRoot 'build'
$RuntimePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$LaneSetPath = Join-Path $RepoRoot 'src/runtime/runtime_spawn_set_windows.s'
$ExtraPath = Join-Path $RepoRoot 'src/runtime/runtime_handle_windows.s'
$JoinPath = Join-Path $RepoRoot 'src/runtime/runtime_join_windows.s'
$RunPath = Join-Path $RepoRoot 'src/runtime/runtime_run_windows.s'
$BootPath = Join-Path $RepoRoot 'src/runtime/runtime_boot_windows.s'
$RuntimeObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime.o'
$LaneSetObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_lanes.o'
$ExtraObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_extra.o'
$JoinObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_join.o'
$RunObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_run.o'
$BootObjectPath = Join-Path $BuildDir 'deadwire_v2_runtime_boot.o'
$ExePath = Join-Path $BuildDir 'deadwire_v2_runtime.exe'

foreach ($Path in @($RuntimePath, $LaneSetPath, $ExtraPath, $JoinPath, $RunPath, $BootPath)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 runtime source: $Path"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $RuntimeObjectPath $RuntimePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 runtime assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $LaneSetObjectPath $LaneSetPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane set assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $ExtraObjectPath $ExtraPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 extra assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $JoinObjectPath $JoinPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 join assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $RunObjectPath $RunPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 run assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $BootObjectPath $BootPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 runtime boot assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' '-Wl,--subsystem,console' -o $ExePath $BootObjectPath $RuntimeObjectPath $LaneSetObjectPath $ExtraObjectPath $JoinObjectPath $RunObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 runtime link failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ExePath)) {
    throw "missing V2 runtime executable: $ExePath"
}

Write-Output "build-v2-runtime: ok $ExePath"
