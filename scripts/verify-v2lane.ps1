$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2lane.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2lane.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2lane.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2lane.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_accept_enqueue:',
    'dw_runtime_work_step:',
    'dw_runtime_output_drain:',
    'call dw_runtime_queue_push',
    'call dw_runtime_worker_take',
    'call dw_runtime_worker_complete',
    'call dw_runtime_queue_pop'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 lane boundary logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane boundary assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane boundary symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredSymbols = @(
    'dw_runtime_accept_enqueue',
    'dw_runtime_work_step',
    'dw_runtime_output_drain'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_accept_enqueue
.extern dw_runtime_work_step
.extern dw_runtime_output_drain
.extern dw_runtime_worker_init
.extern ExitProcess

.section .data
client_a:
    .quad 0x11111111
in_slots:
    .quad 0
    .quad 0
in_queue:
    .quad 0
    .quad 0
    .quad 2
    .quad in_slots
out_slots:
    .quad 0
    .quad 0
out_queue:
    .quad 0
    .quad 0
    .quad 2
    .quad out_slots
worker:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [rip + client_a]
    call dw_runtime_accept_enqueue
    cmp eax, 1
    jne fail

    lea rcx, [rip + in_queue]
    lea rdx, [rip + client_a]
    call dw_runtime_accept_enqueue
    test eax, eax
    jne fail

    lea rcx, [rip + worker]
    mov rdx, 1
    lea r8, [rip + in_queue]
    lea r9, [rip + out_queue]
    call dw_runtime_worker_init
    test eax, eax
    jne fail

    lea rcx, [rip + worker]
    call dw_runtime_work_step
    test eax, eax
    jne fail
    cmp qword ptr [rip + worker + 24], 0
    jne fail
    cmp qword ptr [rip + worker + 32], 1
    jne fail

    lea rcx, [rip + out_queue]
    call dw_runtime_output_drain
    lea r10, [rip + client_a]
    cmp rax, r10
    jne fail

    lea rcx, [rip + out_queue]
    call dw_runtime_output_drain
    test rax, rax
    jne fail

    lea rcx, [rip + worker]
    call dw_runtime_work_step
    cmp eax, 1
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane boundary harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane boundary harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 lane boundary harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2lane: ok'
