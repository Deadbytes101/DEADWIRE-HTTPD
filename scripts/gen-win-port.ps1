$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$In = Join-Path $Root 'src\deadwire_windows.s'
$Out = Join-Path $Root 'build\deadwire_windows_port.s'
$s = [IO.File]::ReadAllText($In).Replace("`r`n", "`n")
$NL = [string][char]10
$DQ = [string][char]34
function Swap([string]$a,[string]$b,[string]$n){ if(-not $script:s.Contains($a)){ throw "missing: $n" }; $script:s=$script:s.Replace($a,$b) }
function SpliceRange([int]$start,[int]$end,[string]$replacement,[string]$name){ if($start -lt 0 -or $end -lt $start){ throw "missing: $name" }; $script:s = $script:s.Substring(0,$start) + $replacement + $script:s.Substring($end) }
Swap ".extern CloseHandle`n" ".extern CloseHandle`n.extern GetCommandLineA`n" 'extern'
Swap 'DEADWIRE HTTPD v0.3.0 ACCESS LOG' 'DEADWIRE HTTPD v0.6.0 ANY BIND' 'banner'
Swap 'listening on http://127.0.0.1:18080' 'listening on http://<bind>:<port>' 'listen line'
Swap 'fatal: bind failed; is port 18080 already in use?' 'fatal: bind failed; address unavailable' 'bind text'
Swap ('fatal_bind_end:'+$NL+'fatal_listen:') ('fatal_bind_end:'+$NL+'fatal_arg:    .ascii '+$DQ+'fatal: bad arg\r\n'+$DQ+$NL+'fatal_arg_end:'+$NL+'fatal_listen:') 'arg text'
Swap ('.section .data'+$NL+'reuse_one: .long 1') 'reuse_one: .long 1' 'data mark'
Swap ('health_path_end:'+$NL+$NL+'sockaddr_in:') ('health_path_end:'+$NL+$NL+'.section .data'+$NL+'sockaddr_in:') 'sockaddr data'
Swap '    .word 0xa046              # port 18080 in network byte order' '    .word 0xa046              # default port 18080 in network byte order' 'port comment'
Swap ('mainCRTStartup:'+$NL+'    push rbp'+$NL+'    mov rbp, rsp'+$NL+'    sub rsp, 64'+$NL+$NL+'    lea rcx, [rip + banner]') ('mainCRTStartup:'+$NL+'    push rbp'+$NL+'    mov rbp, rsp'+$NL+'    sub rsp, 64'+$NL+$NL+'    call configure_args'+$NL+'    jc .die_arg'+$NL+$NL+'    lea rcx, [rip + banner]') 'hook'
Swap ('.die_wsa:'+$NL+'    lea rcx, [rip + fatal_wsa]') ('.die_arg:'+$NL+'    lea rcx, [rip + fatal_arg]'+$NL+'    mov rdx, fatal_arg_end - fatal_arg'+$NL+'    call die'+$NL+'.die_wsa:'+$NL+'    lea rcx, [rip + fatal_wsa]') 'die arg'
Swap 'access 200 static' 'access status=200 route=static' 'log static'
Swap 'access 200 /health' 'access status=200 route=/health' 'log health'
Swap 'access 400 bad-request' 'access status=400 reason=bad-request' 'log 400'
Swap 'access 403 forbidden' 'access status=403 reason=forbidden' 'log 403'
Swap 'access 404 not-found' 'access status=404 reason=not-found' 'log 404'
Swap 'access 405 method' 'access status=405 reason=method' 'log 405'
Swap 'access 413 too-large' 'access status=413 reason=too-large' 'log 413'
Swap 'access 414 uri-too-long' 'access status=414 reason=uri-too-long' 'log 414'
Swap 'access 500 file-error' 'access status=500 reason=file-error' 'log 500'
Swap 'written_done: .long 0' ('written_done: .long 0'+$NL+'head_request: .long 0') 'head flag'
$newMethod = @'
    mov dword ptr [rip + head_request], 0
    lea r10, [rip + request_buf]
    cmp byte ptr [r10 + 0], 'G'
    jne .try_head
    cmp byte ptr [r10 + 1], 'E'
    jne .method_not_allowed
    cmp byte ptr [r10 + 2], 'T'
    jne .method_not_allowed
    cmp byte ptr [r10 + 3], ' '
    jne .method_not_allowed
    lea r10, [rip + request_buf + 4]
    jmp .method_ready
.try_head:
    cmp byte ptr [r10 + 0], 'H'
    jne .method_not_allowed
    cmp byte ptr [r10 + 1], 'E'
    jne .method_not_allowed
    cmp byte ptr [r10 + 2], 'A'
    jne .method_not_allowed
    cmp byte ptr [r10 + 3], 'D'
    jne .method_not_allowed
    cmp byte ptr [r10 + 4], ' '
    jne .method_not_allowed
    mov dword ptr [rip + head_request], 1
    lea r10, [rip + request_buf + 5]
.method_ready:
    mov qword ptr [rbp - 16], r10
    mov r11, qword ptr [rbp - 8]
    lea rax, [rip + request_buf]
    mov rcx, r10
    sub rcx, rax
    sub r11, rcx
    mov qword ptr [rbp - 24], r11      # max scan length
    mov qword ptr [rbp - 32], 0        # path length
'@
$methodStart = $s.IndexOf(('    lea r10, [rip + request_buf]'+$NL+'    cmp byte ptr [r10 + 0], '+[string][char]39+'G'+[string][char]39))
$methodTail = '    mov qword ptr [rbp - 32], 0        # path length'
$methodEnd = $s.IndexOf($methodTail, $methodStart)
if($methodEnd -ge 0){ $methodEnd += $methodTail.Length }
SpliceRange $methodStart $methodEnd $newMethod 'head method'
$newSendBody = @'
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
$responseStart = $s.IndexOf('send_response:')
$bodyNeedle = '    mov rcx, qword ptr [rip + current_client]'+$NL+'    mov rdx, qword ptr [rip + response_body_ptr]'
$bodyStart = $s.IndexOf($bodyNeedle, $responseStart)
$bodyTail = '    ret'
$bodyEnd = $s.IndexOf($bodyTail, $bodyStart)
if($bodyEnd -ge 0){ $bodyEnd += $bodyTail.Length }
SpliceRange $bodyStart $bodyEnd $newSendBody 'head body skip'
$fn = @'
# configure_args() parses optional: <port> [127.0.0.1|0.0.0.0]
configure_args:
    push rbx
    sub rsp, 32
    call GetCommandLineA
    add rsp, 32

    mov rbx, rax
    cmp byte ptr [rbx], '"'
    je .quoted_exe
.unquoted_exe:
    mov al, byte ptr [rbx]
    test al, al
    je .ok
    cmp al, ' '
    je .after_exe
    cmp al, 9
    je .after_exe
    inc rbx
    jmp .unquoted_exe
.quoted_exe:
    inc rbx
.quoted_loop:
    mov al, byte ptr [rbx]
    test al, al
    je .ok
    cmp al, '"'
    je .after_quote
    inc rbx
    jmp .quoted_loop
.after_quote:
    inc rbx
.after_exe:
    call skip_ws
    cmp byte ptr [rbx], 0
    je .ok
    mov rcx, rbx
    call parse_port_arg
    jc .bad
    mov word ptr [rip + sockaddr_in + 2], ax
    mov rbx, rcx
    call skip_ws
    cmp byte ptr [rbx], 0
    je .ok
    mov rcx, rbx
    call parse_bind_arg
    jc .bad
    mov dword ptr [rip + sockaddr_in + 4], eax
.ok:
    clc
    pop rbx
    ret
.bad:
    stc
    pop rbx
    ret

skip_ws:
.skip_ws_loop:
    mov al, byte ptr [rbx]
    cmp al, ' '
    je .skip_one
    cmp al, 9
    je .skip_one
    ret
.skip_one:
    inc rbx
    jmp .skip_ws_loop

parse_port_arg:
    push rbx
    xor eax, eax
    xor r8d, r8d
.port_loop:
    mov bl, byte ptr [rcx]
    test bl, bl
    je .port_done
    cmp bl, ' '
    je .port_done
    cmp bl, 9
    je .port_done
    cmp bl, '0'
    jb .port_bad
    cmp bl, '9'
    ja .port_bad
    imul eax, eax, 10
    movzx ebx, bl
    sub ebx, '0'
    add eax, ebx
    cmp eax, 65535
    ja .port_bad
    inc rcx
    inc r8d
    cmp r8d, 5
    ja .port_bad
    jmp .port_loop
.port_done:
    test r8d, r8d
    jz .port_bad
    test eax, eax
    jz .port_bad
    rol ax, 8
    clc
    pop rbx
    ret
.port_bad:
    stc
    pop rbx
    ret

parse_bind_arg:
    cmp byte ptr [rcx+0], '1'
    jne .try_any
    cmp byte ptr [rcx+1], '2'
    jne .bind_bad
    cmp byte ptr [rcx+2], '7'
    jne .bind_bad
    cmp byte ptr [rcx+3], '.'
    jne .bind_bad
    cmp byte ptr [rcx+4], '0'
    jne .bind_bad
    cmp byte ptr [rcx+5], '.'
    jne .bind_bad
    cmp byte ptr [rcx+6], '0'
    jne .bind_bad
    cmp byte ptr [rcx+7], '.'
    jne .bind_bad
    cmp byte ptr [rcx+8], '1'
    jne .bind_bad
    mov rdx, rcx
    add rdx, 9
    call bind_end_ok
    jc .bind_bad
    mov eax, 0x0100007f
    clc
    ret
.try_any:
    cmp byte ptr [rcx+0], '0'
    jne .bind_bad
    cmp byte ptr [rcx+1], '.'
    jne .bind_bad
    cmp byte ptr [rcx+2], '0'
    jne .bind_bad
    cmp byte ptr [rcx+3], '.'
    jne .bind_bad
    cmp byte ptr [rcx+4], '0'
    jne .bind_bad
    cmp byte ptr [rcx+5], '.'
    jne .bind_bad
    cmp byte ptr [rcx+6], '0'
    jne .bind_bad
    mov rdx, rcx
    add rdx, 7
    call bind_end_ok
    jc .bind_bad
    xor eax, eax
    clc
    ret
.bind_bad:
    stc
    ret

bind_end_ok:
    mov al, byte ptr [rdx]
    test al, al
    je .end_ok
    cmp al, ' '
    je .end_ok
    cmp al, 9
    je .end_ok
    stc
    ret
.end_ok:
    clc
    ret

'@
Swap ('# send_all(socket, buf, len)'+$NL+'send_all:') ($fn+'# send_all(socket, buf, len)'+$NL+'send_all:') 'parser'
[IO.File]::WriteAllText($Out, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'gen: build/deadwire_windows_port.s'
