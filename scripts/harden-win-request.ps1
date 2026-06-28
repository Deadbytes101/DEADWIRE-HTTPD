$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-request: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Insert-After-Scoped([string] $scopeNeedle, [string] $afterNeedle, [string] $insert, [string] $name) {
    $scopeAt = $script:s.IndexOf($scopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-request: missing patch point: $name scope"
    }

    $afterAt = $script:s.IndexOf($afterNeedle, $scopeAt)
    if ($afterAt -lt 0) {
        throw "harden-win-request: missing patch point: $name anchor"
    }

    $insertAt = $afterAt + $afterNeedle.Length
    $script:s = $script:s.Substring(0, $insertAt) + $insert + $script:s.Substring($insertAt)
}

$requestCapGuard = @'

    cmp eax, REQ_CAP
    jae .bad_request
'@

Insert-After-Scoped "    call recv" "    jle .close_client`n" ($requestCapGuard + [string][char]10) 'request cap guard'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-request: ok'
