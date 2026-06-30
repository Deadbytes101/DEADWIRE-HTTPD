$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_bridge_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2bridge.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2bridge.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2bridge.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2bridge.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 bridge source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_live_bridge_once:',
    'dw_runtime_live_accept_once',
    'dw_runtime_accept_enqueue',
    'closesocket',
    'DW_LIVE_LAST_RESULT',
    'DW_CLIENT_SOCKET'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 bridge rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bridge assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bridge symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_live_bridge_once')) {
    throw 'missing runtime object symbol: dw_runtime_live_bridge_once'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global dw_runtime_live_accept_once
.global dw_runtime_accept_enqueue
.global closesocket
.extern dw_runtime_live_bridge_once
.extern ExitProcess

.section .data
live_ctx:
    .quad 0x11112222
    .quad 0
    .quad 0
    .quad 0
    .quad 99
client_ctx:
    .quad 99
    .quad 0
    .quad 0
    .quad 0
input_queue:
    .quad 0
    .quad 0
    .quad 4
    .quad 0
fail_mode:
    .quad 0
accept_count:
    .quad 0
enqueue_count:
    .quad 0
close_count:
    .quad 0
accept_live_seen:
    .quad 0
accept_client_seen:
    .quad 0
enqueue_queue_seen:
    .quad 0
enqueue_client_seen:
    .quad 0
close_seen:
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    lea rdx, [rip + client_ctx]
    lea r8, [rip + input_queue]
    call dw_runtime_live_bridge_once
    cmp eax, 1
    jne fail

    lea rcx, [rip + live_ctx]
    xor rdx, rdx
    lea r8, [rip + input_queue]
    call dw_runtime_live_bridge_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail

    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    xor r8, r8
    call dw_runtime_live_bridge_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + accept_count], 0
    jne fail

    mov qword ptr [rip + fail_mode], 1
    mov qword ptr [rip + accept_count], 0
    mov qword ptr [rip + enqueue_count], 0
    mov qword ptr [rip + close_count], 0
    mov qword ptr [rip + client_ctx + 0], 99
    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    lea r8, [rip + input_queue]
    call dw_runtime_live_bridge_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0
    jne fail
    cmp qword ptr [rip + accept_count], 1
    jne fail
    cmp qword ptr [rip + enqueue_count], 0
    jne fail
    cmp qword ptr [rip + close_count], 0
    jne fail

    mov qword ptr [rip + fail_mode], 2
    mov qword ptr [rip + accept_count], 0
    mov qword ptr [rip + enqueue_count], 0
    mov qword ptr [rip + close_count], 0
    mov qword ptr [rip + close_seen], 0
    mov qword ptr [rip + client_ctx + 0], 99
    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    lea r8, [rip + input_queue]
    call dw_runtime_live_bridge_once
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0
    jne fail
    cmp qword ptr [rip + accept_count], 1
    jne fail
    cmp qword ptr [rip + enqueue_count], 1
    jne fail
    cmp qword ptr [rip + close_count], 1
    jne fail
    cmp qword ptr [rip + close_seen], 0x33334444
    jne fail

    mov qword ptr [rip + fail_mode], 0
    mov qword ptr [rip + accept_count], 0
    mov qword ptr [rip + enqueue_count], 0
    mov qword ptr [rip + close_count], 0
    mov qword ptr [rip + accept_live_seen], 0
    mov qword ptr [rip + accept_client_seen], 0
    mov qword ptr [rip + enqueue_queue_seen], 0
    mov qword ptr [rip + enqueue_client_seen], 0
    mov qword ptr [rip + client_ctx + 0], 99
    mov qword ptr [rip + live_ctx + 32], 99
    lea rcx, [rip + live_ctx]
    lea rdx, [rip + client_ctx]
    lea r8, [rip + input_queue]
    call dw_runtime_live_bridge_once
    test eax, eax
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + client_ctx + 0], 0x33334444
    jne fail
    cmp qword ptr [rip + accept_count], 1
    jne fail
    cmp qword ptr [rip + enqueue_count], 1
    jne fail
    cmp qword ptr [rip + close_count], 0
    jne fail
    lea r10, [rip + live_ctx]
    cmp qword ptr [rip + accept_live_seen], r10
    jne fail
    lea r10, [rip + client_ctx]
    cmp qword ptr [rip + accept_client_seen], r10
    jne fail
    lea r10, [rip + input_queue]
    cmp qword ptr [rip + enqueue_queue_seen], r10
    jne fail
    lea r10, [rip + client_ctx]
    cmp qword ptr [rip + enqueue_client_seen], r10
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

dw_runtime_live_accept_once:
    inc qword ptr [rip + accept_count]
    mov qword ptr [rip + accept_live_seen], rcx
    mov qword ptr [rip + accept_client_seen], rdx
    cmp qword ptr [rip + fail_mode], 1
    je accept_fail
    mov qword ptr [rdx], 0x33334444
    mov qword ptr [rcx + 32], 0
    xor eax, eax
    ret
accept_fail:
    mov qword ptr [rdx], 0
    mov qword ptr [rcx + 32], 1
    mov eax, 1
    ret

dw_runtime_accept_enqueue:
    inc qword ptr [rip + enqueue_count]
    mov qword ptr [rip + enqueue_queue_seen], rcx
    mov qword ptr [rip + enqueue_client_seen], rdx
    cmp qword ptr [rip + fail_mode], 2
    je enqueue_fail
    xor eax, eax
    ret
enqueue_fail:
    mov eax, 2
    ret

closesocket:
    inc qword ptr [rip + close_count]
    mov qword ptr [rip + close_seen], rcx
    xor eax, eax
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bridge harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 bridge harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 bridge harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2bridge: ok'
