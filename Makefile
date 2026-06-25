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
VERIFY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
VERIFY_PORT_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-port.ps1 -Port 19090
VERIFY_BIND_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-bind.ps1 -Port 19091 -Bind 127.0.0.1
VERIFY_ANY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-bind.ps1 -Port 19092 -Bind 0.0.0.0
VERIFY_BADARG_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-badarg.ps1
VERIFY_PREFLIGHT_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify-preflight.ps1
else
UNAME_S := $(shell uname -s 2>/dev/null || echo unknown)
ifeq ($(UNAME_S),Linux)
PLATFORM := linux
TARGET := build/deadwire
OBJ := build/deadwire_linux.o
SRC := src/deadwire.s
LINK_CMD = $(LD) -o $(TARGET) $(OBJ)
VERIFY_CMD = sh scripts/verify.sh
VERIFY_PORT_CMD = true
VERIFY_BIND_CMD = true
VERIFY_ANY_CMD = true
VERIFY_BADARG_CMD = true
VERIFY_PREFLIGHT_CMD = true
else ifeq ($(UNAME_S),Darwin)
PLATFORM := darwin
TARGET := build/deadwire
SRC := src/deadwire_darwin.c
CC ?= cc
LINK_CMD = $(CC) -std=c99 -Wall -Wextra -O2 -o $(TARGET) $(SRC)
VERIFY_CMD = sh scripts/verify.sh
VERIFY_PORT_CMD = sh scripts/verify-posix-port.sh 19090
VERIFY_BIND_CMD = sh scripts/verify-posix-port.sh 19091 127.0.0.1
VERIFY_ANY_CMD = sh scripts/verify-posix-port.sh 19092 0.0.0.0
VERIFY_BADARG_CMD = sh scripts/verify-posix-badarg.sh
VERIFY_PREFLIGHT_CMD = true
else
$(error unsupported platform: $(UNAME_S). DEADWIRE currently supports Windows_NT, Linux, and Darwin)
endif
endif

AS := as
LD := ld
BUILD_DIR := build

.PHONY: all run verify clean doctor platform

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
$(SRC): $(SRC_INPUT) scripts/gen-win-port.ps1 | $(BUILD_DIR)
	$(GEN_WIN_CMD)
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
	$(VERIFY_PORT_CMD)
	$(VERIFY_BIND_CMD)
	$(VERIFY_ANY_CMD)
	$(VERIFY_BADARG_CMD)
	$(VERIFY_PREFLIGHT_CMD)

clean:
ifeq ($(PLATFORM),windows)
	$(POWERSHELL) -NoProfile -Command "if (Test-Path build) { Remove-Item build -Recurse -Force }"
else
	rm -rf $(BUILD_DIR)
endif
