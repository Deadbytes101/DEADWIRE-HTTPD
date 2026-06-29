$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Asm = Join-Path $Root 'build\deadwire_windows_port.s'

if (-not (Test-Path $Asm)) {
    throw "harden-win-response: missing generated source: $Asm"
}

$s = [IO.File]::ReadAllText($Asm).Replace("`r`n", "`n")

function Replace-Once {
    param(
        [string] $Text,
        [string] $Old,
        [string] $New,
        [string] $Name
    )

    $at = $Text.IndexOf($Old)
    if ($at -lt 0) {
        throw "harden-win-response: missing patch point: $Name"
    }

    return $Text.Substring(0, $at) + $New + $Text.Substring($at + $Old.Length)
}

$s = Replace-Once $s "len_buf_end:`n" "len_buf_end:`nresponse_header_buf: .skip 512`n" 'response header buffer'

$start = $s.IndexOf('# send_response() uses response_* globals and current_client')
if ($start -lt 0) {
    throw 'harden-win-response: missing patch point: send_response start'
}

$end = $s.IndexOf('# detect_content_type', $start)
if ($end -lt 0) {
    throw 'harden-win-response: missing patch point: send_response end'
}

$newSendResponse = @'
# send_response() uses response_* globals and current_client
send_response:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    cld
    lea rdi, [rip + response_header_buf]

    mov rsi, qword ptr [rip + response_status_ptr]
    mov rcx, qword ptr [rip + response_status_len]
    rep movsb

    lea rsi, [rip + header_type_prefix]
    mov rcx, header_type_prefix_end - header_type_prefix
    rep movsb

    mov rsi, qword ptr [rip + response_type_ptr]
    mov rcx, qword ptr [rip + response_type_len]
    rep movsb

    lea rsi, [rip + header_len_prefix]
    mov rcx, header_len_prefix_end - header_len_prefix
    rep movsb

    mov rcx, qword ptr [rip + response_body_len]
    call u64_to_dec
    mov rsi, rax
    mov rcx, rdx
    rep movsb

    lea rsi, [rip + header_end]
    mov rcx, header_end_end - header_end
    rep movsb

    mov rcx, qword ptr [rip + current_client]
    lea rdx, [rip + response_header_buf]
    mov r8, rdi
    sub r8, rdx
    call send_all

    cmp dword ptr [rip + head_request], 0
    jne .response_done
    mov rcx, qword ptr [rip + current_client]
    mov rdx, qword ptr [rip + response_body_ptr]
    mov r8, qword ptr [rip + response_body_len]
    call send_all

.response_done:
    leave
    ret

'@

$s = $s.Substring(0, $start) + $newSendResponse + $s.Substring($end)

[IO.File]::WriteAllText($Asm, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'harden-win-response: ok'
