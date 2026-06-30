$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2spawn.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2spawn.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2spawn.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2spawn.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    '.extern CreateThread',
    'dw_runtime_spawn_entry:',
    'call CreateThread',
    'mov qword ptr [rsp + 32], 0',
    'mov qword ptr [rsp + 40], rax'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 spawn boundary logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn boundary assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn boundary symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_spawn_entry')) {
    throw 'missing runtime object symbol: dw_runtime_spawn_entry'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global CreateThread
.extern dw_runtime_spawn_entry
.extern dw_runtime_accept_entry
.extern ExitProcess

.section .data
entry_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
thread_id:
    .quad 0
capture_entry:
    .quad 0
capture_param:
    .quad 0
capture_flags:
    .quad 99
capture_tidptr:
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [rip + entry_ctx]
    lea r8, [rip + thread_id]
    call dw_runtime_spawn_entry
    test rax, rax
    jne fail

    lea rcx, [rip + dw_runtime_accept_entry]
    lea rdx, [rip + entry_ctx]
    lea r8, [rip + thread_id]
    call dw_runtime_spawn_entry
    cmp rax, 0x12345678
    jne fail

    lea r10, [rip + dw_runtime_accept_entry]
    cmp qword ptr [rip + capture_entry], r10
    jne fail
    lea r10, [rip + entry_ctx]
    cmp qword ptr [rip + capture_param], r10
    jne fail
    cmp qword ptr [rip + capture_flags], 0
    jne fail
    lea r10, [rip + thread_id]
    cmp qword ptr [rip + capture_tidptr], r10
    jne fail
    cmp dword ptr [rip + thread_id], 77
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

CreateThread:
    mov qword ptr [rip + capture_entry], r8
    mov qword ptr [rip + capture_param], r9
    mov rax, qword ptr [rsp + 40]
    mov qword ptr [rip + capture_flags], rax
    mov rax, qword ptr [rsp + 48]
    mov qword ptr [rip + capture_tidptr], rax
    test rax, rax
    je create_thread_done
    mov dword ptr [rax], 77
create_thread_done:
    mov eax, 0x12345678
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn boundary harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn boundary harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 spawn boundary harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2spawn: ok'
