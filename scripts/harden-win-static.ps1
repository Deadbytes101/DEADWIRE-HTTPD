$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-static: missing generated source: $Asm"
}

$NL = [string][char]10
$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Insert-After-Scoped([string] $scopeNeedle, [string] $afterNeedle, [string] $insert, [string] $name) {
    $scopeAt = $script:s.IndexOf($scopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-static: missing patch point: $name scope"
    }

    $afterAt = $script:s.IndexOf($afterNeedle, $scopeAt)
    if ($afterAt -lt 0) {
        throw "harden-win-static: missing patch point: $name anchor"
    }

    $insertAt = $afterAt + $afterNeedle.Length
    $script:s = $script:s.Substring(0, $insertAt) + $insert + $script:s.Substring($insertAt)
}

function Replace-Scoped([string] $scopeNeedle, [string] $old, [string] $new, [string] $name) {
    $scopeAt = $script:s.IndexOf($scopeNeedle)
    if ($scopeAt -lt 0) {
        throw "harden-win-static: missing patch point: $name scope"
    }

    $oldAt = $script:s.IndexOf($old, $scopeAt)
    if ($oldAt -lt 0) {
        throw "harden-win-static: missing patch point: $name anchor"
    }

    $script:s = $script:s.Substring(0, $oldAt) + $new + $script:s.Substring($oldAt + $old.Length)
}

$initStaticTypeFast = @'
    mov qword ptr [rbp - 40], 0
'@

Insert-After-Scoped 'handle_client:' "    call set_type_text`n" ($initStaticTypeFast + $NL) 'static fast flag init'

$indexJumpOld = @'
    jmp .serve_file
'@

$indexJumpNew = @'
    mov qword ptr [rbp - 40], 1
    jmp .serve_file
'@

Replace-Scoped '.copy_index:' $indexJumpOld $indexJumpNew 'index html fast flag'

$detectOld = @'
    lea rcx, [rip + path_buf]
    call detect_content_type
'@

$detectNew = @'
    cmp qword ptr [rbp - 40], 1
    jne .static_dynamic_content_type
    call set_type_html
    jmp .static_content_type_done
.static_dynamic_content_type:
    lea rcx, [rip + path_buf]
    call detect_content_type
.static_content_type_done:
'@

Replace-Scoped '.serve_file:' $detectOld $detectNew 'static content type fast path'

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-static: ok'
