$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Gen = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Exe)) {
    throw "verify-preflight: missing exe"
}
if (-not (Test-Path $Gen)) {
    throw "verify-preflight: missing generated source"
}

$exeInfo = Get-Item $Exe
if ($exeInfo.Length -le 0) {
    throw "verify-preflight: empty exe"
}

$src = Get-Content -Raw $Gen
$must = @(
    'DEADWIRE HTTPD v0.8.0 PREFLIGHT',
    'fatal: bad arg',
    'head_request: .long 0',
    'access status=200 route=/health',
    'access status=405 reason=method'
)
foreach ($item in $must) {
    if ($src -notmatch [regex]::Escape($item)) {
        throw "verify-preflight: missing generated marker: $item"
    }
}

$mustNot = @(
    'DEADWIRE HTTPD v0.3.0 ACCESS LOG',
    'access 200 /health',
    'access 405 method'
)
foreach ($item in $mustNot) {
    if ($src -match [regex]::Escape($item)) {
        throw "verify-preflight: stale generated marker: $item"
    }
}

Write-Host 'verify-preflight: ok'
