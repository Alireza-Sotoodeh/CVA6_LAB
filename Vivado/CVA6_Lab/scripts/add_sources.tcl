# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-14 01:03:14 +0330
# Status: NEW FILE
# Reason / Modification: Adds the cv32a6_imac_sv32 CVA6 RTL (335 files) from
#   imports/rtl/ into sources_1 of Vivado/CVA6_Lab/CVA6_Lab.xpr, in the
#   compile order of the reference fpga/vivado/cv32a6_imac_sv32.tcl, and sets
#   the include directories, Verilog defines and design top (cva6).
#   Run with: vivado -mode batch -source scripts/add_sources.tcl
# ============================================================================

set script_dir [file normalize [file dirname [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
cd $proj_dir

open_project [file join $proj_dir CVA6_Lab.xpr]

# --- remove any previous copies of these files, then re-add in order -------
set existing [get_files -quiet -of_objects [get_filesets sources_1]]
if {[llength $existing] > 0} {
    remove_files -fileset sources_1 $existing
}

# 1. tech cells (Xilinx FPGA implementations)
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/pad_functional_xilinx.sv \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_clk_xilinx.sv \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_sram_xilinx.sv \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/rtl/tc_sram_impl.sv \
]

# 2. tech cells (deprecated clock cells)
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clock_gating_async.sv \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/cluster_clk_cells.sv \
    imports/rtl/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clk_cells.sv \
]

# 3. common_cells - group 1
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/binary_to_gray.sv \
]

# 4. common_cells - group 2 (stream/fifo/cdc primitives)
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cb_filter_pkg.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cc_onehot.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_reset_ctrlr_pkg.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cf_math_pkg.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_int_div.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/credit_counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/delta_counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_pkg.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_tx.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/exp_backoff.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/fifo_v3.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/gray_to_binary.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/heaviside.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/isochronous_4phase_handshake.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/isochronous_spill_register.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr_16bit.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr_8bit.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lossy_valid_to_stream.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mv_filter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/onehot_to_bin.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/plru_tree.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/passthrough_stream_fifo.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/popcount.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ring_buffer.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rr_arb_tree.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rstgen_bypass.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/serial_deglitch.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/shift_reg.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/shift_reg_gated.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/spill_register_flushable.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_demux.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_filter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fork.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_intf.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_join_dynamic.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_mux.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_throttle.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sub_per_hash.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sync.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sync_wedge.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/unread.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/read.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode_dync.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/boxcar.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_2phase.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_4phase.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_int_div_static.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/trip_counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode_napot.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/multiaddr_decode.sv \
]

# 5. common_cells - group 3 (deprecated + edge propagators)
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cb_filter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_2phase.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_mux_glitch_free.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_decode.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_encode.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_detect.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lzc.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/max_counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rstgen.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/spill_register.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_delay.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fifo.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fork_dynamic.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_join.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_reset_ctrlr.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_gray.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/fall_through_register.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/id_queue.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_to_mem.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_arbiter_flushable.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fifo_optimal_wrap.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_register.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_xbar.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_gray_clearable.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_2phase_clearable.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mem_to_banks_detailed.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_arbiter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_omega_net.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mem_to_banks.sv \
]

# 6. fpu_div_sqrt_mvp
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clock_divider_counter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clk_div.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/find_first_one.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/generic_LFSR_8bit.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/generic_fifo.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/prioarbiter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/pulp_sync.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/pulp_sync_wedge.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/rrarbiter.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clock_divider.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/fifo_v2.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/fifo_v1.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_ack.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator.sv \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_rx.sv \
]

# 7. axi
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/defs_div_sqrt_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/iteration_div_sqrt_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/control_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/norm_div_sqrt_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/preprocess_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/nrbd_nrsc_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/div_sqrt_top_mvp.sv \
    imports/rtl/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/div_sqrt_mvp_wrapper.sv \
]

# 8. fpnew (floating point unit)
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_pkg.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_intf.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_atop_filter.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_burst_splitter.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc_dst.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc_src.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cut.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_delayer.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_demux.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_downsizer.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_upsizer.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_remap.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_prepend.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_isolate.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_join.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_demux.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_join.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_mailbox.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_mux.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_regs.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_to_apb.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_to_axi.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_modify_address.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_mux.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_serializer.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_err_slv.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_converter.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_serialize.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_multicut.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_to_axi_lite.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_iw_converter.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_xbar.sv \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_xbar.sv \
]

# 9. config_pkg
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_pkg.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_cast_multi.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_classifier.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ctrl.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ff1.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_pack_single.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_prepare.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_round_single.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_special.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_srt_single.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_top.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_dp.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_frbus.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_src_type.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ctrl.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_double.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ff1.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_pack.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_prepare.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_round.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_scalar_dp.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_with_sqrt.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_top.v \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_th_32.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_th_64_multi.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_multi.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/cvw/fma/fmalza.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_fma.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_fma_multi.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_noncomp.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_block.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_fmt_slice.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_multifmt_slice.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_rounding.sv \
    imports/rtl/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_top.sv \
]

# 10. cv32a6_imac_sv32_config_pkg
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/include/config_pkg.sv \
]

# 11. riscv_pkg / ariane_pkg / build_config_pkg
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/include/cv32a6_imac_sv32_config_pkg.sv \
]

# 12. accelerator first-pass decoder stub
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/include/riscv_pkg.sv \
    imports/rtl/core/include/ariane_pkg.sv \
    imports/rtl/core/include/build_config_pkg.sv \
]

# 13. cva6 MMU
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/cva6_accel_first_pass_decoder_stub.sv \
]

# 14. cvxif / packages / CVA6 core and pipeline
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/cva6_mmu/cva6_tlb.sv \
    imports/rtl/core/cva6_mmu/cva6_shared_tlb.sv \
    imports/rtl/core/cva6_mmu/cva6_mmu.sv \
    imports/rtl/core/cva6_mmu/cva6_ptw.sv \
]

# 15. CVA6 pmp
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/core/include/dummy_l15_pkg.sv \
    imports/rtl/core/include/wt_cache_pkg.sv \
    imports/rtl/core/include/std_cache_pkg.sv \
    imports/rtl/core/include/aes_pkg.sv \
    imports/rtl/core/cvxif_example/include/cvxif_instr_pkg.sv \
    imports/rtl/core/cvxif_fu.sv \
    imports/rtl/core/cvxif_issue_register_commit_if_driver.sv \
    imports/rtl/core/cvxif_compressed_if_driver.sv \
    imports/rtl/core/cvxif_example/cvxif_example_coprocessor.sv \
    imports/rtl/core/cvxif_example/instr_decoder.sv \
    imports/rtl/core/cva6_rvfi_probes.sv \
    imports/rtl/core/cva6_fifo_v3.sv \
    imports/rtl/core/cva6.sv \
    imports/rtl/core/aes.sv \
    imports/rtl/core/alu.sv \
    imports/rtl/core/alu_wrapper.sv \
    imports/rtl/core/fpu_wrap.sv \
    imports/rtl/core/branch_unit.sv \
    imports/rtl/core/compressed_decoder.sv \
    imports/rtl/core/controller.sv \
    imports/rtl/core/csr_buffer.sv \
    imports/rtl/core/csr_regfile.sv \
    imports/rtl/core/decoder.sv \
    imports/rtl/core/ex_stage.sv \
    imports/rtl/core/acc_dispatcher.sv \
    imports/rtl/core/instr_realign.sv \
    imports/rtl/core/id_stage.sv \
    imports/rtl/core/issue_read_operands.sv \
    imports/rtl/core/issue_stage.sv \
    imports/rtl/core/load_unit.sv \
    imports/rtl/core/load_store_unit.sv \
    imports/rtl/core/lsu_bypass.sv \
    imports/rtl/core/mult.sv \
    imports/rtl/core/multiplier.sv \
    imports/rtl/core/serdiv.sv \
    imports/rtl/core/perf_counters.sv \
    imports/rtl/core/ariane_regfile_ff.sv \
    imports/rtl/core/ariane_regfile_fpga.sv \
    imports/rtl/core/scoreboard.sv \
    imports/rtl/core/raw_checker.sv \
    imports/rtl/core/store_buffer.sv \
    imports/rtl/core/amo_buffer.sv \
    imports/rtl/core/store_unit.sv \
    imports/rtl/core/commit_stage.sv \
    imports/rtl/core/axi_shim.sv \
    imports/rtl/core/frontend/btb.sv \
    imports/rtl/core/frontend/bht.sv \
    imports/rtl/core/frontend/bht2lvl.sv \
    imports/rtl/core/frontend/ras.sv \
    imports/rtl/core/frontend/instr_scan.sv \
    imports/rtl/core/frontend/instr_queue.sv \
    imports/rtl/core/frontend/frontend.sv \
    imports/rtl/core/cache_subsystem/wt_dcache_ctrl.sv \
    imports/rtl/core/cache_subsystem/wt_dcache_mem.sv \
    imports/rtl/core/cache_subsystem/wt_dcache_missunit.sv \
    imports/rtl/core/cache_subsystem/wt_dcache_wbuffer.sv \
    imports/rtl/core/cache_subsystem/wt_dcache.sv \
    imports/rtl/core/cache_subsystem/wt_cache_subsystem.sv \
    imports/rtl/core/cache_subsystem/wt_axi_adapter.sv \
    imports/rtl/core/cache_subsystem/cva6_icache.sv \
    imports/rtl/core/cache_subsystem/tag_cmp.sv \
    imports/rtl/core/cache_subsystem/cva6_icache_axi_wrapper.sv \
    imports/rtl/core/cache_subsystem/axi_adapter.sv \
    imports/rtl/core/cache_subsystem/miss_handler.sv \
    imports/rtl/core/cache_subsystem/cache_ctrl.sv \
    imports/rtl/core/cache_subsystem/std_nbdcache.sv \
    imports/rtl/core/cache_subsystem/std_cache_subsystem.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_pkg.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_resp_demux.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_to_axi_read.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_to_axi_write.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_demux.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_lfsr.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sync_buffer.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fifo_reg.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fifo_reg_initialized.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fxarb.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_rrarb.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_mux.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_decoder.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_1hot_to_binary.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_prio_1hot_encoder.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_prio_bin_encoder.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram_wbyteenable.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram_wmask.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_regbank_wbyteenable_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_regbank_wmask_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_downsize.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_upsize.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_resize.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_pkg.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_arb.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_wrapper.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_amo.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_cmo.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_core_arbiter.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_ctrl.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_ctrl_pe.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_memctrl.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_miss_handler.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_mshr.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_rtab.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_uncached.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_plru.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_random.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_sel.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_wbuf.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_flush.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/hpdcache_cbuf.sv \
    imports/rtl/core/cache_subsystem/cva6_hpdcache_if_adapter.sv \
    imports/rtl/core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv \
    imports/rtl/core/cache_subsystem/cva6_hpdcache_subsystem.sv \
    imports/rtl/core/cache_subsystem/cva6_hpdcache_wrapper.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_pkg.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_36_29_dec.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_36_29_enc.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_39_32_dec.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_39_32_enc.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_55_48_dec.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_55_48_enc.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_72_64_dec.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_72_64_enc.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_ecc_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_ecc_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wmask_ecc_1rw.sv \
    imports/rtl/core/pmp/src/pmp.sv \
    imports/rtl/core/pmp/src/pmp_entry.sv \
    imports/rtl/core/pmp/src/pmp_data_if.sv \
]

# 16. common/local/util sram
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/common/local/util/sram.sv \
]

# 17. common/local/util sram wrappers + fpga-support
add_files -norecurse -fileset sources_1 [list \
    imports/rtl/common/local/util/sram_cache.sv \
    imports/rtl/common/local/util/tc_sram_fpga_wrapper.sv \
    imports/rtl/vendor/pulp-platform/fpga-support/rtl/SyncSpRamBeNx64.sv \
]

# --- include search paths ---------------------------------------------------
set_property include_dirs [list \
    imports/rtl/.bender/git/checkouts/axi-f14341c32cf56c49/include \
    imports/rtl/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include \
    imports/rtl/common/local/util \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/include \
    imports/rtl/core/cache_subsystem/hpdcache/rtl/src/utils/ecc \
    imports/rtl/core/include \
] [get_filesets sources_1]

# --- compile defines (same as the reference Vivado script) ------------------
set_property verilog_define [list \
    TARGET_CV32A6_IMAC_SV32 \
    TARGET_FPGA \
    TARGET_SYNTHESIS \
    TARGET_VIVADO \
    TARGET_XILINX \
] [get_filesets sources_1]

# --- design top -------------------------------------------------------------
set_property top cva6 [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "INFO: sources_1 files = [llength [get_files -of_objects [get_filesets sources_1]]]"
puts "INFO: sources_1 top   = [get_property top [get_filesets sources_1]]"
puts "INFO: include_dirs    = [get_property include_dirs [get_filesets sources_1]]"
puts "INFO: verilog_define  = [get_property verilog_define [get_filesets sources_1]]"

close_project
