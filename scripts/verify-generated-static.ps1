$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "verify-generated-static: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Assert-Contains {
    param(
        [string] $Needle,
        [string] $Name
    )

    if (-not $s.Contains($Needle)) {
        throw "verify-generated-static: missing marker: $Name"
    }
}

function Assert-Ordered {
    param(
        [string] $First,
        [string] $Second,
        [string] $Name
    )

    $a = $s.IndexOf($First)
    $b = $s.IndexOf($Second)
    if ($a -lt 0 -or $b -lt 0 -or $a -ge $b) {
        throw "verify-generated-static: bad order: $Name"
    }
}

Assert-Contains '.serve_file:' 'serve file label'
Assert-Contains 'call CreateFileA' 'CreateFileA call'
Assert-Contains 'call GetFileSizeEx' 'GetFileSizeEx call'
Assert-Contains 'cmp rax, FILE_CAP' 'file cap compare'
Assert-Contains 'ja .file_too_large' 'file too large branch'
Assert-Contains 'call ReadFile' 'ReadFile call'
Assert-Contains 'mov eax, dword ptr [rip + bytes_done]' 'bytes_done load'
Assert-Contains 'cmp rax, r10' 'full read compare'
Assert-Contains 'jne .file_error' 'short read error branch'
Assert-Contains 'call CloseHandle' 'CloseHandle call'
Assert-Contains 'call detect_content_type' 'MIME detect call'
Assert-Contains 'call send_response' 'send response call'

Assert-Ordered '.serve_file:' 'call CreateFileA' 'serve before open'
Assert-Ordered 'call CreateFileA' 'call GetFileSizeEx' 'open before size'
Assert-Ordered 'call GetFileSizeEx' 'call ReadFile' 'size before read'
Assert-Ordered 'call ReadFile' 'call CloseHandle' 'read before close'
Assert-Ordered 'call CloseHandle' 'call detect_content_type' 'close before MIME detect'
Assert-Ordered 'call detect_content_type' 'call send_response' 'MIME before response'

Write-Host 'verify-generated-static: ok'
