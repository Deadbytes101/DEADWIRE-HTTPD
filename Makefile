ifeq ($(OS),Windows_NT)
PLATFORM := windows
TARGET := build/deadwire.exe
OBJ := build/deadwire_windows.o
SRC := build/deadwire_windows_port.s
SRC_INPUT := src/deadwire_windows.s
CC ?= gcc
POWERSHELL ?= powershell.exe
LINK_CMD = $(CC) -nostdlib -Wl,-e,mainCRTStartup -Wl,--subsystem,console -o $(TARGET) $(OBJ) -lws2_32 -lkernel32
GEN_WIN_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/gen-win-port.ps1
HARDEN_WIN_PATH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/harden-win-path.ps1
HARDEN_WIN_IO_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/harden-win-io.ps1
HARDEN_WIN_REQUEST_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/harden-win-request.ps1
VERIFY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
VERIFY_PARSER_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-parser.ps1
VERIFY_RESPONSE_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-response.ps1
VERIFY_WINPATH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-winpath.ps1
VERIFY_IO_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-io.ps1
VERIFY_GENERATED_IO_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-generated-io.ps1
VERIFY_GENERATED_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-generated-static.ps1
VERIFY_REQUEST_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-request.ps1
VERIFY_PORT_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-port.ps1 -Port 19090
VERIFY_BIND_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-bind.ps1 -Port 19091 -Bind 127.0.0.1
VERIFY_ANY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-bind.ps1 -Port 19092 -Bind 0.0.0.0
VERIFY_BADARG_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-badarg.ps1
VERIFY_PREFLIGHT_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-preflight.ps1
VERIFY_QUIET_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-quiet.ps1 -Port 19093
VERIFY_KEEPALIVE_EXPERIMENTAL_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-keepalive-experimental.ps1 -PortBase 19860
VERIFY_KEEPALIVE_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-keepalive.ps1 -PortBase 19870
VERIFY_RUNTIME_BOUNDARY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-runtime-boundary.ps1
VERIFY_TRIPLE_THREAD_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2modeprobe.ps1
VERIFY_V2_REQUEST_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-v2requestprobe.ps1
PROBE_KEEPALIVE_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/probe-keepalive.ps1 -Port 19820 -Path /health
BENCH_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19100 -Requests 256 -Path /health
BENCH_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19101 -Requests 256 -Path /
BENCH_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19102 -Requests 256 -Path /hello.txt
BENCH_LONG_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19110 -Requests 1024 -Path /health -Rounds 5
BENCH_LONG_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19111 -Requests 1024 -Path / -Rounds 5
BENCH_LONG_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19112 -Requests 1024 -Path /hello.txt -Rounds 5
BENCH_COST_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19120 -Requests 1024 -Path /health -Rounds 5
BENCH_COST_MISSING_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19121 -Requests 1024 -Path /missing-bench.txt -Rounds 5
BENCH_COST_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19122 -Requests 1024 -Path /hello.txt -Rounds 5
BENCH_COST_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-smoke.ps1 -Port 19123 -Requests 1024 -Path / -Rounds 5
BENCH_NATIVE_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19220 -Requests 1024 -Path /health -Rounds 5
BENCH_NATIVE_MISSING_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19221 -Requests 1024 -Path /missing-bench.txt -Rounds 5
BENCH_NATIVE_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19222 -Requests 1024 -Path /hello.txt -Rounds 5
BENCH_NATIVE_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19223 -Requests 1024 -Path / -Rounds 5
BENCH_NATIVE_LONG_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19320 -Requests 4096 -Path /health -Rounds 5
BENCH_NATIVE_LONG_MISSING_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19321 -Requests 4096 -Path /missing-bench.txt -Rounds 5
BENCH_NATIVE_LONG_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19322 -Requests 4096 -Path /hello.txt -Rounds 5
BENCH_NATIVE_LONG_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -Port 19323 -Requests 4096 -Path / -Rounds 5
BENCH_NATIVE_XL_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native-xl.ps1 -Requests 16384 -Rounds 5
BENCH_NATIVE_XXL_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native-xl.ps1 -Requests 32768 -Rounds 5
BENCH_NATIVE_LIFECYCLE_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native-lifecycle.ps1 -Requests 16384 -Rounds 5
BENCH_NATIVE_NOLOG_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native-nolog.ps1 -Requests 32768 -Rounds 5
BUILD_QUIET_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build-win-accesslog-off.ps1
BENCH_NATIVE_QUIET_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native-quiet.ps1 -Requests 32768 -Rounds 5
BUILD_KEEPALIVE_EXPERIMENTAL_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build-win-keepalive-experimental.ps1
BUILD_KEEPALIVE_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build-win-keepalive.ps1
BUILD_V2_RUNTIME_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build-v2-runtime.ps1
BENCH_V2_RUNTIME_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-v2-runtime.ps1 -Requests 262144 -Rounds 5
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive_experimental.exe -Port 19850 -Requests 32768 -Path /health -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive_experimental.exe -Port 19851 -Requests 32768 -Path /hello.txt -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_MISSING_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive_experimental.exe -Port 19852 -Requests 32768 -Path /missing-bench.txt -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive_experimental.exe -Port 19853 -Requests 32768 -Path / -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_HEALTH_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive.exe -Port 19880 -Requests 32768 -Path /health -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_STATIC_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive.exe -Port 19881 -Requests 32768 -Path /hello.txt -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_MISSING_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive.exe -Port 19882 -Requests 32768 -Path /missing-bench.txt -Rounds 5 -KeepAlive
BENCH_NATIVE_KEEPALIVE_INDEX_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/bench-native.ps1 -ServerExePath build/deadwire_keepalive.exe -Port 19883 -Requests 32768 -Path / -Rounds 5 -KeepAlive
else
UNAME_S := $(shell uname -s 2>/dev/null || echo unknown)
ifeq ($(UNAME_S),Linux)
PLATFORM := linux
TARGET := build/deadwire
OBJ := build/deadwire_linux.o
SRC := src/deadwire.s
LINK_CMD = $(LD) -o $(TARGET) $(OBJ)
VERIFY_CMD = sh scripts/verify.sh
VERIFY_PARSER_CMD = true
VERIFY_RESPONSE_CMD = true
VERIFY_WINPATH_CMD = true
VERIFY_IO_CMD = true
VERIFY_GENERATED_IO_CMD = true
VERIFY_GENERATED_STATIC_CMD = true
VERIFY_REQUEST_CMD = true
VERIFY_PORT_CMD = true
VERIFY_BIND_CMD = true
VERIFY_ANY_CMD = true
VERIFY_BADARG_CMD = true
VERIFY_PREFLIGHT_CMD = true
VERIFY_QUIET_CMD = true
VERIFY_KEEPALIVE_EXPERIMENTAL_CMD = true
VERIFY_KEEPALIVE_CMD = true
VERIFY_RUNTIME_BOUNDARY_CMD = true
VERIFY_TRIPLE_THREAD_CMD = true
VERIFY_V2_REQUEST_CMD = true
PROBE_KEEPALIVE_CMD = true
BENCH_HEALTH_CMD = true
BENCH_INDEX_CMD = true
BENCH_STATIC_CMD = true
BENCH_LONG_HEALTH_CMD = true
BENCH_LONG_INDEX_CMD = true
BENCH_LONG_STATIC_CMD = true
BENCH_COST_HEALTH_CMD = true
BENCH_COST_MISSING_CMD = true
BENCH_COST_STATIC_CMD = true
BENCH_COST_INDEX_CMD = true
BENCH_NATIVE_HEALTH_CMD = true
BENCH_NATIVE_MISSING_CMD = true
BENCH_NATIVE_STATIC_CMD = true
BENCH_NATIVE_INDEX_CMD = true
BENCH_NATIVE_LONG_HEALTH_CMD = true
BENCH_NATIVE_LONG_MISSING_CMD = true
BENCH_NATIVE_LONG_STATIC_CMD = true
BENCH_NATIVE_LONG_INDEX_CMD = true
BENCH_NATIVE_XL_CMD = true
BENCH_NATIVE_XXL_CMD = true
BENCH_NATIVE_LIFECYCLE_CMD = true
BENCH_NATIVE_NOLOG_CMD = true
BUILD_QUIET_CMD = true
BENCH_NATIVE_QUIET_CMD = true
BUILD_KEEPALIVE_EXPERIMENTAL_CMD = true
BUILD_KEEPALIVE_CMD = true
BUILD_V2_RUNTIME_CMD = true
BENCH_V2_RUNTIME_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_HEALTH_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_STATIC_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_MISSING_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_INDEX_CMD = true
BENCH_NATIVE_KEEPALIVE_HEALTH_CMD = true
BENCH_NATIVE_KEEPALIVE_STATIC_CMD = true
BENCH_NATIVE_KEEPALIVE_MISSING_CMD = true
BENCH_NATIVE_KEEPALIVE_INDEX_CMD = true
else ifeq ($(UNAME_S),Darwin)
PLATFORM := darwin
TARGET := build/deadwire
SRC := src/deadwire_darwin.c
CC ?= cc
LINK_CMD = $(CC) -std=c99 -Wall -Wextra -O2 -o $(TARGET) $(SRC)
VERIFY_CMD = sh scripts/verify.sh
VERIFY_PARSER_CMD = true
VERIFY_RESPONSE_CMD = true
VERIFY_WINPATH_CMD = true
VERIFY_IO_CMD = true
VERIFY_GENERATED_IO_CMD = true
VERIFY_GENERATED_STATIC_CMD = true
VERIFY_REQUEST_CMD = true
VERIFY_PORT_CMD = true
VERIFY_BIND_CMD = true
VERIFY_ANY_CMD = true
VERIFY_BADARG_CMD = true
VERIFY_PREFLIGHT_CMD = true
VERIFY_QUIET_CMD = true
VERIFY_KEEPALIVE_EXPERIMENTAL_CMD = true
VERIFY_KEEPALIVE_CMD = true
VERIFY_RUNTIME_BOUNDARY_CMD = true
VERIFY_TRIPLE_THREAD_CMD = true
VERIFY_V2_REQUEST_CMD = true
PROBE_KEEPALIVE_CMD = true
BENCH_HEALTH_CMD = true
BENCH_INDEX_CMD = true
BENCH_STATIC_CMD = true
BENCH_LONG_HEALTH_CMD = true
BENCH_LONG_INDEX_CMD = true
BENCH_LONG_STATIC_CMD = true
BENCH_COST_HEALTH_CMD = true
BENCH_COST_MISSING_CMD = true
BENCH_COST_STATIC_CMD = true
BENCH_COST_INDEX_CMD = true
BENCH_NATIVE_HEALTH_CMD = true
BENCH_NATIVE_MISSING_CMD = true
BENCH_NATIVE_STATIC_CMD = true
BENCH_NATIVE_INDEX_CMD = true
BENCH_NATIVE_LONG_HEALTH_CMD = true
BENCH_NATIVE_LONG_MISSING_CMD = true
BENCH_NATIVE_LONG_STATIC_CMD = true
BENCH_NATIVE_LONG_INDEX_CMD = true
BENCH_NATIVE_XL_CMD = true
BENCH_NATIVE_XXL_CMD = true
BENCH_NATIVE_LIFECYCLE_CMD = true
BENCH_NATIVE_NOLOG_CMD = true
BUILD_QUIET_CMD = true
BENCH_NATIVE_QUIET_CMD = true
BUILD_KEEPALIVE_EXPERIMENTAL_CMD = true
BUILD_KEEPALIVE_CMD = true
BUILD_V2_RUNTIME_CMD = true
BENCH_V2_RUNTIME_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_HEALTH_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_STATIC_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_MISSING_CMD = true
BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_INDEX_CMD = true
BENCH_NATIVE_KEEPALIVE_HEALTH_CMD = true
BENCH_NATIVE_KEEPALIVE_STATIC_CMD = true
BENCH_NATIVE_KEEPALIVE_MISSING_CMD = true
BENCH_NATIVE_KEEPALIVE_INDEX_CMD = true
else
$(error unsupported platform: $(UNAME_S). DEADWIRE currently supports Windows_NT, Linux, and Darwin)
endif
endif

AS := as
LD := ld
BUILD_DIR := build

.PHONY: all run verify verify-runtime-boundary verify-triple-thread verify-quiet verify-keepalive-experimental verify-keepalive probe-keepalive bench bench-long bench-cost bench-native bench-native-long bench-native-xl bench-native-xxl bench-native-lifecycle bench-native-nolog build-quiet bench-native-quiet build-keepalive-experimental build-keepalive build-v2-runtime bench-v2-runtime bench-native-keepalive-experimental bench-native-keepalive clean doctor platform

all: $(TARGET)

platform:
	@echo "platform: $(PLATFORM)"
	@echo "target: $(TARGET)"

doctor:
	@echo "platform: $(PLATFORM)"
ifeq ($(PLATFORM),windows)
	@command -v $(AS) >/dev/null || { echo "missing: $(AS)" >&2; exit 1; }
	@command -v $(CC) >/dev/null || { echo "missing: $(CC)" >&2; exit 1; }
	@command -v $(POWERSHELL) >/dev/null || { echo "missing: $(POWERSHELL)" >&2; exit 1; }
else ifeq ($(PLATFORM),linux)
	@command -v $(AS) >/dev/null || { echo "missing: $(AS)" >&2; exit 1; }
	@command -v $(LD) >/dev/null || { echo "missing: $(LD)" >&2; exit 1; }
	@command -v curl >/dev/null || { echo "missing: curl" >&2; exit 1; }
else ifeq ($(PLATFORM),darwin)
	@command -v $(CC) >/dev/null || { echo "missing: $(CC)" >&2; exit 1; }
	@command -v curl >/dev/null || { echo "missing: curl" >&2; exit 1; }
endif
	@echo "doctor: ok"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

ifeq ($(PLATFORM),windows)
$(SRC): $(SRC_INPUT) scripts/gen-win-port.ps1 scripts/harden-win-path.ps1 scripts/harden-win-io.ps1 scripts/harden-win-request.ps1 | $(BUILD_DIR)
	$(GEN_WIN_CMD)
	$(HARDEN_WIN_PATH_CMD)
	$(HARDEN_WIN_IO_CMD)
	$(HARDEN_WIN_REQUEST_CMD)
endif

ifeq ($(PLATFORM),darwin)
$(TARGET): $(SRC) | $(BUILD_DIR)
	$(LINK_CMD)
else
$(OBJ): $(SRC) | $(BUILD_DIR)
	$(AS) --64 -o $(OBJ) $(SRC)

$(TARGET): $(OBJ)
	$(LINK_CMD)
endif

run: all
	$(TARGET)

verify: all
	$(VERIFY_CMD)
	$(VERIFY_PARSER_CMD)
	$(VERIFY_RESPONSE_CMD)
	$(VERIFY_WINPATH_CMD)
	$(VERIFY_IO_CMD)
	$(VERIFY_GENERATED_IO_CMD)
	$(VERIFY_GENERATED_STATIC_CMD)
	$(VERIFY_REQUEST_CMD)
	$(VERIFY_PORT_CMD)
	$(VERIFY_BIND_CMD)
	$(VERIFY_ANY_CMD)
	$(VERIFY_BADARG_CMD)
	$(VERIFY_PREFLIGHT_CMD)

verify-runtime-boundary:
	$(VERIFY_RUNTIME_BOUNDARY_CMD)

verify-triple-thread:
	$(VERIFY_TRIPLE_THREAD_CMD)
	$(VERIFY_V2_REQUEST_CMD)

verify-quiet: all
	$(VERIFY_QUIET_CMD)

verify-keepalive-experimental: all
	$(VERIFY_KEEPALIVE_EXPERIMENTAL_CMD)

verify-keepalive: all
	$(VERIFY_KEEPALIVE_CMD)

probe-keepalive: all
	$(PROBE_KEEPALIVE_CMD)

bench: all
	$(BENCH_HEALTH_CMD)
	$(BENCH_INDEX_CMD)
	$(BENCH_STATIC_CMD)

bench-long: all
	$(BENCH_LONG_HEALTH_CMD)
	$(BENCH_LONG_INDEX_CMD)
	$(BENCH_LONG_STATIC_CMD)

bench-cost: all
	$(BENCH_COST_HEALTH_CMD)
	$(BENCH_COST_MISSING_CMD)
	$(BENCH_COST_STATIC_CMD)
	$(BENCH_COST_INDEX_CMD)

bench-native: all
	$(BENCH_NATIVE_HEALTH_CMD)
	$(BENCH_NATIVE_MISSING_CMD)
	$(BENCH_NATIVE_STATIC_CMD)
	$(BENCH_NATIVE_INDEX_CMD)

bench-native-long: all
	$(BENCH_NATIVE_LONG_HEALTH_CMD)
	$(BENCH_NATIVE_LONG_MISSING_CMD)
	$(BENCH_NATIVE_LONG_STATIC_CMD)
	$(BENCH_NATIVE_LONG_INDEX_CMD)

bench-native-xl: all
	$(BENCH_NATIVE_XL_CMD)

bench-native-xxl: all
	$(BENCH_NATIVE_XXL_CMD)

bench-native-lifecycle: all
	$(BENCH_NATIVE_LIFECYCLE_CMD)

bench-native-nolog: all
	$(BENCH_NATIVE_NOLOG_CMD)

build-quiet: all
	$(BUILD_QUIET_CMD)

bench-native-quiet: all
	$(BENCH_NATIVE_QUIET_CMD)

build-keepalive-experimental: all
	$(BUILD_KEEPALIVE_EXPERIMENTAL_CMD)

build-keepalive: all
	$(BUILD_KEEPALIVE_CMD)

build-v2-runtime:
	$(BUILD_V2_RUNTIME_CMD)

bench-v2-runtime: build-v2-runtime
	$(BENCH_V2_RUNTIME_CMD)

bench-native-keepalive-experimental: build-keepalive-experimental
	$(BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_HEALTH_CMD)
	$(BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_STATIC_CMD)
	$(BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_MISSING_CMD)
	$(BENCH_NATIVE_KEEPALIVE_EXPERIMENTAL_INDEX_CMD)

bench-native-keepalive: build-keepalive
	$(BENCH_NATIVE_KEEPALIVE_HEALTH_CMD)
	$(BENCH_NATIVE_KEEPALIVE_STATIC_CMD)
	$(BENCH_NATIVE_KEEPALIVE_MISSING_CMD)
	$(BENCH_NATIVE_KEEPALIVE_INDEX_CMD)

clean:
ifeq ($(PLATFORM),windows)
	$(POWERSHELL) -NoProfile -Command "if (Test-Path build) { Remove-Item build -Recurse -Force }"
else
	rm -rf $(BUILD_DIR)
endif
