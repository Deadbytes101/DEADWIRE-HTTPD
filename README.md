# DEADWIRE HTTPD

A tiny HTTP/1.0 static-file server with explicit platform backends.

No HTTP framework. No server library. No hidden runtime layer.

<img width="1672" height="941" alt="image" src="https://github.com/user-attachments/assets/13397280-5830-4526-afaf-4503d32be06c" />

## Status

```txt
CURRENT: V1.3.0 KEEP-ALIVE BUILD FLAVOR WORK
LATEST RELEASE: V1.2.0 I/O DISCIPLINE
WINDOWS: VERIFIED
LINUX: WIRED
MACOS: WIRED
```

## Backends

```txt
Windows -> WinSock2 + Kernel32
Linux   -> raw Linux syscall path
macOS   -> POSIX socket path
```

## Scope

```txt
bind default: 127.0.0.1:18080
args: deadwire [port] [127.0.0.1|0.0.0.0]
methods: GET, HEAD
root: public/
health: /health
style: blocking, single-threaded
```

Default behavior remains close-after-response. Windows also has an opt-in keep-alive build flavor for repeated sequential requests on one accepted socket.

DEADWIRE is not TLS, not async, not CGI, not a framework, and not an internet-facing daemon.

## Pipeline

```mermaid
flowchart LR
    A[TCP CLIENT] --> B[PLATFORM SOCKET]
    B --> C[RECV / READ]
    C --> D[REQUEST PARSER]
    D --> E[PATH GUARD]
    E --> F[PUBLIC FILE OR /HEALTH]
    F --> G[RESPONSE BUILDER]
    G --> H[SEND ALL]
    H --> I[CLOSE OR LOOP]
```

## Build

```sh
make clean
make doctor
make verify
make run
```

On Windows, `make verify` runs the full checked path:

```txt
verify
verify-parser
verify-response
verify-winpath
verify-io
verify-generated-io
verify-port
verify-bind
verify-badarg
verify-preflight
```

## Windows build flavors

```txt
build/deadwire.exe                 default close-after-response server
build/deadwire_accesslog_off.exe   quiet close-after-response server for benchmarks
build/deadwire_keepalive.exe       stable opt-in keep-alive server flavor
```

### Windows quiet build

The normal Windows binary keeps per-request access logs enabled. For benchmark or local production-style use, build the quiet binary that disables only access-log write sites while keeping banner and fatal output intact.

```sh
make build-quiet
build/deadwire_accesslog_off.exe 18080
```

### Windows keep-alive build

The keep-alive flavor keeps the accepted socket open for repeated sequential requests and advertises `Connection: keep-alive`. It remains blocking and single-threaded. This is a connection-reuse win, not a concurrency feature.

```sh
make build-keepalive
make verify-keepalive
build/deadwire_keepalive.exe 18080
```

Benchmarks for the quiet and keep-alive builds are tracked in `BENCHMARKS.md` and `docs/v1.3-keepalive-native-bench.md`.

## Windows native benches

```sh
make bench-native
make bench-native-long
make bench-native-xl
make bench-native-xxl
make bench-native-lifecycle
make bench-native-quiet
make bench-native-keepalive
```

## Limits

```txt
request buffer: 4096 bytes
max served file: 65536 bytes
default binary: close-after-response
keep-alive flavor: opt-in Windows build
no chunked encoding
no percent-decoding yet
```

## Core paths

```txt
Linux:   socket -> bind -> listen -> accept -> read -> parse -> openat -> read -> write -> close
Windows: WSAStartup -> socket -> bind -> listen -> accept -> recv -> parse -> CreateFileA -> ReadFile -> send -> closesocket
macOS:   socket -> bind -> listen -> accept -> recv -> parse -> fopen -> fread -> send -> close
```

Every platform boundary is explicit.
