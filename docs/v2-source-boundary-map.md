# V2 SOURCE BOUNDARY MAP

This document turns the V2 runtime boundary into repository layout rules.

V2 is not allowed to become a pile of random assembly labels. It needs explicit ownership.

## Current state

```txt
src/deadwire_windows.s
```

The current Windows source is monolithic. That is acceptable for V1.3, but it is not enough for V2 native-runtime parity.

## Boundary directories

```txt
src/runtime/
src/platform/windows/
```

`src/runtime/` owns server meaning.

```txt
request lifecycle
parser policy
path guard policy
response builder policy
send-all guarantee
close or keep-alive policy
future worker lifecycle policy
```

`src/platform/windows/` owns Windows plumbing.

```txt
WinSock2 calls
Kernel32 calls
socket lifetime primitives
file lifetime primitives
console output primitives
platform error edges
```

## Current label map

```txt
mainCRTStartup       -> runtime entry plus temporary platform startup
.accept_loop         -> runtime accept loop plus temporary platform accept
handle_client        -> runtime client lifecycle
send_response        -> runtime response boundary
send_all             -> runtime send-all guarantee over platform send
write_stdout         -> platform console output
CreateFileA path     -> platform file open/read/close boundary
```

## Split order

```txt
1. document boundary ownership
2. verify boundary files exist
3. keep V1 behavior unchanged
4. move labels only after verifier covers the move
5. add thread runtime only after connection lifecycle is isolated
```

## Forbidden shortcuts

```txt
NO C SERVER GLUE
NO THREADS BEFORE BOUNDARY
NO MUTEX BEFORE THREAD ABI
NO CLAIMS WITHOUT TESTS
NO HIDING PLATFORM DETAILS BEHIND FAKE ABSTRACTION
```

## Pass condition

```powershell
make verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-boundary.ps1
```
