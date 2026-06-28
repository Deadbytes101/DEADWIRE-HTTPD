$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-path: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")
$NL = [string][char]10

function Swap([string] $a, [string] $b, [string] $name) {
    if (-not $script:s.Contains($a)) {
        throw "harden-win-path: missing patch point: $name"
    }
    $script:s = $script:s.Replace($a, $b)
}

function Insert-Before([string] $needle, [string] $insert, [string] $name) {
    $at = $script:s.IndexOf($needle)
    if ($at -lt 0) {
        throw "harden-win-path: missing patch point: $name"
    }
    $script:s = $script:s.Substring(0, $at) + $insert + $script:s.Substring($at)
}

$forbiddenChars = @'
    cmp al, ':'
    je .forbidden
    cmp al, '*'
    je .forbidden
    cmp al, '?'
    je .forbidden
    cmp al, '"'
    je .forbidden
    cmp al, '<'
    je .forbidden
    cmp al, '>'
    je .forbidden
    cmp al, '|'
    je .forbidden

'@

Insert-Before "    cmp al, '.'" $forbiddenChars 'win32 forbidden path characters'

$pathReadyOld = @'
.path_ready:
    cmp qword ptr [rbp - 32], 0
    je .bad_request
'@

$pathReadyNew = @'
.path_ready:
    cmp qword ptr [rbp - 32], 0
    je .bad_request

    mov r10, qword ptr [rbp - 16]
    mov rax, qword ptr [rbp - 32]
    dec rax
    mov al, byte ptr [r10 + rax]
    cmp al, '.'
    je .forbidden
'@

Swap $pathReadyOld $pathReadyNew 'trailing dot path guard'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-path: ok'
