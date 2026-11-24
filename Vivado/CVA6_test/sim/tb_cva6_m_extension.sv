// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 22:35:00 +03:30
// Status: NEW FILE
// Reason / Modification: Dedicated SystemVerilog verification testbench for
//                        Suite 11 (M-Extension Arithmetic Corner Cases:
//                        Division by zero, signed overflow -2^31/-1, magnitude
//                        |opB| > |opA| early termination, and high-word multiplier
//                        operations MULH, MULHU, and MULHSU).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_m_extension;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // Clock and Reset Signals
  // ----------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // 100 MHz (10 ns clock period)
  end

  // ----------------------------------------------------------------------------
  // Top-Level Control & Interrupt Inputs
  // ----------------------------------------------------------------------------
  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;

  logic [31:0] boot_addr;
  logic [31:0] hart_id;
  logic [1:0]  irq;
  logic        ipi;
  logic        time_irq;
  logic        debug_req;

  // CVXIF interface (disabled in bare-metal FPGA configuration)
  cvxif_req_t  cvxif_req;
  cvxif_resp_t cvxif_resp;

  // AXI Master Request & Slave Response
  cva6_types_pkg::noc_req_t  noc_req;
  cva6_types_pkg::noc_resp_t noc_resp;

  // ----------------------------------------------------------------------------
  // Memory Subsystem Modeling (4 KB local memory, 1024 x 32-bit words)
  // ----------------------------------------------------------------------------
  localparam int MEM_WORDS = 1024;
  logic [31:0] mem [0:MEM_WORDS-1];

  initial begin
    boot_addr = BOOT_ADDR;
    hart_id   = '0;
    irq       = '0;
    ipi       = 1'b0;
    time_irq  = 1'b0;
    debug_req = 1'b0;
    cvxif_resp = '0;

    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h0000_0013; // nop
    end

    // --------------------------------------------------------------------------
    // Suite 11 Benchmark Program (.text loaded from 0x8000_0000)
    // --------------------------------------------------------------------------
    mem[  0] = 32'h80000137; // 0x80000000: lui    sp, 0x80000
    mem[  1] = 32'h20010113; // 0x80000004: addi   sp, sp, 512
    mem[  2] = 32'h3e800193; // 0x80000008: li     gp, 1000
    mem[  3] = 32'h00000213; // 0x8000000c: li     tp, 0
    mem[  4] = 32'h0241c533; // 0x80000010: div    a0, gp, tp
    mem[  5] = 32'h0241d5b3; // 0x80000014: divu   a1, gp, tp
    mem[  6] = 32'h0241e633; // 0x80000018: rem    a2, gp, tp
    mem[  7] = 32'h0241f6b3; // 0x8000001c: remu   a3, gp, tp
    mem[  8] = 32'h80000937; // 0x80000020: lui    s2, 0x80000
    mem[  9] = 32'hfff00993; // 0x80000024: li     s3, -1
    mem[ 10] = 32'h03394733; // 0x80000028: div    a4, s2, s3
    mem[ 11] = 32'h033967b3; // 0x8000002c: rem    a5, s2, s3
    mem[ 12] = 32'h03395833; // 0x80000030: divu   a6, s2, s3
    mem[ 13] = 32'h033978b3; // 0x80000034: remu   a7, s2, s3
    mem[ 14] = 32'h00500293; // 0x80000038: li     t0, 5
    mem[ 15] = 32'h06400313; // 0x8000003c: li     t1, 100
    mem[ 16] = 32'h0262ca33; // 0x80000040: div    s4, t0, t1
    mem[ 17] = 32'h0262eab3; // 0x80000044: rem    s5, t0, t1
    mem[ 18] = 32'hffe00393; // 0x80000048: li     t2, -2
    mem[ 19] = 32'h00300e13; // 0x8000004c: li     t3, 3
    mem[ 20] = 32'h03c38b33; // 0x80000050: mul    s6, t2, t3
    mem[ 21] = 32'h03c39bb3; // 0x80000054: mulh   s7, t2, t3
    mem[ 22] = 32'hfff00e93; // 0x80000058: li     t4, -1
    mem[ 23] = 32'h03de8c33; // 0x8000005c: mul    s8, t4, t4
    mem[ 24] = 32'h03debcb3; // 0x80000060: mulhu  s9, t4, t4
    mem[ 25] = 32'h03deadb3; // 0x80000064: mulhsu s11, t4, t4
    mem[ 26] = 32'h40000f37; // 0x80000068: lui    t5, 0x40000
    mem[ 27] = 32'h032f1fb3; // 0x8000006c: mulh   t6, t5, s2
    mem[ 28] = 32'h3e700d13; // 0x80000070: li     s10, 999
    mem[ 29] = 32'h0000006f; // 0x80000074: j      end_loop
    mem[ 30] = 32'h00000013; // 0x80000078: nop
  end

  // ----------------------------------------------------------------------------
  // Instantiate Device Under Test (CVA6 Core)
  // ----------------------------------------------------------------------------
  cva6 u_dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .boot_addr_i    (boot_addr),
    .hart_id_i      (hart_id),
    .irq_i          (irq),
    .ipi_i          (ipi),
    .time_irq_i     (time_irq),
    .debug_req_i    (debug_req),
    .rvfi_probes_o  (),
    .cvxif_req_o    (cvxif_req),
    .cvxif_resp_i   (cvxif_resp),
    .noc_req_o      (noc_req),
    .noc_resp_i     (noc_resp)
  );

  // ----------------------------------------------------------------------------
  // Microarchitectural Internal Hierarchy Probes
  // ----------------------------------------------------------------------------
  wire        probe_commit_ack0         = u_dut.commit_ack[0];
  wire        probe_commit_ack1         = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.commit_ack[1] : 1'b0;
  wire        probe_dual_commit         = probe_commit_ack0 && probe_commit_ack1;
  wire [31:0] probe_commit_pc0          = probe_commit_ack0 ? u_dut.commit_instr_id_commit[0].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_pc1          = probe_commit_ack1 ? u_dut.commit_instr_id_commit[1].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_res0         = probe_commit_ack0 ? u_dut.commit_instr_id_commit[0].result[31:0] : 32'h0;
  wire [31:0] probe_commit_res1         = probe_commit_ack1 ? u_dut.commit_instr_id_commit[1].result[31:0] : 32'h0;

  wire        probe_gpr_we0             = u_dut.we_gpr_commit_id[0];
  wire [4:0]  probe_gpr_waddr0          = u_dut.waddr_commit_id[0];
  wire [31:0] probe_gpr_wdata0          = u_dut.wdata_commit_id[0][31:0];

  wire        probe_gpr_we1             = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.we_gpr_commit_id[1] : 1'b0;
  wire [4:0]  probe_gpr_waddr1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.waddr_commit_id[1] : 5'd0;
  wire [31:0] probe_gpr_wdata1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.wdata_commit_id[1][31:0] : 32'h0;

  wire [31:0] probe_fetch_pc            = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_valid         = u_dut.icache_dreq_cache_if.valid;

  // Multiplier and Divider Subsystem Probes
  wire        probe_div_valid_op        = u_dut.ex_stage_i.i_mult.div_valid_op;
  wire        probe_div_ready           = u_dut.ex_stage_i.mult_ready;
  wire        probe_mul_valid_op        = u_dut.ex_stage_i.i_mult.mul_valid_op;
  wire [1:0]  probe_serdiv_state        = u_dut.ex_stage_i.i_mult.i_div.state_q;
  wire [4:0]  probe_serdiv_cnt          = u_dut.ex_stage_i.i_mult.i_div.cnt_q;
  wire        probe_serdiv_div_res_zero = u_dut.ex_stage_i.i_mult.i_div.div_res_zero_q;
  wire        probe_serdiv_op_b_zero    = u_dut.ex_stage_i.i_mult.i_div.op_b_zero_q;
  wire        probe_serdiv_op_b_neg_one = u_dut.ex_stage_i.i_mult.i_div.op_b_neg_one_q;
  wire        probe_flu_ready           = u_dut.ex_stage_i.flu_ready_o;
  wire        probe_sb_full             = u_dut.issue_stage_i.i_scoreboard.sb_full_o;

  // ----------------------------------------------------------------------------
  // AXI Slave Memory Responder (Proven Robust Logic)
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_state           <= AR_IDLE;
      noc_resp.ar_ready <= 1'b0;
      noc_resp.r_valid  <= 1'b0;
      noc_resp.r        <= '0;
      ar_id_q           <= '0;
      ar_addr_q         <= '0;
      ar_len_q          <= '0;
      ar_cnt_q          <= '0;
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
            automatic logic [31:0] d0 = (word_idx < MEM_WORDS) ? mem[word_idx] : 32'h00000013;
            automatic logic [31:0] d1 = (word_idx + 1 < MEM_WORDS) ? mem[word_idx + 1] : 32'h00000013;
            noc_resp.r.data <= {d1, d0};
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

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_state           <= AW_IDLE;
      noc_resp.aw_ready <= 1'b0;
      noc_resp.w_ready  <= 1'b0;
      noc_resp.b_valid  <= 1'b0;
      noc_resp.b        <= '0;
      aw_id_q           <= '0;
      aw_addr_q         <= '0;
      aw_cnt_q          <= '0;
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
            w_state           <= AW_IDLE;
          end
        end
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // GPR State Tracking Shadow Register File
  // ----------------------------------------------------------------------------
  logic [31:0] shadow_gpr [0:31];
  initial begin
    for (int r = 0; r < 32; r++) shadow_gpr[r] = '0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int r = 0; r < 32; r++) shadow_gpr[r] <= '0;
    end else begin
      if (probe_commit_ack0 && probe_gpr_we0 && (probe_gpr_waddr0 != 5'd0)) begin
        shadow_gpr[probe_gpr_waddr0] <= probe_gpr_wdata0;
      end
      if (probe_commit_ack1 && probe_gpr_we1 && (probe_gpr_waddr1 != 5'd0)) begin
        shadow_gpr[probe_gpr_waddr1] <= probe_gpr_wdata1;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // Simulation Metrics & CSV Trace Logging
  // ----------------------------------------------------------------------------
  int unsigned cycle_cnt = 0;
  int unsigned instret_cnt = 0;
  int unsigned dual_commit_total = 0;
  int unsigned div_ops_count = 0;
  int unsigned mul_ops_count = 0;

  int csv_fd;
  initial begin
    csv_fd = $fopen("cva6_m_extension_trace.csv", "w");
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,DualCommit,CommitPC0,CommitRes0,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchValid,DivValidOp,DivReady,MulValidOp,SerdivState,SerdivCnt,SerdivDivResZero,SerdivOpBZero,SerdivOpBNegOne,FluReady,SbFull");
    end else begin
      $display("[TB_ERROR] Failed to open cva6_m_extension_trace.csv for writing!");
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cycle_cnt <= cycle_cnt + 1;
      if (probe_commit_ack0) instret_cnt <= instret_cnt + 1;
      if (probe_commit_ack1) instret_cnt <= instret_cnt + 1;
      if (probe_dual_commit) dual_commit_total <= dual_commit_total + 1;
      if (probe_div_valid_op) div_ops_count <= div_ops_count + 1;
      if (probe_mul_valid_op) mul_ops_count <= mul_ops_count + 1;

      if (csv_fd) begin
        $fdisplay(csv_fd, "%0d,%0d,%0d,%0b,%0b,%0b,0x%08x,0x%08x,%0b,%0d,0x%08x,%0b,%0d,0x%08x,0x%08x,%0b,%0b,%0b,%0b,%0d,%0d,%0b,%0b,%0b,%0b,%0b",
          $time,
          cycle_cnt,
          instret_cnt,
          probe_commit_ack0,
          probe_commit_ack1,
          probe_dual_commit,
          probe_commit_pc0,
          probe_commit_res0,
          probe_gpr_we0,
          probe_gpr_waddr0,
          probe_gpr_wdata0,
          probe_gpr_we1,
          probe_gpr_waddr1,
          probe_gpr_wdata1,
          probe_fetch_pc,
          probe_fetch_valid,
          probe_div_valid_op,
          probe_div_ready,
          probe_mul_valid_op,
          probe_serdiv_state,
          probe_serdiv_cnt,
          probe_serdiv_div_res_zero,
          probe_serdiv_op_b_zero,
          probe_serdiv_op_b_neg_one,
          probe_flu_ready,
          probe_sb_full
        );
      end
    end
  end

  // ----------------------------------------------------------------------------
  // Main Testbench Control & Scoreboard Assertions
  // ----------------------------------------------------------------------------
  int error_count = 0;
  int check_count = 0;

  task automatic check_reg(input int reg_num, input logic [31:0] expected_val, input string reg_name);
    check_count++;
    if (shadow_gpr[reg_num] === expected_val) begin
      $display("[PASS] Reg x%0d (%s) = 0x%08x (%0d)", reg_num, reg_name, shadow_gpr[reg_num], shadow_gpr[reg_num]);
    end else begin
      $display("[FAIL] Reg x%0d (%s) MISMATCH! Expected: 0x%08x (%0d), Got: 0x%08x (%0d)",
               reg_num, reg_name, expected_val, expected_val, shadow_gpr[reg_num], shadow_gpr[reg_num]);
      error_count++;
    end
  endtask

  initial begin
    $display("============================================================");
    $display("[TB_INFO] CVA6 Suite 11: M-Extension Arithmetic Corner Cases");
    $display("[TB_INFO] Div-by-Zero, Signed Overflow, |opB|>|opA| & Upper Products");
    $display("============================================================");

    rst_n = 1'b0;
    #75;
    rst_n = 1'b1;
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08x", $time, BOOT_ADDR);

    // Run until terminal self-loop is reached and commits (PC = 0x8000_0074)
    fork
      begin
        wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_0074));
        $display("[%0t] [TB_END] END self-loop reached at cycle %0d.", $time, cycle_cnt);
        repeat (25) @(posedge clk);
      end
      begin
        #35000; // 35 us watchdog timeout
        $display("[TIMEOUT] Testbench timed out at cycle %0d!", cycle_cnt);
        error_count++;
      end
    join_any

    if (csv_fd) $fclose(csv_fd);
    $display("[TB_INFO] Trace dumped to cva6_m_extension_trace.csv");

    // --------------------------------------------------------------------------
    // Architectural Register File Assertions
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural Register & Arithmetic Corner Checks");
    $display("============================================================");

    // Phase 0: Setup
    check_reg(2,  32'h8000_0200, "sp: base stack pointer");
    check_reg(3,  32'd1000,      "gp: dividend operand 1000");
    check_reg(4,  32'd0,         "tp: divisor operand 0");

    // Phase 1: Division by Zero
    check_reg(10, 32'hffff_ffff, "a0: DIV(1000, 0) == -1 (0xFFFFFFFF)");
    check_reg(11, 32'hffff_ffff, "a1: DIVU(1000, 0) == 2^32-1 (0xFFFFFFFF)");
    check_reg(12, 32'd1000,      "a2: REM(1000, 0) == 1000 (dividend)");
    check_reg(13, 32'd1000,      "a3: REMU(1000, 0) == 1000 (dividend)");

    // Phase 2: Signed Division Overflow (-2^31 / -1)
    check_reg(18, 32'h8000_0000, "s2: minimal negative number -2^31 (0x80000000)");
    check_reg(19, 32'hffff_ffff, "s3: divisor -1 (0xFFFFFFFF)");
    check_reg(14, 32'h8000_0000, "a4: DIV(-2^31, -1) == -2^31 (Signed Overflow Saturated)");
    check_reg(15, 32'd0,         "a5: REM(-2^31, -1) == 0");
    check_reg(16, 32'd0,         "a6: DIVU(2^31, 2^32-1) == 0");
    check_reg(17, 32'h8000_0000, "a7: REMU(2^31, 2^32-1) == 2^31 (0x80000000)");

    // Phase 3: Magnitude |opB| > |opA| Early Termination
    check_reg(5,  32'd5,         "t0: dividend 5");
    check_reg(6,  32'd100,       "t1: divisor 100");
    check_reg(20, 32'd0,         "s4: DIV(5, 100) == 0 (Early Terminated)");
    check_reg(21, 32'd5,         "s5: REM(5, 100) == 5");

    // Phase 4: Multiplier Upper Words (MUL, MULH, MULHU, MULHSU)
    check_reg(22, 32'hffff_fffa, "s6: MUL(-2, 3) == -6 (0xFFFFFFFA)");
    check_reg(23, 32'hffff_ffff, "s7: MULH(-2, 3) == -1 (Upper word 0xFFFFFFFF)");
    check_reg(24, 32'd1,         "s8: MUL(0xFFFFFFFF, 0xFFFFFFFF) lower word == 1");
    check_reg(25, 32'hffff_fffe, "s9: MULHU(0xFFFFFFFF, 0xFFFFFFFF) upper word == 0xFFFFFFFE");
    check_reg(27, 32'hffff_ffff, "s11: MULHSU(-1, 0xFFFFFFFF) upper word == 0xFFFFFFFF");
    check_reg(31, 32'he000_0000, "t6: MULH(+2^30, -2^31) upper word == 0xE0000000 (-2^61)");

    // Terminal completion marker
    check_reg(26, 32'd999,       "s10: Completion marker reached 999");

    $display("------------------------------------------------------------");
    $display("[METRICS] Total Cycles Run       : %0d", cycle_cnt);
    $display("[METRICS] Total Instructions     : %0d", instret_cnt);
    $display("[METRICS] Total Dual-Commits     : %0d", dual_commit_total);
    $display("[METRICS] Total DIV Valid Ops    : %0d", div_ops_count);
    $display("[METRICS] Total MUL Valid Ops    : %0d", mul_ops_count);
    if (instret_cnt > 0) begin
      $display("[METRICS] Overall Benchmark CPI  : %0.2f", real'(cycle_cnt) / real'(instret_cnt));
    end
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 11:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_cnt);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-11 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-11 FAILED WITH %0d ERRORS", error_count);
    end

    $finish;
  end

endmodule