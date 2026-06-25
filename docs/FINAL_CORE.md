# DEADWIRE HTTPD v0.2.0 FINAL CORE

This document freezes what `FINAL CORE` means for this repo.

DEADWIRE is not claiming to be a complete production web server. It is a small native HTTP core with explicit platform ownership.

## Freeze criteria

A build is considered FINAL CORE when all of this is true:

- Windows builds `build/deadwire.exe` from `src/deadwire_windows.s`.
- Linux builds `build/deadwire` from `src/deadwire.s`.
- `/health` returns `200` with `deadwire: ok`.
- `/` serves `public/index.html` as `text/html; charset=utf-8`.
- `/hello.txt` serves text as `text/plain; charset=utf-8`.
- `/style.css` serves CSS as `text/css; charset=utf-8`.
- unsupported methods return `405`.
- traversal attempts return `403`.
- missing files return `404`.
- every response closes the connection intentionally.

## Non-goals

- TLS.
- HTTP/2.
- async runtime.
- general-purpose CGI or app hosting.
- automatic directory listing.
- hidden filesystem behavior.
- pretending Windows and Linux have the same system boundary.

## Engineering principle

The server is allowed to be small, but it is not allowed to be vague. Every platform call path must be visible in the source.
