// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-20 18:01:00 +03:30
// Status: MODIFIED FILE
// Reason / Modification: Updated benchmark program with 4-byte naturally aligned DRAM addresses to avoid ST_ADDR_MISALIGNED exception, updated END_PC to 0x8000_0040, and aligned verification checks.
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_simulator_alignment;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clock
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 3000;
  localparam int  MEM_WORDS      = 1024;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;
  localparam logic [31:0] END_PC    = 32'h8000_0040; // BEQ x0, x0, 0 at END

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
  // 3. DUT Internal Microarchitectural Probes
  // ----------------------------------------------------------------------------
  // Commit Stage Probes
  wire [1:0]  probe_commit_ack      = u_dut.commit_stage_i.commit_ack_o;
  wire [31:0] probe_commit_pc0      = probe_commit_ack[0] ? u_dut.commit_stage_i.commit_instr_i[0].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_pc1      = probe_commit_ack[1] ? u_dut.commit_stage_i.commit_instr_i[1].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_instr0   = probe_commit_ack[0] ? u_dut.commit_instr_id_commit[0].result[31:0] : 32'h0;
  wire [31:0] probe_commit_instr1   = probe_commit_ack[1] ? u_dut.commit_instr_id_commit[1].result[31:0] : 32'h0;
  wire [1:0]  probe_we_gpr          = u_dut.we_gpr_commit_id;
  wire [1:0][4:0]  probe_waddr_gpr  = u_dut.waddr_commit_id;
  wire [1:0][31:0] probe_wdata_gpr  = u_dut.wdata_commit_id;

  // Fetch / Front-End
  wire [31:0] probe_fetch_pc        = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_req       = u_dut.icache_dreq_if_cache.req;
  wire        probe_fetch_valid     = u_dut.icache_dreq_cache_if.valid;
  wire [31:0] probe_fe_instr        = u_dut.fetch_entry_if_id[0].instruction;
  wire        probe_fe_id_valid     = u_dut.fetch_valid_if_id;
  wire        probe_id_fe_ready     = u_dut.fetch_ready_id_if;
  wire [3:0]  probe_fifo_usage      = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;

  // I-Cache
  wire [2:0]  probe_icache_state    = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q;
  wire        probe_icache_miss     = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.miss_o;
  wire        probe_icache_ready    = u_dut.icache_dreq_cache_if.ready;

  // Issue Stage & Scoreboard Hazard Probes
  wire        probe_issue_valid0    = u_dut.issue_stage_i.issue_instr_valid_sb_iro[0];
  wire        probe_issue_ack0      = u_dut.issue_stage_i.issue_ack_iro_sb[0];
  wire        probe_stall_issue     = u_dut.issue_stage_i.i_issue_read_operands.stall_issue_o;
  wire        probe_stall_raw       = u_dut.issue_stage_i.i_issue_read_operands.stall_raw[0];
  wire        probe_stall_rs1       = u_dut.issue_stage_i.i_issue_read_operands.stall_rs1[0];
  wire        probe_stall_rs2       = u_dut.issue_stage_i.i_issue_read_operands.stall_rs2[0];
  wire        probe_rs1_has_raw     = u_dut.issue_stage_i.i_issue_read_operands.rs1_has_raw[0];
  wire        probe_rs2_has_raw     = u_dut.issue_stage_i.i_issue_read_operands.rs2_has_raw[0];
  wire        probe_forward_rs1     = u_dut.issue_stage_i.i_issue_read_operands.forward_rs1[0];
  wire        probe_forward_rs2     = u_dut.issue_stage_i.i_issue_read_operands.forward_rs2[0];
  wire        probe_is_alu_bypass   = u_dut.issue_stage_i.i_issue_read_operands.is_alu_bypass;
  wire        probe_alu_bypass_rs1  = u_dut.issue_stage_i.i_issue_read_operands.alu_bypass.rs1_from_rd;
  wire        probe_alu_bypass_rs2  = u_dut.issue_stage_i.i_issue_read_operands.alu_bypass.rs2_from_rd;
  wire        probe_fu_busy_alu     = u_dut.issue_stage_i.i_issue_read_operands.fus_busy[0].alu;
  wire        probe_fu_busy_mult    = u_dut.issue_stage_i.i_issue_read_operands.fus_busy[0].mult;
  wire        probe_fu_busy_load    = u_dut.issue_stage_i.i_issue_read_operands.fus_busy[0].load;
  wire        probe_flu_ready       = u_dut.ex_stage_i.flu_ready_o;
  wire        probe_lsu_ready       = u_dut.lsu_ready_ex_id;
  wire        probe_sb_full         = u_dut.issue_stage_i.i_scoreboard.sb_full_o;

  // Scoreboard internal slot occupancy
  int probe_sb_issued_count;
  always_comb begin
    probe_sb_issued_count = 0;
    for (int s = 0; s < CVA6Cfg.NR_SB_ENTRIES; s++) begin
      if (u_dut.issue_stage_i.i_scoreboard.mem_q[s].issued &&
          !u_dut.issue_stage_i.i_scoreboard.mem_q[s].cancelled) begin
        probe_sb_issued_count++;
      end
    end
  end

  // Multiplier Probes
  wire        probe_mult_valid_id   = u_dut.mult_valid_id_ex[0];
  wire        probe_mult_ready      = u_dut.ex_stage_i.mult_ready;
  wire        probe_mult_valid      = u_dut.ex_stage_i.mult_valid;
  wire [CVA6Cfg.TRANS_ID_BITS-1:0] probe_mult_trans_id = u_dut.ex_stage_i.mult_trans_id;
  wire [31:0] probe_mult_result     = u_dut.ex_stage_i.mult_result[31:0];
  wire        probe_mul_valid_op    = u_dut.ex_stage_i.i_mult.mul_valid_op;
  wire        probe_mul_valid       = u_dut.ex_stage_i.i_mult.mul_valid;

  // LSU & Store Buffer Probes
  wire        probe_lsu_valid_id    = u_dut.lsu_valid_id_ex[0];
  wire [31:0] probe_load_result     = u_dut.load_result_ex_id[31:0];
  wire [CVA6Cfg.TRANS_ID_BITS-1:0] probe_load_trans_id = u_dut.load_trans_id_ex_id;
  wire [3:0]  probe_load_unit_state = u_dut.ex_stage_i.lsu_i.i_load_unit.state_q;
  wire        probe_page_offset_matches = u_dut.ex_stage_i.lsu_i.page_offset_matches;
  wire        probe_store_buf_empty = u_dut.ex_stage_i.lsu_i.i_store_unit.store_buffer_empty_o;
  wire        probe_store_buf_no_pending = u_dut.ex_stage_i.lsu_i.i_store_unit.no_st_pending_o;
  wire        probe_store_buf_valid = u_dut.ex_stage_i.lsu_i.i_store_unit.store_buffer_i.valid_i;
  wire        probe_store_buf_ready = u_dut.ex_stage_i.lsu_i.i_store_unit.store_buffer_i.ready_o;
  wire        probe_store_buf_commit= u_dut.ex_stage_i.lsu_i.i_store_unit.store_buffer_i.commit_i;

  // Branch Unit Probes
  wire        probe_branch_valid    = u_dut.branch_valid_id_ex[0];
  wire        probe_branch_predict  = u_dut.branch_predict_id_ex.valid;
  wire        probe_resolve_branch  = u_dut.resolve_branch_ex_id;
  wire        probe_resolved_valid  = u_dut.resolved_branch.valid;
  wire        probe_resolved_taken  = u_dut.resolved_branch.is_taken;
  wire        probe_resolved_mispredict = u_dut.resolved_branch.is_mispredict;
  wire [31:0] probe_resolved_target = u_dut.resolved_branch.target_address[31:0];
  wire        probe_flush_bp        = u_dut.flush_ctrl_bp;
  wire        probe_flush_if        = u_dut.flush_ctrl_if;
  wire        probe_flush_id        = u_dut.flush_ctrl_id;

  // AXI Bus Probes
  wire        probe_axi_arvalid     = noc_req.ar_valid;
  wire [31:0] probe_axi_araddr      = noc_req.ar.addr[31:0];
  wire        probe_axi_rvalid      = noc_resp.r_valid;
  wire        probe_axi_rlast       = noc_resp.r.last;
  wire        probe_axi_awvalid     = noc_req.aw_valid;
  wire [31:0] probe_axi_awaddr      = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid      = noc_req.w_valid;
  wire        probe_axi_wlast       = noc_req.w.last;
  wire        probe_axi_bvalid      = noc_resp.b_valid;

  // ----------------------------------------------------------------------------
  // 4. Memory Model Image (Unified Alignment Benchmark)
  // ----------------------------------------------------------------------------
  logic [31:0] mem[0:MEM_WORDS-1];

  initial begin
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h00000013; // ADDI x0, x0, 0 (NOP)
    end

    // 17-instruction Unified Multi-Hazard Alignment Benchmark
    mem[0]  = 32'h80000637; // 0x8000_0000: LUI  x12, 0x80000      (DRAM base 0x8000_0000)
    mem[1]  = 32'h00a00093; // 0x8000_0004: ADDI x1, x0, 10        (x1 = 10)
    mem[2]  = 32'h01400113; // 0x8000_0008: ADDI x2, x0, 20        (x2 = 20)
    mem[3]  = 32'h002081b3; // 0x8000_000c: ADD  x3, x1, x2        (x3 = 30)
    mem[4]  = 32'h00118233; // 0x8000_0010: ADD  x4, x3, x1        (x4 = 40, RAW hazard on x3)
    mem[5]  = 32'h00500293; // 0x8000_0014: ADDI x5, x0, 5         (x5 = 5)
    mem[6]  = 32'h10362023; // 0x8000_0018: SW   x3, 256(x12)      (Store 30 to 0x8000_0100)
    mem[7]  = 32'h10462223; // 0x8000_001c: SW   x4, 260(x12)      (Store 40 to 0x8000_0104)
    mem[8]  = 32'h10062303; // 0x8000_0020: LW   x6, 256(x12)      (Load from 0x8000_0100, x6 = 30)
    mem[9]  = 32'h025303b3; // 0x8000_0024: MUL  x7, x6, x5        (x7 = 30*5 = 150)
    mem[10] = 32'h06400413; // 0x8000_0028: ADDI x8, x0, 100       (x8 = 100)
    mem[11] = 32'h008384b3; // 0x8000_002c: ADD  x9, x7, x8        (x9 = 150+100 = 250, RAW on x7)
    mem[12] = 32'h00200513; // 0x8000_0030: ADDI x10, x0, 2        (x10 = 2)
    mem[13] = 32'hfff50513; // 0x8000_0034: ADDI x10, x10, -1      (align_loop body)
    mem[14] = 32'hfe051ee3; // 0x8000_0038: BNE  x10, x0, -4       (Branch to 0x34 while x10 != 0)
    mem[15] = 32'h02a48593; // 0x8000_003c: ADDI x11, x9, 42       (x11 = 250+42 = 292)
    mem[16] = 32'h00000063; // 0x8000_0040: BEQ  x0, x0, 0         (Terminal self-loop)
  end

  // ----------------------------------------------------------------------------
  // 5. AXI4 Read/Write Responder (64-bit channels)
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

  logic [CVA6Cfg.AxiIdWidth-1:0]   ar_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] ar_addr_q;
  axi_pkg::len_t                   ar_len_q;
  logic [7:0]                      ar_cnt_q;

  logic [CVA6Cfg.AxiIdWidth-1:0]   aw_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] aw_addr_q;
  logic [7:0]                      aw_cnt_q;

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
            automatic int unsigned word_idx = (cur_addr[11:3] << 1);
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
              automatic int unsigned word_idx = (noc_req.aw.addr[11:3] << 1);
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
                w_state          <= B_RESP;
              end else begin
                w_state          <= W_BURST;
                aw_cnt_q         <= aw_cnt_q + 8'd1;
              end
            end else begin
              w_state <= W_BURST;
            end
          end
        end

        W_BURST: begin
          noc_resp.w_ready  <= 1'b1;
          noc_resp.aw_ready <= 1'b0;

          if (noc_req.w_valid && noc_resp.w_ready) begin
            automatic logic [63:0] cur_addr = aw_addr_q + (aw_cnt_q * 8);
            automatic int unsigned word_idx = (cur_addr[11:3] << 1);
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
              w_state          <= B_RESP;
            end else begin
              aw_cnt_q <= aw_cnt_q + 8'd1;
            end
          end
        end

        B_RESP: begin
          noc_resp.w_ready  <= 1'b0;
          noc_resp.aw_ready <= 1'b0;
          noc_resp.b_valid  <= 1'b1;

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
  // 6. GPR Helper Function
  // ----------------------------------------------------------------------------
  function automatic logic [31:0] read_gpr(input int r);
    if (r == 0) return 32'h0;
    return u_dut.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[r];
  endfunction

  // ----------------------------------------------------------------------------
  // 7. Metrics, Event Monitor & 83-Column CSV Logger
  // ----------------------------------------------------------------------------
  int check_count     = 0;
  int error_count     = 0;
  int cycle_count     = 0;
  int instret_count   = 0;
  int csv_fd;
  logic logging_en    = 1'b0;

  int first_commit_cycle = 0;
  int end_commit_cycle   = 0;

  int raw_forward_count        = 0;
  int load_use_stall_count     = 0;
  int store_buffer_stall_count = 0;
  int mul_exec_count           = 0;

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      instret_count            <= 0;
      raw_forward_count        <= 0;
      load_use_stall_count     <= 0;
      store_buffer_stall_count <= 0;
      mul_exec_count           <= 0;
      first_commit_cycle       <= 0;
      end_commit_cycle         <= 0;
    end else begin
      if (probe_commit_ack[0]) instret_count <= instret_count + 1;
      if (probe_commit_ack[1]) instret_count <= instret_count + 1;

      if ((probe_commit_ack[0] || probe_commit_ack[1]) && first_commit_cycle == 0)
        first_commit_cycle <= cycle_count;

      if (probe_forward_rs1 || probe_forward_rs2)
        raw_forward_count <= raw_forward_count + 1;

      if (probe_stall_raw && (probe_stall_rs1 || probe_stall_rs2))
        load_use_stall_count <= load_use_stall_count + 1;

      if (probe_page_offset_matches || probe_load_unit_state == 4'd3)
        store_buffer_stall_count <= store_buffer_stall_count + 1;

      if (probe_mul_valid_op)
        mul_exec_count <= mul_exec_count + 1;
    end
  end

  // Cycle counter
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) cycle_count <= 0;
    else         cycle_count <= cycle_count + 1;
  end

  initial begin
    csv_fd = $fopen("cva6_simulator_alignment_trace.csv", "w");
    logging_en = 1'b1;
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,IcacheState,IcacheMiss,IcacheReady,IssueValid0,IssueAck0,StallIssue,StallRaw,StallRs1,StallRs2,Rs1HasRaw,Rs2HasRaw,ForwardRs1,ForwardRs2,IsAluBypass,AluBypassRs1,AluBypassRs2,FuBusyAlu,FuBusyMult,FuBusyLoad,FluReady,LsuReady,SbFull,SbIssuedCount,MultValidId,MultReady,MultValid,MultTransId,MultResult,MulValidOp,MulValid,LsuValidId,LoadResult,LoadTransId,LoadUnitState,PageOffsetMatches,StoreBufEmpty,StoreBufNoPending,StoreBufValid,StoreBufReady,StoreBufCommit,BranchValid,BranchPredictValid,ResolveBranch,ResolvedValid,ResolvedTaken,ResolvedMispredict,ResolvedTarget,FlushBp,FlushIf,FlushId,AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiWLast,AxiBValid,RawForwardCount,LoadUseStallCount,StoreBufStallCount,MulExecCount");
    end else begin
      $display("[TB_WARNING] Could not open cva6_simulator_alignment_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    if (csv_fd && logging_en) begin
      $fdisplay(csv_fd, "%0t,%0d,%0d,%b,%b,0x%08h,0x%08h,0x%08h,0x%08h,%b,%0d,0x%08h,%b,%0d,0x%08h,0x%08h,%b,%b,0x%08h,%b,%b,%0d,%0d,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%0d,%b,%b,%b,%0d,0x%08h,%b,%b,%b,0x%08h,%0d,%0d,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,0x%08h,%b,%b,%b,%b,0x%08h,%b,%b,%b,0x%08h,%b,%b,%b,%0d,%0d,%0d,%0d",
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
                probe_issue_valid0,
                probe_issue_ack0,
                probe_stall_issue,
                probe_stall_raw,
                probe_stall_rs1,
                probe_stall_rs2,
                probe_rs1_has_raw,
                probe_rs2_has_raw,
                probe_forward_rs1,
                probe_forward_rs2,
                probe_is_alu_bypass,
                probe_alu_bypass_rs1,
                probe_alu_bypass_rs2,
                probe_fu_busy_alu,
                probe_fu_busy_mult,
                probe_fu_busy_load,
                probe_flu_ready,
                probe_lsu_ready,
                probe_sb_full,
                probe_sb_issued_count,
                probe_mult_valid_id,
                probe_mult_ready,
                probe_mult_valid,
                probe_mult_trans_id,
                probe_mult_result,
                probe_mul_valid_op,
                probe_mul_valid,
                probe_lsu_valid_id,
                probe_load_result,
                probe_load_trans_id,
                probe_load_unit_state,
                probe_page_offset_matches,
                probe_store_buf_empty,
                probe_store_buf_no_pending,
                probe_store_buf_valid,
                probe_store_buf_ready,
                probe_store_buf_commit,
                probe_branch_valid,
                probe_branch_predict,
                probe_resolve_branch,
                probe_resolved_valid,
                probe_resolved_taken,
                probe_resolved_mispredict,
                probe_resolved_target,
                probe_flush_bp,
                probe_flush_if,
                probe_flush_id,
                probe_axi_arvalid,
                probe_axi_araddr,
                probe_axi_rvalid,
                probe_axi_rlast,
                probe_axi_awvalid,
                probe_axi_awaddr,
                probe_axi_wvalid,
                probe_axi_wlast,
                probe_axi_bvalid,
                raw_forward_count,
                load_use_stall_count,
                store_buffer_stall_count,
                mul_exec_count
      );
    end
  end

  // ----------------------------------------------------------------------------
  // 8. Main Test Execution & Self-Checking Block
  // ----------------------------------------------------------------------------
  initial begin
    $display("=================================================================");
    $display(" Starting tb_cva6_simulator_alignment (Unified Multi-Hazard Suite)");
    $display("=================================================================");

    rst_ni     = 1'b0;
    boot_addr  = BOOT_ADDR;
    hart_id    = '0;
    irq        = 2'b00;
    ipi        = 1'b0;
    time_irq   = 1'b0;
    debug_req  = 1'b0;
    cvxif_resp = '0;

    #(CLK_PERIOD * 5);
    rst_ni = 1'b1;
    $display("[TB] Deasserted reset at %0t (Cycle %0d)", $time, cycle_count);

    // Run until END_PC (0x8000_003C) commits or timeout
    while (!sim_done && cycle_count < TIMEOUT_CYCLES) begin
      @(posedge clk);
      if ((probe_commit_ack[0] && probe_commit_pc0 == END_PC) ||
          (probe_commit_ack[1] && probe_commit_pc1 == END_PC)) begin
        if (end_commit_cycle == 0) begin
          end_commit_cycle = cycle_count;
          $display("[TB] Terminal PC 0x%08h committed at Cycle %0d!", END_PC, end_commit_cycle);
        end
        // Allow a few pipeline drain cycles
        #(CLK_PERIOD * 15);
        sim_done = 1'b1;
      end
    end

    if (!sim_done) begin
      $display("[TB_ERROR] Simulation reached TIMEOUT (%0d cycles) without hitting END_PC 0x%08h",
               TIMEOUT_CYCLES, END_PC);
      error_count++;
    end

    // Close CSV trace
    if (csv_fd) begin
      $fclose(csv_fd);
      $display("[TB] Closed cva6_simulator_alignment_trace.csv");
    end

    // Verify Architectural Register File State
    $display("\n--- ARCHITECTURAL REGISTER VERIFICATION ---");
    check_reg(12, 32'h8000_0000, "x12 (DRAM base pointer = 0x80000000)");
    check_reg(1,  32'd10,        "x1  (constant 10)");
    check_reg(2,  32'd20,        "x2  (operand 20)");
    check_reg(3,  32'd30,        "x3  (ADD x1, x2 = 30)");
    check_reg(4,  32'd40,        "x4  (ADD x3, x1 = 40, RAW dependency)");
    check_reg(5,  32'd5,         "x5  (ADDI 5)");
    check_reg(6,  32'd30,        "x6  (LW from 0x8000_0100 = 30, store forwarding)");
    check_reg(7,  32'd150,       "x7  (MUL x6, x5 = 150)");
    check_reg(8,  32'd100,       "x8  (ADDI 100, out-of-order write-back)");
    check_reg(9,  32'd250,       "x9  (ADD x7, x8 = 250)");
    check_reg(10, 32'd0,         "x10 (loop counter decremented to 0)");
    check_reg(11, 32'd292,       "x11 (Final result: 250 + 42 = 292)");

    // Verify Memory Content written by stores (0x100 = word 64, 0x104 = word 65)
    $display("\n--- MEMORY WRITEBACK VERIFICATION ---");
    check_mem(64, 32'd30, "Mem[0x100/4] (SW x3, 256(x12) = 30)");
    check_mem(65, 32'd40, "Mem[0x104/4] (SW x4, 260(x12) = 40)");

    // Microarchitectural Metric Summary
    $display("\n=================================================================");
    $display(" SIMULATION METRICS SUMMARY");
    $display("=================================================================");
    $display(" Total Simulation Cycles : %0d", cycle_count);
    $display(" First Commit Cycle      : %0d", first_commit_cycle);
    $display(" End Commit Cycle        : %0d", end_commit_cycle);
    $display(" Active Execution Window : %0d cycles", (end_commit_cycle - first_commit_cycle));
    $display(" Committed Instructions  : %0d", instret_count);
    if (instret_count > 0 && end_commit_cycle > first_commit_cycle) begin
      $display(" Active CPI              : %0.2f",
               real'(end_commit_cycle - first_commit_cycle) / real'(instret_count));
    end
    $display(" Total Error Count       : %0d / %0d checks", error_count, check_count);
    $display("=================================================================");

    if (error_count == 0 && sim_done) begin
      $display("\n[TEST RESULT: ALL CHECKS PASSED SUCCESSFULLY!]\n");
    end else begin
      $display("\n[TEST RESULT: FAILED with %0d errors]\n", error_count);
    end

    $finish;
  end

  task check_reg(input int r, input logic [31:0] expected, input string desc);
    logic [31:0] actual;
    actual = read_gpr(r);
    check_count++;
    if (actual === expected) begin
      $display("  [PASS] Reg x%0d = %0d (0x%08h) | %s", r, actual, actual, desc);
    end else begin
      $display("  [FAIL] Reg x%0d = %0d (expected %0d, 0x%08h) | %s", r, actual, expected, expected, desc);
      error_count++;
    end
  endtask

  task check_mem(input int w, input logic [31:0] expected, input string desc);
    logic [31:0] actual;
    actual = mem[w];
    check_count++;
    if (actual === expected) begin
      $display("  [PASS] Mem[%0d] = %0d (0x%08h) | %s", w, actual, actual, desc);
    end else begin
      $display("  [FAIL] Mem[%0d] = %0d (expected %0d) | %s", w, actual, expected, desc);
      error_count++;
    end
  endtask

endmodule
