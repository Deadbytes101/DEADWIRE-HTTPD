$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-path: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Insert-Before([string] $needle, [string] $insert, [string] $name) {
    $at = $script:s.IndexOf($needle)
    if ($at -lt 0) {
        throw "harden-win-path: missing patch point: $name"
    }
    $script:s = $script:s.Substring(0, $at) + $insert + $script:s.Substring($at)
}

function Insert-After-Scoped([string] $scopeNeedle, [string] $afterNeedle, [string] $insert, [string] $name) {
    $scopeAt = $script:s.IndexOf($scopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-path: missing patch point: $name scope"
    }

    $afterAt = $script:s.IndexOf($afterNeedle, $scopeAt)
    if ($afterAt -lt 0) {
        throw "harden-win-path: missing patch point: $name anchor"
    }

    $insertAt = $afterAt + $afterNeedle.Length
    $script:s = $script:s.Substring(0, $insertAt) + $insert + $script:s.Substring($insertAt)
}

$forbiddenChars = @'
    cmp al, ':'
    je .forbidden
    cmp al, '*'
    je .forbidden
    cmp al, '?'
    je .forbidden
    cmp al, 34
    je .forbidden
    cmp al, '<'
    je .forbidden
    cmp al, '>'
    je .forbidden
    cmp al, '|'
    je .forbidden

'@

Insert-Before "    cmp al, '.'" $forbiddenChars 'win32 forbidden path characters'

$trailingDotGuard = @'

    mov r10, qword ptr [rbp - 16]
    mov r11, qword ptr [rbp - 32]
    dec r11
    add r10, r11
    cmp byte ptr [r10], 46
    je .forbidden
'@

Insert-After-Scoped ".path_ready:" "    je .bad_request`n" $trailingDotGuard 'trailing dot path guard'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-path: ok'
