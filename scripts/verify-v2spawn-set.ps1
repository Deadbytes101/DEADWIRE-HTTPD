$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$SetPath = Join-Path $RepoRoot 'src/runtime/runtime_spawn_set_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$RuntimeObjectPath = Join-Path $BuildDir 'runtime_v2spawn_set_base.o'
$SetObjectPath = Join-Path $BuildDir 'runtime_v2spawn_set.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2spawn_set.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2spawn_set.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2spawn_set.exe'

foreach ($Path in @($RuntimePath, $SetPath)) {
    if (-not (Test-Path $Path)) {
        throw "missing V2 source: $Path"
    }
}

$Source = Get-Content -Raw -Encoding UTF8 $SetPath
$RequiredNeedles = @(
    'DW_SPAWN_ACCEPT_CONTEXT_PTR',
    'DW_SPAWN_WORK_CONTEXT_PTR',
    'DW_SPAWN_OUTPUT_CONTEXT_PTR',
    'DW_SPAWN_LAST_RESULT',
    'dw_runtime_spawn_lanes:',
    'dw_runtime_accept_entry',
    'dw_runtime_work_entry',
    'dw_runtime_output_entry',
    'call dw_runtime_spawn_entry'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 spawn set logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $RuntimeObjectPath $RuntimePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 base runtime assembly failed with exit code $LASTEXITCODE"
}

& as --64 -o $SetObjectPath $SetPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn set assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $SetObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn set symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_spawn_lanes')) {
    throw 'missing runtime object symbol: dw_runtime_spawn_lanes'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global CreateThread
.extern dw_runtime_spawn_lanes
.extern dw_runtime_accept_entry
.extern dw_runtime_work_entry
.extern dw_runtime_output_entry
.extern ExitProcess

.section .data
accept_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
work_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
output_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
accept_tid:
    .quad 0
work_tid:
    .quad 0
output_tid:
    .quad 0
spawn_ctx:
    .quad accept_ctx
    .quad work_ctx
    .quad output_ctx
    .quad accept_tid
    .quad work_tid
    .quad output_tid
    .quad 0
    .quad 0
    .quad 0
    .quad 99
bad_ctx:
    .quad accept_ctx
    .quad 0
    .quad output_ctx
    .quad accept_tid
    .quad work_tid
    .quad output_tid
    .quad 0
    .quad 0
    .quad 0
    .quad 99
capture_count:
    .quad 0
capture_entry:
    .quad 0
    .quad 0
    .quad 0
capture_param:
    .quad 0
    .quad 0
    .quad 0
capture_tidptr:
    .quad 0
    .quad 0
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_spawn_lanes
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_ctx]
    call dw_runtime_spawn_lanes
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + bad_ctx + 72], 1
    jne fail

    mov qword ptr [rip + capture_count], 0
    lea rcx, [rip + spawn_ctx]
    call dw_runtime_spawn_lanes
    test eax, eax
    jne fail
    cmp qword ptr [rip + spawn_ctx + 72], 0
    jne fail
    cmp qword ptr [rip + capture_count], 3
    jne fail

    cmp qword ptr [rip + spawn_ctx + 48], 0x12345001
    jne fail
    cmp qword ptr [rip + spawn_ctx + 56], 0x12345002
    jne fail
    cmp qword ptr [rip + spawn_ctx + 64], 0x12345003
    jne fail

    cmp dword ptr [rip + accept_tid], 101
    jne fail
    cmp dword ptr [rip + work_tid], 102
    jne fail
    cmp dword ptr [rip + output_tid], 103
    jne fail

    lea r10, [rip + dw_runtime_accept_entry]
    cmp qword ptr [rip + capture_entry + 0], r10
    jne fail
    lea r10, [rip + dw_runtime_work_entry]
    cmp qword ptr [rip + capture_entry + 8], r10
    jne fail
    lea r10, [rip + dw_runtime_output_entry]
    cmp qword ptr [rip + capture_entry + 16], r10
    jne fail

    lea r10, [rip + accept_ctx]
    cmp qword ptr [rip + capture_param + 0], r10
    jne fail
    lea r10, [rip + work_ctx]
    cmp qword ptr [rip + capture_param + 8], r10
    jne fail
    lea r10, [rip + output_ctx]
    cmp qword ptr [rip + capture_param + 16], r10
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

CreateThread:
    mov r10, qword ptr [rip + capture_count]
    lea r11, [rip + capture_entry]
    mov qword ptr [r11 + r10 * 8], r8
    lea r11, [rip + capture_param]
    mov qword ptr [r11 + r10 * 8], r9
    mov rax, qword ptr [rsp + 48]
    lea r11, [rip + capture_tidptr]
    mov qword ptr [r11 + r10 * 8], rax
    test rax, rax
    je no_tid
    mov r11, r10
    add r11, 101
    mov dword ptr [rax], r11d
no_tid:
    inc qword ptr [rip + capture_count]
    mov rax, qword ptr [rip + capture_count]
    add rax, 0x12345000
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn set harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $SetObjectPath $RuntimeObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn set harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn set harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2spawn-set: ok'
