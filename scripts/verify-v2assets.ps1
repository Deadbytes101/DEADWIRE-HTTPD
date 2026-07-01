$ErrorActionPreference='Stop'
$R=Resolve-Path (Join-Path $PSScriptRoot '..')
$Boot=Join-Path $R 'src/runtime/runtime_boot_windows.c'
$Index=Join-Path $R 'public/index.html'
$Css=Join-Path $R 'public/style.css'
foreach($P in @($Boot,$Index,$Css)){if(!(Test-Path $P)){throw "missing $P"}}
$S=Get-Content -Raw -Encoding UTF8 $Boot
$IndexText=[System.IO.File]::ReadAllText($Index,[System.Text.Encoding]::UTF8).Replace("`r`n","`n").Replace("`r","`n")
$CssText=[System.IO.File]::ReadAllText($Css,[System.Text.Encoding]::UTF8).Replace("`r`n","`n").Replace("`r","`n")
$IndexBytes=[System.Text.Encoding]::UTF8.GetByteCount($IndexText)
$CssBytes=[System.Text.Encoding]::UTF8.GetByteCount($CssText)
function Has([string]$Needle,[string]$Label){if(!$S.Contains($Needle)){throw "missing $Label"}}
if($IndexBytes -ne 1254){throw "bad index bytes $IndexBytes"}
if($CssBytes -ne 772){throw "bad css bytes $CssBytes"}
Has 'Content-Length: 1254\r\n' 'root length'
Has 'Content-Length: 772\r\n' 'css length'
Has 'Content-Length: 13\r\n' 'health length'
Has 'Content-Length: 14\r\n' 'missing length'
Has 'deadwire: ok\n' 'health body'
Has '404 not found\n' 'missing body'
Has '<title>DEADWIRE HTTPD</title>' 'root title'
Has 'GET /style.css' 'css route line'
Has 'font-size: clamp(13px, 1.45vw, 18px);' 'css screen rule'
Has 'deadwire_set_response(root_response_context' 'root response'
Has 'deadwire_set_response(css_response_context' 'css response'
Write-Output 'verify-v2assets: ok'
