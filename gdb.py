import os
import gdb
import re
import subprocess
import sys
from pathlib import Path

NX_IP = os.environ.get("NX_IP", None)
DEVKITPRO_BASE = Path(os.environ["DEVKITPRO"])
TARGET_NRO = Path(os.environ["TARGET_NRO"])
TARGET_ELF = TARGET_NRO.with_suffix(".elf")

if not TARGET_NRO.is_file():
    sys.exit(f"Could not find target NRO at {TARGET_NRO}")

if not TARGET_ELF.is_file():
    sys.exit(f"Could not find target ELF at {TARGET_ELF}")

gdb.write(f"Target NRO: {TARGET_NRO}\n")
gdb.write(f"Target ELF: {TARGET_ELF}\n")
gdb.write(f"Switch IP: {NX_IP}\n")

# connect to the switch
if NX_IP is not None:
    gdb.write("Connecting to switch...\n")
    gdb.execute(f"target extended-remote {NX_IP}:22225", to_string=True)

# Get the PID of hblaunch
gdb.write("Finding hbloader process...\n")
pid_list = gdb.execute("info os processes", to_string=True)
pid_pattern = r"^([0-9]+)\s+hbloader\s*$"
matched = re.search(pid_pattern, pid_list, re.MULTILINE)
if matched is None:
    sys.exit("Could not find hbloader process")
pid = matched.group(1)

# Attach
gdb.write(f"Attaching to process with PID {pid}...\n")
gdb.execute(f"attach {pid}")

# Get address base
gdb.write("Finding base address for target...\n")
base_list = gdb.execute("monitor get info", to_string=True)
base_pattern = rf"(0x[0-9a-f]+)\s+-\s+(0x[0-9a-f]+)\s+{TARGET_ELF.name}"
matched = re.search(base_pattern, base_list, re.MULTILINE)
if matched is None:
    sys.exit(f"Could not find base address for target {TARGET_ELF.name}")
base_addr = int(matched.group(1), 16)

# Get offsets
gdb.write("Finding section offsets...\n")
READELF = DEVKITPRO_BASE / "devkitA64" / "bin" / "aarch64-none-elf-readelf"
if not READELF.is_file():
    sys.exit(f"Could not find readelf at {READELF}")
output = subprocess.check_output([READELF, "-S", TARGET_ELF], text=True)
rodata_offset_pattern = r"\.rodata\s+PROGBITS\s+([0-9a-fA-F]+)"
data_offset_pattern = r"\.data\s+PROGBITS\s+([0-9a-fA-F]+)"
bss_offset_pattern = r"\.bss\s+NOBITS\s+([0-9a-fA-F]+)"
rodata_offset = int("0x" + re.search(rodata_offset_pattern,
                    output, re.MULTILINE).group(1), 16)
data_offset = int("0x" + re.search(data_offset_pattern,
                  output, re.MULTILINE).group(1), 16)
bss_offset = int("0x" + re.search(bss_offset_pattern,
                 output, re.MULTILINE).group(1), 16)

# Get gdb_wait address
gdb.write("Finding gdb_wait address...\n")
NM = DEVKITPRO_BASE / "devkitA64" / "bin" / "aarch64-none-elf-nm"
if not NM.is_file():
    sys.exit(f"Could not find nm at {NM}")
output = subprocess.check_output([NM, TARGET_ELF], text=True)
gdb_wait_pattern = rf"([0-9a-f]+)\s+D\s+gdb_wait"
gdb_wait_addr = int("0x" + re.search(gdb_wait_pattern, output).group(1), 16)

# Add symbols
gdb.write("Adding symbols...\n")
gdb.execute(f"add-symbol-file {TARGET_ELF} {hex(base_addr)} "
            f"-s .rodata {hex(base_addr + rodata_offset)} "
            f"-s .data {hex(base_addr + data_offset)} "
            f"-s .bss {hex(base_addr + bss_offset)}")

# Set the flag
gdb.write("Setting gdb_wait flag to 0...\n")
gdb.execute(f"set *(int*){hex(base_addr + gdb_wait_addr)} = 0")
