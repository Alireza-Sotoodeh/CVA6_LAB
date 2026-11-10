---
author: Alireza Sotodeh
date: 2026-11-10 23:27:00 +03:30
status: NEW FILE
reason: Complete user guide for running Verilator simulation, viewing waveforms in GTKWave, and writing custom testbenches in CVA6_Lab
---

# CVA6_Lab Verilator Simulation Guide

This folder contains an **isolated, standalone Verilator simulation environment** for the **CVA6-Lab (Amin-Maky)** RISC-V processor (`cv32a6_imac_sv32` 32-bit single-issue baseline with decoupled write-back / structural hazard resolution).

---

## 1. Quick Start: Running the Simulation

All necessary tools (Verilator $\ge 5.020$, RISC-V GCC cross-compiler, and GTKWave) are configured. Run the simulation directly:

```bash
cd /home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_Lab

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
  [COMMIT #17] Cycle=324 PC=0x8000002a
[TOHOST] Benchmark termination signal written! Data=0x100000001

============================================================
          [SUCCESS] SIMULATION COMPLETED.
          Total Clock Cycles    : 326
          Startup/Flush Cycles  : 295 (cache flush & boot overhead)
          Active Exec Cycles    : 30
          Committed Instrs      : 17
          Steady-State CPI      : 1.76
          Steady-State IPC      : 0.57
============================================================
```

---

## 2. Generating & Inspecting Waveforms with GTKWave

To record internal signals and visualize instruction execution:

### Step 1: Run Simulation with Waveform Recording
```bash
make wave_run
```
This generates `waveform.vcd` (cycle-by-cycle signal dump).

### Step 2: Open in GTKWave
```bash
make wave
# or directly: gtkwave waveform.vcd CVA6_simple_smoke.gtkw &
```

### Key Signals Pre-Configured in `CVA6_simple_smoke.gtkw`:
* **Clock & Reset**: `TOP.clk_i` and `TOP.rst_ni`
* **Instruction Retirement / Commit**:
  - `commit_ack_o[1:0]`: Pulses high whenever an instruction retires.
  - `commit_pc_o[0]`, `commit_pc_o[1]`: PC of committed instructions.
  - `commit_rd_o[0]`, `commit_wdata_o[0]`: Register written back and value.
* **Scoreboard Counters & Ring Buffer Pointers**:
  - `num_issue[0]`: Dispatched instructions in cycle.
  - `num_commit[1:0]`: Retired instructions in cycle.
  - `issue_pointer_q[2:0]`: In-flight issue ring-buffer pointer.
  - `commit_pointer_q[0][2:0]`: Oldest uncommitted transaction waiting for retirement.
  - `still_issued[7:0]`: Scoreboard active in-flight instruction mask.

---

## 3. How to Create and Run Your Own Testbench

### Level A: Writing Your Own RISC-V Test Program (`my_test.S`)

Create an assembly test file, e.g. `my_test.S`:

```assembly
.section .data
.align 6
.global tohost
tohost: .dword 0

.global fromhost
fromhost: .dword 0

.section .text
.global _start
_start:
    # 1. Your custom assembly instructions:
    li x1, 42
    li x2, 58
    add x3, x1, x2      # x3 = 100
    mul x4, x1, x2      # Multiplier test

    # 2. Tell testbench simulation is complete by writing 1 to tohost:
    la t0, tohost
    li t1, 1
    sw t1, 0(t0)

spin:
    j spin
```

#### Compile and Run Your Program:
```bash
# 1. Assemble to RISC-V ELF
riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -mcmodel=medany \
    -T /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/benchmarks/linker/link.ld -nostdlib \
    my_test.S -o my_test.elf

# 2. Convert to flat binary image
riscv64-unknown-elf-objcopy -O binary my_test.elf firmware.bin

# 3. Run the simulator
./obj_dir/Vcva6_axi_wrapper
```

---

### Level B: Writing a Custom C++ Verilator Harness

The C++ testbench lives in `tb/cpp/tb_cva6_direct.cpp`. You can create a copy (e.g. `tb/cpp/tb_custom.cpp`) to implement custom stimulus or memory latencies:

```cpp
#include "Vcva6_axi_wrapper.h"
#include "verilated.h"
#include <iostream>
#include <vector>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcva6_axi_wrapper* top = new Vcva6_axi_wrapper;

    // 1. Initialize Virtual RAM and load binary
    std::vector<uint8_t> ram(16 * 1024 * 1024, 0);

    // 2. Power-on reset sequence
    top->clk_i = 0; top->rst_ni = 0;
    for (int i = 0; i < 20; i++) {
        top->clk_i = !top->clk_i; top->eval();
    }
    top->rst_ni = 1;

    // 3. Main clock loop & memory responder
    while (!Verilated::gotFinish()) {
        top->clk_i = 1; top->eval(); // Rising edge

        // Handle memory reads (AXI AR channel):
        if (top->axi_ar_valid_o) {
            top->axi_ar_ready_i = 1;
            uint64_t addr = top->axi_ar_addr_o - 0x80000000ULL;
            top->axi_r_data_i = *reinterpret_cast<uint64_t*>(&ram[addr]);
            top->axi_r_valid_i = 1;
        }

        top->clk_i = 0; top->eval(); // Falling edge
    }

    delete top;
    return 0;
}
```

To build with your custom testbench, update `TB_CPP` in the `Makefile`:
```makefile
TB_CPP = tb/cpp/tb_custom.cpp
```
Then run `make build`.

---

## 4. Summary of Makefile Targets

| Command | Action |
| :--- | :--- |
| `make run` | Assembles firmware, compiles simulator, and runs test (fast, no waveform). |
| `make wave_run` | Runs simulation with full VCD signal dumping enabled. |
| `make wave` | Opens the generated `waveform.vcd` and `CVA6_simple_smoke.gtkw` in GTKWave. |
| `make clean` | Removes compiled binaries, temporary files, and waveforms. |
