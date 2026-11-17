# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-17 23:45:00 +03:30
# Status: NEW FILE
# Reason / Modification: Automated registration of local CVA6 RTL and Sim sources in CVA6.xpr
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR [file normalize [file join $SCRIPT_DIR ".."]]
set PROJ_FILE [file join $PROJ_DIR "CVA6.xpr"]

puts "====================================================================="
puts " Opening Vivado Project: $PROJ_FILE"
puts "====================================================================="
open_project $PROJ_FILE

puts "====================================================================="
puts " Clearing existing files in sources_1 and sim_1"
puts "====================================================================="
set cur_srcs [get_files -quiet -of_objects [get_filesets sources_1]]
if {[llength $cur_srcs] > 0} {
    remove_files -fileset sources_1 $cur_srcs
}
set cur_sims [get_files -quiet -of_objects [get_filesets sim_1]]
if {[llength $cur_sims] > 0} {
    remove_files -fileset sim_1 $cur_sims
}

puts "====================================================================="
puts " Adding 142 Local RTL Design Sources to sources_1"
puts "====================================================================="
set rtl_file_list [list \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ctrl.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_double.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ff1.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_pack.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_prepare.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_round.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_scalar_dp.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_with_sqrt.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_top.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/AsyncDpRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/SyncDpRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/SyncDpRam_ind_r_w.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/SyncThreePortRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/config_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/cv32a6_ima_sv32_fpga_config_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/riscv_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/ariane_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/wt_cache_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/axi/src/axi_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/build_config_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/cva6_types_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "alu.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "alu_wrapper.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "amo_buffer.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "ariane_regfile_ff.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "ariane_regfile_fpga.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "axi_shim.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/bht.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/bht2lvl.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "branch_unit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/btb.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/cf_math_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "commit_stage.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "compressed_decoder.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/control_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "controller.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "csr_buffer.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "csr_regfile.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_fifo_v3.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/cva6_icache.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_mmu/cva6_mmu.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_mmu/cva6_ptw.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_rvfi_probes.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_mmu/cva6_shared_tlb.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6_mmu/cva6_tlb.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_compressed_if_driver.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_fu.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_issue_register_commit_if_driver.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "decoder.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/div_sqrt_top_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "ex_stage.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/exp_backoff.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_cast_multi.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_classifier.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_divsqrt_multi.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_divsqrt_th_64_multi.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_fma.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_fma_multi.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_noncomp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_opgroup_block.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_opgroup_fmt_slice.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_opgroup_multifmt_slice.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_rounding.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpnew_top.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "fpu_wrap.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/frontend.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "id_stage.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/instr_queue.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "instr_realign.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/instr_scan.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "issue_read_operands.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "issue_stage.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/iteration_div_sqrt_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/lfsr.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "load_store_unit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "load_unit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "lsu_bypass.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/lzc.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "mult.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "multiplier.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/norm_div_sqrt_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/nrbd_nrsc_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "perf_counters.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "pmp/src/pmp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "pmp/src/pmp_data_if.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "pmp/src/pmp_entry.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/popcount.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/preprocess_mvp.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "frontend/ras.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "raw_checker.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/rr_arb_tree.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "scoreboard.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "serdiv.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/shift_reg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "common/local/util/sram.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "common/local/util/sram_cache.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "store_buffer.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "store_unit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "common/local/util/tc_sram_wrapper.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/unread.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_axi_adapter.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_cache_subsystem.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_dcache.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_dcache_ctrl.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_dcache_mem.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_dcache_missunit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/wt_dcache_wbuffer.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cva6.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/instr_tracer_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "corev_apu/tb/ariane_soc_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "corev_apu/tb/ariane_axi_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "include/test_fe_types_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "corev_apu/tb/axi_intf.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_example/include/cvxif_instr_pkg.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/deprecated/rrarbiter.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/fifo_v3.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/lfsr_8bit.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/rstgen_bypass.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/cdc_2phase.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "corev_apu/axi_mem_if/src/axi2mem.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/axi_adapter.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/SyncSpRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/fpga-support/rtl/SyncTpRam.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cache_subsystem/cva6_icache_axi_wrapper.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvfpu/src/fpu_div_sqrt_mvp/hdl/div_sqrt_mvp_wrapper.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "common/local/util/instr_tracer.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_example/cvxif_example_coprocessor.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "cvxif_example/instr_decoder.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/counter.sv"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor/pulp-platform/common_cells/src/delta_counter.sv"]] \
]
add_files -norecurse -fileset [get_filesets sources_1] $rtl_file_list

puts "====================================================================="
puts " Configuring include directories for sources_1"
puts "====================================================================="
set rtl_inc_dirs [list \
    [file normalize [file join $PROJ_DIR "rtl" "include"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor" "pulp-platform" "common_cells" "include"]] \
    [file normalize [file join $PROJ_DIR "rtl" "common" "local" "util"]] \
    [file normalize [file join $PROJ_DIR "rtl" "corev_apu" "register_interface" "include"]] \
    [file normalize [file join $PROJ_DIR "rtl" "vendor" "pulp-platform" "axi" "include"]] \
]
set_property include_dirs $rtl_inc_dirs [get_filesets sources_1]

# Set Top module for Design Sources
set_property top cva6 [get_filesets sources_1]

puts "====================================================================="
puts " Adding Simulation Sources to sim_1"
puts "====================================================================="
set sim_file_list [list \
    [file normalize [file join $PROJ_DIR "sim" "tb_cva6.sv"]] \
    [file normalize [file join $PROJ_DIR "sim" "tb_test2_cva6.sv"]] \
    [file normalize [file join $PROJ_DIR "tb_cva6_behav.wcfg"]] \
    [file normalize [file join $PROJ_DIR "tb_test2_cva6_behav.wcfg"]] \
    [file normalize [file join $PROJ_DIR "cva6_architecture_analysis.wcfg"]] \
    [file normalize [file join $PROJ_DIR "cva6_behav.wcfg"]] \
    [file normalize [file join $PROJ_DIR "tb1_cva6_mine.wcfg"]] \
]
add_files -norecurse -fileset [get_filesets sim_1] $sim_file_list

# Configure sim_1 settings
set_property include_dirs $rtl_inc_dirs [get_filesets sim_1]
set_property verilog_define [list XSIM=1 WT_DCACHE=1 TARGET_SIMULATION=1] [get_filesets sim_1]
set_property top tb_cva6 [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {15000ns} -objects [get_filesets sim_1]

puts "====================================================================="
puts " Updating Compile Order"
puts "====================================================================="
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "====================================================================="
puts " Auditing Project Files (Verifying Local Self-Containment)"
puts "====================================================================="
set ext_files [get_files -filter {IS_EXTERNAL == 1}]
set ext_count [llength $ext_files]
puts "Audit External Files Count: $ext_count"
if {$ext_count != 0} {
    puts "ERROR: Found $ext_count external files in project:"
    foreach ef $ext_files {
        puts "  External: $ef"
    }
    error "Project contains external file references!"
} else {
    puts "SUCCESS: All files are 100% self-contained inside $PROJ_DIR!"
}

puts "====================================================================="
puts " Saving and Closing Project"
puts "====================================================================="
close_project
puts "Project setup completed successfully."
