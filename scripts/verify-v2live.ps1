$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$LivePath = Join-Path $RepoRoot 'src/runtime/runtime_live_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$LiveObjectPath = Join-Path $BuildDir 'runtime_v2live.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2live.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2live.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2live.exe'

if (-not (Test-Path $LivePath)) {
    throw "missing V2 live source: $LivePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $LivePath
$RequiredNeedles = @(
    'dw_runtime_live_open:',
    'WSAStartup',
    'socket',
    'setsockopt',
    'bind',
    'listen',
    'closesocket',
    'WSACleanup',
    'DW_LIVE_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 live rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $LiveObjectPath $LivePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $LiveObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_live_open')) {
    throw 'missing runtime object symbol: dw_runtime_live_open'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global WSAStartup
.global WSACleanup
.global socket
.global setsockopt
.global bind
.global listen
.global closesocket
.extern dw_runtime_live_open
.extern ExitProcess

.section .data
sock_addr:
    .word 2
    .word 0x4eea
    .long 0x0100007f
    .quad 0
live_ctx:
    .quad 0
    .quad sock_addr
    .quad 16
    .quad 16
    .quad 99
bad_ctx:
    .quad 0
    .quad 0
    .quad 16
    .quad 16
    .quad 99
fail_ctx:
    .quad 0
    .quad sock_addr
    .quad 16
    .quad 16
    .quad 99
fail_mode:
    .quad 0
wsa_count:
    .quad 0
socket_count:
    .quad 0
setopt_count:
    .quad 0
bind_count:
    .quad 0
listen_count:
    .quad 0
close_count:
    .quad 0
cleanup_count:
    .quad 0
close_seen:
    .quad 0
bind_addr_seen:
    .quad 0
listen_backlog_seen:
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_live_open
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_ctx]
    call dw_runtime_live_open
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + bad_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + wsa_count], 0
    jne fail

    mov qword ptr [rip + fail_mode], 2
    lea rcx, [rip + fail_ctx]
    call dw_runtime_live_open
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + fail_ctx + 32], 1
    jne fail
    cmp qword ptr [rip + fail_ctx + 0], 0
    jne fail
    cmp qword ptr [rip + close_count], 1
    jne fail
    cmp qword ptr [rip + cleanup_count], 1
    jne fail
    cmp qword ptr [rip + close_seen], 0x12345678
    jne fail

    mov qword ptr [rip + fail_mode], 0
    mov qword ptr [rip + wsa_count], 0
    mov qword ptr [rip + socket_count], 0
    mov qword ptr [rip + setopt_count], 0
    mov qword ptr [rip + bind_count], 0
    mov qword ptr [rip + listen_count], 0
    mov qword ptr [rip + close_count], 0
    mov qword ptr [rip + cleanup_count], 0
    mov qword ptr [rip + close_seen], 0
    mov qword ptr [rip + bind_addr_seen], 0
    mov qword ptr [rip + listen_backlog_seen], 0
    mov qword ptr [rip + live_ctx + 0], 0
    mov qword ptr [rip + live_ctx + 32], 99

    lea rcx, [rip + live_ctx]
    call dw_runtime_live_open
    test eax, eax
    jne fail
    cmp qword ptr [rip + live_ctx + 32], 0
    jne fail
    cmp qword ptr [rip + live_ctx + 0], 0x12345678
    jne fail
    cmp qword ptr [rip + wsa_count], 1
    jne fail
    cmp qword ptr [rip + socket_count], 1
    jne fail
    cmp qword ptr [rip + setopt_count], 1
    jne fail
    cmp qword ptr [rip + bind_count], 1
    jne fail
    cmp qword ptr [rip + listen_count], 1
    jne fail
    cmp qword ptr [rip + close_count], 0
    jne fail
    cmp qword ptr [rip + cleanup_count], 0
    jne fail
    lea r10, [rip + sock_addr]
    cmp qword ptr [rip + bind_addr_seen], r10
    jne fail
    cmp qword ptr [rip + listen_backlog_seen], 16
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

WSAStartup:
    inc qword ptr [rip + wsa_count]
    xor eax, eax
    ret

WSACleanup:
    inc qword ptr [rip + cleanup_count]
    xor eax, eax
    ret

socket:
    inc qword ptr [rip + socket_count]
    cmp qword ptr [rip + fail_mode], 1
    je socket_fail
    mov eax, 0x12345678
    ret
socket_fail:
    mov rax, -1
    ret

setsockopt:
    inc qword ptr [rip + setopt_count]
    xor eax, eax
    ret

bind:
    inc qword ptr [rip + bind_count]
    mov qword ptr [rip + bind_addr_seen], rdx
    cmp qword ptr [rip + fail_mode], 2
    je bind_fail
    xor eax, eax
    ret
bind_fail:
    mov eax, -1
    ret

listen:
    inc qword ptr [rip + listen_count]
    mov qword ptr [rip + listen_backlog_seen], rdx
    xor eax, eax
    ret

closesocket:
    inc qword ptr [rip + close_count]
    mov qword ptr [rip + close_seen], rcx
    xor eax, eax
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $LiveObjectPath -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 live harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 live harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2live: ok'
