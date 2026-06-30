$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$BuildDir = Join-Path $RepoRoot 'build'
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$OutPath = Join-Path $BuildDir 'deadwire_v2_runtime_hot.s'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 runtime source: $SourcePath"
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath

$AcceptOld = @'
# dw_runtime_accept_enqueue(input_queue rcx, client rdx) maps to the accept lane handoff boundary.
dw_runtime_accept_enqueue:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call dw_runtime_queue_push
    leave
    ret
'@

$AcceptNew = @'
# dw_runtime_accept_enqueue(input_queue rcx, client rdx) maps to the accept lane handoff boundary.
# V2 build keeps this wrapper frame-free: tail-call straight into queue push.
dw_runtime_accept_enqueue:
    jmp dw_runtime_queue_push
'@

$DrainOld = @'
# dw_runtime_output_drain(output_queue rcx) maps to one output lane drain boundary.
dw_runtime_output_drain:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call dw_runtime_queue_pop
    leave
    ret
'@

$DrainNew = @'
# dw_runtime_output_drain(output_queue rcx) maps to one output drain helper.
# V2 build keeps this helper frame-free: tail-call straight into queue pop.
dw_runtime_output_drain:
    jmp dw_runtime_queue_pop
'@

$Hot = $Source.Replace($AcceptOld, $AcceptNew).Replace($DrainOld, $DrainNew)
if ($Hot -eq $Source) {
    throw 'V2 thin runtime generation made no changes'
}
if (-not $Hot.Contains('dw_runtime_accept_enqueue:')) {
    throw 'generated source missing accept enqueue symbol'
}
if (-not $Hot.Contains('jmp dw_runtime_queue_push')) {
    throw 'generated source missing accept enqueue tail-call'
}
if (-not $Hot.Contains('jmp dw_runtime_queue_pop')) {
    throw 'generated source missing output drain tail-call'
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutPath, $Hot, $Utf8NoBom)
Write-Output "gen-v2-runtime-hot: ok $OutPath"
