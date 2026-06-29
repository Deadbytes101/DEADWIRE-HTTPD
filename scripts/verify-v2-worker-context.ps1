$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_worker_context.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_worker_context.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_worker_context.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_worker_context.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'DW_WORKER_ID',
    'DW_WORKER_INPUT_QUEUE_PTR',
    'DW_WORKER_OUTPUT_QUEUE_PTR',
    'DW_WORKER_CURRENT_CLIENT_PTR',
    'DW_WORKER_PROCESSED_COUNT',
    'dw_runtime_worker_init:',
    'dw_runtime_worker_take:',
    'dw_runtime_worker_complete:'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 worker context logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 worker context assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 worker context symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredSymbols = @(
    'dw_runtime_worker_init',
    'dw_runtime_worker_take',
    'dw_runtime_worker_complete'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_worker_init
.extern dw_runtime_worker_take
.extern dw_runtime_worker_complete
.extern dw_runtime_queue_pop
.extern ExitProcess

.section .data
client_a:
    .quad 0x11111111
input_slots:
    .quad client_a
    .quad 0
input_queue:
    .quad 0
    .quad 1
    .quad 2
    .quad input_slots
output_slots:
    .quad 0
    .quad 0
output_queue:
    .quad 0
    .quad 0
    .quad 2
    .quad output_slots
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
    mov rdx, 7
    lea r8, [rip + input_queue]
    lea r9, [rip + output_queue]
    call dw_runtime_worker_init
    cmp eax, 1
    jne fail

    lea rcx, [rip + worker]
    mov rdx, 7
    lea r8, [rip + input_queue]
    lea r9, [rip + output_queue]
    call dw_runtime_worker_init
    test eax, eax
    jne fail

    cmp qword ptr [rip + worker + 0], 7
    jne fail
    lea r10, [rip + input_queue]
    cmp qword ptr [rip + worker + 8], r10
    jne fail
    lea r10, [rip + output_queue]
    cmp qword ptr [rip + worker + 16], r10
    jne fail
    cmp qword ptr [rip + worker + 24], 0
    jne fail
    cmp qword ptr [rip + worker + 32], 0
    jne fail

    lea rcx, [rip + worker]
    call dw_runtime_worker_take
    lea r10, [rip + client_a]
    cmp rax, r10
    jne fail
    cmp qword ptr [rip + worker + 24], r10
    jne fail

    lea rcx, [rip + worker]
    lea rdx, [rip + client_a]
    call dw_runtime_worker_complete
    test eax, eax
    jne fail
    cmp qword ptr [rip + worker + 24], 0
    jne fail
    cmp qword ptr [rip + worker + 32], 1
    jne fail

    lea rcx, [rip + output_queue]
    call dw_runtime_queue_pop
    lea r10, [rip + client_a]
    cmp rax, r10
    jne fail

    lea rcx, [rip + worker]
    xor rdx, rdx
    call dw_runtime_worker_complete
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
    throw "V2 worker context harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 worker context harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 worker context harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2-worker-context: ok'
