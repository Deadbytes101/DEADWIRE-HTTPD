$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2entry.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2entry.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2entry.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2entry.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'DW_ENTRY_INPUT_QUEUE_PTR',
    'DW_ENTRY_WORKER_PTR',
    'DW_ENTRY_OUTPUT_QUEUE_PTR',
    'DW_ENTRY_CLIENT_PTR',
    'DW_ENTRY_LAST_RESULT',
    'dw_runtime_accept_entry:',
    'dw_runtime_work_entry:',
    'dw_runtime_output_entry:',
    'call dw_runtime_accept_enqueue',
    'call dw_runtime_work_step',
    'call dw_runtime_output_drain'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 raw entry logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 raw entry assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 raw entry symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredSymbols = @(
    'dw_runtime_accept_entry',
    'dw_runtime_work_entry',
    'dw_runtime_output_entry'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_accept_entry
.extern dw_runtime_work_entry
.extern dw_runtime_output_entry
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
accept_ctx:
    .quad in_queue
    .quad 0
    .quad 0
    .quad client_a
    .quad 99
work_ctx:
    .quad 0
    .quad worker
    .quad 0
    .quad 0
    .quad 99
output_ctx:
    .quad 0
    .quad 0
    .quad out_queue
    .quad 0
    .quad 99
bad_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 99

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_accept_entry
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_ctx]
    call dw_runtime_accept_entry
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + bad_ctx + 32], 1
    jne fail

    lea rcx, [rip + accept_ctx]
    call dw_runtime_accept_entry
    test eax, eax
    jne fail
    cmp qword ptr [rip + accept_ctx + 32], 0
    jne fail

    lea rcx, [rip + worker]
    mov rdx, 1
    lea r8, [rip + in_queue]
    lea r9, [rip + out_queue]
    call dw_runtime_worker_init
    test eax, eax
    jne fail

    lea rcx, [rip + work_ctx]
    call dw_runtime_work_entry
    test eax, eax
    jne fail
    cmp qword ptr [rip + work_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + worker + 32], 1
    jne fail

    lea rcx, [rip + output_ctx]
    call dw_runtime_output_entry
    lea r10, [rip + client_a]
    cmp rax, r10
    jne fail
    cmp qword ptr [rip + output_ctx + 32], r10
    jne fail

    lea rcx, [rip + output_ctx]
    call dw_runtime_output_entry
    test rax, rax
    jne fail
    cmp qword ptr [rip + output_ctx + 32], 0
    jne fail

    lea rcx, [rip + work_ctx]
    call dw_runtime_work_entry
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + work_ctx + 32], 1
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
    throw "V2 raw entry harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 raw entry harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 raw entry harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2entry: ok'
