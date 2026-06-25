$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$In = Join-Path $Root 'src\deadwire_windows.s'
$Out = Join-Path $Root 'build\deadwire_windows_port.s'
$s = [IO.File]::ReadAllText($In).Replace("`r`n", "`n")
$NL = [string][char]10
$DQ = [string][char]34
function Swap([string]$a,[string]$b,[string]$n){ if(-not $script:s.Contains($a)){ throw "missing: $n" }; $script:s=$script:s.Replace($a,$b) }
Swap ".extern CloseHandle`n" ".extern CloseHandle`n.extern GetCommandLineA`n" 'extern'
Swap 'DEADWIRE HTTPD v0.3.0 ACCESS LOG' 'DEADWIRE HTTPD v0.2.0 PORT ARG' 'banner'
Swap 'listening on http://127.0.0.1:18080' 'listening on http://127.0.0.1:<port>' 'port banner'
Swap 'fatal: bind failed; is port 18080 already in use?' 'fatal: bind failed; port unavailable' 'bind text'
Swap ('fatal_bind_end:'+$NL+'fatal_listen:') ('fatal_bind_end:'+$NL+'fatal_port:   .ascii '+$DQ+'fatal: bad port\r\n'+$DQ+$NL+'fatal_port_end:'+$NL+'fatal_listen:') 'port text'
Swap ('.section .data'+$NL+'reuse_one: .long 1') 'reuse_one: .long 1' 'data mark'
Swap ('health_path_end:'+$NL+$NL+'sockaddr_in:') ('health_path_end:'+$NL+$NL+'.section .data'+$NL+'sockaddr_in:') 'sockaddr data'
Swap '    .word 0xa046              # port 18080 in network byte order' '    .word 0xa046              # default port 18080 in network byte order' 'port comment'
Swap ('mainCRTStartup:'+$NL+'    push rbp'+$NL+'    mov rbp, rsp'+$NL+'    sub rsp, 64'+$NL+$NL+'    lea rcx, [rip + banner]') ('mainCRTStartup:'+$NL+'    push rbp'+$NL+'    mov rbp, rsp'+$NL+'    sub rsp, 64'+$NL+$NL+'    call configure_port'+$NL+'    jc .die_port'+$NL+$NL+'    lea rcx, [rip + banner]') 'hook'
Swap ('.die_wsa:'+$NL+'    lea rcx, [rip + fatal_wsa]') ('.die_port:'+$NL+'    lea rcx, [rip + fatal_port]'+$NL+'    mov rdx, fatal_port_end - fatal_port'+$NL+'    call die'+$NL+'.die_wsa:'+$NL+'    lea rcx, [rip + fatal_wsa]') 'die port'
$fn = @'
# configure_port() parses optional command-line port into sockaddr_in
configure_port:
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
    je .no_arg
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
    je .no_arg
    cmp al, '"'
    je .after_quote
    inc rbx
    jmp .quoted_loop

.after_quote:
    inc rbx

.after_exe:
.skip_ws:
    mov al, byte ptr [rbx]
    cmp al, ' '
    je .skip_one
    cmp al, 9
    je .skip_one
    jmp .maybe_arg
.skip_one:
    inc rbx
    jmp .skip_ws

.maybe_arg:
    cmp byte ptr [rbx], 0
    je .no_arg
    mov rcx, rbx
    call parse_port_arg
    jc .bad_port
    mov word ptr [rip + sockaddr_in + 2], ax

.no_arg:
    clc
    pop rbx
    ret

.bad_port:
    stc
    pop rbx
    ret

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

'@
Swap ('# send_all(socket, buf, len)'+$NL+'send_all:') ($fn+'# send_all(socket, buf, len)'+$NL+'send_all:') 'parser'
[IO.File]::WriteAllText($Out, $s.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'gen: build/deadwire_windows_port.s'
