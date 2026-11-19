---
author: Alireza Sotodeh
date: 2026-11-19 15:00:00 +03:30
status: MODIFIED FILE
reason: Updated testbench filename and top module name to tb_cva6_smoke_cold_startup representing smoke testing and cold-startup analysis.
---

# CVA6 (Ariane) Simulation Testbenches & Vivado Verification Guide

This folder contains the standardized behavioral simulation testbenches for the **CVA6 (Ariane)** RISC-V processor core.

---

## 1. Testbench Suite Overview

The testbench suite follows the unified architectural standard defined in [`Document/Simulation/testbench_standardization_guide.md`](../../../Document/Simulation/testbench_standardization_guide.md):
- Active-low synchronous reset assertion.
- Cycle-accurate execution monitoring.
- Built-in hardware assertion scoreboard checking architectural register writes.
- Deterministic watchdog timeout preventing infinite simulation loops.
- Standardized `$finish(0)` termination reporting total cycles, instructions retired, and pass/fail summary.

### Available Testbenches

| Testbench File | Top Module | Test Description | Assertions | Target Cycles | Expected Runtime |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`tb_cva6_warm_cache.sv`** | `tb_cva6_warm_cache` | **Warmed Cache Benchmark:** 10-iteration loop benchmarking true steady-state warm CPI (~1.3 - 1.5) with zero secondary misses + `cva6_warm_trace.csv` | **18 / 18 (100%)** | ~600–700 cycles | ~6500 ns |
| **`tb_cva6_smoke_cold_startup.sv`** | `tb_cva6_smoke_cold_startup` | **Smoke & Cold Startup Test:** 19-instruction RV32I verification suite (ALU, Branches, Memory, Shifts) + I-Cache Cold Startup Tag Flush & Compulsory Miss Analysis | **17 / 17 (100%)** | ~399 cycles | 3985 ns |
| **`tb_test2_cva6.sv`** | `tb_test2_cva6` | **Benchmark Test 2:** Heavy integer workload (Bubble sort, recursive Fibonacci, 3x3 Matrix Multiplication) | **13 / 13 (100%)** | ~1340 cycles | 13395 ns (CPI: 7.88) |

---

## 2. Adding Simulation Sources to Vivado (`sim_1`)

To configure behavioral simulation in Vivado:

1. **Add to `sim_1`:**
   Add either `tb_cva6_smoke_cold_startup.sv` or `tb_test2_cva6.sv` to the **Simulation Sources (`sim_1`)** fileset.
2. **Set Simulation Top:**
   - For Smoke & Cold Startup Test: Set Simulation Top to **`tb_cva6_smoke_cold_startup`**.
   - For Benchmark Test 2: Set Simulation Top to **`tb_test2_cva6`**.
3. **Verify Design Sources:**
   Ensure all corresponding RTL design sources from [`Source Codes/RTL/cva6/`](../../RTL/cva6/) are added to **`sources_1`** with Design Top set to `cva6` (see [RTL README](../../RTL/cva6/README.md) for compile order).

---

## 3. Launching Simulation in Vivado

### Via Vivado GUI:
1. In the **Sources** pane, expand **Simulation Sources -> sim_1**.
2. Right-click the desired testbench (`tb_cva6_smoke_cold_startup` or `tb_test2_cva6`) and select **Set as Top**.
3. In the Flow Navigator, click **Run Simulation -> Run Behavioral Simulation**.
4. In the simulation console (Tcl Console), verify that all assertions report `PASS` and simulation ends with:
   ```text
   Simulation PASSED: All assertion checks verified successfully!
   $finish called at time : ...
   ```

### Via Vivado Tcl Console:
```tcl
# Select simulation top
set_property top tb_cva6_smoke_cold_startup [get_filesets sim_1]
update_compile_order -fileset sim_1

# Launch simulation
launch_simulation -mode behavioral

# Run to completion
run all
```
