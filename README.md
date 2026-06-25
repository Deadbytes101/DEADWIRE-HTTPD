# DEADWIRE HTTPD

A tiny HTTP/1.0 static file server written in x86-64 assembly.

No HTTP framework. No server library. The platform boundary is explicit:

- Linux backend: raw Linux syscalls
- Windows backend: WinSock2 + Kernel32 API calls

## Current milestone

```txt
DEADWIRE HTTPD v0.1.0 INITIAL NATIVE CORE
```

This public history starts at a clean initial import. The server already has a small static-file core, MIME headers, path guards, access log lines, and Windows/Linux backends.

The project is still intentionally small. It is not a TLS server, not an async framework, and not an internet-facing hardened daemon yet.

## v0.1.0 scope

DEADWIRE does one narrow job on both Windows and Linux:

- bind `127.0.0.1:18080`
- accept blocking TCP clients
- parse `GET <path> HTTP/...`
- serve files from `public/`
- render `/` as `public/index.html`
- return `/health`
- emit explicit `Content-Type` and `Content-Length`
- detect MIME for `.html`, `.htm`, `.txt`, `.css`, `.js`, and `.svg`
- print tiny access log lines to stdout
- reject non-GET methods with `405`
- reject path traversal with `403`
- reject raw `%` paths until percent-decoding exists
- return missing files with `404`
- close the connection after every response

Example access log lines:

```txt
access 200 static
access 200 /health
access 405 method
access 403 forbidden
access 404 not-found
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

Manual test:

```powershell
curl.exe http://127.0.0.1:18080/health
curl.exe http://127.0.0.1:18080/hello.txt
curl.exe -I http://127.0.0.1:18080/
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

Expected startup banner:

```txt
DEADWIRE HTTPD v0.3.0 ACCESS LOG
listening on http://127.0.0.1:18080
```

The source banner still reports the pre-rewrite internal milestone. Public release naming starts at `v0.1.0`.

## Verify

```sh
make verify
```

The verification checks:

- `/health` returns `deadwire: ok`
- `/` returns `Content-Type: text/html; charset=utf-8`
- `/hello.txt` returns `Content-Type: text/plain; charset=utf-8`
- `/style.css` returns `Content-Type: text/css; charset=utf-8`
- `POST /` returns `405`
- traversal attempts return `403`
- a missing file returns `404`
- access log lines are emitted for the checked request classes

## Current limitations

- fixed port: `18080`
- fixed bind address: `127.0.0.1`
- single-threaded blocking I/O
- HTTP/1.0 response style
- access log is intentionally small and status-class based
- no TLS
- no keep-alive
- no chunked encoding
- no percent-decoding yet
- max request buffer: 4096 bytes
- max served file size: 65536 bytes

## Release tags

```txt
v0.1.0  initial native assembly server
```

## Roadmap

```txt
v0.2.0  configurable port
v0.3.0  configurable bind address
v0.4.0  structured access log
v0.5.0  stricter HTTP parser
v0.6.0  release hardening
v1.0.0  stable static-file core
```

## Core design

Linux path:

```txt
socket -> setsockopt -> bind -> listen -> accept -> read -> parse -> openat -> read -> write -> close
```

Windows path:

```txt
WSAStartup -> socket -> setsockopt -> bind -> listen -> accept -> recv -> parse -> CreateFileA -> ReadFile -> send -> closesocket
```

That is the point of the project: every platform boundary is explicit.
