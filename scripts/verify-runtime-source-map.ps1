$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_windows_map.o'
$DecimalHarnessPath = Join-Path $BuildDir 'verify_runtime_u64dec.s'
$DecimalHarnessObjectPath = Join-Path $BuildDir 'verify_runtime_u64dec.o'
$DecimalHarnessExePath = Join-Path $BuildDir 'verify_runtime_u64dec.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredSymbols = @(
    'dw_runtime_main:',
    'dw_runtime_accept_loop:',
    'dw_runtime_handle_client:',
    'dw_runtime_send_response:',
    'dw_runtime_send_all:',
    'dw_runtime_write_output:',
    'dw_runtime_u64_to_dec:'
)

foreach ($Symbol in $RequiredSymbols) {
    if (-not $Source.Contains($Symbol)) {
        throw "missing runtime anchor symbol: $Symbol"
    }
}

$RequiredResponseNeedles = @(
    '# dw_runtime_send_response(socket rcx, response rdx) maps to send_response.',
    'DW_RESPONSE_STATUS_PTR',
    'DW_RESPONSE_BODY_LEN',
    '.dw_header_type_prefix:',
    '.dw_header_len_prefix:',
    '.dw_header_end:',
    'call dw_runtime_u64_to_dec',
    'call dw_runtime_send_all'
)

foreach ($Needle in $RequiredResponseNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime send_response logic: $Needle"
    }
}

$RequiredSendAllNeedles = @(
    '# dw_runtime_send_all(socket rcx, buffer rdx, length r8) maps to send_all.',
    '.dw_runtime_send_loop:',
    'call send',
    'cdqe',
    'add qword ptr [rbp - 16], rax',
    'sub qword ptr [rbp - 24], rax'
)

foreach ($Needle in $RequiredSendAllNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime send_all logic: $Needle"
    }
}

$RequiredWriteOutputNeedles = @(
    '# dw_runtime_write_output(ptr rcx, length rdx) maps to write_stdout.',
    'mov ecx, STD_OUTPUT_HANDLE',
    'call GetStdHandle',
    'call WriteFile'
)

foreach ($Needle in $RequiredWriteOutputNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime write_output logic: $Needle"
    }
}

$RequiredDecimalNeedles = @(
    '# dw_runtime_u64_to_dec(value rcx) -> rax=ptr, rdx=len',
    '.dw_len_buf_end',
    'mov byte ptr [r11], ''0''',
    'mov r10, 10',
    'div r10',
    'add dl, ''0'''
)

foreach ($Needle in $RequiredDecimalNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime decimal logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "runtime source map assembly failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ObjectPath)) {
    throw "runtime source map object was not produced: $ObjectPath"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "runtime source map symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
$RequiredObjectSymbols = @(
    'dw_runtime_main',
    'dw_runtime_accept_loop',
    'dw_runtime_handle_client',
    'dw_runtime_send_response',
    'dw_runtime_send_all',
    'dw_runtime_write_output',
    'dw_runtime_u64_to_dec',
    'send',
    'GetStdHandle',
    'WriteFile'
)

foreach ($Symbol in $RequiredObjectSymbols) {
    if (-not $SymbolText.Contains($Symbol)) {
        throw "missing runtime object symbol: $Symbol"
    }
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_u64_to_dec
.extern ExitProcess

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_u64_to_dec
    cmp rdx, 1
    jne fail
    cmp byte ptr [rax], '0'
    jne fail

    mov rcx, 12345
    call dw_runtime_u64_to_dec
    cmp rdx, 5
    jne fail
    cmp byte ptr [rax + 0], '1'
    jne fail
    cmp byte ptr [rax + 1], '2'
    jne fail
    cmp byte ptr [rax + 2], '3'
    jne fail
    cmp byte ptr [rax + 3], '4'
    jne fail
    cmp byte ptr [rax + 4], '5'
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess
'@ | Set-Content -Encoding ASCII $DecimalHarnessPath

& as --64 -o $DecimalHarnessObjectPath $DecimalHarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "runtime decimal harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $DecimalHarnessExePath $DecimalHarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "runtime decimal harness link failed with exit code $LASTEXITCODE"
}

& $DecimalHarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "runtime decimal harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-runtime-source-map: ok'
