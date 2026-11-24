// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 21:05:30 +03:30
// Status: MODIFIED FILE
// Reason / Modification: Suite 5 Testbench for CVA6 Instruction Cache Synchronization
//                        (FENCE.I), Self-Modifying Code Dynamic Execution, and CSR
//                        Side-Effect Pipeline Flushes (flush_csr).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_fence_flush;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Clock and Reset Generation
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns; // 100 MHz
  localparam int  TIMEOUT_CYCLES = 3500;
  localparam int  MEM_WORDS      = 512;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;
  localparam logic [31:0] SUB_ADDR  = 32'h8000_0200;
  localparam logic [31:0] END_PC    = 32'h8000_0068;

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
  // 2. Memory Emulation and Benchmark Program (Suite 5: FENCE.I & Pipeline Flushes)
  // ----------------------------------------------------------------------------
  logic [31:0] mem [0:MEM_WORDS-1];

  initial begin
    rst_ni    = 1'b0;
    boot_addr = BOOT_ADDR;
    hart_id   = '0;
    irq       = '0;
    ipi       = 1'b0;
    time_irq  = 1'b0;
    debug_req = 1'b0;

    cvxif_resp = '0;

    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h0000_0013; // nop (addi x0, x0, 0)
    end

    // --------------------------------------------------------------------------
    // Main Program (0x8000_0000 to 0x8000_006c)
    // --------------------------------------------------------------------------
    mem[  0] = 32'h80000fb7; // 0x80000000: lui  t6, 0x80000
    mem[  1] = 32'h200f8f93; // 0x80000004: addi t6, t6, 512 (t6 = 0x8000_0200)
    mem[  2] = 32'h00000113; // 0x80000008: li   sp, 0
    mem[  3] = 32'h00000193; // 0x8000000c: li   gp, 0
    mem[  4] = 32'h00000213; // 0x80000010: li   tp, 0
    mem[  5] = 32'h00000293; // 0x80000014: li   t0, 0
    mem[  6] = 32'h00000313; // 0x80000018: li   t1, 0
    mem[  7] = 32'h00000393; // 0x8000001c: li   t2, 0
    mem[  8] = 32'h00000413; // 0x80000020: li   s0, 0
    mem[  9] = 32'h00000493; // 0x80000024: li   s1, 0
    mem[ 10] = 32'h00000513; // 0x80000028: li   a0, 0
    mem[ 11] = 32'h00000593; // 0x8000002c: li   a1, 0

    // Phase 1: First call to subroutine at 0x8000_0200
    mem[ 12] = 32'h000f8467; // 0x80000030: jalr s0, t6, 0 (save ret in s0)
    mem[ 13] = 32'h00050093; // 0x80000034: mv   x1 (ra), a0 (expected 100)

    // Phase 2: Modify code via Store (Self-Modifying Code)
    mem[ 14] = 32'h3e7002b7; // 0x80000038: lui  t0, 0x3e700
    mem[ 15] = 32'h51328293; // 0x8000003c: addi t0, t0, 0x513 (t0 = 0x3e700513 -> addi a0, 0, 999)
    mem[ 16] = 32'h005fa023; // 0x80000040: sw   t0, 0(t6)

    // Phase 3: FENCE.I instruction cache synchronization
    mem[ 17] = 32'h0000100f; // 0x80000044: fence.i

    // Phase 4: Second call to subroutine at 0x8000_0200 (post-FENCE.I)
    mem[ 18] = 32'h000f8467; // 0x80000048: jalr s0, t6, 0
    mem[ 19] = 32'h00050113; // 0x8000004c: mv   x2 (sp), a0 (expected 999)

    // Phase 5: CSR Side-Effect Pipeline Flush
    mem[ 20] = 32'h30002373; // 0x80000050: csrr t1, mstatus
    mem[ 21] = 32'h30031073; // 0x80000054: csrw mstatus, t1 (triggers flush_csr)
    mem[ 22] = 32'h22b00193; // 0x80000058: li   x3 (gp), 555

    // Phase 6: Standard Data FENCE instruction
    mem[ 23] = 32'h0ff0000f; // 0x8000005c: fence
    mem[ 24] = 32'h30900213; // 0x80000060: li   x4 (tp), 777

    // Phase 7: Terminal self-loop
    mem[ 25] = 32'h3e700a13; // 0x80000064: li   x20 (s4), 999
    mem[ 26] = 32'h0000006f; // 0x80000068: j    0x80000068 (end_loop)
    mem[ 27] = 32'h00000013; // 0x8000006c: nop

    // --------------------------------------------------------------------------
    // Initial Subroutine at 0x8000_0200 (Word index 128)
    // --------------------------------------------------------------------------
    mem[128] = 32'h06400513; // 0x80000200: addi a0, zero, 100
    mem[129] = 32'h00040067; // 0x80000204: jr   s0

    // Hold reset low for 8 cycles
    repeat (8) @(posedge clk);
    #(1ns);
    rst_ni = 1'b1;
  end

  // ----------------------------------------------------------------------------
  // 3. DUT Instantiation
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
  // 4. DUT Probes for Tracing & Hardware Assertion Verification
  // ----------------------------------------------------------------------------
  // Commit ports (dual-commit accounting)
  wire [1:0]  probe_commit_ack      = u_dut.commit_ack;
  wire [31:0] probe_commit_pc0      = probe_commit_ack[0] ? u_dut.commit_instr_id_commit[0].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_pc1      = probe_commit_ack[1] ? u_dut.commit_instr_id_commit[1].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_res0     = probe_commit_ack[0] ? u_dut.commit_instr_id_commit[0].result[31:0] : 32'h0;
  wire [31:0] probe_commit_res1     = probe_commit_ack[1] ? u_dut.commit_instr_id_commit[1].result[31:0] : 32'h0;
  wire [1:0]  probe_we_gpr          = u_dut.we_gpr_commit_id;
  wire [1:0][4:0]  probe_waddr_gpr  = u_dut.waddr_commit_id;
  wire [1:0][31:0] probe_wdata_gpr  = u_dut.wdata_commit_id;

  wire        probe_fence_i_commit  = u_dut.commit_stage_i.fence_i_o;
  wire        probe_fence_commit    = u_dut.commit_stage_i.fence_o;
  wire        probe_no_st_pending   = u_dut.commit_stage_i.no_st_pending_i;

  // Frontend / Fetch
  wire [31:0] probe_fetch_pc        = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_req       = u_dut.icache_dreq_if_cache.req;
  wire        probe_fetch_valid     = u_dut.icache_dreq_cache_if.valid;
  wire [31:0] probe_fe_instr        = u_dut.fetch_entry_if_id[0].instruction;
  wire        probe_fe_id_valid     = u_dut.fetch_valid_if_id;
  wire        probe_id_fe_ready     = u_dut.fetch_ready_id_if;
  wire [3:0]  probe_fifo_usage      = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;

  // I-cache & Flush internals
  wire [2:0]  probe_icache_state    = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q;
  wire        probe_icache_miss     = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.miss_o;
  wire        probe_icache_ready    = u_dut.icache_dreq_cache_if.ready;
  wire        probe_icache_flush_en = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_en;
  wire        probe_icache_flush_done = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_done;
  wire [7:0]  probe_icache_flush_cnt  = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_cnt_q;
  wire        probe_icache_flush_d  = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_d;

  // Controller & Flush probes
  wire        probe_fence_i_ctrl    = u_dut.controller_i.fence_i_i;
  wire        probe_fence_i_active  = u_dut.controller_i.fence_i_active_q;
  wire        probe_flush_icache    = u_dut.controller_i.flush_icache_o;
  wire        probe_flush_dcache    = u_dut.controller_i.flush_dcache_o;
  wire        probe_flush_csr       = u_dut.controller_i.flush_csr_i;
  wire        probe_halt_frontend   = u_dut.controller_i.halt_frontend_o;
  wire        probe_flush_bp        = u_dut.controller_i.flush_bp_o;
  wire        probe_flush_if        = u_dut.controller_i.flush_if_o;
  wire        probe_flush_id        = u_dut.controller_i.flush_id_o;
  wire        probe_flush_ex        = u_dut.controller_i.flush_ex_o;
  wire        probe_flush_unissued  = u_dut.controller_i.flush_unissued_instr_o;

  // Issue & Scoreboard Probes
  wire        probe_issue_valid0    = u_dut.issue_stage_i.issue_instr_valid_sb_iro[0];
  wire        probe_issue_ack0      = u_dut.issue_stage_i.issue_ack_iro_sb[0];
  wire        probe_stall_issue     = u_dut.issue_stage_i.i_issue_read_operands.stall_issue_o;
  wire        probe_stall_raw       = u_dut.issue_stage_i.i_issue_read_operands.stall_raw[0];

  // AXI Probes
  wire        probe_axi_arvalid     = noc_req.ar_valid;
  wire [31:0] probe_axi_araddr      = noc_req.ar.addr[31:0];
  wire        probe_axi_rvalid      = noc_resp.r_valid;
  wire        probe_axi_rlast       = noc_resp.r.last;
  wire        probe_axi_awvalid     = noc_req.aw_valid;
  wire [31:0] probe_axi_awaddr      = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid      = noc_req.w_valid;
  wire        probe_axi_bvalid      = noc_resp.b_valid;

  // ----------------------------------------------------------------------------
  // 5. AXI Slave Memory Responder (Read and Write)
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

  // AXI Read Channel
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

  // AXI Write Channel (Updates memory and self-modifying code target)
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
              automatic logic [63:0] cur_addr = noc_req.aw.addr;
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
  // 6. Architectural Register Inspection Function
  // ----------------------------------------------------------------------------
  function logic [31:0] read_arch_reg(input int r);
    if (r == 0) return 32'h0;
    return u_dut.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[r];
  endfunction

  // ----------------------------------------------------------------------------
  // 7. Event Counters & Performance Metrics Tracking
  // ----------------------------------------------------------------------------
  int unsigned cycle_count = 0;
  int unsigned inst_ret_count = 0;
  int unsigned fence_i_count = 0;
  int unsigned fence_count = 0;
  int unsigned flush_icache_count = 0;
  int unsigned flush_csr_count = 0;
  int unsigned icache_flush_state_count = 0;
  int unsigned flush_pipeline_count = 0;
  int unsigned flush_if_count = 0;
  int unsigned flush_bp_count = 0;

  int unsigned first_commit_cycle = 0;
  int unsigned end_commit_cycle = 0;
  bit end_loop_committed = 1'b0;

  always_ff @(posedge clk) begin
    if (rst_ni) begin
      cycle_count <= cycle_count + 1;

      if (probe_commit_ack[0]) begin
        inst_ret_count <= inst_ret_count + 1;
        if (first_commit_cycle == 0) first_commit_cycle <= cycle_count;
        if (probe_commit_pc0 == END_PC) begin
          end_commit_cycle   <= cycle_count;
          end_loop_committed <= 1'b1;
        end
        if (probe_fence_i_commit) begin
          fence_i_count <= fence_i_count + 1;
        end
        if (probe_fence_commit) begin
          fence_count <= fence_count + 1;
        end
      end

      if (probe_commit_ack[1]) begin
        inst_ret_count <= inst_ret_count + 1;
        if (probe_commit_pc1 == END_PC) begin
          end_commit_cycle   <= cycle_count;
          end_loop_committed <= 1'b1;
        end
      end

      if (probe_flush_icache) begin
        flush_icache_count <= flush_icache_count + 1;
      end

      if (probe_flush_csr) begin
        flush_csr_count <= flush_csr_count + 1;
      end

      if (probe_icache_flush_en) begin
        icache_flush_state_count <= icache_flush_state_count + 1;
      end

      if (probe_flush_if && probe_flush_id && probe_flush_ex) begin
        flush_pipeline_count <= flush_pipeline_count + 1;
      end

      if (probe_flush_if) begin
        flush_if_count <= flush_if_count + 1;
      end

      if (probe_flush_bp) begin
        flush_bp_count <= flush_bp_count + 1;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 8. CSV Trace Logging (60+ Microarchitectural Signals)
  // ----------------------------------------------------------------------------
  integer csv_fd;
  initial begin
    csv_fd = $fopen("cva6_fence_trace.csv", "w");
    if (csv_fd) begin
      $fwrite(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,CommitPC0,CommitPC1,");
      $fwrite(csv_fd, "CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,");
      $fwrite(csv_fd, "FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,");
      $fwrite(csv_fd, "IcacheState,IcacheMiss,IcacheReady,IcacheFlushEn,IcacheFlushDone,IcacheFlushCnt,IcacheFlushD,");
      $fwrite(csv_fd, "FenceICommit,FenceCommit,NoStPending,FenceICtrl,FenceIActive,FlushICache,FlushDCache,FlushCSR,HaltFrontend,");
      $fwrite(csv_fd, "FlushBP,FlushIF,FlushUnissued,FlushID,FlushEX,");
      $fwrite(csv_fd, "IssueValid0,IssueAck0,StallIssue,StallRaw,");
      $fwrite(csv_fd, "FenceICount,FlushIcacheCount,FlushCsrCount,FlushPipelineCount,IcacheFlushCycles,");
      $fwrite(csv_fd, "AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiBValid\n");
    end else begin
      $display("[TB_ERR] Failed to open cva6_fence_trace.csv for writing!");
    end
  end

  always_ff @(posedge clk) begin
    if (csv_fd && rst_ni) begin
      $fwrite(csv_fd, "%0d,%0d,%0d,%b,%b,0x%08x,0x%08x,",
              $time, cycle_count, inst_ret_count,
              probe_commit_ack[0], probe_commit_ack[1], probe_commit_pc0, probe_commit_pc1);
      $fwrite(csv_fd, "0x%08x,0x%08x,%b,%0d,0x%08x,%b,%0d,0x%08x,",
              probe_commit_res0, probe_commit_res1,
              probe_we_gpr[0], probe_waddr_gpr[0], probe_wdata_gpr[0],
              probe_we_gpr[1], probe_waddr_gpr[1], probe_wdata_gpr[1]);
      $fwrite(csv_fd, "0x%08x,%b,%b,0x%08x,%b,%b,%0d,",
              probe_fetch_pc, probe_fetch_req, probe_fetch_valid, probe_fe_instr,
              probe_fe_id_valid, probe_id_fe_ready, probe_fifo_usage);
      $fwrite(csv_fd, "%0d,%b,%b,%b,%b,%0d,%b,",
              probe_icache_state, probe_icache_miss, probe_icache_ready,
              probe_icache_flush_en, probe_icache_flush_done, probe_icache_flush_cnt, probe_icache_flush_d);
      $fwrite(csv_fd, "%b,%b,%b,%b,%b,%b,%b,%b,%b,",
              probe_fence_i_commit, probe_fence_commit, probe_no_st_pending,
              probe_fence_i_ctrl, probe_fence_i_active, probe_flush_icache, probe_flush_dcache, probe_flush_csr, probe_halt_frontend);
      $fwrite(csv_fd, "%b,%b,%b,%b,%b,",
              probe_flush_bp, probe_flush_if, probe_flush_unissued, probe_flush_id, probe_flush_ex);
      $fwrite(csv_fd, "%b,%b,%b,%b,",
              probe_issue_valid0, probe_issue_ack0, probe_stall_issue, probe_stall_raw);
      $fwrite(csv_fd, "%0d,%0d,%0d,%0d,%0d,",
              fence_i_count, flush_icache_count, flush_csr_count, flush_pipeline_count, icache_flush_state_count);
      $fwrite(csv_fd, "%b,0x%08x,%b,%b,%b,0x%08x,%b,%b\n",
              probe_axi_arvalid, probe_axi_araddr, probe_axi_rvalid, probe_axi_rlast,
              probe_axi_awvalid, probe_axi_awaddr, probe_axi_wvalid, probe_axi_bvalid);
    end
  end

  // ----------------------------------------------------------------------------
  // 9. Simulation Watchdog & Scoreboard Verification
  // ----------------------------------------------------------------------------
  int check_count = 0;
  int error_count = 0;

  task automatic check_reg(input int reg_idx, input logic [31:0] expected, input string name);
    logic [31:0] actual;
    actual = read_arch_reg(reg_idx);
    check_count++;
    if (actual === expected) begin
      $display("[PASS] Reg x%0d (%s) = 0x%08x", reg_idx, name, actual);
    end else begin
      $display("[FAIL] Reg x%0d (%s) = 0x%08x (Expected: 0x%08x)", reg_idx, name, actual, expected);
      error_count++;
    end
  endtask

  initial begin
    $display("============================================================");
    $display("[TB_INFO] CVA6 Suite 5: Pipeline Flushes & FENCE.I Sync");
    $display("[TB_INFO] Self-Modifying Code, I-Cache Invalidation, CSR Flushes");
    $display("============================================================");

    @(posedge rst_ni);
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08x", $time, BOOT_ADDR);

    // Run until end_loop has committed or timeout
    while (!end_loop_committed && cycle_count < TIMEOUT_CYCLES) begin
      @(posedge clk);
    end

    if (end_loop_committed) begin
      $display("[%0t] [TB_END] END self-loop committed at cycle %0d.", $time, end_commit_cycle);
    end else begin
      $display("[%0t] [TB_TIMEOUT] Watchdog expired after %0d cycles!", $time, cycle_count);
    end

    // Extra cycles to settle
    repeat (20) @(posedge clk);

    // Close CSV
    if (csv_fd) begin
      $fclose(csv_fd);
      $display("[TB_INFO] Trace dumped to cva6_fence_trace.csv");
    end

    // --------------------------------------------------------------------------
    // Verification Scoreboard Checks
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural register checks");
    $display("============================================================");

    check_reg(1,  32'd100,        "ra: first subroutine call before modification");
    check_reg(2,  32'd999,        "sp: second subroutine call AFTER FENCE.I rewrite");
    check_reg(3,  32'd555,        "gp: marker after CSR side-effect flush");
    check_reg(4,  32'd777,        "tp: marker after standard data FENCE");
    check_reg(20, 32'd999,        "s4: terminal self-loop marker");
    check_reg(31, 32'h8000_0200,  "t6: subroutine pointer preserved");

    // Microarchitectural hardware checks
    check_count++;
    if (end_loop_committed) begin
      $display("[PASS] END self-loop committed");
    end else begin
      $display("[FAIL] END self-loop did not commit");
      error_count++;
    end

    check_count++;
    if (fence_i_count >= 1) begin
      $display("[PASS] FENCE.I instruction committed (fence_i_count = %0d)", fence_i_count);
    end else begin
      $display("[FAIL] FENCE.I instruction did not commit (fence_i_count = %0d)", fence_i_count);
      error_count++;
    end

    check_count++;
    if (flush_icache_count >= 1) begin
      $display("[PASS] flush_icache_o asserted by controller (count = %0d)", flush_icache_count);
    end else begin
      $display("[FAIL] flush_icache_o never asserted (count = %0d)", flush_icache_count);
      error_count++;
    end

    check_count++;
    if (icache_flush_state_count >= 10) begin
      $display("[PASS] I-Cache entered and spent %0d cycles in FLUSH state", icache_flush_state_count);
    end else begin
      $display("[FAIL] I-Cache flush state duration too short (%0d cycles)", icache_flush_state_count);
      error_count++;
    end

    check_count++;
    if (flush_csr_count >= 1) begin
      $display("[PASS] flush_csr_ctrl asserted on CSR write (count = %0d)", flush_csr_count);
    end else begin
      $display("[FAIL] flush_csr_ctrl never asserted (count = %0d)", flush_csr_count);
      error_count++;
    end

    check_count++;
    if (flush_pipeline_count >= 2) begin
      $display("[PASS] Full pipeline flushes occurred on FENCE.I and CSR write (count = %0d)", flush_pipeline_count);
    end else begin
      $display("[FAIL] Full pipeline flush count insufficient (count = %0d)", flush_pipeline_count);
      error_count++;
    end

    // Performance Summary
    $display("------------------------------------------------------------");
    $display("[METRICS] Committed instructions    : %0d", inst_ret_count);
    $display("[METRICS] First commit cycle        : %0d", first_commit_cycle);
    $display("[METRICS] End commit cycle          : %0d", end_commit_cycle);
    $display("[METRICS] FENCE.I instructions      : %0d", fence_i_count);
    $display("[METRICS] Data FENCE instructions   : %0d", fence_count);
    $display("[METRICS] I-Cache tag flush cycles  : %0d", icache_flush_state_count);
    $display("[METRICS] CSR side-effect flushes   : %0d", flush_csr_count);
    $display("[METRICS] Full pipeline flushes     : %0d", flush_pipeline_count);
    if (inst_ret_count > 0 && end_commit_cycle > first_commit_cycle) begin
      automatic real active_cpi = real'(end_commit_cycle - first_commit_cycle) / real'(inst_ret_count);
      $display("[METRICS] Active CPI (FENCE.I load) : %0.2f", active_cpi);
    end
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 5:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-5 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-5 FAILED WITH %0d ERRORS", error_count);
    end

    sim_done = 1'b1;
    $finish;
  end

endmodule
