$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-log: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Replace-Once {
    param(
        [string] $Old,
        [string] $New,
        [string] $Name
    )

    $at = $script:s.IndexOf($Old)
    if ($at -lt 0) {
        throw "harden-win-log: missing patch point: $Name"
    }

    $script:s = $script:s.Substring(0, $at) + $New + $script:s.Substring($at + $Old.Length)
}

Replace-Once "server_socket: .quad 0`n" "server_socket: .quad 0`nstdout_handle: .quad 0`n" 'stdout handle storage'

$oldWriteStdout = @'
# write_stdout(ptr, len)
write_stdout:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx

    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle

    mov rcx, rax
    mov rdx, qword ptr [rbp - 8]
    mov r8, qword ptr [rbp - 16]
    lea r9, [rip + written_done]
    mov qword ptr [rsp + 32], 0
    call WriteFile

    leave
    ret
'@

$newWriteStdout = @'
# write_stdout(ptr, len)
write_stdout:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword ptr [rbp - 8], rcx
    mov qword ptr [rbp - 16], rdx

    mov rcx, qword ptr [rip + stdout_handle]
    test rcx, rcx
    jne .stdout_ready
    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov qword ptr [rip + stdout_handle], rax
    mov rcx, rax

.stdout_ready:
    mov rdx, qword ptr [rbp - 8]
    mov r8, qword ptr [rbp - 16]
    lea r9, [rip + written_done]
    mov qword ptr [rsp + 32], 0
    call WriteFile

    leave
    ret
'@

Replace-Once $oldWriteStdout $newWriteStdout 'write_stdout cache body'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-log: ok'
