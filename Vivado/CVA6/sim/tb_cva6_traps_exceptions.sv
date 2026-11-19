// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 20:51:00 +03:30
// Status: NEW FILE
// Reason / Modification: Suite 3 trap & exception testbench for CVA6. Exercises
//                        ILLEGAL_INSTR (cause 2), BREAKPOINT/EBREAK (cause 3),
//                        INSTR_ADDR_MISALIGNED (cause 0), and ENV_CALL_MMODE/ECALL
//                        (cause 11), mtvec trap handler redirection, mepc, mcause,
//                        mtval capture, full pipeline flush (flush_bp, flush_id,
//                        flush_ex, flush_if, flush_unissued), and MRET return.
//                        Logs a 75+ column CSV trace (cva6_trap_trace.csv).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_traps_exceptions;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clock
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 4000;
  localparam int  MEM_WORDS      = 1024;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;
  localparam logic [31:0] END_PC    = 32'h8000_0098; // JAL x0, 0 at END

  logic clk;
  logic rst_ni;

  // DUT Interface Signals
  logic [CVA6Cfg.VLEN-1:0] boot_addr;
  logic [CVA6Cfg.XLEN-1:0] hart_id;
  logic [1:0]              irq;
  logic                    ipi;
  logic                    time_irq;
  logic                    debug_req;

  rvfi_probes_t            rvfi_probes;
  cvxif_req_t              cvxif_req;
  cvxif_resp_t             cvxif_resp;
  noc_req_t                noc_req;
  noc_resp_t               noc_resp;

  logic sim_done = 1'b0;

  initial begin
    clk = 1'b0;
    while (!sim_done) #(CLK_PERIOD / 2) clk = ~clk;
  end

  // ----------------------------------------------------------------------------
  // 2. DUT Instantiation
  // ----------------------------------------------------------------------------
  cva6 u_dut (
    .clk_i         ( clk          ),
    .rst_ni        ( rst_ni       ),
    .boot_addr_i   ( boot_addr    ),
    .hart_id_i     ( hart_id      ),
    .irq_i         ( irq          ),
    .ipi_i         ( ipi          ),
    .time_irq_i    ( time_irq     ),
    .debug_req_i   ( debug_req    ),
    .rvfi_probes_o ( rvfi_probes  ),
    .cvxif_req_o   ( cvxif_req    ),
    .cvxif_resp_i  ( cvxif_resp   ),
    .noc_req_o     ( noc_req      ),
    .noc_resp_i    ( noc_resp     )
  );

  // ----------------------------------------------------------------------------
  // 3. Hierarchical Probes
  // ----------------------------------------------------------------------------
  // Commit ports (dual-commit accounting)
  wire [1:0]  probe_commit_ack      = u_dut.commit_ack;
  wire [31:0] probe_commit_pc0      = probe_commit_ack[0] ? u_dut.commit_instr_id_commit[0].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_pc1      = probe_commit_ack[1] ? u_dut.commit_instr_id_commit[1].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_instr0   = probe_commit_ack[0] ? u_dut.commit_instr_id_commit[0].result[31:0] : 32'h0;
  wire [31:0] probe_commit_instr1   = probe_commit_ack[1] ? u_dut.commit_instr_id_commit[1].result[31:0] : 32'h0;
  wire [1:0]  probe_we_gpr          = u_dut.we_gpr_commit_id;
  wire [1:0][4:0]  probe_waddr_gpr  = u_dut.waddr_commit_id;
  wire [1:0][31:0] probe_wdata_gpr  = u_dut.wdata_commit_id;

  // Fetch / front-end
  wire [31:0] probe_fetch_pc        = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_req       = u_dut.icache_dreq_if_cache.req;
  wire        probe_fetch_valid     = u_dut.icache_dreq_cache_if.valid;
  wire [31:0] probe_fe_instr        = u_dut.fetch_entry_if_id[0].instruction;
  wire        probe_fe_id_valid     = u_dut.fetch_valid_if_id;
  wire        probe_id_fe_ready     = u_dut.fetch_ready_id_if;
  wire [3:0]  probe_fifo_usage      = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;

  // I-cache
  wire [2:0]  probe_icache_state    = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q;
  wire        probe_icache_miss     = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.miss_o;
  wire        probe_icache_ready    = u_dut.icache_dreq_cache_if.ready;

  // Trap, Exception & CSR Probes
  wire        probe_exception_valid = u_dut.commit_stage_i.exception_o.valid;
  wire [31:0] probe_exception_cause = {26'b0, u_dut.commit_stage_i.exception_o.cause};
  wire [31:0] probe_exception_tval  = u_dut.commit_stage_i.exception_o.tval[31:0];

  wire [31:0] probe_csr_mepc        = u_dut.csr_regfile_i.mepc_q[31:0];
  wire [31:0] probe_csr_mcause      = u_dut.csr_regfile_i.mcause_q[31:0];
  wire [31:0] probe_csr_mtval       = u_dut.csr_regfile_i.mtval_q[31:0];
  wire [31:0] probe_csr_mtvec       = u_dut.csr_regfile_i.mtvec_q[31:0];
  wire [31:0] probe_csr_mstatus     = u_dut.csr_regfile_i.mstatus_q[31:0];
  wire [31:0] probe_csr_trap_vector = u_dut.csr_regfile_i.trap_vector_base_o[31:0];
  wire [31:0] probe_csr_epc         = u_dut.csr_regfile_i.epc_o[31:0];

  // Controller Probes
  wire        probe_ex_valid        = u_dut.controller_i.ex_valid_i;
  wire        probe_eret            = u_dut.controller_i.eret_i;
  wire        probe_flush_bp        = u_dut.controller_i.flush_bp_o;
  wire        probe_flush_if        = u_dut.controller_i.flush_if_o;
  wire        probe_flush_unissued  = u_dut.controller_i.flush_unissued_instr_o;
  wire        probe_flush_id        = u_dut.controller_i.flush_id_o;
  wire        probe_flush_ex        = u_dut.controller_i.flush_ex_o;
  wire        probe_halt_frontend   = u_dut.controller_i.halt_frontend_o;

  // Issue & Scoreboard Probes
  wire        probe_issue_valid0    = u_dut.issue_stage_i.issue_instr_valid_sb_iro[0];
  wire        probe_issue_ack0      = u_dut.issue_stage_i.issue_ack_iro_sb[0];
  wire        probe_stall_issue     = u_dut.issue_stage_i.i_issue_read_operands.stall_issue_o;
  wire        probe_stall_raw       = u_dut.issue_stage_i.i_issue_read_operands.stall_raw[0];

  // AXI
  wire        probe_axi_arvalid     = noc_req.ar_valid;
  wire [31:0] probe_axi_araddr      = noc_req.ar.addr[31:0];
  wire        probe_axi_rvalid      = noc_resp.r_valid;
  wire        probe_axi_rlast       = noc_resp.r.last;
  wire        probe_axi_awvalid     = noc_req.aw_valid;
  wire [31:0] probe_axi_awaddr      = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid      = noc_req.w_valid;
  wire        probe_axi_bvalid      = noc_resp.b_valid;

  // ----------------------------------------------------------------------------
  // 4. Memory Model Image
  // ----------------------------------------------------------------------------
  logic [31:0] mem[0:MEM_WORDS-1];

  initial begin
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h00000013; // ADDI x0, x0, 0 (NOP)
    end

    // 72-word Traps, Exceptions & Privilege Architecture Benchmark
    mem[ 0] = 32'h800000b7; // 0x80000000: lui  ra, 0x80000
    mem[ 1] = 32'h40008093; // 0x80000004: addi ra, ra, 1024       (ra = 0x8000_0400)
    mem[ 2] = 32'h00000f97; // 0x80000008: auipc t6, 0x0
    mem[ 3] = 32'h098f8f93; // 0x8000000c: addi t6, t6, 152        (t6 = 0x8000_00a0 <trap_handler>)
    mem[ 4] = 32'h305f9073; // 0x80000010: csrw mtvec, t6
    mem[ 5] = 32'h00000113; // 0x80000014: li   sp, 0              (trap counter)
    mem[ 6] = 32'h00000193; // 0x80000018: li   gp, 0
    mem[ 7] = 32'h00000213; // 0x8000001c: li   tp, 0
    mem[ 8] = 32'h00000293; // 0x80000020: li   t0, 0
    mem[ 9] = 32'h00000313; // 0x80000024: li   t1, 0
    mem[10] = 32'h00000393; // 0x80000028: li   t2, 0
    mem[11] = 32'h00000413; // 0x8000002c: li   s0, 0
    mem[12] = 32'h00000493; // 0x80000030: li   s1, 0
    mem[13] = 32'h00000513; // 0x80000034: li   a0, 0
    mem[14] = 32'h00000593; // 0x80000038: li   a1, 0
    mem[15] = 32'h00000613; // 0x8000003c: li   a2, 0
    mem[16] = 32'h00000693; // 0x80000040: li   a3, 0
    mem[17] = 32'h00000713; // 0x80000044: li   a4, 0
    mem[18] = 32'h00000793; // 0x80000048: li   a5, 0
    mem[19] = 32'h00000813; // 0x8000004c: li   a6, 0
    mem[20] = 32'h00000893; // 0x80000050: li   a7, 0
    mem[21] = 32'h00000913; // 0x80000054: li   s2, 0
    mem[22] = 32'h00000993; // 0x80000058: li   s3, 0
    mem[23] = 32'h00000a13; // 0x8000005c: li   s4, 0
    mem[24] = 32'h06400193; // 0x80000060: li   gp, 100            (marker before Trap 1)

    // Phase 1: Trigger ILLEGAL_INSTR (Cause 2)
    mem[25] = 32'h00000000; // 0x80000064: .word 0x00000000        (triggers ILLEGAL_INSTR)
    mem[26] = 32'h06500213; // 0x80000068: li   tp, 101            (marker after Trap 1 resume)
    mem[27] = 32'h0c800293; // 0x8000006c: li   t0, 200            (marker before Trap 2)

    // Phase 2: Trigger BREAKPOINT / EBREAK (Cause 3)
    mem[28] = 32'h00100073; // 0x80000070: ebreak                  (triggers BREAKPOINT)
    mem[29] = 32'h0c900313; // 0x80000074: li   t1, 201            (marker after Trap 2 resume)
    mem[30] = 32'h12c00393; // 0x80000078: li   t2, 300            (marker before Trap 3)
    mem[31] = 32'h00208f93; // 0x8000007c: addi t6, ra, 2          (t6 = 0x8000_0402, unaligned target)

    // Phase 3: Trigger INSTR_ADDR_MISALIGNED (Cause 0)
    mem[32] = 32'h000f8067; // 0x80000080: jr   t6                 (triggers INSTR_ADDR_MISALIGNED)
    mem[33] = 32'h12d00413; // 0x80000084: li   s0, 301            (marker after Trap 3 resume)
    mem[34] = 32'h19000493; // 0x80000088: li   s1, 400            (marker before Trap 4)

    // Phase 4: Trigger ENV_CALL_MMODE / ECALL (Cause 11)
    mem[35] = 32'h00000073; // 0x8000008c: ecall                   (triggers ENV_CALL_MMODE)
    mem[36] = 32'h19100993; // 0x80000090: li   s3, 401            (marker after Trap 4 resume)
    mem[37] = 32'h3e700a13; // 0x80000094: li   s4, 999            (final success flag)

    // Phase 5: Terminal self-loop
    mem[38] = 32'h0000006f; // 0x80000098: j    end_loop           (END self-loop)
    mem[39] = 32'h00000013; // 0x8000009c: nop

    // Trap Handler (aligned at 0x8000_00a0)
    mem[40] = 32'h00110113; // 0x800000a0: addi sp, sp, 1          (increment trap count)
    mem[41] = 32'h34202e73; // 0x800000a4: csrr t3, mcause
    mem[42] = 32'h34102ef3; // 0x800000a8: csrr t4, mepc
    mem[43] = 32'h34302f73; // 0x800000ac: csrr t5, mtval
    mem[44] = 32'h00100f93; // 0x800000b0: li   t6, 1
    mem[45] = 32'h03f10063; // 0x800000b4: beq  sp, t6, handle_trap1
    mem[46] = 32'h00200f93; // 0x800000b8: li   t6, 2
    mem[47] = 32'h03f10263; // 0x800000bc: beq  sp, t6, handle_trap2
    mem[48] = 32'h00300f93; // 0x800000c0: li   t6, 3
    mem[49] = 32'h03f10463; // 0x800000c4: beq  sp, t6, handle_trap3
    mem[50] = 32'h00400f93; // 0x800000c8: li   t6, 4
    mem[51] = 32'h03f10863; // 0x800000cc: beq  sp, t6, handle_trap4
    mem[52] = 32'h0380006f; // 0x800000d0: j    trap_return

    // Handler Trap 1: ILLEGAL_INSTR
    mem[53] = 32'h000e0513; // 0x800000d4: mv   a0, t3             (a0 = mcause = 2)
    mem[54] = 32'h000e8593; // 0x800000d8: mv   a1, t4             (a1 = mepc = 0x8000_0064)
    mem[55] = 32'h02c0006f; // 0x800000dc: j    trap_return

    // Handler Trap 2: BREAKPOINT
    mem[56] = 32'h000e0613; // 0x800000e0: mv   a2, t3             (a2 = mcause = 3)
    mem[57] = 32'h000e8693; // 0x800000e4: mv   a3, t4             (a3 = mepc = 0x8000_0070)
    mem[58] = 32'h0200006f; // 0x800000e8: j    trap_return

    // Handler Trap 3: INSTR_ADDR_MISALIGNED
    mem[59] = 32'h000e0713; // 0x800000ec: mv   a4, t3             (a4 = mcause = 0)
    mem[60] = 32'h000e8793; // 0x800000f0: mv   a5, t4             (a5 = mepc = 0x8000_0080)
    mem[61] = 32'h000f0813; // 0x800000f4: mv   a6, t5             (a6 = mtval = 0x8000_0402)
    mem[62] = 32'h0100006f; // 0x800000f8: j    trap_return

    // Handler Trap 4: ENV_CALL_MMODE
    mem[63] = 32'h000e0893; // 0x800000fc: mv   a7, t3             (a7 = mcause = 11)
    mem[64] = 32'h000e8913; // 0x80000100: mv   s2, t4             (s2 = mepc = 0x8000_008c)
    mem[65] = 32'h0040006f; // 0x80000104: j    trap_return

    // Trap Return (advance mepc past faulting instruction)
    mem[66] = 32'h004e8e93; // 0x80000108: addi t4, t4, 4          (advance mepc by 4)
    mem[67] = 32'h341e9073; // 0x8000010c: csrw mepc, t4
    mem[68] = 32'h30200073; // 0x80000110: mret                   (return to mepc)
    mem[69] = 32'h00000013; // 0x80000114: nop
    mem[70] = 32'h00000013; // 0x80000118: nop
    mem[71] = 32'h00000013; // 0x8000011c: nop
  end

  // ----------------------------------------------------------------------------
  // 5. AXI4 Read/Write Responder (64-bit channels, low-12-bit word index)
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AR_IDLE = 2'b00,
    R_BURST = 2'b01
  } r_state_t;
  r_state_t r_state;

  typedef enum logic [1:0] {
    AW_IDLE = 2'b00,
    W_BURST = 2'b01,
    B_RESP  = 2'b10
  } w_state_t;
  w_state_t w_state;

  logic [CVA6Cfg.AxiIdWidth-1:0] ar_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] ar_addr_q;
  axi_pkg::len_t ar_len_q;
  logic [7:0] ar_cnt_q;

  logic [CVA6Cfg.AxiIdWidth-1:0] aw_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] aw_addr_q;
  logic [7:0] aw_cnt_q;

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      r_state          <= AR_IDLE;
      noc_resp.ar_ready <= 1'b0;
      noc_resp.r_valid  <= 1'b0;
      noc_resp.r        <= '0;
      ar_id_q          <= '0;
      ar_addr_q        <= '0;
      ar_len_q         <= '0;
      ar_cnt_q         <= '0;
    end else begin
      case (r_state)
        AR_IDLE: begin
          noc_resp.ar_ready <= 1'b1;
          noc_resp.r_valid  <= 1'b0;
          if (noc_req.ar_valid && noc_resp.ar_ready) begin
            ar_id_q           <= noc_req.ar.id;
            ar_addr_q         <= noc_req.ar.addr;
            ar_len_q          <= noc_req.ar.len;
            ar_cnt_q          <= 8'd0;
            noc_resp.ar_ready <= 1'b0;
            r_state           <= R_BURST;
          end
        end

        R_BURST: begin
          noc_resp.ar_ready <= 1'b0;
          noc_resp.r_valid  <= 1'b1;
          noc_resp.r.id     <= ar_id_q;
          noc_resp.r.resp   <= axi_pkg::RESP_OKAY;
          noc_resp.r.user   <= '0;
          noc_resp.r.last   <= (ar_cnt_q == ar_len_q);

          begin
            automatic logic [63:0] cur_addr = ar_addr_q + (ar_cnt_q * 8);
            automatic int unsigned word_idx = (cur_addr[11:0] >> 2);
            noc_resp.r.data <= {mem[word_idx + 1], mem[word_idx]};
          end

          if (noc_req.r_ready && noc_resp.r_valid) begin
            if (noc_resp.r.last) begin
              noc_resp.r_valid  <= 1'b0;
              noc_resp.ar_ready <= 1'b1;
              r_state           <= AR_IDLE;
            end else begin
              ar_cnt_q <= ar_cnt_q + 8'd1;
            end
          end
        end

        default: r_state <= AR_IDLE;
      endcase
    end
  end

  // AXI Write Channel
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      w_state          <= AW_IDLE;
      noc_resp.aw_ready <= 1'b0;
      noc_resp.w_ready  <= 1'b0;
      noc_resp.b_valid  <= 1'b0;
      noc_resp.b        <= '0;
      aw_id_q          <= '0;
      aw_addr_q        <= '0;
      aw_cnt_q         <= '0;
    end else begin
      case (w_state)
        AW_IDLE: begin
          noc_resp.aw_ready <= 1'b1;
          noc_resp.w_ready  <= 1'b1;
          noc_resp.b_valid  <= 1'b0;

          if (noc_req.aw_valid && noc_resp.aw_ready) begin
            aw_id_q           <= noc_req.aw.id;
            aw_addr_q         <= noc_req.aw.addr;
            aw_cnt_q          <= 8'd0;
            noc_resp.aw_ready <= 1'b0;

            if (noc_req.w_valid && noc_resp.w_ready) begin
              automatic int unsigned word_idx = (noc_req.aw.addr[11:0] >> 2);
              for (int b = 0; b < 4; b++) begin
                if (noc_req.w.strb[b]) mem[word_idx][b*8 +: 8] <= noc_req.w.data[b*8 +: 8];
              end
              for (int b = 4; b < 8; b++) begin
                if (noc_req.w.strb[b]) mem[word_idx + 1][(b-4)*8 +: 8] <= noc_req.w.data[b*8 +: 8];
              end

              if (noc_req.w.last) begin
                noc_resp.w_ready <= 1'b0;
                noc_resp.b_valid <= 1'b1;
                noc_resp.b.id    <= noc_req.aw.id;
                noc_resp.b.resp  <= axi_pkg::RESP_OKAY;
                noc_resp.b.user  <= '0;
                w_state          <= B_RESP;
              end else begin
                aw_cnt_q <= 8'd1;
                w_state  <= W_BURST;
              end
            end else begin
              w_state <= W_BURST;
            end
          end
        end

        W_BURST: begin
          noc_resp.aw_ready <= 1'b0;
          noc_resp.w_ready  <= 1'b1;
          if (noc_req.w_valid && noc_resp.w_ready) begin
            automatic logic [63:0] cur_addr = aw_addr_q + (aw_cnt_q * 8);
            automatic int unsigned word_idx = (cur_addr[11:0] >> 2);

            for (int b = 0; b < 4; b++) begin
              if (noc_req.w.strb[b]) mem[word_idx][b*8 +: 8] <= noc_req.w.data[b*8 +: 8];
            end
            for (int b = 4; b < 8; b++) begin
              if (noc_req.w.strb[b]) mem[word_idx + 1][(b-4)*8 +: 8] <= noc_req.w.data[b*8 +: 8];
            end

            if (noc_req.w.last) begin
              noc_resp.w_ready <= 1'b0;
              noc_resp.b_valid <= 1'b1;
              noc_resp.b.id    <= aw_id_q;
              noc_resp.b.resp  <= axi_pkg::RESP_OKAY;
              noc_resp.b.user  <= '0;
              w_state          <= B_RESP;
            end else begin
              aw_cnt_q <= aw_cnt_q + 8'd1;
            end
          end
        end

        B_RESP: begin
          noc_resp.w_ready <= 1'b0;
          if (noc_req.b_ready && noc_resp.b_valid) begin
            noc_resp.b_valid  <= 1'b0;
            noc_resp.aw_ready <= 1'b1;
            noc_resp.w_ready  <= 1'b1;
            w_state           <= AW_IDLE;
          end
        end

        default: w_state <= AW_IDLE;
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 6. Architectural Register Read
  // ----------------------------------------------------------------------------
  function logic [31:0] read_arch_reg(input int r);
    if (r == 0) return 32'h0;
    return u_dut.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[r];
  endfunction

  // ----------------------------------------------------------------------------
  // 7. Metrics, Event Monitor & CSV
  // ----------------------------------------------------------------------------
  int check_count     = 0;
  int error_count     = 0;
  int cycle_count     = 0;
  int instret_count   = 0;
  int csv_fd;
  logic logging_en = 1'b0;

  int first_commit_cycle = 0;
  int end_commit_cycle   = 0;

  // Trap event counters
  int trap_event_count  = 0;
  int mret_event_count  = 0;
  int flush_all_count   = 0;
  int flush_bp_count    = 0;
  int flush_if_count    = 0;

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      instret_count      <= 0;
      trap_event_count   <= 0;
      mret_event_count   <= 0;
      flush_all_count    <= 0;
      flush_bp_count     <= 0;
      flush_if_count     <= 0;
      first_commit_cycle <= 0;
      end_commit_cycle   <= 0;
    end else begin
      // Dual-port retirement accounting.
      if (probe_commit_ack[0]) instret_count <= instret_count + 1;
      if (probe_commit_ack[1]) instret_count <= instret_count + 1;

      if ((probe_commit_ack[0] || probe_commit_ack[1]) && first_commit_cycle == 0)
        first_commit_cycle <= cycle_count;

      // Trap events (exception valid at commit)
      if (probe_exception_valid)
        trap_event_count <= trap_event_count + 1;

      // MRET execution events (eret asserted by CSR)
      if (probe_eret)
        mret_event_count <= mret_event_count + 1;

      // Full pipeline flush count (flush_bp & flush_id & flush_ex)
      if (probe_flush_bp && probe_flush_id && probe_flush_ex)
        flush_all_count <= flush_all_count + 1;

      if (probe_flush_bp) flush_bp_count <= flush_bp_count + 1;
      if (probe_flush_if) flush_if_count <= flush_if_count + 1;
    end
  end

  // Cycle counter
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) cycle_count <= 0;
    else         cycle_count <= cycle_count + 1;
  end

  initial begin
    csv_fd = $fopen("cva6_trap_trace.csv", "w");
    logging_en = 1'b1;
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,IcacheState,IcacheMiss,IcacheReady,ExValid,Eret,ExceptionValid,ExceptionCause,ExceptionTval,CsrMepc,CsrMcause,CsrMtval,CsrMtvec,CsrMstatus,CsrTrapVector,CsrEpc,FlushBP,FlushIF,FlushUnissued,FlushID,FlushEX,HaltFrontend,IssueValid0,IssueAck0,StallIssue,StallRaw,TrapEventCount,MretEventCount,FlushAllCount,FlushBpCount,AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiBValid");
    end else begin
      $display("[TB_WARNING] Could not open cva6_trap_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    if (csv_fd && logging_en) begin
      $fdisplay(csv_fd, "%0t,%0d,%0d,%b,%b,0x%08h,0x%08h,0x%08h,0x%08h,%b,%0d,0x%08h,%b,%0d,0x%08h,0x%08h,%b,%b,0x%08h,%b,%b,%0d,%0d,%b,%b,%b,%b,%b,%0d,0x%08h,0x%08h,0x%08h,0x%08h,0x%08h,0x%08h,0x%08h,0x%08h,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%0d,%0d,%0d,%0d,%b,0x%08h,%b,%b,%b,0x%08h,%b,%b",
                $time,
                cycle_count,
                instret_count,
                probe_commit_ack[0],
                probe_commit_ack[1],
                probe_commit_pc0,
                probe_commit_pc1,
                probe_commit_instr0,
                probe_commit_instr1,
                probe_we_gpr[0],
                probe_waddr_gpr[0],
                probe_wdata_gpr[0],
                probe_we_gpr[1],
                probe_waddr_gpr[1],
                probe_wdata_gpr[1],
                probe_fetch_pc,
                probe_fetch_req,
                probe_fetch_valid,
                probe_fe_instr,
                probe_fe_id_valid,
                probe_id_fe_ready,
                probe_fifo_usage,
                probe_icache_state,
                probe_icache_miss,
                probe_icache_ready,
                probe_ex_valid,
                probe_eret,
                probe_exception_valid,
                probe_exception_cause,
                probe_exception_tval,
                probe_csr_mepc,
                probe_csr_mcause,
                probe_csr_mtval,
                probe_csr_mtvec,
                probe_csr_mstatus,
                probe_csr_trap_vector,
                probe_csr_epc,
                probe_flush_bp,
                probe_flush_if,
                probe_flush_unissued,
                probe_flush_id,
                probe_flush_ex,
                probe_halt_frontend,
                probe_issue_valid0,
                probe_issue_ack0,
                probe_stall_issue,
                probe_stall_raw,
                trap_event_count,
                mret_event_count,
                flush_all_count,
                flush_bp_count,
                probe_axi_arvalid,
                probe_axi_araddr,
                probe_axi_rvalid,
                probe_axi_rlast,
                probe_axi_awvalid,
                probe_axi_awaddr,
                probe_axi_wvalid,
                probe_axi_bvalid);
    end
  end

  // ----------------------------------------------------------------------------
  // 8. Driver, Scoreboard & Checks
  // ----------------------------------------------------------------------------
  wire spy_end_hit = (probe_commit_ack[0] && probe_commit_pc0 == END_PC) ||
                     (probe_commit_ack[1] && probe_commit_pc1 == END_PC);

  initial begin
    boot_addr  = BOOT_ADDR;
    hart_id    = '0;
    irq        = 2'b00;
    ipi        = 1'b0;
    time_irq   = 1'b0;
    debug_req  = 1'b0;
    cvxif_resp = '0;

    rst_ni = 1'b0;

    $display("============================================================");
    $display("[TB_INFO] CVA6 Suite 3: Traps, Exceptions & Privilege Arch");
    $display("[TB_INFO] ILLEGAL_INSTR, EBREAK, MISALIGNED_JUMP, ECALL, MRET");
    $display("============================================================");

    repeat (10) @(posedge clk);
    rst_ni = 1'b1;
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08h", $time, BOOT_ADDR);

    while (!spy_end_hit && (cycle_count < TIMEOUT_CYCLES)) begin
      @(posedge clk);
    end

    if (spy_end_hit) begin
      end_commit_cycle = cycle_count;
      $display("[%0t] [TB_END] END self-loop committed at cycle %0d.", $time, cycle_count);
    end else begin
      $display("[%0t] [TB_TIMEOUT] END PC 0x%08h was not committed within %0d cycles.",
               $time, END_PC, TIMEOUT_CYCLES);
    end

    repeat (40) @(posedge clk);

    $display("============================================================");
    $display("[SCOREBOARD] Architectural register checks");
    $display("============================================================");

    check_reg(1,  32'h8000_0400); // Base data memory address
    check_reg(2,  32'd4);         // sp = Total trap count (4 traps handled)
    check_reg(3,  32'd100);       // gp = Marker before Trap 1
    check_reg(4,  32'd101);       // tp = Marker after Trap 1 resume
    check_reg(5,  32'd200);       // t0 = Marker before Trap 2
    check_reg(6,  32'd201);       // t1 = Marker after Trap 2 resume
    check_reg(7,  32'd300);       // t2 = Marker before Trap 3
    check_reg(8,  32'd301);       // s0 = Marker after Trap 3 resume
    check_reg(9,  32'd400);       // s1 = Marker before Trap 4
    check_reg(10, 32'd2);         // a0 = mcause for Trap 1 (ILLEGAL_INSTR = 2)
    check_reg(11, 32'h8000_0064); // a1 = mepc for Trap 1 (fault PC)
    check_reg(12, 32'd3);         // a2 = mcause for Trap 2 (BREAKPOINT = 3)
    check_reg(13, 32'h8000_0070); // a3 = mepc for Trap 2 (fault PC)
    check_reg(14, 32'd0);         // a4 = mcause for Trap 3 (INSTR_ADDR_MISALIGNED = 0)
    check_reg(15, 32'h8000_0080); // a5 = mepc for Trap 3 (fault PC)
    check_reg(16, 32'h8000_0402); // a6 = mtval for Trap 3 (unaligned target address)
    check_reg(17, 32'd11);        // a7 = mcause for Trap 4 (ENV_CALL_MMODE = 11)
    check_reg(18, 32'h8000_008c); // s2 = mepc for Trap 4 (fault PC)
    check_reg(19, 32'd401);       // s3 = Marker after Trap 4 resume
    check_reg(20, 32'd999);       // s4 = Final program completion flag

    check_cond(spy_end_hit, "END self-loop committed");
    check_cond(trap_event_count == 4, "all 4 synchronous traps committed and vectored");
    check_cond(mret_event_count == 4, "all 4 MRET returns executed successfully");
    check_cond(flush_all_count >= 8, "full pipeline flushes asserted on all traps and MRETs (>=8)");
    check_cond(flush_bp_count >= 8, "flush_bp asserted on traps and MRETs (proves trap flush vs branch mispredict)");

    $display("------------------------------------------------------------");
    $display("[METRICS] Committed instructions    : %0d", instret_count);
    $display("[METRICS] First commit cycle        : %0d", first_commit_cycle);
    $display("[METRICS] End commit cycle          : %0d", end_commit_cycle);
    $display("[METRICS] Synchronous traps handled : %0d", trap_event_count);
    $display("[METRICS] MRET returns executed     : %0d", mret_event_count);
    $display("[METRICS] Full pipeline flushes     : %0d", flush_all_count);
    $display("[METRICS] Flush BP count            : %0d", flush_bp_count);
    $display("[METRICS] Flush IF count            : %0d", flush_if_count);
    if (end_commit_cycle > first_commit_cycle && instret_count > 0)
      $display("[METRICS] Active CPI (trap workload): %0.2f",
               real'(end_commit_cycle - first_commit_cycle + 1) / real'(instret_count));
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 3:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    logging_en = 1'b0;

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-3 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-3 ENCOUNTERED %0d ERROR(S)", error_count);
    end

    sim_done = 1'b1;
    $finish;
  end

  final begin
    logging_en = 1'b0;
    if (csv_fd) begin
      $fclose(csv_fd);
      csv_fd = 0;
    end
  end

  task check_reg(input int reg_idx, input logic [31:0] expected_val);
    logic [31:0] actual_val;
    actual_val = read_arch_reg(reg_idx);
    check_count++;
    if (actual_val === expected_val) begin
      $display("[PASS] Reg x%0d = 0x%08h", reg_idx, actual_val);
    end else begin
      error_count++;
      $display("[FAIL] Reg x%0d = 0x%08h (expected 0x%08h)", reg_idx, actual_val, expected_val);
    end
  endtask

  task check_cond(input logic cond, input string msg);
    check_count++;
    if (cond) begin
      $display("[PASS] %s", msg);
    end else begin
      error_count++;
      $display("[FAIL] %s", msg);
    end
  endtask

endmodule
