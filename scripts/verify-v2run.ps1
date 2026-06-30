$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourcePath = Join-Path $RepoRoot 'src/runtime/runtime_run_windows.s'
$BuildDir = Join-Path $RepoRoot 'build'
$ObjectPath = Join-Path $BuildDir 'runtime_v2run.o'
$HarnessPath = Join-Path $BuildDir 'verify_runtime_v2run.s'
$HarnessObjectPath = Join-Path $BuildDir 'verify_runtime_v2run.o'
$HarnessExePath = Join-Path $BuildDir 'verify_runtime_v2run.exe'

if (-not (Test-Path $SourcePath)) {
    throw "missing V2 run source: $SourcePath"
}

$Source = Get-Content -Raw -Encoding UTF8 $SourcePath
$RequiredNeedles = @(
    'dw_runtime_run_lanes:',
    'dw_runtime_spawn_lanes',
    'dw_runtime_join_lanes',
    'DW_SPAWN_LAST_RESULT'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Source.Contains($Needle)) {
        throw "missing V2 run rule: $Needle"
    }
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

& as --64 -o $ObjectPath $SourcePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 run assembly failed with exit code $LASTEXITCODE"
}

$SymbolLines = & nm -g $ObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 run symbol table failed with exit code $LASTEXITCODE"
}

$SymbolText = $SymbolLines -join "`n"
if (-not $SymbolText.Contains('dw_runtime_run_lanes')) {
    throw 'missing runtime object symbol: dw_runtime_run_lanes'
}

@'
.intel_syntax noprefix
.global mainCRTStartup
.global dw_runtime_spawn_lanes
.global dw_runtime_join_lanes
.extern dw_runtime_run_lanes
.extern ExitProcess

.section .data
spawn_ctx:
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 0
    .quad 99
spawn_count:
    .quad 0
join_count:
    .quad 0
last_spawn_ctx:
    .quad 0
last_join_ctx:
    .quad 0
fail_mode:
    .quad 0

.section .text
mainCRTStartup:
    sub rsp, 40

    xor rcx, rcx
    call dw_runtime_run_lanes
    cmp eax, 1
    jne fail

    mov qword ptr [rip + fail_mode], 1
    lea rcx, [rip + spawn_ctx]
    call dw_runtime_run_lanes
    cmp eax, 1
    jne fail
    cmp qword ptr [rip + spawn_ctx + 72], 1
    jne fail
    cmp qword ptr [rip + join_count], 0
    jne fail

    mov qword ptr [rip + fail_mode], 0
    mov qword ptr [rip + spawn_count], 0
    mov qword ptr [rip + join_count], 0
    mov qword ptr [rip + last_spawn_ctx], 0
    mov qword ptr [rip + last_join_ctx], 0
    mov qword ptr [rip + spawn_ctx + 72], 99

    lea rcx, [rip + spawn_ctx]
    call dw_runtime_run_lanes
    test eax, eax
    jne fail
    cmp qword ptr [rip + spawn_ctx + 72], 0
    jne fail
    cmp qword ptr [rip + spawn_count], 1
    jne fail
    cmp qword ptr [rip + join_count], 1
    jne fail

    lea r10, [rip + spawn_ctx]
    cmp qword ptr [rip + last_spawn_ctx], r10
    jne fail
    cmp qword ptr [rip + last_join_ctx], r10
    jne fail

pass:
    xor ecx, ecx
    call ExitProcess

fail:
    mov ecx, 1
    call ExitProcess

dw_runtime_spawn_lanes:
    mov qword ptr [rip + last_spawn_ctx], rcx
    inc qword ptr [rip + spawn_count]
    cmp qword ptr [rip + fail_mode], 1
    je spawn_fail
    xor eax, eax
    ret
spawn_fail:
    mov eax, 1
    ret

dw_runtime_join_lanes:
    mov qword ptr [rip + last_join_ctx], rcx
    inc qword ptr [rip + join_count]
    xor eax, eax
    ret
'@ | Set-Content -Encoding ASCII $HarnessPath

& as --64 -o $HarnessObjectPath $HarnessPath
if ($LASTEXITCODE -ne 0) {
    throw "V2 run harness assembly failed with exit code $LASTEXITCODE"
}

& gcc -nostdlib '-Wl,-e,mainCRTStartup' -o $HarnessExePath $HarnessObjectPath $ObjectPath -lkernel32
if ($LASTEXITCODE -ne 0) {
    throw "V2 run harness link failed with exit code $LASTEXITCODE"
}

& $HarnessExePath
if ($LASTEXITCODE -ne 0) {
    throw "V2 run harness failed with exit code $LASTEXITCODE"
}

Write-Output 'verify-v2run: ok'
$NextProbe = Join-Path $RepoRoot 'scripts/verify-v2final.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NextProbe
if ($LASTEXITCODE -ne 0) { throw "V2 final verifier failed with exit code $LASTEXITCODE" }
