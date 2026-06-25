#!/usr/bin/env sh
set -eu

if ! command -v curl >/dev/null 2>&1; then
  echo "verify: curl is required" >&2
  exit 1
fi

./build/deadwire > build/deadwire.log 2>&1 &
PID=$!
cleanup() {
  kill "$PID" >/dev/null 2>&1 || true
  wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ready=0
i=0
while [ "$i" -lt 50 ]; do
  if curl -fsS http://127.0.0.1:18080/health >/dev/null 2>&1; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 0.1
done

if [ "$ready" -ne 1 ]; then
  echo "verify: server did not become ready" >&2
  cat build/deadwire.log >&2 || true
  exit 1
fi

body=$(curl -fsS http://127.0.0.1:18080/health)
[ "$body" = "deadwire: ok" ]

body=$(curl -fsS http://127.0.0.1:18080/hello.txt)
[ "$body" = "hello from deadwire" ]

headers=$(curl -fsS -D - -o /dev/null http://127.0.0.1:18080/)
printf '%s' "$headers" | grep -iq '^Content-Type: text/html; charset=utf-8'

headers=$(curl -fsS -D - -o /dev/null http://127.0.0.1:18080/hello.txt)
printf '%s' "$headers" | grep -iq '^Content-Type: text/plain; charset=utf-8'

headers=$(curl -fsS -D - -o /dev/null http://127.0.0.1:18080/style.css)
printf '%s' "$headers" | grep -iq '^Content-Type: text/css; charset=utf-8'

status=$(curl -sS -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:18080/)
[ "$status" = "405" ]

status=$(curl --path-as-is -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:18080/../../etc/passwd)
[ "$status" = "403" ]

status=$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:18080/missing.txt)
[ "$status" = "404" ]

echo "verify: ok"
