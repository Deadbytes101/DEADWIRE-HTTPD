ifeq ($(OS),Windows_NT)
PLATFORM := windows
TARGET := build/deadwire.exe
OBJ := build/deadwire_windows.o
SRC := src/deadwire_windows.s
CC ?= gcc
POWERSHELL ?= powershell.exe
LINK_CMD = $(CC) -nostdlib -Wl,-e,mainCRTStartup -Wl,--subsystem,console -o $(TARGET) $(OBJ) -lws2_32 -lkernel32
VERIFY_CMD = $(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
else
UNAME_S := $(shell uname -s 2>/dev/null || echo unknown)
ifeq ($(UNAME_S),Linux)
PLATFORM := linux
TARGET := build/deadwire
OBJ := build/deadwire_linux.o
SRC := src/deadwire.s
LINK_CMD = $(LD) -o $(TARGET) $(OBJ)
VERIFY_CMD = sh scripts/verify.sh
else
$(error unsupported platform: $(UNAME_S). DEADWIRE currently supports Linux x86-64 and Windows x86-64)
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
	@command -v $(AS) >/dev/null || { echo "missing: $(AS)" >&2; exit 1; }
ifeq ($(PLATFORM),windows)
	@command -v $(CC) >/dev/null || { echo "missing: $(CC)" >&2; exit 1; }
	@command -v $(POWERSHELL) >/dev/null || { echo "missing: $(POWERSHELL)" >&2; exit 1; }
else
	@command -v $(LD) >/dev/null || { echo "missing: $(LD)" >&2; exit 1; }
	@command -v curl >/dev/null || { echo "missing: curl" >&2; exit 1; }
endif
	@echo "doctor: ok"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJ): $(SRC) | $(BUILD_DIR)
	$(AS) --64 -o $(OBJ) $(SRC)

$(TARGET): $(OBJ)
	$(LINK_CMD)

run: all
	$(TARGET)

verify: all
	$(VERIFY_CMD)

clean:
	rm -rf $(BUILD_DIR)
