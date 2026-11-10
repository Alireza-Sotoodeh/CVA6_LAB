---
author: Alireza Sotodeh
date: 2026-11-10 23:55:00 +03:30
status: MODIFIED FILE
reason: Updated expected steady-state simulation metrics for CVA6_ThalesGroup native WT cache
---

# CVA6_ThalesGroup Verilator Simulation Guide

This folder contains an **isolated, standalone Verilator simulation environment** for the **Thales Group CVA6 (Ariane)** RISC-V processor (`cv32a6_imac_sv32` 32-bit single-issue baseline from the softcore contest framework).

---

## 1. Quick Start: Running the Simulation

All necessary tools (Verilator $\ge 5.020$, RISC-V GCC cross-compiler, and GTKWave) are configured. Run the simulation directly:

```bash
cd /home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_ThalesGroup

# 1. Compile firmware, build Verilator model, and run simulation
make run
```

### Understanding CVA6 Startup & Pipeline Flushing Overhead
Upon releasing reset, CVA6 executes an internal boot routine that spends **$\sim 256$ cycles flushing and invalidating caches and pipeline structures** before the first instruction commits (`PC=0x80000000` at cycle ~295).

Therefore, true pipeline throughput is evaluated on **active execution cycles**:
$$\text{Active Execution Cycles} = \text{End Cycle} - \text{First Commit Cycle}$$
$$\text{Steady-State CPI} = \frac{\text{Active Execution Cycles}}{\text{Committed Instructions}}$$

### Expected Steady-State Output:
```text
[+] Loaded firmware into memory. Size: 80 bytes.
[+] Reset deasserted. CPU starting execution at 0x80000000...
  [COMMIT #1] Cycle=295 PC=0x80000000
  [COMMIT #2] Cycle=296 PC=0x80000002
  ...
  [COMMIT #16] Cycle=322 PC=0x8000002a
[TOHOST] Benchmark termination signal written! Data=0x100000001

============================================================
          [SUCCESS] SIMULATION COMPLETED.
          Total Clock Cycles    : 323
          Startup/Flush Cycles  : 295 (cache flush & boot overhead)
          Active Exec Cycles    : 28
          Committed Instrs      : 16
          Steady-State CPI      : 1.75
          Steady-State IPC      : 0.57
============================================================
```

---

## 2. Generating and Viewing Waveforms with GTKWave

### Step 1: Run Simulation with Waveform Dumping
```bash
make wave_run
```
This generates `waveform.vcd` (VCD waveform trace) with deep hierarchy.

### Step 2: Open Pre-configured Waveform in GTKWave
```bash
make wave
```
or run directly:
```bash
gtkwave waveform.vcd CVA6_simple_smoke.gtkw
```

### Pre-saved GTKWave Signals
The provided [`CVA6_simple_smoke.gtkw`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_ThalesGroup/CVA6_simple_smoke.gtkw) organizes signals into clean logical groups:
1. **Clock & Reset**: `clk_i`, `rst_ni`
2. **Instruction Retirement Pulse**:
   - `cva6_axi_wrapper.i_cva6.commit_stage_i.commit_ack_o[0]` (high for 1 cycle per retired instruction)
   - `cva6_axi_wrapper.i_cva6.commit_stage_i.commit_ack_o[1]`
3. **Commit Details**:
   - `commit_stage_i.commit_pkt_i[0].pc` (Committed PC in hex)
   - `commit_stage_i.commit_pkt_i[0].valid`
   - `commit_stage_i.commit_pkt_i[0].rd` (Destination register address)
4. **Scoreboard & Hazard Pointers**:
   - `scoreboard_i.issue_pointer_q` (Queue pointer for issue stage)
   - `scoreboard_i.commit_pointer_q` (Queue pointer for commit stage)
   - `scoreboard_i.num_issue` (Number of active issued instructions)
   - `scoreboard_i.num_commit` (Number of committed instructions)
   - `scoreboard_i.still_issued` (Active pending instructions in scoreboard)
5. **Memory Bus (AXI4-Lite / Direct)**:
   - `axi_ar_valid_o`, `axi_ar_ready_i`, `axi_ar_addr_o`
   - `axi_r_valid_i`, `axi_r_data_i`
   - `axi_aw_valid_o`, `axi_w_valid_o`, `axi_b_valid_i`

---

## 3. How to Create and Run Your Own Testbenches

You can run your own Assembly programs without editing the Verilator C++ testbench.

### Step 1: Write Your RISC-V Assembly (`my_test.S`)
Create a new file, e.g. `my_test.S`:
```assembly
.section .text
.globl _start

_start:
    # 1. Initialize test registers
    li x1, 10
    li x2, 20
    add x3, x1, x2       # x3 = 30
    mul x4, x1, x2       # x4 = 200

    # 2. Store result to memory
    la x5, result_data
    sw x4, 0(x5)
    lw x6, 0(x5)         # x6 = 200

    # 3. Notify testbench of completion via tohost
    la x10, tohost
    li x11, 1            # 1 = PASS (exit code 0)
    sw x11, 0(x10)

1:  wfi
    j 1b

.section .tohost
.align 6
.globl tohost
tohost:
    .dword 0

.section .data
.align 4
result_data:
    .word 0
```

### Step 2: Compile to Binary
```bash
riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -mcmodel=medany \
    -T /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/benchmarks/linker/link.ld -nostdlib \
    my_test.S -o my_test.elf

riscv64-unknown-elf-objcopy -O binary my_test.elf firmware.bin
```

### Step 3: Run the Simulation
```bash
./obj_dir/Vcva6_axi_wrapper
```
To run with waveform:
```bash
ENABLE_WAVE=1 ./obj_dir/Vcva6_axi_wrapper
gtkwave waveform.vcd CVA6_simple_smoke.gtkw
```

---

## 4. Makefile Command Summary

| Command | Action | Output / Artifact |
| :--- | :--- | :--- |
| `make` / `make run` | Assembles `simple_smoke.S`, builds model, runs fast simulation | Terminal retirement log + CPI |
| `make wave_run` | Builds with tracing enabled and runs simulation | Creates `waveform.vcd` |
| `make wave` | Opens waveform and signal groups in GTKWave | Launches GTKWave analyzer |
| `make firmware_loop` | Assembles multi-iteration loop test (`loop_smoke.S`) | `firmware.bin` |
| `make clean` | Removes compiled binaries, ELF files, and VCD dumps | Clean directory |

---

## 5. Architectural Comparison with Other Flavors

| Feature | `CVA6_OpenHW` | `CVA6_Lab` | `CVA6_ThalesGroup` |
| :--- | :--- | :--- | :--- |
| **Origin** | OpenHW Group Upstream Master | Amin-Maky CVA6-Lab | Thales Group Softcore Contest |
| **Configuration** | `cv32a6_imac_sv32` | `cv32a6_imac_sv32` | `cv32a6_imac_sv32` |
| **Write-Through Cache** | Yes (`wt_cache_subsystem`) | Yes (`wt_cache_subsystem`) | Yes (`wt_cache_subsystem`) |
| **Scoreboard / Write-Back** | Standard OpenHW Scoreboard | Decoupled FLU Hazard-Resolved | Standard Contest Baseline |
| **Startup Overhead** | ~295 cycles (cache flush) | ~295 cycles (cache flush) | ~295 cycles (cache flush) |
| **Smoke Test Active CPI** | 1.76 | 1.76 | 1.75 |
