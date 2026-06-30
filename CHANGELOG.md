# Changelog

This file tracks DEADWIRE HTTPD milestones. The older changelog stopped at the v0.1.0 baseline even though the repository has already advanced to the v1.3 line and now points toward V2 native-runtime work.

## Unreleased

V2 native runtime foundation.

### Added

- Fixed V2 lane-shape verifier for the opt-in runtime path.
- V2 mode probe, handle probe, run-lanes probe, and final build/run gate are now chained through `make verify-triple-thread`.
- Opt-in V2 runtime build path now reaches `build/deadwire_v2_runtime.exe` from the triple-thread verification chain.
- V2 boot context now aligns with the current fixed-lane shape.

### Planned

- Split the server runtime boundary from platform backend details.
- Define assembly-call ABI boundaries for startup, sockets, request parsing, file I/O, response writing, and shutdown.
- Add a verification gate for the runtime/backend split before changing HTTP behavior.
- Preserve V1.3.0 default behavior while V2 scaffolding is introduced.
- Keep moving the opt-in V2 runtime toward supervisor + acceptor + HTTP engine topology.

### Guardrails

- No concurrency, scalability, or speed claim without benchmark evidence.
- The V2 lane target is fixed topology, not thread-per-connection and not a generic worker-pool claim.
- No TLS, CGI, third-party HTTP parser, async framework, or public internet hardening claim in this track.
- Keep the default binary safe and close-after-response unless an opt-in build flavor is explicitly selected.

## v1.3.0

Stable opt-in keep-alive build flavor and native benchmark evidence.

### Added

- Stable Windows keep-alive build flavor: `build/deadwire_keepalive.exe`.
- Dedicated keep-alive verification target.
- Same-session native benchmark comparison between quiet close-after-response mode and keep-alive mode.
- Guardrail probe proving the default binary remains close-after-response.
- V2 native runtime parity roadmap.

### Notes

- Keep-alive is a connection-reuse win, not a concurrency feature.
- The default binary remains the close-after-response server.
- V2 work starts after this release by introducing a runtime boundary without changing behavior.

## v1.2.x

Native benchmark and quiet-server measurement track.

### Added

- Native benchmark harness targets for health, missing-file, static-file, and index routes.
- Quiet access-log-off benchmark build flavor for cleaner server-side measurement.
- Longer request-count benchmark paths for steadier local measurements.
- Cost-focused route benchmarks for `/health`, `/missing-bench.txt`, `/hello.txt`, and `/`.

### Guardrails

- Benchmark output is documentation evidence, not marketing proof.
- Same-session comparisons are preferred when comparing server modes.

## v1.1.0

Core hardening milestone.

### Added

- Request parser generation hardening.
- Parser verification wiring.
- Response correctness verification.
- Windows path hardening verification.
- Hardening fixes for trailing-dot and path-edge behavior.

## v1.0.0

Stable static-file core.

### Added

- Static-file server behavior promoted beyond early v0.x scaffolding.
- `GET` and `HEAD` behavior in the documented product scope.
- Explicit public root: `public/`.
- Default bind remains safe: `127.0.0.1:18080`.
- Blocking single-threaded server path remains the default architecture.

## v0.4.x - v0.9.x

Verification and platform-surface expansion.

### Added

- Structured verification scripts for parser, response, Windows path behavior, generated I/O, request handling, preflight checks, quiet builds, and bad arguments.
- Platform build surface for Windows, Linux, and Darwin/macOS.
- Make targets for build, doctor, verify, run, and benchmark workflows.

## v0.3.0

Configurable bind address milestone.

### Added

- Optional bind address argument.
- Supported bind forms: `127.0.0.1` and `0.0.0.0`.
- Verification for localhost bind and any-address bind behavior.

### Rules

- Default bind remains `127.0.0.1`.
- `0.0.0.0` is explicit opt-in behavior.

## v0.2.0

Configurable port milestone.

### Added

- Optional Windows command-line port argument.
- Default port remains `18080`.
- `deadwire.exe 19090` binds `127.0.0.1:19090`.
- Invalid port exits before server setup.
- Verification for default and custom port paths.

### Rules

- Valid port range: `1..65535`.
- Bind address defaults to `127.0.0.1`.

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

### Initial limits

- Fixed port: `18080`.
- Fixed bind address: `127.0.0.1`.
- Blocking single-client-at-a-time accept loop.
- HTTP/1.0 response style.
- No TLS, keep-alive, chunked encoding, directory listing, or percent-decoding.
