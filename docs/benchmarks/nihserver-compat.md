# nihserver WSL compatibility note

This note records the current external-target blocker for the WSL / Linux benchmark lane.

## Observed failure

When `nihserver` is launched inside WSL with the shared DEADWIRE static directory, it exits before listening:

```sh
target/nihserver/nihserver 19096 ../DEADWIRE-HTTPD/public 768
```

Observed result:

```text
Segmentation fault
```

A direct probe then fails because nothing is listening on the target port:

```text
curl: (7) Failed to connect to 127.0.0.1 port 19096
```

Batch GDB trace:

```text
Program received signal SIGSEGV, Segmentation fault.
0x00000000004040bd in syscall_stat ()
#0  0x00000000004040bd in syscall_stat ()
#1  0x0000000000403072 in _start.endif_web_dir_too_long () at src/nihserver/start.s:131
```

## Likely cause

The upstream `src/nihserver/linux/syscall.s` file places syscall wrapper code under a data section marker. On current WSL / Ubuntu, that can fault when the program tries to execute code from a non-executable data page.

The relevant shape is:

```asm
section .data

syscall_open:
    mov rax, 2
    syscall
    ret
```

`syscall_stat` is in the same file and is reached during the web directory check before the server starts listening.

## Local compatibility experiment

This is an external-target compatibility experiment, not a DEADWIRE source change. Label any result from it as `nihserver patched-section`.

From the `nihserver` repository:

```sh
cd ~/src/nihserver
cp src/nihserver/linux/syscall.s src/nihserver/linux/syscall.s.bak
python3 - <<'PY'
from pathlib import Path
p = Path('src/nihserver/linux/syscall.s')
s = p.read_text()
s = s.replace('section .data\n\nsyscall_open:', 'section .text\n\nsyscall_open:', 1)
p.write_text(s)
PY
make clean
make
```

Then launch it again:

```sh
target/nihserver/nihserver 19096 ../DEADWIRE-HTTPD/public 768
```

In another WSL shell:

```sh
curl -v http://127.0.0.1:19096/
curl -v http://127.0.0.1:19096/style.css
```

If those probes pass, run the DEADWIRE Linux score harness from the DEADWIRE repository:

```sh
cd ~/src/DEADWIRE-HTTPD
sh scripts/bench-score.sh \
  --left-name DEADWIRE_LINUX \
  --left-exe ./build/deadwire \
  --left-args "" \
  --left-port 18080 \
  --right-name NIHSERVER_PATCHED_SECTION \
  --right-exe ../nihserver/target/nihserver/nihserver \
  --right-args "19096 public 768" \
  --right-port 19096 \
  --path /style.css \
  --ready-path / \
  --requests 1024 \
  --rounds 5 \
  --warmup 16
```

## Claim discipline

Do not report this as an upstream nihserver result unless the upstream binary runs without local changes. If this compatibility edit is used, report it as:

```text
DEADWIRE Linux vs nihserver patched-section, WSL, close-mode, /style.css
```
