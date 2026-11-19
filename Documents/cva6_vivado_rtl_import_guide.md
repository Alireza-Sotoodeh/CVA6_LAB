---
author: Alireza Sotodeh
date: 2026-11-15 12:45:00 +03:30
status: NEW FILE
reason: Step-by-step guide and dependency-ordered RTL filelist for importing OpenHW CVA6 from CVA6-Lab into AMD Vivado.
---

# CVA6 RTL Import and File Ordering Guide for AMD Vivado

This guide explains how to import the RTL source files from the reference clone tree [CVA6-Lab](file:///home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab) into an AMD Vivado project in the correct dependency order.

---

## 1. Upstream Verification Summary

The reference repository has been inspected and verified against the golden upstream repository:
* **Reference Directory:** `/home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab`
* **Upstream Git URL:** `https://github.com/Amin-Maky/CVA6-Lab`
* **Branch:** `Main` (tracked to `origin/Main`)
* **Latest Upstream Commit:** `cd09f43 Main README Update` (with custom hazard resolution tag `v1.1.0-custom`)
* **Verification Status:** Verified up-to-date, valid, and clean.

---

## 2. Why File Ordering Matters in Vivado

SystemVerilog enforces strict compilation ordering:
1. **Package Dependency:** Any file containing an `import package_name::*;` statement must be compiled **after** the package definition file (`*_pkg.sv`).
2. **Configuration Collision Prevention:** CVA6 defines its core parameters inside `package cva6_config_pkg;`. Never add both `cv32a6_imac_sv32_config_pkg.sv` and `cv64a6_imafdc_sv39_config_pkg.sv` to the same project, as the second one will overwrite the first and corrupt the target architecture width (`XLEN`).
3. **Include Directories:** Header files (`*.svh`) are resolved via search paths rather than direct file compilation.

---

## 3. Ordered RTL Source Groups (Dependency Order)

When adding files to `sources_1`, import them in the following ordered groups:

### Group 1: Technology & FPGA Foundation Cells
Low-level clock gating, FPGA pad drivers, and synchronous RAM macros:
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/pad_functional_xilinx.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_clk_xilinx.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_sram_xilinx.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/rtl/tc_sram_impl.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clock_gating_async.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/cluster_clk_cells.sv`
* `rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clk_cells.sv`

### Group 2: Common Support Cells & Base Packages
General arithmetic, arbiters, FIFOs, and synchronizers:
1. **Packages first:**
   * `rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cb_filter_pkg.sv`
   * `rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_reset_ctrlr_pkg.sv`
   * `rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cf_math_pkg.sv`
   * `rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_pkg.sv`
2. **Modules:**
   * `fifo_v3.sv`, `lzc.sv`, `popcount.sv`, `rr_arb_tree.sv`, `stream_*.sv`, `fall_through_register.sv`, `id_queue.sv`, etc. (located under `rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/`).

### Group 3: Core Architectural Packages & Config (Strict Order)
Must be compiled before any CVA6 pipeline stage:
1. `rtl/core/include/config_pkg.sv`
2. `rtl/core/include/cv32a6_imac_sv32_config_pkg.sv` *(for 32-bit core)*
3. `rtl/core/include/riscv_pkg.sv`
4. `rtl/core/include/ariane_pkg.sv`
5. `rtl/core/include/build_config_pkg.sv`

### Group 4: Subsystem Packages & MMU Units
1. **Subsystem Packages:**
   * `rtl/core/include/wt_cache_pkg.sv`
   * `rtl/core/include/std_cache_pkg.sv`
   * `rtl/core/include/aes_pkg.sv`
   * `rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_pkg.sv`
   * `rtl/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_pkg.sv`
   * `rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_pkg.sv`
2. **MMU & TLB Infrastructure:**
   * `rtl/core/cva6_mmu/cva6_tlb.sv`
   * `rtl/core/cva6_mmu/cva6_shared_tlb.sv`
   * `rtl/core/cva6_mmu/cva6_mmu.sv`
   * `rtl/core/cva6_mmu/cva6_ptw.sv`

### Group 5: Execution Units & Pipeline Stages
1. **ALU, Multiplier, Divider:** `alu.sv`, `alu_wrapper.sv`, `mult.sv`, `multiplier.sv`, `serdiv.sv`, `branch_unit.sv`.
2. **Decoders & Registers:** `decoder.sv`, `compressed_decoder.sv`, `controller.sv`, `csr_regfile.sv`, `csr_buffer.sv`, `ariane_regfile_fpga.sv`.
3. **Frontend:** `instr_scan.sv`, `instr_queue.sv`, `btb.sv`, `bht.sv`, `bht2lvl.sv`, `ras.sv`, `frontend.sv`.
4. **Issue & Execution:** `issue_stage.sv`, `issue_read_operands.sv`, `scoreboard.sv`, `raw_checker.sv`, `ex_stage.sv`.
5. **LSU & Commit:** `load_unit.sv`, `store_unit.sv`, `store_buffer.sv`, `load_store_unit.sv`, `commit_stage.sv`.
6. **Cache Subsystems:** `wt_dcache.sv`, `wt_cache_subsystem.sv`, `cva6_icache.sv`, `hpdcache.sv`, etc.
7. **Top-Level:** `rtl/core/cva6.sv`.

### Group 6: Simulation Testbench (`sim_1`)
* Testbench: `tb/sv/cva6_tb.sv`

---

## 4. Mandatory Project Settings (Includes & Defines)

Regardless of how files are added, Vivado requires these include search directories and macros to elaborate successfully:

### Required Include Paths (`include_dirs`)
```tcl
set ROOT "/home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/rtl"

set_property include_dirs [list \
    "$ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/include" \
    "$ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include" \
    "$ROOT/common/local/util" \
    "$ROOT/core/cache_subsystem/hpdcache/rtl/include" \
    "$ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc" \
    "$ROOT/core/include" \
] [current_fileset]

set_property include_dirs [list \
    "$ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/include" \
    "$ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include" \
    "$ROOT/common/local/util" \
    "$ROOT/core/cache_subsystem/hpdcache/rtl/include" \
    "$ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc" \
    "$ROOT/core/include" \
] [current_fileset -simset]
```

### Required Verilog Defines (`verilog_define`)
```tcl
set_property verilog_define [list \
    TARGET_CV32A6_IMAC_SV32 \
    TARGET_FPGA \
    TARGET_SYNTHESIS \
    TARGET_VIVADO \
    TARGET_XILINX \
    VERILATOR \
] [current_fileset]

set_property verilog_define [list \
    TARGET_CV32A6_IMAC_SV32 \
    TARGET_FPGA \
    TARGET_SYNTHESIS \
    TARGET_VIVADO \
    TARGET_XILINX \
    VERILATOR \
] [current_fileset -simset]
```
> [!NOTE]
> The `VERILATOR` macro is defined to bypass the simulation tracer `instr_tracer`, which requires external QuestaSim/UVM classes that are unavailable in Vivado XSIM.

---

## 5. Automated 1-Click Import Script

The complete, tested filelist is already packaged in the CVA6-Lab tree:
* Script Reference: [cv32a6_imac_sv32.tcl](file:///home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/fpga/vivado/cv32a6_imac_sv32.tcl)

To automatically recreate the project or add all sources in one go from Vivado Tcl Console:
```tcl
# In Vivado Tcl Console:
cd /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/fpga/vivado
source cv32a6_imac_sv32.tcl
```
Or to import into your existing project:
```tcl
open_project /home/alireza/GitHub/Mahani/CVA6_LAB/Vivado/CVA6_Lab/CVA6_Lab.xpr
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
```
