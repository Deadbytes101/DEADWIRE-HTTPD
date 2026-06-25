# Changelog

## v0.1.0

Initial native assembly HTTP server.

### Added

- Windows x86-64 backend using WinSock2 + Kernel32.
- Linux x86-64 backend using raw syscalls.
- Static file serving from `public/`.
- `/health`, `/`, `/hello.txt`, and `/style.css` verification.
- MIME headers for common static file types.
- Method rejection, path guard, missing-file response, and access log lines.
- GitHub Actions matrix for Linux and Windows verification.

### Current limits

- Fixed port: `18080`.
- Fixed bind address: `127.0.0.1`.
- Blocking single-client-at-a-time accept loop.
- HTTP/1.0 response style.
- No TLS, keep-alive, chunked encoding, directory listing, or percent-decoding.

## Next

```txt
v0.2.0  configurable port
v0.3.0  configurable bind address
v0.4.0  structured access log
v1.0.0  stable static-file core
```
