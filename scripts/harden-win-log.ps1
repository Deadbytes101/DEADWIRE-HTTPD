$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-log: missing generated source: $Asm"
}

$original = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")
$patched = $original

function Replace-Once {
    param(
        [string] $Text,
        [string] $Old,
        [string] $New,
        [string] $Name
    )

    $at = $Text.IndexOf($Old)
    if ($at -lt 0) {
        throw "harden-win-log: missing patch point: $Name"
    }

    return $Text.Substring(0, $at) + $New + $Text.Substring($at + $Old.Length)
}

$patched = Replace-Once $patched "server_socket: .quad 0`n" "server_socket: .quad 0`nstdout_handle: .quad 0`n" 'stdout handle storage'

$oldGetStdHandleBlock = @'
    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle

    mov rcx, rax
'@

$newGetStdHandleBlock = @'
    mov rcx, qword ptr [rip + stdout_handle]
    test rcx, rcx
    jne .stdout_ready
    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov qword ptr [rip + stdout_handle], rax
    mov rcx, rax

.stdout_ready:
'@

$writeStdoutAt = $patched.IndexOf('write_stdout:')
if ($writeStdoutAt -lt 0) {
    throw 'harden-win-log: missing patch point: write_stdout label'
}

$tail = $patched.Substring($writeStdoutAt)
$patchedTail = Replace-Once $tail $oldGetStdHandleBlock $newGetStdHandleBlock 'write_stdout cache body'
$patched = $patched.Substring(0, $writeStdoutAt) + $patchedTail

[IO.File]::WriteAllText($Asm, $patched.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-log: ok'
