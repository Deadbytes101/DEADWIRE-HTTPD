$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "verify-generated-log: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Assert-Contains {
    param(
        [string] $Needle,
        [string] $Name
    )

    if (-not $s.Contains($Needle)) {
        throw "verify-generated-log: missing marker: $Name"
    }
}

function Assert-Ordered {
    param(
        [string] $First,
        [string] $Second,
        [string] $Name
    )

    $a = $s.IndexOf($First)
    $b = $s.IndexOf($Second)
    if ($a -lt 0 -or $b -lt 0 -or $a -ge $b) {
        throw "verify-generated-log: bad order: $Name"
    }
}

Assert-Contains 'stdout_handle: .quad 0' 'stdout handle storage'
Assert-Contains 'write_stdout:' 'write_stdout label'
Assert-Contains 'mov rcx, qword ptr [rip + stdout_handle]' 'cached handle load'
Assert-Contains 'test rcx, rcx' 'cached handle test'
Assert-Contains 'jne .stdout_ready' 'cached handle branch'
Assert-Contains 'call GetStdHandle' 'GetStdHandle fallback'
Assert-Contains 'mov qword ptr [rip + stdout_handle], rax' 'cached handle store'
Assert-Contains '.stdout_ready:' 'stdout ready label'
Assert-Contains 'call WriteFile' 'WriteFile call'

Assert-Ordered 'write_stdout:' 'mov rcx, qword ptr [rip + stdout_handle]' 'write before handle load'
Assert-Ordered 'mov rcx, qword ptr [rip + stdout_handle]' 'call GetStdHandle' 'load before fallback'
Assert-Ordered 'call GetStdHandle' 'mov qword ptr [rip + stdout_handle], rax' 'fallback before cache store'
Assert-Ordered 'mov qword ptr [rip + stdout_handle], rax' '.stdout_ready:' 'store before ready label'
Assert-Ordered '.stdout_ready:' 'call WriteFile' 'ready before write'

Write-Host 'verify-generated-log: ok'
