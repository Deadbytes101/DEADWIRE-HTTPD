$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$RuntimeObjectPath = Join-Path $BuildDir 'runtime_v2flow_base.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2flow.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2flow.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2flow.exe'

if (-not (Test-Path $RuntimePath)) {
    throw "missing V2 runtime source: $RuntimePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $RuntimePath
$RequiredNeedles = @(
    'dw_runtime_accept_entry:',
    'dw_runtime_work_entry:',
    'dw_runtime_output_entry:',
    'dw_runtime_worker_init:',
    'DW_ENTRY_LAST_RESULT',
    'DW_WORKER_PROCESSED_COUNT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 flow source rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $RuntimeObjectPath $RuntimePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 flow runtime assembly failed with exit code $LASTEXITCODE"
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_worker_init
.extern dw_runtime_accept_entry
.extern dw_runtime_work_entry
.extern dw_runtime_output_entry
.extern ExitProcess

.section .data
input_items:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
output_items:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
input_queue:
    .quad 0
    .quad 0
    .quad 4
    .quad input_items
output_queue:
    .quad 0
    .quad 0
    .quad 4
    .quad output_items
worker_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
client_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
accept_entry_ctx:
    .quad input_queue
    .quad 0
    .quad 0
    .quad client_ctx
    .quad 99
work_entry_ctx:
    .quad 0
    .quad worker_ctx
    .quad 0
    .quad 0
    .quad 99
output_entry_ctx:
    .quad 0
    .quad 0
    .quad output_queue
    .quad 0
    .quad 99

.section .text
mainCRTStartup:
    sub rsp, 40

    lea rcx, [rip + worker_ctx]
    mov edx, 7
    lea r8, [rip + input_queue]
    lea r9, [rip + output_queue]
    call dw_runtime_worker_init
    test eax, eax
    jne fail

    lea rcx, [rip + accept_entry_ctx]
    call dw_runtime_accept_entry
    test eax, eax
    jne fail
    cmp qword ptr [rip + accept_entry_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + input_queue + 8], 1
    jne fail
    lea r10, [rip + client_ctx]
    cmp qword ptr [rip + input_items + 0], r10
    jne fail

    lea rcx, [rip + work_entry_ctx]
    call dw_runtime_work_entry
    test eax, eax
    jne fail
    cmp qword ptr [rip + work_entry_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + input_queue + 0], 1
    jne fail
    cmp qword ptr [rip + output_queue + 8], 1
    jne fail
    cmp qword ptr [rip + worker_ctx + 24], 0
    jne fail
    cmp qword ptr [rip + worker_ctx + 32], 1
    jne fail
    lea r10, [rip + client_ctx]
    cmp qword ptr [rip + output_items + 0], r10
    jne fail

    lea rcx, [rip + output_entry_ctx]
    call dw_runtime_output_entry
    lea r10, [rip + client_ctx]
    cmp rax, r10
    jne fail
    cmp qword ptr [rip + output_entry_ctx + 32], r10
    jne fail
    cmp qword ptr [rip + output_queue + 0], 1
    jne fail

    lea rcx, [rip + output_entry_ctx]
    call dw_runtime_output_entry
    test rax, rax
    jne fail
    cmp qword ptr [rip + output_entry_ctx + 32], 0
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
    throw "V2 flow harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $RuntimeObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 flow harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 flow harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2flow: ok'
