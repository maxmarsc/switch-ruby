# ─────────────────────────────────────────────────────────────────────────────
# Nintendo Switch NRO — single C++ source, pkg-config ruby integration
# ─────────────────────────────────────────────────────────────────────────────
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
  $(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

# Provides: CC, CXX, PORTLIBS, LIBNX, and adds devkitPro tools to PATH
include $(DEVKITPRO)/libnx/switch_rules

# ── Project ───────────────────────────────────────────────────────────────────
TARGET      := ruby_app
BUILD_DIR   := build
SOURCE      := common/main.cpp
ROMFS_SRC   := common/romfs
ROMFS_BUILD := $(BUILD_DIR)/romfs

APP_TITLE   := My Ruby App
APP_AUTHOR  := Author
APP_VERSION := 0.1.0

# ── pkg-config ────────────────────────────────────────────────────────────────
# switch_rules sets PKG_CONFIG_PATH — explicit here for clarity
export PKG_CONFIG_PATH := $(PORTLIBS)/lib/pkgconfig

RUBY_VERSION    := $(shell pkg-config --variable=ruby_version ruby)
RUBY_STDLIB_SRC := $(shell pkg-config --variable=rubylibdir  ruby)
RUBY_CFLAGS     := $(shell pkg-config --cflags ruby)
RUBY_LIBS       := $(shell pkg-config --libs   ruby)

# ── Flags ─────────────────────────────────────────────────────────────────────
ARCH := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE

# String literal macros: outer single-quotes are consumed by the shell,
# inner double-quotes become the C string delimiters the compiler sees.
DEFINES := \
  -D__SWITCH__ \
  -DRUBY_TMP_DIR='"sdmc:/switch/.tmp_ruby"' \
  -DRUBY_STDLIB_DIR='"romfs:/ruby/$(RUBY_VERSION)"' \
  -DRUBY_MAIN_APP='"romfs:/ruby/app/main.rb"'

CXXFLAGS := $(ARCH) -Wall -O2 -ffunction-sections -fno-rtti -fno-exceptions \
            $(DEFINES) $(RUBY_CFLAGS) \
            -I$(LIBNX)/include -I$(PORTLIBS)/include

LDFLAGS := -specs=$(DEVKITPRO)/libnx/switch.specs $(ARCH) \
           -Wl,-Map,$(BUILD_DIR)/$(TARGET).map \
           -Wl,--gc-sections \
           -L$(PORTLIBS)/lib -L$(LIBNX)/lib

# ── Tools ─────────────────────────────────────────────────────────────────────
# Full paths rather than relying on PATH — explicit and hermetic
ELF2NRO  := $(DEVKITPRO)/tools/bin/elf2nro
NACPTOOL := $(DEVKITPRO)/tools/bin/nacptool

# ── Artifacts ─────────────────────────────────────────────────────────────────
OBJ  := $(BUILD_DIR)/main.o
ELF  := $(BUILD_DIR)/$(TARGET).elf
NACP := $(BUILD_DIR)/$(TARGET).nacp
NRO  := $(BUILD_DIR)/$(TARGET).nro

# ── romfs stamps ──────────────────────────────────────────────────────────────
STAMP_ROMFS  := $(BUILD_DIR)/.stamp_romfs
STAMP_STDLIB := $(BUILD_DIR)/.stamp_stdlib

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: all clean
.FORCE:  # empty target — any rule depending on this always runs

all: $(NRO)

# ── Directory ─────────────────────────────────────────────────────────────────
$(BUILD_DIR):
	@mkdir -p $@

# ── Compilation ───────────────────────────────────────────────────────────────
# -MMD -MF: generate a .d dependency file alongside the .o so header changes
# trigger recompilation. The -include below loads it if it exists.
$(BUILD_DIR)/%.o: common/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -MMD -MF $(@:.o=.d) -c $< -o $@

-include $(BUILD_DIR)/main.d

# ── Link ──────────────────────────────────────────────────────────────────────
$(ELF): $(OBJ)
	$(CXX) $(LDFLAGS) $< $(RUBY_LIBS) -o $@

# ── NACP ──────────────────────────────────────────────────────────────────────
$(NACP): | $(BUILD_DIR)
	$(NACPTOOL) --create "$(APP_TITLE)" "$(APP_AUTHOR)" "$(APP_VERSION)" $@

# ── romfs: project sources ────────────────────────────────────────────────────
# Always re-runs via .FORCE — fast and avoids stale content
$(STAMP_ROMFS): .FORCE | $(BUILD_DIR)
	@rm -rf $(ROMFS_BUILD)
	@cp -r $(ROMFS_SRC)/. $(ROMFS_BUILD)/
	@touch $@

# ── romfs: Ruby stdlib ────────────────────────────────────────────────────────
$(STAMP_STDLIB): .FORCE | $(BUILD_DIR)
	@mkdir -p $(ROMFS_BUILD)/ruby/$(RUBY_VERSION)
	@cp -r $(RUBY_STDLIB_SRC)/. $(ROMFS_BUILD)/ruby/$(RUBY_VERSION)/
	@touch $@

# ── NRO ───────────────────────────────────────────────────────────────────────
$(NRO): $(ELF) $(NACP) $(STAMP_ROMFS) $(STAMP_STDLIB)
	$(ELF2NRO) $(ELF) $@ --nacp=$(NACP) --romfsdir=$(ROMFS_BUILD)

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)