$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "verify-generated-io: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Assert-Contains {
    param(
        [string] $Needle,
        [string] $Name
    )

    if (-not $s.Contains($Needle)) {
        throw "verify-generated-io: missing marker: $Name"
    }
}

Assert-Contains 'call ReadFile' 'ReadFile call'
Assert-Contains 'mov eax, dword ptr [rip + bytes_done]' 'bytes_done load'
Assert-Contains 'mov r10, qword ptr [rip + file_size]' 'file_size load'
Assert-Contains 'cmp rax, r10' 'full-read compare'
Assert-Contains 'jne .file_error' 'short-read error path'
Assert-Contains 'send_all:' 'send_all routine'
Assert-Contains '.send_loop:' 'send loop label'
Assert-Contains 'sub qword ptr [rbp - 24], rax' 'send remaining-byte decrement'
Assert-Contains 'jmp .send_loop' 'send retry loop'

Write-Host 'verify-generated-io: ok'
