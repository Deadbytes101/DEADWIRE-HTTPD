$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_request_boundary.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_request_boundary.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_request_boundary.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_request_boundary.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing runtime source map: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_request_is_get:',
    '# dw_runtime_request_is_get(buffer rcx, length rdx) maps to request parser boundary.',
    'call dw_runtime_request_is_get',
    '.dw_runtime_handle_client_bad_request:',
    'mov eax, 4'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing runtime request boundary logic: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "runtime request boundary assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "runtime request boundary symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_request_is_get')) {
    throw 'missing runtime object symbol: dw_runtime_request_is_get'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.extern dw_runtime_request_is_get
.extern ExitProcess

.section .data
good_get:
    .ascii "GET / HTTP/1.1\r\n"
good_get_end:
bad_post:
    .ascii "POST / HTTP/1.1\r\n"
bad_post_end:
short_get:
    .ascii "GE"
short_get_end:

.section .text
mainCRTStartup:
    sub rsp, 40

    lea rcx, [rip + good_get]
    mov rdx, good_get_end - good_get
    call dw_runtime_request_is_get
    cmp eax, 1
    jne fail

    lea rcx, [rip + bad_post]
    mov rdx, bad_post_end - bad_post
    call dw_runtime_request_is_get
    test eax, eax
    jne fail

    lea rcx, [rip + short_get]
    mov rdx, short_get_end - short_get
    call dw_runtime_request_is_get
    test eax, eax
    jne fail

    xor rcx, rcx
    mov rdx, 3
    call dw_runtime_request_is_get
    test eax, eax
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
    throw "runtime request boundary harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lws2_32 -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "runtime request boundary harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "runtime request boundary harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-runtime-request-boundary: ok'
