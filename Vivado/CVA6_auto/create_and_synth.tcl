# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-15 15:10:00 +03:30
# Status: NEW FILE
# Reason / Modification: Automated CVA6 (cv32a6_imac_sv32) Vivado project creation, local import, verification, and OOC synthesis
# ============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_NAME "CVA6_auto"
set PART "xc7vx485tffg1157-1"
set ROOT "/home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/rtl"

puts "====================================================================="
puts " Step 1: Creating Vivado Project: $PROJ_NAME"
puts " Target FPGA: $PART"
puts "====================================================================="

create_project $PROJ_NAME $SCRIPT_DIR -part $PART -force

puts "====================================================================="
puts " Step 2: Registering CVA6 (cv32a6_imac_sv32) RTL Sources & Headers"
puts "====================================================================="

add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/pad_functional_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_clk_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/fpga/tc_sram_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/rtl/tc_sram_impl.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clock_gating_async.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/cluster_clk_cells.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-cc24c124b7267269/src/deprecated/pulp_clk_cells.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/binary_to_gray.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cb_filter_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cc_onehot.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_reset_ctrlr_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cf_math_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_int_div.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/credit_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/delta_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_tx.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/exp_backoff.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/fifo_v3.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/gray_to_binary.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/heaviside.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/isochronous_4phase_handshake.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/isochronous_spill_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr_16bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lfsr_8bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lossy_valid_to_stream.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mv_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/onehot_to_bin.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/plru_tree.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/passthrough_stream_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/popcount.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ring_buffer.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rr_arb_tree.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rstgen_bypass.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/serial_deglitch.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/shift_reg.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/shift_reg_gated.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/spill_register_flushable.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_demux.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fork.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_intf.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_join_dynamic.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_mux.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_throttle.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sub_per_hash.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sync.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/sync_wedge.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/unread.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/read.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode_dync.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/boxcar.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_2phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_4phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_int_div_static.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/trip_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/addr_decode_napot.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/multiaddr_decode.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cb_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_2phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/clk_mux_glitch_free.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_decode.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/ecc_encode.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_detect.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/lzc.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/max_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/rstgen.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/spill_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_delay.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fork_dynamic.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_join.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_reset_ctrlr.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_gray.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/fall_through_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/id_queue.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_to_mem.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_arbiter_flushable.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_fifo_optimal_wrap.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_xbar.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_fifo_gray_clearable.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/cdc_2phase_clearable.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mem_to_banks_detailed.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_arbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/stream_omega_net.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/mem_to_banks.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clock_divider_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clk_div.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/find_first_one.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/generic_LFSR_8bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/generic_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/prioarbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/pulp_sync.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/pulp_sync_wedge.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/rrarbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/clock_divider.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/fifo_v2.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/deprecated/fifo_v1.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_ack.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator.sv \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/src/edge_propagator_rx.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/defs_div_sqrt_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/iteration_div_sqrt_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/control_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/norm_div_sqrt_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/preprocess_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/nrbd_nrsc_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/div_sqrt_top_mvp.sv \
    $ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-dd98d4eaba0b805e/hdl/div_sqrt_mvp_wrapper.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_pkg.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_intf.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_atop_filter.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_burst_splitter.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc_dst.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc_src.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cut.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_delayer.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_demux.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_downsizer.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_upsizer.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_remap.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_prepend.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_isolate.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_join.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_demux.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_join.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_mailbox.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_mux.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_regs.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_to_apb.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_to_axi.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_modify_address.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_mux.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_serializer.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_cdc.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_err_slv.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_dw_converter.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_id_serialize.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_multicut.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_to_axi_lite.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_iw_converter.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_lite_xbar.sv \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/src/axi_xbar.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_pkg.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_cast_multi.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_classifier.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ctrl.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ff1.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_pack_single.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_prepare.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_round_single.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_special.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_srt_single.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_top.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_dp.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_frbus.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_src_type.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ctrl.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_double.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ff1.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_pack.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_prepare.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_round.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_scalar_dp.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_with_sqrt.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_top.v \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_th_32.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_th_64_multi.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_divsqrt_multi.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/vendor/cvw/fma/fmalza.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_fma.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_fma_multi.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_noncomp.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_block.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_fmt_slice.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_opgroup_multifmt_slice.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_rounding.sv \
    $ROOT/.bender/git/checkouts/fpnew-e0f7063a95eee5e4/src/fpnew_top.sv \
    $ROOT/core/include/config_pkg.sv \
    $ROOT/core/include/cv32a6_imac_sv32_config_pkg.sv \
    $ROOT/core/include/riscv_pkg.sv \
    $ROOT/core/include/ariane_pkg.sv \
    $ROOT/core/include/build_config_pkg.sv \
    $ROOT/core/cva6_accel_first_pass_decoder_stub.sv \
    $ROOT/core/cva6_mmu/cva6_tlb.sv \
    $ROOT/core/cva6_mmu/cva6_shared_tlb.sv \
    $ROOT/core/cva6_mmu/cva6_mmu.sv \
    $ROOT/core/cva6_mmu/cva6_ptw.sv \
    $ROOT/core/include/dummy_l15_pkg.sv \
    $ROOT/core/include/wt_cache_pkg.sv \
    $ROOT/core/include/std_cache_pkg.sv \
    $ROOT/core/include/aes_pkg.sv \
    $ROOT/core/cvxif_example/include/cvxif_instr_pkg.sv \
    $ROOT/core/cvxif_fu.sv \
    $ROOT/core/cvxif_issue_register_commit_if_driver.sv \
    $ROOT/core/cvxif_compressed_if_driver.sv \
    $ROOT/core/cvxif_example/cvxif_example_coprocessor.sv \
    $ROOT/core/cvxif_example/instr_decoder.sv \
    $ROOT/core/cva6_rvfi_probes.sv \
    $ROOT/core/cva6_fifo_v3.sv \
    $ROOT/core/cva6.sv \
    $ROOT/core/aes.sv \
    $ROOT/core/alu.sv \
    $ROOT/core/alu_wrapper.sv \
    $ROOT/core/fpu_wrap.sv \
    $ROOT/core/branch_unit.sv \
    $ROOT/core/compressed_decoder.sv \
    $ROOT/core/controller.sv \
    $ROOT/core/csr_buffer.sv \
    $ROOT/core/csr_regfile.sv \
    $ROOT/core/decoder.sv \
    $ROOT/core/ex_stage.sv \
    $ROOT/core/acc_dispatcher.sv \
    $ROOT/core/instr_realign.sv \
    $ROOT/core/id_stage.sv \
    $ROOT/core/issue_read_operands.sv \
    $ROOT/core/issue_stage.sv \
    $ROOT/core/load_unit.sv \
    $ROOT/core/load_store_unit.sv \
    $ROOT/core/lsu_bypass.sv \
    $ROOT/core/mult.sv \
    $ROOT/core/multiplier.sv \
    $ROOT/core/serdiv.sv \
    $ROOT/core/perf_counters.sv \
    $ROOT/core/ariane_regfile_ff.sv \
    $ROOT/core/ariane_regfile_fpga.sv \
    $ROOT/core/scoreboard.sv \
    $ROOT/core/raw_checker.sv \
    $ROOT/core/store_buffer.sv \
    $ROOT/core/amo_buffer.sv \
    $ROOT/core/store_unit.sv \
    $ROOT/core/commit_stage.sv \
    $ROOT/core/axi_shim.sv \
    $ROOT/core/frontend/btb.sv \
    $ROOT/core/frontend/bht.sv \
    $ROOT/core/frontend/bht2lvl.sv \
    $ROOT/core/frontend/ras.sv \
    $ROOT/core/frontend/instr_scan.sv \
    $ROOT/core/frontend/instr_queue.sv \
    $ROOT/core/frontend/frontend.sv \
    $ROOT/core/cache_subsystem/wt_dcache_ctrl.sv \
    $ROOT/core/cache_subsystem/wt_dcache_mem.sv \
    $ROOT/core/cache_subsystem/wt_dcache_missunit.sv \
    $ROOT/core/cache_subsystem/wt_dcache_wbuffer.sv \
    $ROOT/core/cache_subsystem/wt_dcache.sv \
    $ROOT/core/cache_subsystem/wt_cache_subsystem.sv \
    $ROOT/core/cache_subsystem/wt_axi_adapter.sv \
    $ROOT/core/cache_subsystem/cva6_icache.sv \
    $ROOT/core/cache_subsystem/tag_cmp.sv \
    $ROOT/core/cache_subsystem/cva6_icache_axi_wrapper.sv \
    $ROOT/core/cache_subsystem/axi_adapter.sv \
    $ROOT/core/cache_subsystem/miss_handler.sv \
    $ROOT/core/cache_subsystem/cache_ctrl.sv \
    $ROOT/core/cache_subsystem/std_nbdcache.sv \
    $ROOT/core/cache_subsystem/std_cache_subsystem.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_pkg.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_resp_demux.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_to_axi_read.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_to_axi_write.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_req_read_arbiter.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/hpdcache_mem_req_write_arbiter.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_demux.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_lfsr.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sync_buffer.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fifo_reg.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fifo_reg_initialized.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_fxarb.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_rrarb.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_mux.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_decoder.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_1hot_to_binary.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_prio_1hot_encoder.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_prio_bin_encoder.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram_wbyteenable.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_sram_wmask.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_regbank_wbyteenable_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_regbank_wmask_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_downsize.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_upsize.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_resize.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_pkg.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_arb.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hwpf_stride/hwpf_stride_wrapper.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_amo.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_cmo.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_core_arbiter.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_ctrl.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_ctrl_pe.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_memctrl.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_miss_handler.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_mshr.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_rtab.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_uncached.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_plru.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_random.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_victim_sel.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_wbuf.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_flush.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/hpdcache_cbuf.sv \
    $ROOT/core/cache_subsystem/cva6_hpdcache_if_adapter.sv \
    $ROOT/core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv \
    $ROOT/core/cache_subsystem/cva6_hpdcache_subsystem.sv \
    $ROOT/core/cache_subsystem/cva6_hpdcache_wrapper.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_pkg.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_36_29_dec.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_36_29_enc.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_39_32_dec.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_39_32_enc.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_55_48_dec.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_55_48_enc.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_72_64_dec.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_72_64_enc.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_ecc_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_ecc_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/hpdcache_sram_wmask_ecc_1rw.sv \
    $ROOT/core/pmp/src/pmp.sv \
    $ROOT/core/pmp/src/pmp_entry.sv \
    $ROOT/core/pmp/src/pmp_data_if.sv \
    $ROOT/common/local/util/sram.sv \
    $ROOT/common/local/util/sram_cache.sv \
    $ROOT/common/local/util/tc_sram_fpga_wrapper.sv \
    $ROOT/vendor/pulp-platform/fpga-support/rtl/SyncSpRamBeNx64.sv \
]

add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/include/axi/assign.svh \
    $ROOT/.bender/git/checkouts/axi-f14341c32cf56c49/include/axi/typedef.svh \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include/common_cells/assertions.svh \
    $ROOT/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include/common_cells/registers.svh \
    $ROOT/core/cache_subsystem/hpdcache/rtl/include/hpdcache_typedef.svh \
    $ROOT/core/cache_subsystem/hpdcache/rtl/src/utils/ecc/prim_secded_inc.svh \
    $ROOT/core/include/cvxif_types.svh \
    $ROOT/core/include/rvfi_types.svh \
]

# Add Out-of-Context timing constraints
add_files -fileset constrs_1 -norecurse "$SCRIPT_DIR/cva6_ooc.xdc"

puts "====================================================================="
puts " Step 3: Physically Importing Files into Local Project Tree"
puts "====================================================================="

# Physically copy all added source and constraint files into CVA6_auto.srcs/
import_files -fileset [current_fileset]
import_files -fileset constrs_1

set PRJ_DIR [get_property directory [current_project]]
set IMP_RTL "$PRJ_DIR/${PROJ_NAME}.srcs/sources_1/imports/rtl"

puts "====================================================================="
puts " Step 4: Configuring Local Include Dirs & Defines"
puts "====================================================================="

set_property include_dirs [list \
    "$IMP_RTL/.bender/git/checkouts/axi-f14341c32cf56c49/include" \
    "$IMP_RTL/.bender/git/checkouts/common_cells-7e395bb92335c3c4/include" \
    "$IMP_RTL/common/local/util" \
    "$IMP_RTL/core/cache_subsystem/hpdcache/rtl/include" \
    "$IMP_RTL/core/cache_subsystem/hpdcache/rtl/src/utils/ecc" \
    "$IMP_RTL/core/include" \
] [current_fileset]

set_property verilog_define [list \
    TARGET_CV32A6_IMAC_SV32 \
    TARGET_FPGA \
    TARGET_SYNTHESIS \
    TARGET_VIVADO \
    TARGET_XILINX \
] [current_fileset]

# Set Top Module explicitly
set_property top cva6 [current_fileset]
update_compile_order -fileset sources_1

puts "====================================================================="
puts " Step 5: Verification & Boundary Audits"
puts "====================================================================="

# 1. External files audit
set ext_files [get_files -filter {IS_EXTERNAL == 1}]
set ext_count [llength $ext_files]
puts "Audit [1/3] External Files Count: $ext_count"
if {$ext_count != 0} {
    puts "ERROR: Project contains $ext_count external file references!"
    exit 1
}

# 2. Check no 64-bit package is included
set p64 [get_files -filter {NAME =~ "*cv64a6*"}]
puts "Audit [2/3] Unwanted 64-bit files count: [llength $p64]"
if {[llength $p64] != 0} {
    puts "ERROR: Found 64-bit files in 32-bit project: $p64"
    exit 1
}

# 3. Top module validation
set top_module [get_property top [current_fileset]]
puts "Audit [3/3] Top Module: $top_module"
if {$top_module ne "cva6"} {
    puts "ERROR: Top module is $top_module (expected cva6)!"
    exit 1
}

puts "=== ALL VERIFICATION AUDITS PASSED ==="

puts "====================================================================="
puts " Step 6: Launching Out-of-Context Logic Synthesis"
puts "====================================================================="

# Ensure the constraint file is used during out-of-context synthesis
set_property USED_IN {synthesis implementation out_of_context} [get_files *cva6_ooc.xdc*]

# Configure Out-of-Context synthesis mode
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Launch synthesis using 6 jobs
launch_runs synth_1 -jobs 6

# Wait for synthesis run to finish
wait_on_run synth_1

# Check synthesis completion status
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis Status: $synth_status"
if {![string match "*Complete*" $synth_status]} {
    puts "ERROR: Synthesis did not complete successfully. Status: $synth_status"
    exit 1
}

puts "====================================================================="
puts " Step 7: Generating Utilization and Timing Reports"
puts "====================================================================="

open_run synth_1 -name synth_1

report_utilization -file "$PRJ_DIR/utilization_report.txt"
report_timing_summary -file "$PRJ_DIR/timing_summary_report.txt"

puts "Reports generated successfully:"
puts "  - Utilization: $PRJ_DIR/utilization_report.txt"
puts "  - Timing Summary: $PRJ_DIR/timing_summary_report.txt"
puts "====================================================================="
puts " CVA6 (CV32A6) Synthesis Workflow Finished Successfully!"
puts "====================================================================="
