# test-switch/Makefile — Build a Switch NRO that runs Ruby bootstrap tests

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

# Default to release if not specified
BUILD ?= release
ROMFS_DIR := romfs

ifeq ($(BUILD),debug)
    # Append debug flags
    OPT_FLAGS += -g -O0 -DWAIT_FOR_DEBUGGER
else
    # Append release flags
    OPT_FLAGS += -O2
endif

DEVKITPRO ?= /opt/devkitpro
DEVKITA64  = $(DEVKITPRO)/devkitA64
LIBNX      = $(DEVKITPRO)/libnx
PORTLIBS   = $(DEVKITPRO)/portlibs/switch

PREFIX     = $(DEVKITA64)/bin/aarch64-none-elf-

CC         = $(PREFIX)gcc
OBJCOPY    = $(PREFIX)objcopy
NM_TOOL    = $(PREFIX)nm

# ── Where Ruby lives ──
RUBY_SRC   = ..
RUBY_BUILD = ../build

# ── Compiler flags (must match what Ruby was built with) ──
ARCH_FLAGS = -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE

CFLAGS     = $(ARCH_FLAGS) $(OPT_FLAGS) -ffunction-sections -fdata-sections \
             -D__SWITCH__ -DSWITCH \
             -I$(RUBY_SRC)/include \
             -I$(RUBY_BUILD)/.ext/include/aarch64-elf \
             -I$(RUBY_BUILD)/.ext/include \
             -I$(RUBY_SRC) \
             -I$(RUBY_BUILD) \
             -I$(LIBNX)/include \
             -I$(PORTLIBS)/include

# ── Link flags ──
# Use --whole-archive for the ext lib so Init_ functions aren't stripped by --gc-sections.
LDFLAGS    = -L$(RUBY_BUILD) \
             -L$(RUBY_BUILD)/enc \
             -L$(LIBNX)/lib \
             -L$(PORTLIBS)/lib \
             -fPIE \
             -specs=$(DEVKITPRO)/libnx/switch.specs \
             -Wl,--gc-sections

# Ruby's static lib + extensions + encodings
RUBY_LIBS  = -lruby-static \
             -Wl,--whole-archive \
             $(wildcard $(RUBY_BUILD)/ext/*/*.a) \
             $(wildcard $(RUBY_BUILD)/ext/*/*/*.a) \
             $(RUBY_BUILD)/enc/libenc.a \
						 $(RUBY_BUILD)/enc/libtrans.a \
             -Wl,--no-whole-archive

SYS_LIBS   = -lnx -lm -lz

# ── Targets ──
TARGET     = test_runner_switch
ELF        = $(TARGET).elf
NRO        = $(TARGET).nro
NACP       = $(TARGET).nacp

SRCS       = test_runner_switch.c
OBJS       = $(SRCS:.c=.o)

# ── Static init (must override dmyext.o/dmyenc.o in libruby-static.a) ──
EXT_INIT   = $(RUBY_BUILD)/ext/extinit.o
ENC_INIT   = $(RUBY_BUILD)/enc/encinit.o

# ── Generated romfs content ──
ROMFS_GENERATED = $(ROMFS_DIR)/build/rbconfig.rb

.PHONY: all clean nro

all: $(NRO)

nro: $(NRO)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Copy rbconfig.rb into romfs so Ruby can require it at runtime
$(ROMFS_DIR)/build/rbconfig.rb: $(RUBY_BUILD)/rbconfig.rb
	@mkdir -p $(dir $@)
	cp $< $@

$(ELF): $(OBJS) $(EXT_INIT) $(ENC_INIT) $(ROMFS_GENERATED)
	$(CC) $(LDFLAGS) $(OBJS) $(EXT_INIT) $(ENC_INIT) $(RUBY_LIBS) $(SYS_LIBS) -o $@

$(NACP):
	$(DEVKITPRO)/tools/bin/nacptool --create "Ruby Bootstrap Test" "dev" "0.1.0" $@

$(NRO): $(ELF) $(NACP)
	$(DEVKITPRO)/tools/bin/elf2nro $< $@ --nacp=$(NACP) --romfsdir=$(ROMFS_DIR)

clean:
	rm -f $(OBJS) $(ELF) $(NRO) $(NACP)
	rm -rf $(ROMFS_DIR)/build