$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$DocPath = Join-Path $RepoRoot 'docs/v2-triple-threading.md'

if (-not (Test-Path $DocPath)) {
    throw "missing V2 triple-threading architecture doc: $DocPath"
}

$Doc = Get-Content -Raw -Encoding UTF8 $DocPath
$RequiredNeedles = @(
    '# DEADWIRE V2 Triple-threading Architecture',
    'Lane 1: Accept lane',
    'Lane 2: Work lane',
    'Lane 3: Output lane',
    'dw_runtime_recv_request',
    'dw_runtime_request_is_get',
    'dw_runtime_send_response',
    'Thread creation before queue verification is forbidden.',
    'No default server behavior change.',
    'DEADWIRE V2 has an executable-tested runtime lifecycle foundation.'
)

foreach ($Needle in $RequiredNeedles) {
    if (-not $Doc.Contains($Needle)) {
        throw "missing V2 triple-threading design rule: $Needle"
    }
}

Write-Output 'verify-v2-triple-threading: ok'
