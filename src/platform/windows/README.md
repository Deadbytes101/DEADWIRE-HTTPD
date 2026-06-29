# DEADWIRE WINDOWS PLATFORM BACKEND

This directory defines the Windows platform backend boundary for V2 work.

The backend exists to expose platform operations to the runtime without hiding the machine.

## Current implementation

The current Windows implementation still lives in `src/deadwire_windows.s`. V2.0 maps the platform-owned parts before moving code.

```txt
platform startup       -> WSAStartup
platform shutdown      -> WSACleanup
socket create          -> socket
socket option          -> setsockopt
bind/listen/accept     -> bind / listen / accept
socket receive/send    -> recv / send
socket close           -> closesocket
file open/read/close   -> CreateFileA / ReadFile / CloseHandle
file size              -> GetFileSizeEx
stdout/fatal exit      -> GetStdHandle / WriteFile / ExitProcess
```

## Backend owns

```txt
WINSOCK2 API BOUNDARY
KERNEL32 API BOUNDARY
SOCKET LIFETIME PRIMITIVES
FILE LIFETIME PRIMITIVES
CONSOLE OUTPUT PRIMITIVES
PLATFORM ERROR EDGES
```

## Backend does not own

```txt
HTTP PARSE POLICY
PATH SECURITY POLICY
RESPONSE STATUS SELECTION
CONTENT TYPE POLICY
CONNECTION REUSE POLICY
FUTURE WORKER POOL POLICY
```

## Rule

```txt
THE BACKEND MAY TOUCH WINDOWS.
THE RUNTIME MAY OWN SERVER MEANING.
DO NOT MIX POLICY WITH PLATFORM PLUMBING.
```
