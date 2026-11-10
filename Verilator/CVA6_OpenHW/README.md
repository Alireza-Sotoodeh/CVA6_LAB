---
author: Alireza Sotodeh
date: 2026-11-10 22:14:00 +03:30
status: MODIFIED FILE
reason: Updated README.md to explain startup and cache flush overhead (~256 cycles) and highlight steady-state execution CPI (~1.3-1.6)
---

# CVA6_OpenHW Verilator Simulation Guide

This folder contains an **isolated, standalone Verilator simulation environment** for the **OpenHW Group CVA6 (Ariane)** RISC-V processor (`cv32a6_imac_sv32` 32-bit single-issue core).

---

## 1. Quick Start: Running the Simulation

All tools (Verilator, RISC-V GCC cross-compiler, and GTKWave) are configured. Run the simulation with:

```bash
cd /home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW

# Compile firmware, build Verilator model, and run simulation
make run
```

### Understanding CVA6 Startup & Pipeline Flushing Overhead
Upon releasing reset, CVA6 executes an internal boot routine that spends **$\sim 256$ cycles flushing and invalidating caches and pipeline structures** before the first instruction commits (`PC=0x80000000` at cycle ~295). 

Therefore, true pipeline throughput must be evaluated based on **active execution cycles** rather than raw startup cycles:

$$\text{Active Execution Cycles} = \text{End Cycle} - \text{First Commit Cycle}$$
$$\text{Steady-State CPI} = \frac{\text{Active Execution Cycles}}{\text{Committed Instructions}}$$

### Expected Steady-State Output:
```text
[+] Loaded firmware into memory. Size: 80 bytes.
[+] Reset deasserted. CPU starting execution at 0x80000000...
  [COMMIT #1] Cycle=295 PC=0x80000000
  [COMMIT #2] Cycle=297 PC=0x80000002
  ...
  [COMMIT #600] Cycle=1005 PC=0x8000000e
[TOHOST] Benchmark termination signal written! Data=0x100000001

============================================================
          [SUCCESS] SIMULATION COMPLETED.
          Total Clock Cycles    : 1029
          Startup/Flush Cycles  : 295 (cache flush & boot overhead)
          Active Exec Cycles    : 735
          Committed Instrs      : 612
          Steady-State CPI      : 1.20
          Steady-State IPC      : 0.83
============================================================
```

> [!TIP]
> With the initial 256-cycle boot/flush phase properly isolated, the steady-state performance achieves **$\text{CPI} \approx 1.20 - 1.50$**, perfectly matching theoretical out-of-order/single-issue CVA6 throughput!

simple_smoke Test bench result:
![[CPI_and_instructions_verilator_OpenHW.png]]

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
# or directly: gtkwave waveform.vcd &
```

### Key Signals to Add in GTKWave:
* **Clock & Reset**:
  `TOP.cva6_axi_wrapper.clk_i` and `TOP.cva6_axi_wrapper.rst_ni`
* **Instruction Retirement / Commit**:
  - `TOP.cva6_axi_wrapper.commit_ack_o`: Pulses `1` every time an instruction commits.
  - `TOP.cva6_axi_wrapper.commit_pc_o`: PC of the committed instruction.
  - `TOP.cva6_axi_wrapper.commit_wdata_o`: Destination register value written back.
* **Virtual Memory Bus (AXI)**:
  - `TOP.cva6_axi_wrapper.axi_ar_valid_o` / `axi_ar_ready_i`: Read address request handshake.
  - `TOP.cva6_axi_wrapper.axi_r_data_i`: Instruction/data word delivered from memory.
  - `TOP.cva6_axi_wrapper.axi_aw_valid_o` & `axi_w_valid_o`: Store/write handshakes.

---

## 3. How to Create and Run Your Own Testbench

There are two levels of customization:
1. **Software Testbench (Writing custom RISC-V assembly/C tests)**.
2. **Hardware/C++ Driver Testbench (Customizing the Verilator C++ harness)**.

---

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

The C++ testbench lives in `tb/cpp/tb_cva6_direct.cpp`. You can create a copy (e.g. `tb/cpp/tb_custom.cpp`) to implement custom stimulus:

#### Basic Structure of the Testbench:
```cpp
#include "Vcva6_axi_wrapper.h"
#include "verilated.h"
#include <iostream>
#include <vector>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcva6_axi_wrapper* top = new Vcva6_axi_wrapper;

    // 1. Initialize 16MB Virtual RAM and load binary
    std::vector<uint8_t> ram(16 * 1024 * 1024, 0);
    // (Load firmware.bin into ram array...)

    // 2. Power-on reset sequence
    top->clk_i = 0;
    top->rst_ni = 0; // Assert reset
    for (int i = 0; i < 20; i++) {
        top->clk_i = !top->clk_i;
        top->eval();
    }
    top->rst_ni = 1; // Release reset

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

        // Count retired instructions:
        if (top->commit_ack_o) {
            std::cout << "[COMMIT] Instruction retired!\n";
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
| `make run` | Assembles firmware, compiles simulator, and runs test. |
| `make wave_run` | Runs simulation with full VCD signal dumping enabled. |
| `make wave` | Opens the generated `waveform.vcd` in GTKWave. |
| `make clean` | Removes compiled binaries, temporary files, and waveforms. |

---


When you run `make run` in [`Verilator/CVA6_OpenHW`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW), it executes:

### 1. Hardware Testbench Harness (The Simulator)
* **C++ Driver**: [`tb/cpp/tb_cva6_direct.cpp`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/cpp/tb_cva6_direct.cpp)  
  This is the C++ testbench that:
  - Drives clock (`clk_i`) and reset (`rst_ni`).
  - Acts as a 16MB virtual AXI RAM responder (`read_ram`, `write_ram`).
  - Catches the test-end notification via write to `tohost`.
  - Tracks commit signals (`commit_ack_o`, `commit_pc_o`) and computes the steady-state CPI.
* **Top-Level Verilog Wrapper**: [`tb/wrappers/cva6_axi_wrapper.sv`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/wrappers/cva6_axi_wrapper.sv)  
  Instantiates the CVA6 core and exposes clean AXI memory channels to the C++ driver.

### 2. Software Testbench Program (The Code Executed by the Core)
* **Assembly Benchmark**: [`simple_smoke.S`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/simple_smoke.S)  
  The Makefile has this rule:
  ```makefile
  firmware:
      riscv64-unknown-elf-gcc ... simple_smoke.S -o firmware_smoke.elf
      riscv64-unknown-elf-objcopy -O binary firmware_smoke.elf firmware.bin
  ```
  It compiles `simple_smoke.S` into `firmware.bin`, which the C++ driver pre-loads into virtual RAM at address `0x80000000`.

### Summary Table

| Layer | File Being Used | Role |
| :--- | :--- | :--- |
| **Software Program** | [`simple_smoke.S`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/simple_smoke.S) $\rightarrow$ `firmware.bin` | The RISC-V instructions being fetched & executed |
| **SystemVerilog Top** | [`tb/wrappers/cva6_axi_wrapper.sv`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/wrappers/cva6_axi_wrapper.sv) | Bridges internal core structs to external AXI bus |
| **C++ Testbench Harness** | [`tb/cpp/tb_cva6_direct.cpp`](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Verilator/CVA6_OpenHW/tb/cpp/tb_cva6_direct.cpp) | Drives clock/reset, simulates RAM, and measures CPI |

*(If you want to run `loop_smoke.S` instead, you simply change `simple_smoke.S` in the Makefile's `firmware:` target or compile it to `firmware.bin`).*