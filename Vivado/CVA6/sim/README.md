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
| **`tb_cva6.sv`** | `tb_cva6` | **Smoke Test 1:** 19-instruction RV32I verification suite (ALU, Branches, Memory, Shifts) | **17 / 17 (100%)** | ~399 cycles | 3985 ns |
| **`tb_test2_cva6.sv`** | `tb_test2_cva6` | **Benchmark Test 2:** Heavy integer workload (Bubble sort, recursive Fibonacci, 3x3 Matrix Multiplication) | **13 / 13 (100%)** | ~1340 cycles | 13395 ns (CPI: 7.88) |

---

## 2. Adding Simulation Sources to Vivado (`sim_1`)

To configure behavioral simulation in Vivado:

1. **Add to `sim_1`:**
   Add either `tb_cva6.sv` or `tb_test2_cva6.sv` to the **Simulation Sources (`sim_1`)** fileset.
2. **Set Simulation Top:**
   - For Smoke Test 1: Set Simulation Top to **`tb_cva6`**.
   - For Benchmark Test 2: Set Simulation Top to **`tb_test2_cva6`**.
3. **Verify Design Sources:**
   Ensure all corresponding RTL design sources from [`Source Codes/RTL/cva6/`](../../RTL/cva6/) are added to **`sources_1`** with Design Top set to `cva6` (see [RTL README](../../RTL/cva6/README.md) for compile order).

---

## 3. Launching Simulation in Vivado

### Via Vivado GUI:
1. In the **Sources** pane, expand **Simulation Sources -> sim_1**.
2. Right-click the desired testbench (`tb_cva6` or `tb_test2_cva6`) and select **Set as Top**.
3. In the Flow Navigator, click **Run Simulation -> Run Behavioral Simulation**.
4. In the simulation console (Tcl Console), verify that all assertions report `PASS` and simulation ends with:
   ```text
   Simulation PASSED: All assertion checks verified successfully!
   $finish called at time : ...
   ```

### Via Vivado Tcl Console:
```tcl
# Select simulation top
set_property top tb_cva6 [get_filesets sim_1]
update_compile_order -fileset sim_1

# Launch simulation
launch_simulation -mode behavioral

# Run to completion
run all
```
