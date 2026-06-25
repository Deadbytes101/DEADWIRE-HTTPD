# Changelog

## v0.3.0 ACCESS LOG

This milestone keeps the v0.2.x FINAL CORE intact and adds visible daemon behavior.

### Added

- Linux access log lines written through raw `write` syscall path.
- Windows access log lines written through `WriteFile` stdout path.
- Startup banner updated to `DEADWIRE HTTPD v0.3.0 ACCESS LOG`.
- README updated with v0.3.0 scope and access log examples.

### Access log format

```txt
access 200 static
access 200 /health
access 400 bad-request
access 403 forbidden
access 404 not-found
access 405 method
access 413 too-large
access 414 uri-too-long
access 500 file-error
```

### Notes

- The log is intentionally tiny and fixed-string based.
- It does not allocate, format timestamps, or copy request paths yet.
- The server core remains blocking and single-client-at-a-time.

## v0.2.1 RAW PAGE

Patch after FINAL CORE:

- Replaced the AI/SaaS-style landing page with a raw system page.
- Removed gradient card styling and replaced it with a minimal terminal-like page.

## v0.2.0 FINAL CORE

This milestone promotes DEADWIRE HTTPD from proof-of-life to a showable cross-platform core.

### Added

- Native Windows x86-64 assembly backend using WinSock2 and Kernel32.
- Linux x86-64 assembly backend using raw Linux syscalls.
- MIME response selection for `.html`, `.htm`, `.txt`, `.css`, `.js`, and `.svg`.
- Real browser rendering for `/` through `text/html; charset=utf-8`.
- Final landing page under `public/index.html`.
- Stylesheet fixture under `public/style.css`.
- Windows PowerShell verification for status codes, body checks, and MIME headers.
- Linux shell verification for status codes, body checks, and MIME headers.
- GitHub Actions matrix for Linux and Windows verification.

### Hardened

- Path traversal rejection remains fail-closed.
- Raw `%` paths are rejected until percent-decoding is implemented intentionally.
- Fixed request buffer and file buffer limits remain explicit.
- Responses always include `Connection: close`, `Content-Type`, and `Content-Length`.

### Known limits

- Fixed bind address: `127.0.0.1`.
- Fixed port: `18080`.
- Blocking single-client-at-a-time accept loop.
- HTTP/1.0 response style.
- No TLS, keep-alive, chunked encoding, directory listing, or percent-decoding yet.

## v0.1.0

Initial proof-of-life server:

- Windows native backend validated locally by DEADBYTE.
- Linux syscall backend added.
- `/health`, `/hello.txt`, `/`, `405`, `403`, and `404` smoke checks.
