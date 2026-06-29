$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "verify-generated-response-pack: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Assert-Contains {
    param(
        [string] $Text,
        [string] $Needle,
        [string] $Name
    )

    if (-not $Text.Contains($Needle)) {
        throw "verify-generated-response-pack: missing marker: $Name"
    }
}

Assert-Contains $s 'response_header_buf: .skip 512' 'response header buffer'

$start = $s.IndexOf('send_response:')
if ($start -lt 0) {
    throw 'verify-generated-response-pack: missing send_response label'
}

$end = $s.IndexOf('# detect_content_type', $start)
if ($end -lt 0) {
    throw 'verify-generated-response-pack: missing send_response end'
}

$fn = $s.Substring($start, $end - $start)

Assert-Contains $fn 'lea rdi, [rip + response_header_buf]' 'header buffer cursor'
Assert-Contains $fn 'rep movsb' 'header copy'
Assert-Contains $fn 'call u64_to_dec' 'content length formatting'
Assert-Contains $fn 'lea rdx, [rip + response_header_buf]' 'header send pointer'
Assert-Contains $fn 'sub r8, rdx' 'header length compute'
Assert-Contains $fn 'cmp dword ptr [rip + head_request], 0' 'HEAD body gate'
Assert-Contains $fn '.response_done:' 'response done label'

$sendAllCount = ([regex]::Matches($fn, 'call send_all')).Count
if ($sendAllCount -ne 2) {
    throw "verify-generated-response-pack: expected 2 send_all calls in send_response, got $sendAllCount"
}

Write-Host 'verify-generated-response-pack: ok'
