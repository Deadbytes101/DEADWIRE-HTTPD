<div align="center">

# DEADWIRE HTTPD

**TINY HTTP/1.0 STATIC SERVER. RAW BACKENDS. NO FRAMEWORK.**

<p>
  <img alt="http" src="https://img.shields.io/badge/HTTP-1.0-informational">
  <img alt="asm" src="https://img.shields.io/badge/X86--64-ASSEMBLY-critical">
  <img alt="keep alive" src="https://img.shields.io/badge/KEEP--ALIVE-OPT--IN-orange">
  <img alt="framework" src="https://img.shields.io/badge/NO-FRAMEWORK-black">
</p>

<p>
  <img width="860" alt="DEADWIRE HTTPD" src="https://github.com/user-attachments/assets/13397280-5830-4526-afaf-4503d32be06c">
</p>

</div>

## WHAT IT IS

```txt
DEADWIRE HTTPD IS A SMALL HTTP/1.0 STATIC-FILE SERVER.
NO HTTP FRAMEWORK. NO SERVER LIBRARY. NO HIDDEN RUNTIME LAYER.
```

```txt
WINDOWS -> WINSOCK2 + KERNEL32
LINUX   -> RAW LINUX SYSCALL PATH
MACOS   -> POSIX SOCKET PATH
```

## ARCHITECTURAL PIPELINE

```mermaid
flowchart LR
    CLIENT["TCP CLIENT"] --> SOCKET["PLATFORM SOCKET"]
    SOCKET --> RECV["RECV / READ"]
    RECV --> PARSE["REQUEST PARSER"]
    PARSE --> GUARD["PATH GUARD"]
    GUARD --> ROUTE{"ROUTE"}
    ROUTE --> HEALTH["/health"]
    ROUTE --> STATIC["public file"]
    ROUTE --> MISS["404"]
    HEALTH --> RESPONSE["RESPONSE BUILDER"]
    STATIC --> RESPONSE
    MISS --> RESPONSE
    RESPONSE --> SEND["SEND ALL"]
    SEND --> CLOSE["CLOSE"]
    SEND --> LOOP["KEEP-ALIVE LOOP"]
```

## BUILD

```sh
make clean
make doctor
make verify
make run
```

## WINDOWS BUILD FLAVORS

```txt
build/deadwire.exe                 DEFAULT CLOSE-AFTER-RESPONSE SERVER
build/deadwire_accesslog_off.exe   QUIET CLOSE-AFTER-RESPONSE BENCH SERVER
build/deadwire_keepalive.exe       STABLE OPT-IN KEEP-ALIVE SERVER
build/deadwire_v2_runtime.exe      OPT-IN V2 LIVE SMOKE RUNTIME
```

```sh
make build-quiet
make build-keepalive
make verify-keepalive
make build-v2-runtime
make verify-triple-thread
```

## V2 STATUS

```txt
V1.3.0 IS RELEASED.
THE DEFAULT SERVER PATH IS STILL THE CLOSE-AFTER-RESPONSE V1 SERVER.
V2 IS OPT-IN AND PROVED BY LOCAL VERIFY GATES.
```

```txt
CURRENT V2 PROOF:
- FIXED RUNTIME SHAPE: SUPERVISOR / ACCEPTOR / HTTP ENGINE
- NO WORKER POOL
- NO THREAD-PER-CONNECTION
- V2 TICK ACCEPTS A LOOPBACK CLIENT AND RUNS THE HTTP REQUEST STEP
- DEADWIRE_V2_RUNTIME.EXE OPENS LOOPBACK, SENDS FOUR GETS, CHECKS EACH RESPONSE, WRAPS THE QUEUE CURSOR, AND CLOSES CLEANLY
- V2 SHUTDOWN CHECKS LIVE SOCKET RESET, CLIENT SOCKET SENTINEL, AND IDEMPOTENT LIVE CLOSE
- MAKE VERIFY-TRIPLE-THREAD RUNS THE V2 LIVE SMOKE EXE THROUGH VERIFY-V2FINAL
```

SEE `docs/v2-native-runtime-parity-roadmap.md` AND `docs/v2-triple-thread-runtime.md`.

## SCOPE

```txt
BIND DEFAULT: 127.0.0.1:18080
ARGS:         deadwire [port] [127.0.0.1|0.0.0.0]
METHODS:      GET, HEAD
ROOT:         public/
HEALTH:       /health
STYLE:        BLOCKING, SINGLE-THREADED
```

DEFAULT BEHAVIOR REMAINS CLOSE-AFTER-RESPONSE.
KEEP-ALIVE IS AN OPT-IN WINDOWS BUILD FLAVOR.
THIS IS A CONNECTION-REUSE WIN, NOT A CONCURRENCY FEATURE.

## BENCHMARKS

```sh
make bench-native
make bench-native-quiet
make bench-native-keepalive
make bench-v2-runtime
```

SEE `BENCHMARKS.md` AND `docs/v1.3-keepalive-native-bench.md` FOR RECORDED RUNS.
V2 RUNTIME MICROBENCH NUMBERS ARE LOCAL HANDOFF NUMBERS, NOT PUBLIC SERVER BENCHMARK CLAIMS.

## LIMITS

```txt
REQUEST BUFFER: 4096 BYTES
MAX SERVED FILE: 65536 BYTES
NO CHUNKED ENCODING
NO PERCENT-DECODING YET
NOT TLS
NOT ASYNC
NOT CGI
NOT INTERNET-FACING
```

EVERY PLATFORM BOUNDARY IS EXPLICIT.
