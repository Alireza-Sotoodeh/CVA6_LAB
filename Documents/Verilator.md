---
author: Alireza Sotodeh
date: 2026-11-10 23:58:00 +03:30
status: MODIFIED FILE
reason: Updated universal guide with tb_cva6_direct testbench, GTKWave waveform support, and status of all CVA6 cloned variants
---

# Universal Guide: Extracting RTL & Building a Standalone Verilator Simulation

This guide provides a **completely generalized, reproducible step-by-step workflow** to extract only the necessary RTL and dependency files from **any RISC-V / CVA6 source repository** (upstream OpenHW, Thales Group, CVA6-Lab, Pulp, etc.) and package them into **any custom destination directory** (e.g. `Verilator/<DEST_NAME>/`) for standalone Verilator simulation.

For cloning a file:
```
git clone --recursive https://github.com/openhwfoundation/cva6.git
```

```
git status
```
Reset
```
# 1. Delete the damaged directory (replace directory name if different) 

rm -rf CVA6_OpenHWGroup 

# 2. Re-clone recursively to fetch the core and all submodules 
git clone --recursive https://github.com/openhwfoundation/cva6.git CVA6_OpenHWGroup cd CVA6_OpenHWGroup
```

---

## 1. Prerequisites & Toolchain Setup

Run once on your Linux machine to install all necessary compilers, simulators, and build tools:

```bash
# 1. Install simulation and build utilities
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    verilator \
    device-tree-compiler \
    help2man \
    python3 \
    libfl-dev \
    zlib1g-dev \
    gtkwave

# 2. Install RISC-V Bare-Metal GCC Cross-Compiler
sudo apt install -y gcc-riscv64-unknown-elf
```

### Install & Configure Bender (IP Dependency Manager)
```bash
# Download Bender if not already installed
curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init | bash

# Ensure Bender is accessible in your PATH
mkdir -p $HOME/bin
ln -sf $HOME/.cargo/bin/bender $HOME/bin/bender
export PATH="$HOME/bin:$PATH"

# Verify installations
verilator --version
riscv64-unknown-elf-gcc --version
bender --version
```

---

## 2. Parameterizing Your Source and Destination

Before running commands, define two environment variables for your workflow:

```bash
# The source repository where Bender.yml and the core RTL reside:
export SRC_REPO="/home/alireza/GitHub/Mahani/CloneFiles/cva6"

# The target standalone folder you want to create:
export DEST_DIR="/home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW"

# The desired processor target (e.g. cv32a6_imac_sv32 or cv64a6_imafdc_sv39):
export TARGET_NAME="cv32a6_imac_sv32"
```

---

## 3. Step 1: Generate the Compilation Filelist with Bender

Inside any Bender-managed repository, Bender resolves dependencies (`common_cells`, `axi`, `fpnew`, `tech_cells_generic`) and produces a topologically sorted list of files and include paths:

```bash
cd "$SRC_REPO"

# Update/fetch all remote dependencies listed in Bender.lock
bender checkout

# Generate the Verilator-specific filelist
bender script verilator -t "$TARGET_NAME" > raw_verilator.f
```

---

## 4. Step 2: Extracting & Isolating RTL to Your Custom Destination

We isolate only the files referenced in `raw_verilator.f` into `$DEST_DIR/rtl/` and generate a portable filelist (`cv32a6_local.f`) where all paths use `${CVA6_ROOT}`.

### Automated Universal Extraction Script (`isolate_cva6_rtl.py`)

Run this universal Python script:

```python
#!/usr/bin/env python3
import os
import sys
import shutil

def isolate_rtl(input_f, dest_dir):
    rtl_dest = os.path.join(dest_dir, "rtl")
    os.makedirs(rtl_dest, exist_ok=True)
    out_f_path = os.path.join(dest_dir, "cv32a6_local.f")

    copied_files = 0
    inc_dirs = set()

    with open(input_f, "r") as infile, open(out_f_path, "w") as outfile:
        for line in infile:
            sline = line.strip()
            if not sline:
                outfile.write("\n")
                continue

            # 1. Preserve defines (+define+TARGET_...)
            if sline.startswith("+define+"):
                outfile.write(f"{sline}\n")
                continue

            # 2. Handle include directories (+incdir+...)
            if sline.startswith("+incdir+"):
                inc_path = sline.replace("+incdir+", "").strip()
                if os.path.isdir(inc_path):
                    # Compute a clean unique subdirectory under include/
                    base_name = os.path.basename(os.path.normpath(inc_path))
                    inc_target = os.path.join(rtl_dest, "include", base_name)
                    os.makedirs(inc_target, exist_ok=True)
                    shutil.copytree(inc_path, inc_target, dirs_exist_ok=True)
                    
                    portable_inc = f"+incdir+${{CVA6_ROOT}}/include/{base_name}"
                    if portable_inc not in inc_dirs:
                        inc_dirs.add(portable_inc)
                        outfile.write(f"{portable_inc}\n")
                continue

            # 3. Handle SystemVerilog / Verilog RTL source files
            file_path = sline.split()[-1] if not sline.startswith("-") else ""
            if file_path and os.path.isfile(file_path):
                # Flatten file into rtl/ preserving unique file names
                filename = os.path.basename(file_path)
                dest_file = os.path.join(rtl_dest, filename)
                shutil.copy2(file_path, dest_file)
                outfile.write(f"${{CVA6_ROOT}}/{filename}\n")
                copied_files += 1
            else:
                outfile.write(f"{sline}\n")

    print(f"[+] Successfully copied {copied_files} source files to: {rtl_dest}")
    print(f"[+] Created portable filelist: {out_f_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 isolate_cva6_rtl.py <input_f_file> <dest_directory>")
        sys.exit(1)
    isolate_rtl(sys.argv[1], sys.argv[2])
```

### Execute the Extraction:
```bash
python3 isolate_cva6_rtl.py "$SRC_REPO/raw_verilator.f" "$DEST_DIR"
```

---

## 5. Step 3: Verilator Compatibility Patch (The `default disable iff` Assertion Fix)

In certain AXI dependency files (`axi_id_remap.sv`), SystemVerilog assertions use `default disable iff (!rst_ni);` outside `ifndef VERILATOR` guards. Because Verilator 5.x does not support this SVA construct, guard it:

```bash
# If axi_id_remap.sv is present in your isolated rtl folder, ensure it is guarded:
if [ -f "$DEST_DIR/rtl/axi_id_remap.sv" ]; then
    sed -i 's/default disable iff (!rst_ni);/`ifndef VERILATOR\n  default disable iff (!rst_ni);\n`endif/' \
        "$DEST_DIR/rtl/axi_id_remap.sv"
fi
```

---

## 6. Step 4: Add Simulation Harness & Standalone Makefile

Copy the standard top-level AXI wrapper and C++ testbench (`tb_cva6_direct.cpp`) from your reference repository into `$DEST_DIR/tb/`:

```bash
mkdir -p "$DEST_DIR/tb/wrappers"
mkdir -p "$DEST_DIR/tb/cpp"

# Copy proven wrapper and testbench
cp /home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/wrappers/cva6_axi_wrapper.sv \
   "$DEST_DIR/tb/wrappers/"

cp /home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/cpp/tb_cva6_direct.cpp \
   "$DEST_DIR/tb/cpp/"
```

### Standalone Makefile (`$DEST_DIR/Makefile`):
Create this Makefile in `$DEST_DIR` to automate assembly, simulation, and GTKWave tracing:

```makefile
# =============================================================================
# Standalone Makefile for Verilator Simulation with GTKWave Support
# =============================================================================
ARCH             ?= 32
VERILATOR        ?= verilator
TOP_MODULE       = cva6_axi_wrapper
WRAPPER_SV       = tb/wrappers/cva6_axi_wrapper.sv
TB_CPP           = tb/cpp/tb_cva6_direct.cpp
FILE_LIST        = cv32a6_local.f
CVA6_ROOT        ?= $(CURDIR)/rtl

VERILATOR_FLAGS  = \
    --cc \
    --exe \
    --build \
    -j 0 \
    --trace \
    --trace-structs \
    -Wno-PINMISSING \
    -Wno-BLKANDNBLK \
    -Wno-fatal \
    -O1 \
    -CFLAGS "-DRV32"

.PHONY: all build run wave_run wave clean firmware firmware_loop

all: run

firmware:
	@echo "--- Assembling simple_smoke.S ---"
	riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -mcmodel=medany \
	    -T /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/benchmarks/linker/link.ld -nostdlib \
	    simple_smoke.S -o firmware_smoke.elf
	riscv64-unknown-elf-objcopy -O binary firmware_smoke.elf firmware.bin

build: firmware
	@echo "--- Resolving filelist with CVA6_ROOT=$(CVA6_ROOT) ---"
	sed "s|\$${CVA6_ROOT}|$(CVA6_ROOT)|g" $(FILE_LIST) > cv32a6_resolved.f
	@echo "--- Compiling with Verilator ---"
	$(VERILATOR) $(VERILATOR_FLAGS) -f cv32a6_resolved.f $(WRAPPER_SV) --top-module $(TOP_MODULE) $(TB_CPP)
	@echo "--- Build Complete: obj_dir/V$(TOP_MODULE) ---"

run: build
	@echo "--- Running Standalone Simulation (no waveform) ---"
	./obj_dir/V$(TOP_MODULE)

wave_run: build
	@echo "--- Running Standalone Simulation with Waveform ---"
	ENABLE_WAVE=1 ./obj_dir/V$(TOP_MODULE)

wave:
	gtkwave waveform.vcd CVA6_simple_smoke.gtkw

clean:
	rm -rf obj_dir cv32a6_resolved.f waveform.vcd *.elf firmware.bin
```

---

## 7. Step 5: Compile Firmware & Run Simulation

```bash
cd "$DEST_DIR"

# 1. Run direct fast simulation
make run

# 2. Run simulation with waveform tracing and view in GTKWave
make wave_run
make wave
```

---

## 8. Summary of Active Isolated Environments in `CVA6_LAB/Verilator/`

| Environment Directory | Source Repository | Configuration | Status | Active CPI |
| :--- | :--- | :--- | :--- | :--- |
| `Verilator/CVA6_OpenHW/` | `CloneFiles/cva6` (Upstream OpenHW) | `cv32a6_imac_sv32` | **Verified & Passing** | **1.76** |
| `Verilator/CVA6_Lab/` | `CloneFiles/CVA6-Lab` (Amin-Maky) | `cv32a6_imac_sv32` | **Verified & Passing** | **1.76** |
| `Verilator/CVA6_ThalesGroup/` | `CloneFiles/CVA6_ThalesGroup` | `cv32a6_imac_sv32` | **Verified & Passing** | **1.75** |

### Note on Remaining Directories in `CloneFiles/`:
- **`CVA6_OpenHWSafe`**: The dual-core lockstep safety variant has an uninitialized `cva6/` submodule in the clone (`cva6/` directory is empty).
- **`CVA6_PulpPlatform`**: Git submodule `core/cache_subsystem/hpdcache/` was uninitialized in the clone.
- **Other architectures (`cv32e*`, `cva5`, `cvw`, `ibex`, `veer_eh1`, `HORCRUX`)**: These are non-CVA6 processor architectures and are kept separate from CVA6 workspace directories.

---

## 9. Summary of Standard Folder Structure

Each isolated directory follows this identical, reproducible layout:

```text
Verilator/<CUSTOM_CORE_NAME>/
├── rtl/
│   ├── include/                    # Extracted include headers
│   ├── cva6.sv                     # Top-level core RTL
│   └── ... (all .sv files)
├── tb/
│   ├── wrappers/
│   │   └── cva6_axi_wrapper.sv     # Direct AXI memory wrapper
│   └── cpp/
│       └── tb_cva6_direct.cpp      # C++ cycle-accurate testbench
├── cv32a6_local.f                  # Portable filelist using ${CVA6_ROOT}
├── Makefile                        # Standalone build, run, and waveform targets
├── README.md                       # Complete step-by-step user manual
├── CVA6_simple_smoke.gtkw          # Pre-configured GTKWave signal workspace
├── simple_smoke.S                  # Basic integer ALU smoke test
├── loop_smoke.S                    # Multi-iteration loop test
└── obj_dir/
    └── Vcva6_axi_wrapper           # Compiled simulation binary
```
