---
author: Alireza Sotodeh
date: 2026-11-16 11:08:00 +03:30
status: NEW FILE
reason: Quick reference guide for compiling custom assembly programs to firmware_syn.hex for Vivado simulation.
---

# Quick Guide: Running Custom Assembly in Vivado Simulation

Follow these 3 simple steps to compile and simulate any RISC-V assembly program with `cva6_tb.sv`.

---

## Step 1: Write Your Assembly Code

Save your assembly code (e.g., `my_program.S`) in this folder. Make sure it has `_start:` at the beginning and ends in a loop:

```assembly
    .section .text.init
    .global _start

_start:
    li x1, 10
    li x2, 20
    add x3, x1, x2

loop:
    j loop              # Keep core in loop to end test
```

---

## Step 2: Convert to `.hex`

Run the conversion script:

```bash
# For 32-bit (default - cv32a6_imac_sv32)
./asm2hex.sh my_program.S

# For 64-bit (cv64a6_imafdc_sv39)
./asm2hex.sh my_program.S rv64imafdc
```

> [!NOTE]
> This command automatically:
> 1. Compiles and links at `0x80000000`.
> 2. Generates `firmware_syn.hex`.
> 3. Creates `firmware_syn.dump` (disassembly view for debugging).
> 4. Automatically copies `firmware_syn.hex` into all Vivado XSIM simulation folders.

---

## Step 3: Run Vivado Simulation

Open Vivado or use the Tcl console:

1. Click **Run Simulation** -> **Run Behavioral Simulation** (or **Run Post-Synthesis Functional Simulation**).
2. The testbench (`cva6_tb.sv`) will automatically load your new `firmware_syn.hex`.
3. Check the waveform in Vivado to see your instructions execute!

---

## Useful Commands

| Task | Command |
|---|---|
| Compile default `main-syn.S` | `./asm2hex.sh` |
| Compile custom file | `./asm2hex.sh <filename.S>` |
| Inspect generated instructions | `cat firmware_syn.dump` |
| Inspect hex memory words | `cat firmware_syn.hex` |
| Clean build files | `make clean` |
