# DEADWIRE HTTPD

A tiny HTTP/1.0 static file server written in x86-64 assembly.

No HTTP framework. No server library. The platform boundary is explicit:

- Linux backend: raw Linux syscalls
- Windows backend: WinSock2 + Kernel32 API calls

## Current milestone

```txt
DEADWIRE HTTPD v0.9.0 RELEASE POLISH
```

The project has a verified Windows release path for the stable static-file core: default local bind, configurable port, configurable bind address, HEAD support, structured access logs, and explicit bad-argument failure checks.

DEADWIRE is still intentionally small. It is not a TLS server, not an async framework, and not an internet-facing hardened daemon.

## Current scope

DEADWIRE does one narrow job:

- bind `127.0.0.1:18080` by default
- accept an optional port argument on Windows: `deadwire.exe 19090`
- accept an optional bind argument on Windows: `deadwire.exe 19091 127.0.0.1`
- accept `0.0.0.0` when explicitly requested
- accept blocking TCP clients
- parse `GET <path> HTTP/...`
- parse `HEAD <path> HTTP/...`
- serve files from `public/`
- render `/` as `public/index.html`
- return `/health`
- emit explicit `Content-Type` and `Content-Length`
- detect MIME for `.html`, `.htm`, `.txt`, `.css`, `.js`, and `.svg`
- print small structured access log lines to stdout
- reject unsupported methods with `405`
- reject path traversal with `403`
- reject raw `%` paths until percent-decoding exists
- return missing files with `404`
- close the connection after every response

Example access log lines:

```txt
access status=200 route=static
access status=200 route=/health
access status=405 reason=method
access status=403 reason=forbidden
access status=404 reason=not-found
```

## Platform model

```txt
src/deadwire.s           Linux x86-64 backend, raw syscalls
src/deadwire_windows.s   Windows x86-64 backend, WinSock2 + Kernel32
```

The `Makefile` selects the backend automatically:

```txt
Windows_NT -> build/deadwire.exe
Linux      -> build/deadwire
```

On Windows, the build generates `build/deadwire_windows_port.s` from `src/deadwire_windows.s` before assembling. The generated file adds the current Windows release features while preserving the small assembly core.

## Windows build

Use a Windows x86-64 toolchain that provides:

- `make`
- GNU assembler: `as`
- `gcc` for PE/COFF linking
- PowerShell

```powershell
make clean
make doctor
make verify
make run
```

Manual tests:

```powershell
build\deadwire.exe
curl.exe http://127.0.0.1:18080/health

build\deadwire.exe 19090
curl.exe http://127.0.0.1:19090/health

build\deadwire.exe 19091 127.0.0.1
curl.exe -I http://127.0.0.1:19091/health
```

## Linux / WSL2 build

Use Linux x86-64 or WSL2 with:

- `make`
- GNU assembler: `as`
- GNU linker: `ld`
- `curl` for verification

```sh
sudo apt update
sudo apt install -y build-essential curl
make clean
make doctor
make verify
make run
```

The Linux backend remains the compact raw-syscall static server path. The current argument parsing release train is Windows-first.

## Verify

```sh
make verify
```

The Windows verification checks:

- `/health` returns `deadwire: ok`
- `/` returns `Content-Type: text/html; charset=utf-8`
- `/hello.txt` returns `Content-Type: text/plain; charset=utf-8`
- `/style.css` returns `Content-Type: text/css; charset=utf-8`
- `HEAD /health` returns headers without a body
- `POST /` returns `405`
- traversal attempts return `403`
- a missing file returns `404`
- structured access log lines are emitted
- custom port works on `19090`
- explicit loopback bind works on `127.0.0.1:19091`
- explicit any-address bind works on `0.0.0.0:19092`
- bad argument cases exit with `fatal: bad arg`
- generated Windows source contains expected release markers

## Current limitations

- single-threaded blocking I/O
- HTTP/1.0 response style
- no TLS
- no keep-alive
- no chunked encoding
- no percent-decoding yet
- max request buffer: 4096 bytes
- max served file size: 65536 bytes
- Windows argument support is generated at build time

## Release tags

```txt
v0.1.0  initial native assembly server
v0.2.0  port arg
v0.3.0  bind arg
v0.4.0  log shape
v0.5.0  HEAD request
v0.6.0  any bind
v0.7.0  bad arg verify
v0.8.0  preflight verify
v0.9.0  release polish
```

## Roadmap

```txt
v1.0.0  stable static-file core
```

## Core design

Linux path:

```txt
socket -> bind -> listen -> accept -> read -> parse -> openat -> read -> write -> close
```

Windows path:

```txt
WSAStartup -> socket -> setsockopt -> bind -> listen -> accept -> recv -> parse -> CreateFileA -> ReadFile -> send -> closesocket
```

That is the point of the project: every platform boundary is explicit.
