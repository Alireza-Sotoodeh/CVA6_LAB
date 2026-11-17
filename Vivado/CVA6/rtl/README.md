# CVA6 (Ariane) RTL Sources & Vivado Integration Guide

This directory contains the synthesizable Register-Transfer Level (RTL) sources for the **CVA6 (Ariane)** RISC-V processor core, originating from OpenHW Group & ETH Zurich.

---

## 1. Core Architectural Profile

| Parameter | Specification |
| :--- | :--- |
| **Processor Core** | CVA6 (Ariane) |
| **Architecture** | 6-stage, single-issue application-class RISC-V core (RV32/RV64) |
| **Pipeline Stages** | 6 (PC Gen, Fetch, Decode, Issue, Execute, Commit) |
| **ISA Support** | `RV32IMA / RV64GC with MMU and Sv32/Sv39` |
| **Primary Bus Interface** | AXI4 64-bit with L1 I/D-caches & CV-X-IF v0.4 |
| **Design Top Module** | `cva6` |
| **Total RTL Files** | 142 |
| **Target Device (Default)** | AMD Xilinx Spartan-7 `xa7s6cpga196-1Q` (or Artix-7 / Zynq-7000) |

> [!NOTE]
> Linux-capable application core with non-blocking write-through caches.

---

## 2. Adding Design Sources to Vivado Manually (`sources_1`)

To add this core to a Vivado project, import/add the following **142 files** to **Design Sources (`sources_1`)** in the **exact compile order** listed below.
Packages (`*_pkg.sv`) and header files must be compiled before modules that depend on them.

The paths below are relative to this folder (`Source Codes/RTL/cva6/`):

```text
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ctrl.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_double.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ff1.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_pack.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_prepare.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_round.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_scalar_dp.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_with_sqrt.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_top.v
cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v
vendor/pulp-platform/fpga-support/rtl/AsyncDpRam.sv
vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv
vendor/pulp-platform/fpga-support/rtl/SyncDpRam.sv
vendor/pulp-platform/fpga-support/rtl/SyncDpRam_ind_r_w.sv
vendor/pulp-platform/fpga-support/rtl/SyncThreePortRam.sv
include/config_pkg.sv
include/cv32a6_ima_sv32_fpga_config_pkg.sv
include/riscv_pkg.sv
include/ariane_pkg.sv
include/wt_cache_pkg.sv
vendor/pulp-platform/axi/src/axi_pkg.sv
include/build_config_pkg.sv
include/cva6_types_pkg.sv
alu.sv
alu_wrapper.sv
amo_buffer.sv
ariane_regfile_ff.sv
ariane_regfile_fpga.sv
axi_shim.sv
frontend/bht.sv
frontend/bht2lvl.sv
branch_unit.sv
frontend/btb.sv
vendor/pulp-platform/common_cells/src/cf_math_pkg.sv
commit_stage.sv
compressed_decoder.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/control_mvp.sv
controller.sv
csr_buffer.sv
csr_regfile.sv
cva6_fifo_v3.sv
cache_subsystem/cva6_icache.sv
cva6_mmu/cva6_mmu.sv
cva6_mmu/cva6_ptw.sv
cva6_rvfi_probes.sv
cva6_mmu/cva6_shared_tlb.sv
cva6_mmu/cva6_tlb.sv
cvxif_compressed_if_driver.sv
cvxif_fu.sv
cvxif_issue_register_commit_if_driver.sv
decoder.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/div_sqrt_top_mvp.sv
ex_stage.sv
vendor/pulp-platform/common_cells/src/exp_backoff.sv
cvfpu/src/fpnew_pkg.sv
cvfpu/src/fpnew_cast_multi.sv
cvfpu/src/fpnew_classifier.sv
cvfpu/src/fpnew_divsqrt_multi.sv
cvfpu/src/fpnew_divsqrt_th_64_multi.sv
cvfpu/src/fpnew_fma.sv
cvfpu/src/fpnew_fma_multi.sv
cvfpu/src/fpnew_noncomp.sv
cvfpu/src/fpnew_opgroup_block.sv
cvfpu/src/fpnew_opgroup_fmt_slice.sv
cvfpu/src/fpnew_opgroup_multifmt_slice.sv
cvfpu/src/fpnew_rounding.sv
cvfpu/src/fpnew_top.sv
fpu_wrap.sv
frontend/frontend.sv
id_stage.sv
frontend/instr_queue.sv
instr_realign.sv
frontend/instr_scan.sv
issue_read_operands.sv
issue_stage.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/iteration_div_sqrt_mvp.sv
vendor/pulp-platform/common_cells/src/lfsr.sv
load_store_unit.sv
load_unit.sv
lsu_bypass.sv
vendor/pulp-platform/common_cells/src/lzc.sv
mult.sv
multiplier.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/norm_div_sqrt_mvp.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/nrbd_nrsc_mvp.sv
perf_counters.sv
pmp/src/pmp.sv
pmp/src/pmp_data_if.sv
pmp/src/pmp_entry.sv
vendor/pulp-platform/common_cells/src/popcount.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/preprocess_mvp.sv
frontend/ras.sv
raw_checker.sv
vendor/pulp-platform/common_cells/src/rr_arb_tree.sv
scoreboard.sv
serdiv.sv
vendor/pulp-platform/common_cells/src/shift_reg.sv
common/local/util/sram.sv
common/local/util/sram_cache.sv
store_buffer.sv
store_unit.sv
vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv
common/local/util/tc_sram_wrapper.sv
vendor/pulp-platform/common_cells/src/unread.sv
cache_subsystem/wt_axi_adapter.sv
cache_subsystem/wt_cache_subsystem.sv
cache_subsystem/wt_dcache.sv
cache_subsystem/wt_dcache_ctrl.sv
cache_subsystem/wt_dcache_mem.sv
cache_subsystem/wt_dcache_missunit.sv
cache_subsystem/wt_dcache_wbuffer.sv
cva6.sv
include/instr_tracer_pkg.sv
corev_apu/tb/ariane_soc_pkg.sv
corev_apu/tb/ariane_axi_pkg.sv
include/test_fe_types_pkg.sv
corev_apu/tb/axi_intf.sv
cvxif_example/include/cvxif_instr_pkg.sv
vendor/pulp-platform/common_cells/src/deprecated/rrarbiter.sv
vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv
vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv
vendor/pulp-platform/common_cells/src/fifo_v3.sv
vendor/pulp-platform/common_cells/src/lfsr_8bit.sv
vendor/pulp-platform/common_cells/src/rstgen_bypass.sv
vendor/pulp-platform/common_cells/src/cdc_2phase.sv
corev_apu/axi_mem_if/src/axi2mem.sv
vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv
vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv
vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv
cache_subsystem/axi_adapter.sv
vendor/pulp-platform/fpga-support/rtl/SyncSpRam.sv
vendor/pulp-platform/fpga-support/rtl/SyncTpRam.sv
cache_subsystem/cva6_icache_axi_wrapper.sv
cvfpu/src/fpu_div_sqrt_mvp/hdl/div_sqrt_mvp_wrapper.sv
common/local/util/instr_tracer.sv
cvxif_example/cvxif_example_coprocessor.sv
cvxif_example/instr_decoder.sv
vendor/pulp-platform/common_cells/src/counter.sv
vendor/pulp-platform/common_cells/src/delta_counter.sv
```

### Compiler Settings & Defines
In Vivado Project Settings under **Verilog options**, add the following compiler defines:
```text
XSIM=1
WT_DCACHE=1
TARGET_SIMULATION=1
```

---

## 3. Adding Simulation Sources (`sim_1`)

Add either of the standardized testbenches located in [`Source Codes/Sim/cva6/`](../../Sim/cva6/) to **Simulation Sources (`sim_1`)**:

1. **Functional Smoke Test (Directed RV32I Verification Suite):**
   - **File:** `Source Codes/Sim/cva6/tb_cva6.sv`
   - **Simulation Top Module:** `tb_cva6`
   - **Expected Outcome:** 17 assertions passed, 0 failures (~399 cycles)

2. **Heavy Benchmark Test 2 (Sorting, Fibonacci, Matrix Operations):**
   - **File:** `Source Codes/Sim/cva6/tb_test2_cva6.sv`
   - **Simulation Top Module:** `tb_test2_cva6`
   - **Expected Outcome:** 13 assertions passed, 0 failures (~1340 cycles, CPI: 7.88)

---

## 4. Automated Vivado Tcl Script

You can copy and execute the following Tcl snippet in the Vivado Tcl Console to automate project creation, source registration, and simulation launch:

```tcl
# 1. Create project
create_project cva6 ./Vivado/cva6 -part xa7s6cpga196-1Q -force

# 2. Add Design Sources (RTL)
add_files -fileset sources_1 [glob -nocomplain "Source Codes/RTL/cva6/*.sv" "Source Codes/RTL/cva6/*.v"]
set_property top cva6 [get_filesets sources_1]

# 3. Add Simulation Sources (Smoke Test)
add_files -fileset sim_1 "Source Codes/Sim/cva6/tb_cva6.sv"
set_property top tb_cva6 [get_filesets sim_1]

# 4. Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 5. Launch Behavioral Simulation
launch_simulation -mode behavioral
```
