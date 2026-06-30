$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_join_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2join.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2join.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2join.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2join.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 join source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_join_lanes:',
    'dw_runtime_wait_handle',
    'dw_runtime_close_handle',
    'DW_SPAWN_ACCEPT_HANDLE',
    'DW_SPAWN_WORK_HANDLE',
    'DW_SPAWN_OUTPUT_HANDLE',
    'DW_SPAWN_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 join rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 join assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 join symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_join_lanes')) {
    throw 'missing runtime object symbol: dw_runtime_join_lanes'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global dw_runtime_wait_handle
.global dw_runtime_close_handle
.extern dw_runtime_join_lanes
.extern ExitProcess

.section .data
spawn_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0x101
    .quad 0x202
    .quad 0x303
    .quad 99
bad_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0x101
    .quad 0
    .quad 0x303
    .quad 99
wait_count:
    .quad 0
close_count:
    .quad 0
wait_seen:
    .quad 0
    .quad 0
    .quad 0
close_seen:
    .quad 0
    .quad 0
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_join_lanes
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_ctx]
    call dw_runtime_join_lanes
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + bad_ctx + 72], 1
    jne fail

    mov qword ptr [rip + wait_count], 0
    mov qword ptr [rip + close_count], 0
    mov qword ptr [rip + wait_seen + 0], 0
    mov qword ptr [rip + wait_seen + 8], 0
    mov qword ptr [rip + wait_seen + 16], 0
    mov qword ptr [rip + close_seen + 0], 0
    mov qword ptr [rip + close_seen + 8], 0
    mov qword ptr [rip + close_seen + 16], 0

    lea rcx, [rip + spawn_ctx]
    call dw_runtime_join_lanes
    test eax, eax
    jne fail
    cmp qword ptr [rip + spawn_ctx + 72], 0
    jne fail
    cmp qword ptr [rip + wait_count], 3
    jne fail
    cmp qword ptr [rip + close_count], 3
    jne fail

    cmp qword ptr [rip + wait_seen + 0], 0x101
    jne fail
    cmp qword ptr [rip + wait_seen + 8], 0x202
    jne fail
    cmp qword ptr [rip + wait_seen + 16], 0x303
    jne fail

    cmp qword ptr [rip + close_seen + 0], 0x101
    jne fail
    cmp qword ptr [rip + close_seen + 8], 0x202
    jne fail
    cmp qword ptr [rip + close_seen + 16], 0x303
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

dw_runtime_wait_handle:
    mov r10, qword ptr [rip + wait_count]
    lea r11, [rip + wait_seen]
    mov qword ptr [r11 + r10 * 8], rcx
    inc qword ptr [rip + wait_count]
    xor eax, eax
    ret

dw_runtime_close_handle:
    mov r10, qword ptr [rip + close_count]
    lea r11, [rip + close_seen]
    mov qword ptr [r11 + r10 * 8], rcx
    inc qword ptr [rip + close_count]
    mov eax, 1
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 join harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 join harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 join harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2join: ok'
