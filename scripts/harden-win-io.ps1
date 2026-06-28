$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-io: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Swap([string] $a, [string] $b, [string] $name) {
    if (-not $script:s.Contains($a)) {
        throw "harden-win-io: missing patch point: $name"
    }
    $script:s = $script:s.Replace($a, $b)
}

$readFileOld = @'
    call ReadFile
    test eax, eax
    je .file_error

    mov rcx, qword ptr [rip + current_file]
'@

$readFileNew = @'
    call ReadFile
    test eax, eax
    je .file_error

    mov eax, dword ptr [rip + bytes_done]
    mov r10, qword ptr [rip + file_size]
    cmp rax, r10
    jne .file_error

    mov rcx, qword ptr [rip + current_file]
'@

Swap $readFileOld $readFileNew 'full file read check'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-io: ok'
