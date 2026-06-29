$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-static: missing generated source: $Asm"
}

$NL = [string][char]10
$original = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")
$patched = $original

function Insert-After-Scoped {
    param(
        [string] $Text,
        [string] $ScopeNeedle,
        [string] $AfterNeedle,
        [string] $Insert,
        [string] $Name
    )

    $scopeAt = $Text.IndexOf($ScopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-static: missing patch point: $Name scope"
    }

    $afterAt = $Text.IndexOf($AfterNeedle, $scopeAt)
    if ($afterAt -lt 0) {
        throw "harden-win-static: missing patch point: $Name anchor"
    }

    $insertAt = $afterAt + $AfterNeedle.Length
    return $Text.Substring(0, $insertAt) + $Insert + $Text.Substring($insertAt)
}

function Replace-Scoped {
    param(
        [string] $Text,
        [string] $ScopeNeedle,
        [string] $Old,
        [string] $New,
        [string] $Name
    )

    $scopeAt = $Text.IndexOf($ScopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-static: missing patch point: $Name scope"
    }

    $oldAt = $Text.IndexOf($Old, $scopeAt)
    if ($oldAt -lt 0) {
        throw "harden-win-static: missing patch point: $Name anchor"
    }

    return $Text.Substring(0, $oldAt) + $New + $Text.Substring($oldAt + $Old.Length)
}

$initStaticTypeFast = @'
    mov qword ptr [rbp - 40], 0
'@

$patched = Insert-After-Scoped $patched 'handle_client:' "    call set_type_text`n" ($initStaticTypeFast + $NL) 'static fast flag init'

$indexJumpOld = @'
    jmp .serve_file
'@

$indexJumpNew = @'
    mov qword ptr [rbp - 40], 1
    jmp .serve_file
'@

$patched = Replace-Scoped $patched '.copy_index:' $indexJumpOld $indexJumpNew 'index html fast flag'

$detectCallOld = @'
    call detect_content_type
'@

$detectCallNew = @'
    cmp qword ptr [rbp - 40], 1
    jne .static_dynamic_content_type
    call set_type_html
    jmp .static_content_type_done
.static_dynamic_content_type:
    call detect_content_type
.static_content_type_done:
'@

$patched = Replace-Scoped $patched '.serve_file:' $detectCallOld $detectCallNew 'static content type fast path'

[IO.File]::WriteAllText($Asm, $patched.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-static: ok'
