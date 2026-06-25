# DEADWIRE HTTPD v0.1.0 INITIAL NATIVE CORE

This document defines the public `v0.1.0` baseline after the repository history cleanup.

DEADWIRE is not claiming to be a complete production web server. It is a small native HTTP core with explicit platform ownership.

## Baseline criteria

A build is considered the initial native core when all of this is true:

- Windows builds `build/deadwire.exe` from `src/deadwire_windows.s`.
- Linux builds `build/deadwire` from `src/deadwire.s`.
- `/health` returns `200` with `deadwire: ok`.
- `/` serves `public/index.html` as `text/html; charset=utf-8`.
- `/hello.txt` serves text as `text/plain; charset=utf-8`.
- `/style.css` serves CSS as `text/css; charset=utf-8`.
- Unsupported methods return `405`.
- Traversal attempts return `403`.
- Missing files return `404`.
- Every response closes the connection intentionally.
- Access log lines are emitted for the checked request classes.

## Non-goals

- TLS.
- HTTP/2.
- Async runtime.
- General-purpose CGI or app hosting.
- Automatic directory listing.
- Hidden filesystem behavior.
- Pretending Windows and Linux have the same system boundary.

## Engineering principle

The server is allowed to be small, but it is not allowed to hide what it is doing. Platform boundaries stay visible.
