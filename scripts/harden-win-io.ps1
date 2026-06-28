$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-io: missing generated source: $Asm"
}

$NL = [string][char]10
$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Insert-After-Scoped([string] $scopeNeedle, [string] $afterNeedle, [string] $insert, [string] $name) {
    $scopeAt = $script:s.IndexOf($scopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-io: missing patch point: $name scope"
    }

    $afterAt = $script:s.IndexOf($afterNeedle, $scopeAt)
    if ($afterAt -lt 0) {
        throw "harden-win-io: missing patch point: $name anchor"
    }

    $insertAt = $afterAt + $afterNeedle.Length
    $script:s = $script:s.Substring(0, $insertAt) + $insert + $script:s.Substring($insertAt)
}

$fullReadCheck = @'

    mov eax, dword ptr [rip + bytes_done]
    mov r10, qword ptr [rip + file_size]
    cmp rax, r10
    jne .file_error
'@

Insert-After-Scoped "    call ReadFile" "    je .file_error`n" ($fullReadCheck + $NL) 'full file read check'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-io: ok'
