$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Exe = Join-Path $Root 'build\deadwire.exe'
$Log = Join-Path $Root 'build\deadwire-badarg.log'
$Err = Join-Path $Root 'build\deadwire-badarg.err'

if (-not (Test-Path $Exe)) {
    throw "verify-badarg: missing executable: $Exe"
}

function Invoke-BadArg {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Args,
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    Remove-Item $Log, $Err -ErrorAction SilentlyContinue
    $proc = Start-Process -FilePath $Exe -WorkingDirectory $Root -ArgumentList $Args -PassThru -RedirectStandardOutput $Log -RedirectStandardError $Err

    if (-not $proc.WaitForExit(3000)) {
        Stop-Process -Id $proc.Id -Force
        throw "verify-badarg: $Name did not exit"
    }

    $out = ''
    if (Test-Path $Log) { $out = Get-Content -Raw $Log }
    if ($out -notmatch [regex]::Escape('fatal: bad arg')) {
        throw "verify-badarg: $Name missing fatal text"
    }
}

Invoke-BadArg -Name 'bad-port-alpha' -Args @('nope')
Invoke-BadArg -Name 'bad-port-zero' -Args @('0')
Invoke-BadArg -Name 'bad-bind' -Args @('19093', '127.0.0.2')

Write-Host 'verify-badarg: ok'
