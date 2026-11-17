// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: CVA6 Top-level module

`include "rvfi_types.svh"
`include "cvxif_types.svh"

module cva6_test
  import ariane_pkg::*;
  import cva6_types_pkg::*;
(

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Reset boot address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hard ID reflected as CSR - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Inter-processor (async) interrupt - SUBSYSTEM
    input logic ipi_i,
    // Timer (async) interrupt - SUBSYSTEM
    input logic time_irq_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t rvfi_probes_o,
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t cvxif_req_o,
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t cvxif_resp_i,
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input noc_resp_t noc_resp_i
);

  

  localparam interrupts_t INTERRUPTS = '{
      S_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_SOFT),
      VS_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_SOFT),
      M_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_SOFT),
      S_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_TIMER),
      VS_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_TIMER),
      M_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_TIMER),
      S_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_EXT),
      VS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_EXT),
      M_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_EXT),
      HS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_HS_EXT)
  };

  // ------------------------------------------
  // Global Signals
  // Signals connecting more than one module
  // ------------------------------------------
  riscv::priv_lvl_t priv_lvl;
  logic v;
  exception_t ex_commit;  // exception from commit stage
  bp_resolve_t resolved_branch;
  logic [CVA6Cfg.VLEN-1:0] pc_commit;
  logic eret;
  logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack;
  logic [CVA6Cfg.NrCommitPorts-1:0] commit_macro_ack;
  logic mbe;  // determines the data endian-ness of the processor

  localparam NumPorts = 4;

  // CVXIF
  cvxif_req_t cvxif_req;
  // CVXIF OUTPUTS
  logic x_compressed_valid;
  x_compressed_req_t x_compressed_req;
  logic x_issue_valid;
  x_issue_req_t x_issue_req;
  logic x_register_valid;
  x_register_t x_register;
  logic x_commit_valid;
  x_commit_t x_commit;
  logic x_result_ready;
  // CVXIF INPUTS
  logic x_compressed_ready;
  x_compressed_resp_t x_compressed_resp;
  logic x_issue_ready;
  x_issue_resp_t x_issue_resp;
  logic x_register_ready;
  logic x_result_valid;
  x_result_t x_result;

  // --------------
  // PCGEN <-> CSR
  // --------------
  logic [CVA6Cfg.VLEN-1:0] trap_vector_base_commit_pcgen;
  logic [CVA6Cfg.VLEN-1:0] epc_commit_pcgen;
  // --------------
  // IF <-> ID
  // --------------
  fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_if_id;
  logic [CVA6Cfg.NrIssuePorts-1:0] fetch_valid_if_id;
  logic [CVA6Cfg.NrIssuePorts-1:0] fetch_ready_id_if;

  // --------------
  // ID <-> ISSUE
  // --------------
  scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_entry_id_issue, issue_entry_id_issue_prev;
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_id_issue;
  logic [CVA6Cfg.NrIssuePorts-1:0] issue_entry_valid_id_issue;
  logic [CVA6Cfg.NrIssuePorts-1:0] is_ctrl_fow_id_issue;
  logic [CVA6Cfg.NrIssuePorts-1:0] issue_instr_issue_id;

  // --------------
  // ISSUE <-> EX
  // --------------
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_id_ex;  // unregistered version of fu_data_o.operanda
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_id_ex;  // unregistered version of fu_data_o.operandb
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs1;
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs2;

  fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_id_ex;
  alu_bypass_t alu_bypass_id_ex;
  logic [CVA6Cfg.VLEN-1:0] pc_id_ex;
  logic zcmt_id_ex;
  logic is_compressed_instr_id_ex;
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_ex;
  // fixed latency units
  logic flu_ready_ex_id;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] flu_trans_id_ex_id;
  logic flu_valid_ex_id;
  logic [CVA6Cfg.XLEN-1:0] flu_result_ex_id;
  exception_t flu_exception_ex_id;
  // ALU
  logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_id_ex;
  logic [5:0] orig_instr_aes;
  logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_id_ex;
  // Branches and Jumps
  logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_id_ex;

  branchpredict_sbe_t branch_predict_id_ex;
  logic resolve_branch_ex_id;
  // LSU
  logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_id_ex;
  logic lsu_ready_ex_id;

  logic [CVA6Cfg.TRANS_ID_BITS-1:0] load_trans_id_ex_id;
  logic [CVA6Cfg.XLEN-1:0] load_result_ex_id;
  logic load_valid_ex_id;
  exception_t load_exception_ex_id;

  logic [CVA6Cfg.XLEN-1:0] store_result_ex_id;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] store_trans_id_ex_id;
  logic store_valid_ex_id;
  exception_t store_exception_ex_id;
  // MULT
  logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_id_ex;
  // FPU
  logic fpu_ready_ex_id;
  logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_id_ex;
  logic [1:0] fpu_fmt_id_ex;
  logic [2:0] fpu_rm_id_ex;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id_ex_id;
  logic [CVA6Cfg.XLEN-1:0] fpu_result_ex_id;
  logic fpu_valid_ex_id;
  exception_t fpu_exception_ex_id;
  logic fpu_early_valid_ex_id;
  // ALU2
  logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_id_ex;
  // Accelerator
  logic stall_acc_id;
  scoreboard_entry_t issue_instr_id_acc;
  logic issue_instr_hs_id_acc;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] acc_trans_id_ex_id;
  logic [CVA6Cfg.XLEN-1:0] acc_result_ex_id;
  logic acc_valid_ex_id;
  exception_t acc_exception_ex_id;
  logic halt_acc_ctrl;
  logic [4:0] acc_resp_fflags;
  logic acc_resp_fflags_valid;
  logic single_step_acc_commit;
  // CSR
  logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_id_ex;
  logic csr_hs_ld_st_inst_ex;
  // CVXIF
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_ex_id;
  logic [CVA6Cfg.XLEN-1:0] x_result_ex_id;
  logic x_valid_ex_id;
  exception_t x_exception_ex_id;
  logic x_we_ex_id;
  logic [4:0] x_rd_ex_id;
  logic [CVA6Cfg.NrIssuePorts-1:0] x_issue_valid_id_ex;
  logic x_issue_ready_ex_id;
  logic [31:0] x_off_instr_id_ex;
  logic x_transaction_rejected;
  // --------------
  // EX <-> COMMIT
  // --------------
  // CSR Commit
  logic csr_commit_commit_ex;
  logic dirty_fp_state;
  logic dirty_v_state;
  // LSU Commit
  logic lsu_commit_commit_ex;
  logic lsu_commit_ready_ex_commit;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] lsu_commit_trans_id;
  logic stall_st_pending_ex;
  logic no_st_pending_ex;
  logic no_st_pending_commit;
  logic shared_tlb_flush_busy_ex;
  logic amo_valid_commit;
  // ACCEL Commit
  logic acc_valid_acc_ex;
  // --------------
  // EX <-> ACC_DISP
  // --------------
  acc_mmu_req_t acc_mmu_req;
  acc_mmu_resp_t acc_mmu_resp;
  // --------------
  // ID <-> COMMIT
  // --------------
  scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_id_commit;
  logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_id_commit;
  logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_commit_id;

  // --------------
  // RVFI
  // --------------
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_issue_pointer;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_commit_pointer;
  // --------------
  // COMMIT <-> ID
  // --------------
  logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_commit_id;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_commit_id;
  logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_commit_id;
  logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_commit_id;
  // --------------
  // CSR <-> *
  // --------------
  logic [4:0] fflags_csr_commit;
  riscv::xs_t fs;
  riscv::xs_t vfs;
  logic [2:0] frm_csr_id_issue_ex;
  logic [6:0] fprec_csr_ex;
  riscv::xs_t vs;
  logic enable_translation_csr_ex;
  logic enable_g_translation_csr_ex;
  logic en_ld_st_translation_csr_ex;
  logic en_ld_st_g_translation_csr_ex;
  riscv::priv_lvl_t ld_st_priv_lvl_csr_ex;
  logic ld_st_v_csr_ex;
  logic sum_csr_ex;
  logic vs_sum_csr_ex;
  logic mxr_csr_ex;
  logic vmxr_csr_ex;
  logic [CVA6Cfg.PPNW-1:0] satp_ppn_csr_ex;
  logic [CVA6Cfg.ASID_WIDTH-1:0] asid_csr_ex;
  logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_csr_ex;
  logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_csr_ex;
  logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_csr_ex;
  logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_csr_ex;
  logic [11:0] csr_addr_ex_csr;
  fu_op csr_op_commit_csr;
  logic [CVA6Cfg.XLEN-1:0] csr_wdata_commit_csr;
  logic [CVA6Cfg.XLEN-1:0] csr_rdata_csr_commit;
  exception_t csr_exception_csr_commit;
  logic tvm_csr_id;
  logic tw_csr_id;
  logic vtw_csr_id;
  logic tsr_csr_id;
  logic hu;
  irq_ctrl_t irq_ctrl_csr_id;
  logic dcache_en_csr;
  logic dcache_scrub_en_csr;
  logic [5:0] dcache_scrub_period_csr;
  logic dcache_scrub_cycle_csr;
  logic dcache_dat_cor_err_csr;
  logic dcache_dat_unc_err_csr;
  logic dcache_dir_cor_err_csr;
  logic dcache_dir_unc_err_csr;
  logic csr_write_fflags_commit_cs;
  logic icache_en_csr;
  logic acc_cons_en_csr;
  logic debug_mode;
  logic single_step_csr_commit;
  riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg;
  logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr;
  logic [31:0] mcountinhibit_csr_perf;
  //jvt
  jvt_t jvt;
  // trigger module
  logic
      sdtrig_commit_std_exception_valid,
      sdtrig_sb_std_exception_valid,
      sdtrig_load_stall,
      sdtrig_load_cancel,
      sdtrig_store_stall;
  logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action[CVA6Cfg.NrIssuePorts];
  logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action, sdtrig_store_action, sdtrig_commit_action;
  logic [CVA6Cfg.VLEN-1:0] sdtrig_lsu_inputs_operand_a;
  logic [CVA6Cfg.XLEN-1:0] sdtrig_lsu_inputs_operand_c;
  logic sdtrig_lsu_inputs_we, sdtrig_lsu_inputs_valid;
  logic sdtrig_commit_icount_valid;
  logic [$clog2(CVA6Cfg.NrCommitPorts)-1:0] sdtrig_commit_icount_nr_instr;

  riscv::cbie_t mcbie, scbie, hcbie;
  logic mcbcfe, scbcfe, hcbcfe;
  // ----------------------------
  // Performance Counters <-> *
  // ----------------------------
  logic [11:0] addr_csr_perf;
  logic [CVA6Cfg.XLEN-1:0] data_csr_perf, data_perf_csr;
  logic we_csr_perf;

  logic icache_flush_ctrl_cache;
  logic itlb_miss_ex_perf;
  logic dtlb_miss_ex_perf;
  logic dcache_miss_cache_perf;
  logic icache_miss_cache_perf;
  logic [NumPorts-1:0][CVA6Cfg.DCACHE_SET_ASSOC-1:0] miss_vld_bits;
  logic stall_issue;
  // --------------
  // CTRL <-> *
  // --------------
  logic set_pc_ctrl_pcgen;
  logic flush_csr_ctrl;
  logic flush_unissued_instr_ctrl_id;
  logic flush_ctrl_if;
  logic flush_ctrl_id;
  logic flush_ctrl_ex;
  logic flush_ctrl_bp;
  logic flush_tlb_ctrl_ex;
  logic flush_tlb_vvma_ctrl_ex;
  logic flush_tlb_gvma_ctrl_ex;
  logic fence_i_commit_controller;
  logic fence_commit_controller;
  logic sfence_vma_commit_controller;
  logic hfence_vvma_commit_controller;
  logic hfence_gvma_commit_controller;
  logic halt_ctrl;
  logic halt_frontend;
  logic halt_csr_ctrl;
  logic dcache_flush_ctrl_cache;
  logic dcache_flush_ack_cache_ctrl;
  logic set_debug_pc;
  logic flush_commit;
  logic flush_acc;

  icache_areq_t icache_areq_ex_cache;
  icache_arsp_t icache_areq_cache_ex;
  icache_dreq_t icache_dreq_if_cache;
  icache_drsp_t icache_dreq_cache_if;

  amo_req_t amo_req;
  amo_resp_t amo_resp;
  logic sb_full;

  // ----------------
  // DCache <-> *
  // ----------------
  dcache_req_i_t [2:0] dcache_req_ports_ex_cache;
  dcache_req_o_t [2:0] dcache_req_ports_cache_ex;
  dcache_req_i_t dcache_req_ports_id_cache;
  dcache_req_o_t dcache_req_ports_cache_id;
  dcache_req_i_t [1:0] dcache_req_ports_acc_cache;
  dcache_req_o_t [1:0] dcache_req_ports_cache_acc;
  logic dcache_commit_wbuffer_empty;
  logic dcache_commit_wbuffer_not_ni;

  //RVFI
  lsu_ctrl_t rvfi_lsu_ctrl;
  logic [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr;
  logic [CVA6Cfg.NrIssuePorts-1:0] rvfi_is_compressed;
  rvfi_probes_csr_t rvfi_csr;

  // Accelerator port
  logic [63:0] inval_addr;
  logic inval_valid;
  logic inval_ready;

  // --------------
  // Frontend
  // --------------
  frontend  i_frontend (
      .clk_i,
      .rst_ni,
      .boot_addr_i        (boot_addr_i[CVA6Cfg.VLEN-1:0]),
      .flush_bp_i         ((CVA6Cfg.RVU || CVA6Cfg.RVS) ? flush_ctrl_bp : 1'b0),
      // below line is not entirely correct
      .flush_i            (flush_ctrl_if),
      .halt_i             (halt_ctrl),
      .halt_frontend_i    (halt_frontend),
      .set_pc_commit_i    (set_pc_ctrl_pcgen),
      .pc_commit_i        (pc_commit),
      .ex_valid_i         (ex_commit.valid),
      .resolved_branch_i  (resolved_branch),
      .eret_i             (eret),
      .epc_i              (epc_commit_pcgen),
      .trap_vector_base_i (trap_vector_base_commit_pcgen),
      .set_debug_pc_i     (set_debug_pc),
      .debug_mode_i       (debug_mode),
      .icache_dreq_o      (icache_dreq_if_cache),
      .icache_dreq_i      (icache_dreq_cache_if),
      .fetch_entry_o      (fetch_entry_if_id),
      .fetch_entry_valid_o(fetch_valid_if_id),
      .fetch_entry_ready_i(fetch_ready_id_if)
  );

  // ---------
  // ID
  // ---------
  id_stage #(
      
      
      
      
      
      
      
      
      
      
      .INTERRUPTS(INTERRUPTS)
      
      ) id_stage_i (
      .clk_i,
      .rst_ni,
      .flush_i(flush_ctrl_if),
      .debug_req_i,

      .fetch_entry_i      (fetch_entry_if_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .fetch_entry_ready_o(fetch_ready_id_if),

      .issue_entry_o      (issue_entry_id_issue),
      .issue_entry_o_prev (issue_entry_id_issue_prev),
      .orig_instr_o       (orig_instr_id_issue),
      .issue_entry_valid_o(issue_entry_valid_id_issue),
      .is_ctrl_flow_o     (is_ctrl_fow_id_issue),
      .issue_instr_ack_i  (issue_instr_issue_id),

      .rvfi_is_compressed_o(rvfi_is_compressed),

      .priv_lvl_i             (priv_lvl),
      .v_i                    (v),
      .fs_i                   (fs),
      .vfs_i                  (vfs),
      .frm_i                  (frm_csr_id_issue_ex),
      .vs_i                   (vs),
      .irq_i                  (irq_i),
      .irq_ctrl_i             (irq_ctrl_csr_id),
      .debug_mode_i           (debug_mode),
      .tvm_i                  (tvm_csr_id),
      .tw_i                   (tw_csr_id),
      .vtw_i                  (vtw_csr_id),
      .tsr_i                  (tsr_csr_id),
      .hu_i                   (hu),
      .mcbie_i                (mcbie),
      .scbie_i                (scbie),
      .hcbie_i                (hcbie),
      .mcbcfe_i               (mcbcfe),
      .scbcfe_i               (scbcfe),
      .hcbcfe_i               (hcbcfe),
      .hart_id_i              (hart_id_i),
      .compressed_ready_i     (x_compressed_ready),
      .compressed_resp_i      (x_compressed_resp),
      .compressed_valid_o     (x_compressed_valid),
      .compressed_req_o       (x_compressed_req),
      .jvt_i                  (jvt),
      // DCACHE interfaces
      .dcache_req_ports_i     (dcache_req_ports_cache_id),
      .dcache_req_ports_o     (dcache_req_ports_id_cache),
      //Trigger Module command signal
      .sdtrig_decoder_action_i(sdtrig_decoder_action)
  );

  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_ex_id;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_ex_id;
  exception_t [CVA6Cfg.NrWbPorts-1:0] ex_ex_ex_id;  // exception from execute, ex_stage to id_stage
  logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_ex_id;

  assign trans_id_ex_id[FLU_WB] = flu_trans_id_ex_id;
  assign wbdata_ex_id[FLU_WB]   = flu_result_ex_id;
  assign ex_ex_ex_id[FLU_WB]    = flu_exception_ex_id;
  assign wt_valid_ex_id[FLU_WB] = flu_valid_ex_id;

  assign trans_id_ex_id[STORE_WB] = store_trans_id_ex_id;
  assign wbdata_ex_id[STORE_WB]   = store_result_ex_id;
  assign ex_ex_ex_id[STORE_WB]    = store_exception_ex_id;
  assign wt_valid_ex_id[STORE_WB] = store_valid_ex_id;

  assign trans_id_ex_id[LOAD_WB] = load_trans_id_ex_id;
  assign wbdata_ex_id[LOAD_WB]   = load_result_ex_id;
  assign ex_ex_ex_id[LOAD_WB]    = load_exception_ex_id;
  assign wt_valid_ex_id[LOAD_WB] = load_valid_ex_id;

  assign trans_id_ex_id[FPU_WB] = fpu_trans_id_ex_id;
  assign wbdata_ex_id[FPU_WB]   = fpu_result_ex_id;
  assign ex_ex_ex_id[FPU_WB]    = fpu_exception_ex_id;
  assign wt_valid_ex_id[FPU_WB] = fpu_valid_ex_id;

  if (CVA6Cfg.CvxifEn) begin
    always_comb begin : gen_cvxif_input_assignment
      x_compressed_ready = cvxif_resp_i.compressed_ready;
      x_compressed_resp  = cvxif_resp_i.compressed_resp;
      x_issue_ready      = cvxif_resp_i.issue_ready;
      x_issue_resp       = cvxif_resp_i.issue_resp;
      x_register_ready   = cvxif_resp_i.register_ready;
      x_result_valid     = cvxif_resp_i.result_valid;
      x_result           = cvxif_resp_i.result;
    end

    always_comb begin : gen_cvxif_output_assignment
      cvxif_req.compressed_valid = x_compressed_valid;
      cvxif_req.compressed_req   = x_compressed_req;
      cvxif_req.issue_valid      = x_issue_valid;
      cvxif_req.issue_req        = x_issue_req;
      cvxif_req.register_valid   = x_register_valid;
      cvxif_req.register         = x_register;
      cvxif_req.commit_valid     = x_commit_valid;
      cvxif_req.commit           = x_commit;
      cvxif_req.result_ready     = x_result_ready;
    end
    assign trans_id_ex_id[X_WB] = x_trans_id_ex_id;
    assign wbdata_ex_id[X_WB]   = x_result_ex_id;
    assign ex_ex_ex_id[X_WB]    = x_exception_ex_id;
    assign wt_valid_ex_id[X_WB] = x_valid_ex_id;
  end else if (CVA6Cfg.EnableAccelerator) begin
    assign cvxif_req = '0;
    assign trans_id_ex_id[ACC_WB] = acc_trans_id_ex_id;
    assign wbdata_ex_id[ACC_WB]   = acc_result_ex_id;
    assign ex_ex_ex_id[ACC_WB]    = acc_exception_ex_id;
    assign wt_valid_ex_id[ACC_WB] = acc_valid_ex_id;
  end else begin
    assign cvxif_req = '0;
    assign x_compressed_ready = '0;
    assign x_compressed_resp = '0;
    assign x_issue_ready = '0;
    assign x_issue_resp = '0;
    assign x_register_ready = '0;
    assign x_result_valid = '0;
    assign x_result = '0;
  end

  if (CVA6Cfg.CvxifEn && CVA6Cfg.EnableAccelerator) begin : gen_err_xif_and_acc
    $error("X-interface and accelerator port cannot be enabled at the same time.");
  end

  // ---------
  // Issue
  // ---------
  issue_stage  issue_stage_i (
      .clk_i,
      .rst_ni,
      .sb_full_o               (sb_full),
      .flush_unissued_instr_i  (flush_unissued_instr_ctrl_id),
      .flush_i                 (flush_ctrl_id),
      .stall_i                 (stall_acc_id),
      // ID Stage
      .decoded_instr_i         (issue_entry_id_issue),
      .decoded_instr_i_prev    (issue_entry_id_issue_prev),
      .orig_instr_i            (orig_instr_id_issue),
      .decoded_instr_valid_i   (issue_entry_valid_id_issue),
      .is_ctrl_flow_i          (is_ctrl_fow_id_issue),
      .decoded_instr_ack_o     (issue_instr_issue_id),
      // Functional Units
      .rs1_forwarding_o        (rs1_forwarding_id_ex),
      .rs2_forwarding_o        (rs2_forwarding_id_ex),
      .fu_data_o               (fu_data_id_ex),
      .alu_bypass_o            (alu_bypass_id_ex),
      .pc_o                    (pc_id_ex),
      .is_zcmt_o               (zcmt_id_ex),
      .is_compressed_instr_o   (is_compressed_instr_id_ex),
      .tinst_o                 (tinst_ex),
      // fixed latency unit ready
      .flu_ready_i             (flu_ready_ex_id),
      // ALU
      .alu_valid_o             (alu_valid_id_ex),
      .aes_valid_o             (aes_valid_id_ex),
      // Branches and Jumps
      .branch_valid_o          (branch_valid_id_ex),            // branch is valid
      .branch_predict_o        (branch_predict_id_ex),          // branch predict to ex
      .resolve_branch_i        (resolve_branch_ex_id),          // in order to resolve the branch
      // LSU
      .lsu_ready_i             (lsu_ready_ex_id),
      .lsu_valid_o             (lsu_valid_id_ex),
      // Multiplier
      .mult_valid_o            (mult_valid_id_ex),
      // FPU
      .fpu_ready_i             (fpu_ready_ex_id),
      .fpu_valid_o             (fpu_valid_id_ex),
      .fpu_fmt_o               (fpu_fmt_id_ex),
      .fpu_rm_o                (fpu_rm_id_ex),
      .fpu_early_valid_i       (fpu_early_valid_ex_id),
      // ALU2
      .alu2_valid_o            (alu2_valid_id_ex),
      // CSR
      .csr_valid_o             (csr_valid_id_ex),
      // CVXIF
      .xfu_valid_o             (x_issue_valid_id_ex),
      .xfu_ready_i             (x_issue_ready_ex_id),
      .x_off_instr_o           (x_off_instr_id_ex),
      .hart_id_i               (hart_id_i),
      .x_issue_ready_i         (x_issue_ready),
      .x_issue_resp_i          (x_issue_resp),
      .x_issue_valid_o         (x_issue_valid),
      .x_issue_req_o           (x_issue_req),
      .x_register_ready_i      (x_register_ready),
      .x_register_valid_o      (x_register_valid),
      .x_register_o            (x_register),
      .x_commit_valid_o        (x_commit_valid),
      .x_commit_o              (x_commit),
      .x_transaction_rejected_o(x_transaction_rejected),
      // Accelerator
      .issue_instr_o           (issue_instr_id_acc),
      .issue_instr_hs_o        (issue_instr_hs_id_acc),
      // Commit
      .trans_id_i              (trans_id_ex_id),
      .resolved_branch_i       (resolved_branch),
      .wbdata_i                (wbdata_ex_id),
      .ex_ex_i                 (ex_ex_ex_id),
      .wt_valid_i              (wt_valid_ex_id),
      .x_we_i                  (x_we_ex_id),
      .x_rd_i                  (x_rd_ex_id),

      .waddr_i              (waddr_commit_id),
      .wdata_i              (wdata_commit_id),
      .we_gpr_i             (we_gpr_commit_id),
      .we_fpr_i             (we_fpr_commit_id),
      .commit_instr_o       (commit_instr_id_commit),
      .commit_drop_o        (commit_drop_id_commit),
      .commit_ack_i         (commit_ack_commit_id),
      // Performance Counters
      .stall_issue_o        (stall_issue),
      //RVFI
      .rvfi_issue_pointer_o (rvfi_issue_pointer),
      .rvfi_commit_pointer_o(rvfi_commit_pointer),
      .rvfi_rs1_o           (rvfi_rs1),
      .rvfi_rs2_o           (rvfi_rs2),
      .orig_instr_aes_bits  (orig_instr_aes)
  );

  // ---------
  // EX
  // ---------
  
    assign flu_result_ex_id = '0;
    assign flu_trans_id_ex_id = '0;
    assign flu_valid_ex_id = '0;
    assign flu_exception_ex_id = '0;
    assign flu_ready_ex_id = 1'b1;
    assign resolved_branch = '0;
    assign resolve_branch_ex_id = '0;
    assign csr_addr_ex_csr = '0;
    assign csr_hs_ld_st_inst_ex = '0;
    assign lsu_ready_ex_id = 1'b1;
    assign load_result_ex_id = '0;
    assign load_trans_id_ex_id = '0;
    assign load_valid_ex_id = '0;
    assign load_exception_ex_id = '0;
    assign store_result_ex_id = '0;
    assign store_trans_id_ex_id = '0;
    assign store_valid_ex_id = '0;
    assign store_exception_ex_id = '0;
    assign lsu_commit_ready_ex_commit = 1'b1;
    assign shared_tlb_flush_busy_ex = '0;
    assign no_st_pending_ex = 1'b1;
    assign fpu_ready_ex_id = 1'b1;
    assign fpu_trans_id_ex_id = '0;
    assign fpu_result_ex_id = '0;
    assign fpu_valid_ex_id = '0;
    assign fpu_exception_ex_id = '0;
    assign fpu_early_valid_ex_id = '0;
    assign amo_req = '0;
    assign x_issue_ready_ex_id = 1'b1;
    assign x_trans_id_ex_id = '0;
    assign x_exception_ex_id = '0;
    assign x_result_ex_id = '0;
    assign x_valid_ex_id = '0;
    assign x_we_ex_id = '0;
    assign x_rd_ex_id = '0;
    assign x_result_ready = 1'b1;
    assign acc_mmu_resp = '0;
    assign itlb_miss_ex_perf = '0;
    assign dtlb_miss_ex_perf = '0;


  // ---------
  // Commit
  // ---------

  // we have to make sure that the whole write buffer path is empty before
  // used e.g. for fence instructions.
  assign no_st_pending_commit = no_st_pending_ex & dcache_commit_wbuffer_empty;

  commit_stage  commit_stage_i (
      .clk_i,
      .rst_ni,
      .halt_i                             (halt_ctrl),
      .flush_dcache_i                     (dcache_flush_ctrl_cache),
      .exception_o                        (ex_commit),
      .dirty_fp_state_o                   (dirty_fp_state),
      .single_step_i                      (single_step_csr_commit || single_step_acc_commit),
      .commit_instr_i                     (commit_instr_id_commit),
      .commit_drop_i                      (commit_drop_id_commit),
      .commit_ack_o                       (commit_ack_commit_id),
      .commit_macro_ack_o                 (commit_macro_ack),
      .waddr_o                            (waddr_commit_id),
      .wdata_o                            (wdata_commit_id),
      .we_gpr_o                           (we_gpr_commit_id),
      .we_fpr_o                           (we_fpr_commit_id),
      .amo_resp_i                         (amo_resp),
      .pc_o                               (pc_commit),
      .csr_op_o                           (csr_op_commit_csr),
      .csr_wdata_o                        (csr_wdata_commit_csr),
      .csr_rdata_i                        (csr_rdata_csr_commit),
      .csr_write_fflags_o                 (csr_write_fflags_commit_cs),
      .csr_exception_i                    (csr_exception_csr_commit),
      .commit_lsu_o                       (lsu_commit_commit_ex),
      .commit_lsu_ready_i                 (lsu_commit_ready_ex_commit),
      .commit_tran_id_o                   (lsu_commit_trans_id),
      .amo_valid_commit_o                 (amo_valid_commit),
      .no_st_pending_i                    (no_st_pending_commit),
      .shared_tlb_flush_busy_i            (shared_tlb_flush_busy_ex),
      .commit_csr_o                       (csr_commit_commit_ex),
      .fence_i_o                          (fence_i_commit_controller),
      .fence_o                            (fence_commit_controller),
      .flush_commit_o                     (flush_commit),
      .sfence_vma_o                       (sfence_vma_commit_controller),
      .hfence_vvma_o                      (hfence_vvma_commit_controller),
      .hfence_gvma_o                      (hfence_gvma_commit_controller),
      .sdtrig_commit_std_exception_valid_i(sdtrig_commit_std_exception_valid),
      .sdtrig_commit_icount_valid_i       (sdtrig_commit_icount_valid),
      .sdtrig_commit_action_i             (sdtrig_commit_action),
      .sdtrig_commit_icount_nr_instr_i    (sdtrig_commit_icount_nr_instr)
  );

  assign commit_ack = commit_macro_ack & ~commit_drop_id_commit;

  // ---------
  // CSR
  // ---------

  //Trigger Module assignments
  logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] fetch_sdtrig_pc;
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] fetch_sdtrig_instr;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; ++i) begin
    assign fetch_sdtrig_pc[i] = CVA6Cfg.SdtrigMcontrol6ExecAddr ? fetch_entry_if_id[i].address : '0;
    assign fetch_sdtrig_instr[i] = CVA6Cfg.SdtrigMcontrol6ExecData ? fetch_entry_if_id[i].instruction : '0;
  end

  csr_regfile #(
      
      
      
      
      
      
      .MHPMCounterNum    (MHPMCounterNum)
  ) csr_regfile_i (
      .clk_i,
      .rst_ni,
      .time_irq_i,
      .flush_o                            (flush_csr_ctrl),
      .halt_csr_o                         (halt_csr_ctrl),
      .commit_instr_i                     (commit_instr_id_commit[0]),
      .commit_ack_i                       (commit_ack),
      .boot_addr_i                        (boot_addr_i[CVA6Cfg.VLEN-1:0]),
      .hart_id_i                          (hart_id_i[CVA6Cfg.XLEN-1:0]),
      .ex_i                               (ex_commit),
      .csr_op_i                           (csr_op_commit_csr),
      .csr_addr_i                         (csr_addr_ex_csr),
      .csr_wdata_i                        (csr_wdata_commit_csr),
      .csr_rdata_o                        (csr_rdata_csr_commit),
      .dirty_fp_state_i                   (dirty_fp_state),
      .csr_write_fflags_i                 (csr_write_fflags_commit_cs),
      .dirty_v_state_i                    (dirty_v_state),
      .pc_i                               (pc_commit),
      .csr_exception_o                    (csr_exception_csr_commit),
      .epc_o                              (epc_commit_pcgen),
      .eret_o                             (eret),
      .trap_vector_base_o                 (trap_vector_base_commit_pcgen),
      .priv_lvl_o                         (priv_lvl),
      .mbe_o                              (mbe),
      .v_o                                (v),
      .acc_fflags_ex_i                    (acc_resp_fflags),
      .acc_fflags_ex_valid_i              (acc_resp_fflags_valid),
      .fs_o                               (fs),
      .vfs_o                              (vfs),
      .fflags_o                           (fflags_csr_commit),
      .frm_o                              (frm_csr_id_issue_ex),
      .fprec_o                            (fprec_csr_ex),
      .vs_o                               (vs),
      .irq_ctrl_o                         (irq_ctrl_csr_id),
      .en_translation_o                   (enable_translation_csr_ex),
      .en_g_translation_o                 (enable_g_translation_csr_ex),
      .en_ld_st_translation_o             (en_ld_st_translation_csr_ex),
      .en_ld_st_g_translation_o           (en_ld_st_g_translation_csr_ex),
      .ld_st_priv_lvl_o                   (ld_st_priv_lvl_csr_ex),
      .ld_st_v_o                          (ld_st_v_csr_ex),
      .csr_hs_ld_st_inst_i                (csr_hs_ld_st_inst_ex),
      .sum_o                              (sum_csr_ex),
      .vs_sum_o                           (vs_sum_csr_ex),
      .mxr_o                              (mxr_csr_ex),
      .vmxr_o                             (vmxr_csr_ex),
      .satp_ppn_o                         (satp_ppn_csr_ex),
      .asid_o                             (asid_csr_ex),
      .vsatp_ppn_o                        (vsatp_ppn_csr_ex),
      .vs_asid_o                          (vs_asid_csr_ex),
      .hgatp_ppn_o                        (hgatp_ppn_csr_ex),
      .vmid_o                             (vmid_csr_ex),
      .irq_i,
      .ipi_i,
      .debug_req_i,
      .set_debug_pc_o                     (set_debug_pc),
      .tvm_o                              (tvm_csr_id),
      .tw_o                               (tw_csr_id),
      .vtw_o                              (vtw_csr_id),
      .tsr_o                              (tsr_csr_id),
      .hu_o                               (hu),
      .debug_mode_o                       (debug_mode),
      .single_step_o                      (single_step_csr_commit),
      .icache_en_o                        (icache_en_csr),
      .dcache_en_o                        (dcache_en_csr),
      .dcache_scrub_en_o                  (dcache_scrub_en_csr),
      .dcache_scrub_period_o              (dcache_scrub_period_csr),
      .dcache_scrub_cycle_i               (dcache_scrub_cycle_csr),
      .dcache_dat_cor_err_i               (dcache_dat_cor_err_csr),
      .dcache_dat_unc_err_i               (dcache_dat_unc_err_csr),
      .dcache_dir_cor_err_i               (dcache_dir_cor_err_csr),
      .dcache_dir_unc_err_i               (dcache_dir_unc_err_csr),
      .acc_cons_en_o                      (acc_cons_en_csr),
      .perf_addr_o                        (addr_csr_perf),
      .perf_data_o                        (data_csr_perf),
      .perf_data_i                        (data_perf_csr),
      .perf_we_o                          (we_csr_perf),
      .pmpcfg_o                           (pmpcfg),
      .pmpaddr_o                          (pmpaddr),
      .mcountinhibit_o                    (mcountinhibit_csr_perf),
      .mcbie_o                            (mcbie),
      .scbie_o                            (scbie),
      .hcbie_o                            (hcbie),
      .mcbcfe_o                           (mcbcfe),
      .scbcfe_o                           (scbcfe),
      .hcbcfe_o                           (hcbcfe),
      .jvt_o                              (jvt),
      //RVFI
      .rvfi_csr_o                         (rvfi_csr),
      // Trigger Signals
      .sdtrig_commit_std_exception_valid_o(sdtrig_commit_std_exception_valid),
      //Decoder/FE <-> Trigger Module
      .fetch_sdtrig_pc_i                  (fetch_sdtrig_pc),
      .fetch_sdtrig_instr_i               (fetch_sdtrig_instr),
      .sdtrig_decoder_action_o            (sdtrig_decoder_action),
      //Load/Store Unit <-> Trigger Module
      .sdtrig_lsu_inputs_vaddr_i          (sdtrig_lsu_inputs_operand_a),
      .sdtrig_lsu_inputs_data_i           (sdtrig_lsu_inputs_operand_c),
      .sdtrig_lsu_inputs_fu_i             (sdtrig_lsu_inputs_we),
      .sdtrig_lsu_inputs_valid_i          (sdtrig_lsu_inputs_valid),
      .sdtrig_load_data_i                 (load_result_ex_id),
      .sdtrig_load_valid_i                (load_valid_ex_id),
      .sdtrig_load_stall_o                (sdtrig_load_stall),
      .sdtrig_load_cancel_o               (sdtrig_load_cancel),
      .sdtrig_load_action_o               (sdtrig_load_action),
      .sdtrig_store_stall_o               (sdtrig_store_stall),
      .sdtrig_store_action_o              (sdtrig_store_action),
      //Commit <- Trigger module
      .sdtrig_commit_icount_valid_o       (sdtrig_commit_icount_valid),
      .sdtrig_commit_action_o             (sdtrig_commit_action),
      .sdtrig_commit_icount_nr_instr_o    (sdtrig_commit_icount_nr_instr)
  );

  // ------------------------
  // Performance Counters
  // ------------------------
  if (CVA6Cfg.PerfCounterEn) begin : gen_perf_counter
    perf_counters #(
        
        
        
        
        
        
        
        .NumPorts(NumPorts)
    ) perf_counters_i (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .debug_mode_i  (debug_mode),
        .addr_i        (addr_csr_perf),
        .we_i          (we_csr_perf),
        .data_i        (data_csr_perf),
        .data_o        (data_perf_csr),
        .commit_instr_i(commit_instr_id_commit),
        .commit_ack_i  (commit_ack),

        .l1_icache_miss_i   (icache_miss_cache_perf),
        .l1_dcache_miss_i   (dcache_miss_cache_perf),
        .itlb_miss_i        (itlb_miss_ex_perf),
        .dtlb_miss_i        (dtlb_miss_ex_perf),
        .sb_full_i          (sb_full),
        // TODO this is more complex that that
        // If superscalar then we additionally have to check [1] when transaction 0 succeeded
        .if_empty_i         (~fetch_valid_if_id[0]),
        .ex_i               (ex_commit),
        .eret_i             (eret),
        .resolved_branch_i  (resolved_branch),
        .branch_exceptions_i(flu_exception_ex_id),
        .l1_icache_access_i (icache_dreq_if_cache),
        .l1_dcache_access_i (dcache_req_ports_ex_cache),
        .miss_vld_bits_i    (miss_vld_bits),
        .i_tlb_flush_i      (flush_tlb_ctrl_ex),
        .stall_issue_i      (stall_issue),
        .mcountinhibit_i    (mcountinhibit_csr_perf)
    );
  end : gen_perf_counter
  else begin : gen_no_perf_counter
    assign data_perf_csr = '0;
  end : gen_no_perf_counter

  // ------------
  // Controller
  // ------------
  controller  controller_i (
      .clk_i,
      .rst_ni,
      // virtualization mode
      .v_i                   (v),
      // flush ports
      .set_pc_commit_o       (set_pc_ctrl_pcgen),
      .flush_if_o            (flush_ctrl_if),
      .flush_unissued_instr_o(flush_unissued_instr_ctrl_id),
      .flush_id_o            (flush_ctrl_id),
      .flush_ex_o            (flush_ctrl_ex),
      .flush_bp_o            (flush_ctrl_bp),
      .flush_icache_o        (icache_flush_ctrl_cache),
      .flush_dcache_o        (dcache_flush_ctrl_cache),
      .flush_dcache_ack_i    (dcache_flush_ack_cache_ctrl),
      .flush_tlb_o           (flush_tlb_ctrl_ex),
      .flush_tlb_vvma_o      (flush_tlb_vvma_ctrl_ex),
      .flush_tlb_gvma_o      (flush_tlb_gvma_ctrl_ex),
      .halt_csr_i            (halt_csr_ctrl),
      .halt_acc_i            (halt_acc_ctrl),
      .halt_frontend_o       (halt_frontend),
      .halt_o                (halt_ctrl),
      // control ports
      .eret_i                (eret),
      .ex_valid_i            (ex_commit.valid),
      .set_debug_pc_i        (set_debug_pc),
      .resolved_branch_i     (resolved_branch),
      .flush_csr_i           (flush_csr_ctrl),
      .fence_i_i             (fence_i_commit_controller),
      .fence_i               (fence_commit_controller),
      .sfence_vma_i          (sfence_vma_commit_controller),
      .hfence_vvma_i         (hfence_vvma_commit_controller),
      .hfence_gvma_i         (hfence_gvma_commit_controller),
      .flush_commit_i        (flush_commit),
      .flush_acc_i           (flush_acc)
  );

  // -------------------
  // Cache Subsystem
  // -------------------

  // Acc dispatcher and store buffer share a dcache request port.
  // Store buffer always has priority access over acc dispatcher.
  dcache_req_i_t [NumPorts-1:0] dcache_req_to_cache;
  dcache_req_o_t [NumPorts-1:0] dcache_req_from_cache;

  // D$ request
  // Since ZCMT is only enabled for embedded class so MMU should be disabled.
  // Cache port 0 is being utilized in implicit read access in ZCMT extension.
  if (CVA6Cfg.RVZCMT & ~(CVA6Cfg.MmuPresent)) begin
    assign dcache_req_to_cache[0] = dcache_req_ports_id_cache;
  end else begin
    assign dcache_req_to_cache[0] = dcache_req_ports_ex_cache[0];
  end
  assign dcache_req_to_cache[1] = dcache_req_ports_ex_cache[1];
  assign dcache_req_to_cache[2] = dcache_req_ports_acc_cache[0];
  assign dcache_req_to_cache[3] = dcache_req_ports_ex_cache[2].data_req ? dcache_req_ports_ex_cache [2] :
                                                                          dcache_req_ports_acc_cache[1];

  // D$ response
  // Since ZCMT is only enabled for embedded class so MMU should be disabled.
  // Cache port 0 is being utilized in implicit read access in ZCMT extension.
  if (CVA6Cfg.RVZCMT & ~(CVA6Cfg.MmuPresent)) begin
    assign dcache_req_ports_cache_id = dcache_req_from_cache[0];
    assign dcache_req_ports_cache_ex[0] = '0;
  end else begin
    assign dcache_req_ports_cache_ex[0] = dcache_req_from_cache[0];
    assign dcache_req_ports_cache_id = '0;
  end
  assign dcache_req_ports_cache_ex[1]  = dcache_req_from_cache[1];
  assign dcache_req_ports_cache_acc[0] = dcache_req_from_cache[2];
  always_comb begin : gen_dcache_req_store_data_gnt
    dcache_req_ports_cache_ex[2]  = dcache_req_from_cache[3];
    dcache_req_ports_cache_acc[1] = dcache_req_from_cache[3];

    // Set gnt signal
    dcache_req_ports_cache_ex[2].data_gnt &= dcache_req_ports_ex_cache[2].data_req;
    dcache_req_ports_cache_acc[1].data_gnt &= !dcache_req_ports_ex_cache[2].data_req;
  end

  if (CVA6Cfg.DCacheType == config_pkg::WT) begin : gen_cache_wt
    // this is a cache subsystem that is compatible with OpenPiton
    wt_cache_subsystem #(
        
        
        
        
        
        
        
        
        
        .NumPorts  (NumPorts)
        
        ) i_cache_subsystem (
        // to D$
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        // I$
        .icache_en_i       (icache_en_csr),
        .icache_flush_i    (icache_flush_ctrl_cache),
        .icache_miss_o     (icache_miss_cache_perf),
        .icache_areq_i     (icache_areq_ex_cache),
        .icache_areq_o     (icache_areq_cache_ex),
        .icache_dreq_i     (icache_dreq_if_cache),
        .icache_dreq_o     (icache_dreq_cache_if),
        // D$
        .dcache_enable_i   (dcache_en_csr),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        // to commit stage
        .dcache_amo_req_i  (amo_req),
        .dcache_amo_resp_o (amo_resp),
        .mbe_i             (mbe),
        // from PTW, Load Unit  and Store Unit
        .dcache_miss_o     (dcache_miss_cache_perf),
        .miss_vld_bits_o   (miss_vld_bits),
        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),
        // write buffer status
        .wbuffer_empty_o   (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o  (dcache_commit_wbuffer_not_ni),
        // memory side
        .noc_req_o         (noc_req_o),
        .noc_resp_i        (noc_resp_i),
        .inval_addr_i      (inval_addr),
        .inval_valid_i     (inval_valid),
        .inval_ready_o     (inval_ready)
    );
    assign dcache_scrub_cycle_csr = 1'b0;
    assign dcache_dat_cor_err_csr = 1'b0;
    assign dcache_dat_unc_err_csr = 1'b0;
    assign dcache_dir_cor_err_csr = 1'b0;
    assign dcache_dir_unc_err_csr = 1'b0;
  end else if (
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB
  )
  begin : gen_cache_hpd
    cva6_hpdcache_subsystem #(
        
        
        
        
        
        
        
        
        
        .NumPorts  (NumPorts),
        
        
        
        .axi_b_chan_t (b_chan_t),
        .axi_r_chan_t (r_chan_t)
        
        ) i_cache_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .icache_en_i   (icache_en_csr),
        .icache_flush_i(icache_flush_ctrl_cache),
        .icache_miss_o (icache_miss_cache_perf),
        .icache_areq_i (icache_areq_ex_cache),
        .icache_areq_o (icache_areq_cache_ex),
        .icache_dreq_i (icache_dreq_if_cache),
        .icache_dreq_o (icache_dreq_cache_if),

        .dcache_enable_i      (dcache_en_csr),
        .dcache_flush_i       (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o   (dcache_flush_ack_cache_ctrl),
        .dcache_miss_o        (dcache_miss_cache_perf),
        .dcache_scrub_enable_i(dcache_scrub_en_csr),
        .dcache_scrub_period_i(dcache_scrub_period_csr),
        .dcache_scrub_cycle_o (dcache_scrub_cycle_csr),
        .dcache_dat_cor_err_o (dcache_dat_cor_err_csr),
        .dcache_dat_unc_err_o (dcache_dat_unc_err_csr),
        .dcache_dir_cor_err_o (dcache_dir_cor_err_csr),
        .dcache_dir_unc_err_o (dcache_dir_unc_err_csr),

        .dcache_amo_req_i (amo_req),
        .dcache_amo_resp_o(amo_resp),

        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),

        .wbuffer_empty_o (dcache_commit_wbuffer_empty),
        .wbuffer_not_ni_o(dcache_commit_wbuffer_not_ni),

        .hwpf_base_set_i    ('0  /*FIXME*/),
        .hwpf_base_i        ('0  /*FIXME*/),
        .hwpf_base_o        (  /*FIXME*/),
        .hwpf_param_set_i   ('0  /*FIXME*/),
        .hwpf_param_i       ('0  /*FIXME*/),
        .hwpf_param_o       (  /*FIXME*/),
        .hwpf_throttle_set_i('0  /*FIXME*/),
        .hwpf_throttle_i    ('0  /*FIXME*/),
        .hwpf_throttle_o    (  /*FIXME*/),
        .hwpf_status_o      (  /*FIXME*/),

        .noc_req_o (noc_req_o),
        .noc_resp_i(noc_resp_i)
    );
    assign inval_ready   = 1'b1;
    assign miss_vld_bits = '0;
  end else begin : gen_cache_wb
    std_cache_subsystem #(
        // note: this only works with one cacheable region
        // not as important since this cache subsystem is about to be
        // deprecated
        
        
        
        
        
        
        
        
        
        .NumPorts      (NumPorts),
        
        
        
        .axi_req_t     (noc_req_t),
        .axi_rsp_t     (noc_resp_t)
    ) i_cache_subsystem (
        // to D$
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        .priv_lvl_i        (priv_lvl),
        // I$
        .icache_en_i       (icache_en_csr),
        .icache_flush_i    (icache_flush_ctrl_cache),
        .icache_miss_o     (icache_miss_cache_perf),
        .icache_areq_i     (icache_areq_ex_cache),
        .icache_areq_o     (icache_areq_cache_ex),
        .icache_dreq_i     (icache_dreq_if_cache),
        .icache_dreq_o     (icache_dreq_cache_if),
        // D$
        .dcache_enable_i   (dcache_en_csr),
        .dcache_flush_i    (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),
        // to commit stage
        .amo_req_i         (amo_req),
        .amo_resp_o        (amo_resp),
        .dcache_miss_o     (dcache_miss_cache_perf),
        // this is statically set to 1 as the std_cache does not have a wbuffer
        .wbuffer_empty_o   (dcache_commit_wbuffer_empty),
        // from PTW, Load Unit  and Store Unit
        .dcache_req_ports_i(dcache_req_to_cache),
        .dcache_req_ports_o(dcache_req_from_cache),
        // memory side
        .axi_req_o         (noc_req_o),
        .axi_resp_i        (noc_resp_i)
    );
    assign dcache_commit_wbuffer_not_ni = 1'b1;
    assign dcache_scrub_cycle_csr       = 1'b0;
    assign dcache_dat_cor_err_csr       = 1'b0;
    assign dcache_dat_unc_err_csr       = 1'b0;
    assign dcache_dir_cor_err_csr       = 1'b0;
    assign dcache_dir_unc_err_csr       = 1'b0;
    assign inval_ready                  = 1'b1;
    assign miss_vld_bits                = '0;
  end

  // ----------------
  // Accelerator
  // ----------------

  if (CVA6Cfg.EnableAccelerator) begin : gen_accelerator
    acc_dispatcher #(
        
        
        
        
        
        
        
        .AccCfg            (AccCfg),
        .acc_req_t         (cvxif_req_t),
        .acc_resp_t        (cvxif_resp_t)
        
        
        
        ) i_acc_dispatcher (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),
        .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
        .flush_ex_i            (flush_ctrl_ex),
        .flush_pipeline_o      (flush_acc),
        .single_step_o         (single_step_acc_commit),
        .acc_cons_en_i         (acc_cons_en_csr),
        .acc_fflags_valid_o    (acc_resp_fflags_valid),
        .acc_fflags_o          (acc_resp_fflags),
        .ld_st_priv_lvl_i      (ld_st_priv_lvl_csr_ex),
        .sum_i                 (sum_csr_ex),
        .pmpcfg_i              (pmpcfg),
        .pmpaddr_i             (pmpaddr),
        .fcsr_frm_i            (frm_csr_id_issue_ex),
        .acc_mmu_en_i          (enable_translation_csr_ex),
        .dirty_v_state_o       (dirty_v_state),
        .issue_instr_i         (issue_instr_id_acc),
        .issue_instr_hs_i      (issue_instr_hs_id_acc),
        .issue_stall_o         (stall_acc_id),
        .fu_data_i             (fu_data_id_ex[0]),
        .commit_instr_i        (commit_instr_id_commit),
        .commit_st_barrier_i   (fence_i_commit_controller | fence_commit_controller),
        .acc_trans_id_o        (acc_trans_id_ex_id),
        .acc_result_o          (acc_result_ex_id),
        .acc_valid_o           (acc_valid_ex_id),
        .acc_exception_o       (acc_exception_ex_id),
        .acc_valid_ex_o        (acc_valid_acc_ex),
        .commit_ack_i          (commit_ack),
        .acc_stall_st_pending_o(stall_st_pending_ex),
        .acc_no_st_pending_i   (no_st_pending_commit),
        .dcache_req_ports_i    (dcache_req_ports_ex_cache),
        .acc_mmu_req_o         (acc_mmu_req),
        .acc_mmu_resp_i        (acc_mmu_resp),
        .ctrl_halt_o           (halt_acc_ctrl),
        .csr_addr_i            (csr_addr_ex_csr),
        .acc_dcache_req_ports_o(dcache_req_ports_acc_cache),
        .acc_dcache_req_ports_i(dcache_req_ports_cache_acc),
        .inval_ready_i         (inval_ready),
        .inval_valid_o         (inval_valid),
        .inval_addr_o          (inval_addr),
        .acc_req_o             (cvxif_req_o),
        .acc_resp_i            (cvxif_resp_i)
    );
  end : gen_accelerator
  else begin : gen_no_accelerator
    assign acc_trans_id_ex_id         = '0;
    assign acc_result_ex_id           = '0;
    assign acc_valid_ex_id            = '0;
    assign acc_exception_ex_id        = '0;
    assign acc_resp_fflags            = '0;
    assign acc_resp_fflags_valid      = '0;
    assign stall_acc_id               = '0;
    assign dirty_v_state              = '0;
    assign acc_valid_acc_ex           = '0;
    assign halt_acc_ctrl              = '0;
    assign stall_st_pending_ex        = '0;
    assign flush_acc                  = '0;
    assign single_step_acc_commit     = '0;

    // D$ connection is unused
    assign dcache_req_ports_acc_cache = '0;

    // MMU access is unused
    assign acc_mmu_req                = '0;

    // No invalidation interface
    assign inval_valid                = '0;
    assign inval_addr                 = '0;

    // Feed through cvxif
    assign cvxif_req_o                = cvxif_req;
  end : gen_no_accelerator

  // -------------------
  // Parameter Check
  // -------------------
  // pragma translate_off
  initial config_pkg::check_cfg(CVA6Cfg);
  // pragma translate_on

  // -------------------
  // Instruction Tracer
  // -------------------

  //pragma translate_off
`ifdef PITON_ARIANE
  localparam PC_QUEUE_DEPTH = 16;

  logic                                               piton_pc_vld;
  logic [         CVA6Cfg.VLEN-1:0]                   piton_pc;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.VLEN-1:0] pc_data;
  logic [CVA6Cfg.NrCommitPorts-1:0] pc_pop, pc_empty;

  for (genvar i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin : gen_pc_fifo
    cva6_fifo_v3 #(
        .DATA_WIDTH(64),
        .DEPTH(PC_QUEUE_DEPTH),
        .FPGA_EN(CVA6Cfg.FpgaEn)
    ) i_pc_fifo (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   ('0),
        .testmode_i('0),
        .full_o    (),
        .empty_o   (pc_empty[i]),
        .usage_o   (),
        .data_i    (commit_instr_id_commit[i].pc),
        .push_i    (commit_ack[i] & ~commit_instr_id_commit[i].ex.valid),
        .data_o    (pc_data[i]),
        .pop_i     (pc_pop[i])
    );
  end

  rr_arb_tree #(
      .NumIn(CVA6Cfg.NrCommitPorts),
      .DataWidth(64)
  ) i_rr_arb_tree (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .flush_i('0),
      .rr_i   ('0),
      .req_i  (~pc_empty),
      .gnt_o  (pc_pop),
      .data_i (pc_data),
      .gnt_i  (piton_pc_vld),
      .req_o  (piton_pc_vld),
      .data_o (piton_pc),
      .idx_o  ()
  );
`endif  // PITON_ARIANE

`ifdef USE_INSTR_TRACER

  logic [                     31:0]       fetch_instructions     [CVA6Cfg.NrIssuePorts-1:0];
  logic [CVA6Cfg.NrCommitPorts-1:0][63:0] wdata_commit_id_padded;

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; ++i) begin
    assign fetch_instructions[i] = fetch_entry_if_id[i].instruction;
  end

  for (genvar i = 0; i < CVA6Cfg.NrCommitPorts; ++i) begin
    assign wdata_commit_id_padded[i] = {{(64 - CVA6Cfg.XLEN) {1'b0}}, wdata_commit_id[i]};
  end

  instr_tracer #(
      
      
      
      
      
      .INTERRUPTS(INTERRUPTS)
  ) instr_tracer_i (
      // .tracer_if(tracer_if),
      .pck(clk_i),
      .rstn(rst_ni),
      .flush_unissued(flush_unissued_instr_ctrl_id),
      .flush_all(flush_ctrl_ex),
      .instruction(fetch_instructions),
      .fetch_valid(id_stage_i.fetch_entry_valid_i),
      .fetch_ack(id_stage_i.fetch_entry_ready_o),
      .issue_ack(issue_stage_i.i_scoreboard.issue_ack_i),
      .issue_sbe(issue_stage_i.i_scoreboard.issue_instr_o),
      .waddr(waddr_commit_id),
      .wdata(wdata_commit_id_padded),
      .we_gpr(we_gpr_commit_id),
      .we_fpr(we_fpr_commit_id),
      .commit_instr(commit_instr_id_commit),
      .commit_ack(commit_ack_commit_id),
      .commit_drop(commit_drop_id_commit),
      .st_valid(ex_stage_i.lsu_i.i_store_unit.store_buffer_i.valid_i),
      .st_paddr(ex_stage_i.lsu_i.i_store_unit.store_buffer_i.paddr_i),
      .ld_valid(ex_stage_i.lsu_i.i_load_unit.req_port_o.tag_valid),
      .ld_kill(ex_stage_i.lsu_i.i_load_unit.req_port_o.kill_req),
      .ld_paddr(ex_stage_i.lsu_i.i_load_unit.paddr_i),
      .resolve_branch(resolved_branch),
      .commit_exception(commit_stage_i.exception_o),
      .priv_lvl(priv_lvl),
      .debug_mode(debug_mode),
      .hart_id_i(hart_id_i)
  );

  // mock tracer for Verilator, to be used with spike-dasm
`else

  int f;
  logic [63:0] cycles;

  initial begin
    string fn;
    $sformat(fn, "trace_hart_%0.0f.dasm", hart_id_i);
    f = $fopen(fn, "w");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cycles <= 0;
    end else begin
      automatic byte mode = "";
      if (CVA6Cfg.DebugEn && debug_mode) mode = "D";
      else begin
        case (priv_lvl)
          riscv::PRIV_LVL_M: mode = "M";
          riscv::PRIV_LVL_S: if (CVA6Cfg.RVS) mode = "S";
          riscv::PRIV_LVL_U: mode = "U";
          default: ;  // Do nothing
        endcase
      end
      for (int i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin
        if (commit_ack[i] && !commit_instr_id_commit[i].ex.valid) begin
          $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc, mode,
                  commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].ex.tval[31:0]);
        end else if (commit_ack[i] && commit_instr_id_commit[i].ex.valid) begin
          if (commit_instr_id_commit[i].ex.cause == 2) begin
            $fwrite(f, "Exception Cause: Illegal Instructions, DASM(%h) PC=%h\n",
                    commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].pc);
          end else begin
            if (CVA6Cfg.DebugEn && debug_mode) begin
              $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc,
                      mode, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].ex.tval[31:0]);
            end else begin
              $fwrite(f, "Exception Cause: %5d, DASM(%h) PC=%h\n",
                      commit_instr_id_commit[i].ex.cause, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].pc);
            end
          end
        end
      end
      cycles <= cycles + 1;
    end
  end

  final begin
    $fclose(f);
  end
`endif  // VERILATOR
  //pragma translate_on


  //RVFI INSTR
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] rvfi_fetch_instr;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign rvfi_fetch_instr[i] = fetch_entry_if_id[i].instruction;
  end

  cva6_rvfi_probes  i_cva6_rvfi_probes (

      .flush_i            (flush_ctrl_if),
      .issue_instr_ack_i  (issue_instr_issue_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .instruction_i      (rvfi_fetch_instr),
      .is_compressed_i    (rvfi_is_compressed),

      .issue_pointer_i (rvfi_issue_pointer),
      .commit_pointer_i(rvfi_commit_pointer),

      .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
      .decoded_instr_valid_i (issue_entry_valid_id_issue),
      .decoded_instr_ack_i   (issue_instr_issue_id),

      .rs1_i(rvfi_rs1),
      .rs2_i(rvfi_rs2),

      .commit_instr_i(commit_instr_id_commit),
      .commit_drop_i (commit_drop_id_commit),
      .ex_commit_i   (ex_commit),
      .priv_lvl_i    (priv_lvl),

      .lsu_ctrl_i  (rvfi_lsu_ctrl),
      .wbdata_i    (wbdata_ex_id),
      .commit_ack_i(commit_ack),
      .mem_paddr_i (rvfi_mem_paddr),
      .debug_mode_i(debug_mode),
      .wdata_i     (wdata_commit_id),

      .csr_i(rvfi_csr),
      .irq_i(irq_i),
      .resolved_branch_i(resolved_branch),
      .flu_trans_id_ex_id_i(flu_trans_id_ex_id),
      .rvfi_probes_o(rvfi_probes_o)

  );

  //pragma translate_off
  initial begin
    assert (!(CVA6Cfg.SuperscalarEn && CVA6Cfg.EnableAccelerator))
    else $fatal(1, "Accelerator is not supported by superscalar pipeline");
  end
  //pragma translate_on

endmodule  // ariane
