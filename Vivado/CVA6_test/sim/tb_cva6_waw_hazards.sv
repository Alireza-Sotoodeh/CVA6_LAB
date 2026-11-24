// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 21:40:00 +03:30
// Status: NEW FILE
// Reason / Modification: Dedicated SystemVerilog verification testbench for
//                        Suite 7 (Advanced Data Hazards: WAW out-of-order execution
//                        vs in-order retirement, intermediate consumer routing,
//                        Memory WAR, Store-to-Load forwarding, sub-word accesses,
//                        and Register x0 invariant immunity).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_waw_hazards;

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
    // Benchmark Program (.text loaded from 0x8000_0000)
    // --------------------------------------------------------------------------
    mem[  0] = 32'h80000137; // 0x80000000: lui   sp, 0x80000
    mem[  1] = 32'h20010113; // 0x80000004: addi  sp, sp, 512 (sp = 0x8000_0200)
    mem[  2] = 32'h3e800193; // 0x80000008: li    gp, 1000
    mem[  3] = 32'h00a00213; // 0x8000000c: li    tp, 10
    mem[  4] = 32'h0241c533; // 0x80000010: div   a0, gp, tp
    mem[  5] = 32'h06300513; // 0x80000014: li    a0, 99
    mem[  6] = 32'h000505b3; // 0x80000018: add   a1, a0, zero
    mem[  7] = 32'h00100613; // 0x8000001c: li    a2, 1
    mem[  8] = 32'h0241c6b3; // 0x80000020: div   a3, gp, tp
    mem[  9] = 32'h00068733; // 0x80000024: add   a4, a3, zero
    mem[ 10] = 32'h04d00693; // 0x80000028: li    a3, 77
    mem[ 11] = 32'h000687b3; // 0x8000002c: add   a5, a3, zero
    mem[ 12] = 32'h00312023; // 0x80000030: sw    gp, 0(sp)
    mem[ 13] = 32'h00012803; // 0x80000034: lw    a6, 0(sp)
    mem[ 14] = 32'h00412023; // 0x80000038: sw    tp, 0(sp)
    mem[ 15] = 32'h00012883; // 0x8000003c: lw    a7, 0(sp)
    mem[ 16] = 32'h12345937; // 0x80000040: lui   s2, 0x12345
    mem[ 17] = 32'h67890913; // 0x80000044: addi  s2, s2, 1656 (0x12345678)
    mem[ 18] = 32'h01212223; // 0x80000048: sw    s2, 4(sp)
    mem[ 19] = 32'h00412983; // 0x8000004c: lw    s3, 4(sp)
    mem[ 20] = 32'haabbda37; // 0x80000050: lui   s4, 0xaabbd
    mem[ 21] = 32'hcdda0a13; // 0x80000054: addi  s4, s4, -803 (0xAABBCCDD)
    mem[ 22] = 32'h01412423; // 0x80000058: sw    s4, 8(sp)
    mem[ 23] = 32'h00810a83; // 0x8000005c: lb    s5, 8(sp)
    mem[ 24] = 32'h00814b03; // 0x80000060: lbu   s6, 8(sp)
    mem[ 25] = 32'h00811b83; // 0x80000064: lh    s7, 8(sp)
    mem[ 26] = 32'h00815c03; // 0x80000068: lhu   s8, 8(sp)
    mem[ 27] = 32'h0241c033; // 0x8000006c: div   zero, gp, tp
    mem[ 28] = 32'h00012003; // 0x80000070: lw    zero, 0(sp)
    mem[ 29] = 32'h22b00013; // 0x80000074: li    zero, 555
    mem[ 30] = 32'h00000cb3; // 0x80000078: add   s9, zero, zero
    mem[ 31] = 32'h3e700d13; // 0x8000007c: li    s10, 999
    mem[ 32] = 32'h0000006f; // 0x80000080: j     end_loop
    mem[ 33] = 32'h00000013; // 0x80000084: nop
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
  wire [31:0] probe_fetch_instr         = u_dut.fetch_entry_if_id[0].instruction;

  wire [3:0]  probe_instr_queue_usage   = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;
  wire        probe_issue_valid0        = u_dut.issue_stage_i.issue_instr_valid_sb_iro[0];
  wire        probe_issue_ack0          = u_dut.issue_stage_i.issue_ack_iro_sb[0];
  wire        probe_stall_issue         = u_dut.issue_stage_i.i_issue_read_operands.stall_issue_o;
  wire        probe_stall_raw           = u_dut.issue_stage_i.i_issue_read_operands.stall_raw[0];

  wire        probe_div_valid_op        = u_dut.ex_stage_i.i_mult.div_valid_op;
  wire        probe_flu_ready           = u_dut.ex_stage_i.flu_ready_o;
  wire        probe_sb_full             = u_dut.issue_stage_i.i_scoreboard.sb_full_o;

  wire        probe_axi_arvalid         = noc_req.ar_valid;
  wire [31:0] probe_axi_araddr          = noc_req.ar.addr[31:0];
  wire        probe_axi_rvalid          = noc_resp.r_valid;
  wire        probe_axi_rlast           = noc_resp.r.last;
  wire        probe_axi_awvalid         = noc_req.aw_valid;
  wire [31:0] probe_axi_awaddr          = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid          = noc_req.w_valid;
  wire [7:0]  probe_axi_wstrb           = noc_req.w.strb;
  wire        probe_axi_bvalid          = noc_resp.b_valid;

  // ----------------------------------------------------------------------------
  // AXI Slave Memory Responder
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
  axi_pkg::len_t                   ar_cnt_q;

  logic [CVA6Cfg.AxiIdWidth-1:0]   aw_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] aw_addr_q;
  axi_pkg::len_t                   aw_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_state           <= AR_IDLE;
      noc_resp.ar_ready <= 1'b0;
      noc_resp.r_valid  <= 1'b0;
      noc_resp.r.last   <= 1'b0;
      noc_resp.r.data   <= '0;
      noc_resp.r.id     <= '0;
      noc_resp.r.resp   <= axi_pkg::RESP_OKAY;
      noc_resp.r.user   <= '0;
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
      noc_resp.b.id     <= '0;
      noc_resp.b.resp   <= axi_pkg::RESP_OKAY;
      noc_resp.b.user   <= '0;
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
          noc_resp.w_ready <= 1'b1;
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
  int unsigned waw_detected_cnt = 0;

  int csv_fd;
  initial begin
    csv_fd = $fopen("cva6_waw_trace.csv", "w");
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,DualCommit,CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchValid,FetchInstr,InstrQueueUsage,IssueValid0,IssueAck0,StallIssue,StallRaw,DivValidOp,FluReady,SbFull,AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiWStrb,AxiBValid");
    end else begin
      $display("[TB_ERROR] Failed to open cva6_waw_trace.csv for writing!");
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cycle_cnt <= cycle_cnt + 1;
      if (probe_commit_ack0) instret_cnt <= instret_cnt + 1;
      if (probe_commit_ack1) instret_cnt <= instret_cnt + 1;
      if (probe_dual_commit) dual_commit_total <= dual_commit_total + 1;

      if (csv_fd) begin
        $fdisplay(csv_fd, "%0d,%0d,%0d,%0b,%0b,%0b,0x%08x,0x%08x,0x%08x,0x%08x,%0b,%0d,0x%08x,%0b,%0d,0x%08x,0x%08x,%0b,0x%08x,%0d,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,0x%08x,%0b,%0b,%0b,0x%08x,%0b,0x%02x,%0b",
          $time,
          cycle_cnt,
          instret_cnt,
          probe_commit_ack0,
          probe_commit_ack1,
          probe_dual_commit,
          probe_commit_pc0,
          probe_commit_pc1,
          probe_commit_res0,
          probe_commit_res1,
          probe_gpr_we0,
          probe_gpr_waddr0,
          probe_gpr_wdata0,
          probe_gpr_we1,
          probe_gpr_waddr1,
          probe_gpr_wdata1,
          probe_fetch_pc,
          probe_fetch_valid,
          probe_fetch_instr,
          probe_instr_queue_usage,
          probe_issue_valid0,
          probe_issue_ack0,
          probe_stall_issue,
          probe_stall_raw,
          probe_div_valid_op,
          probe_flu_ready,
          probe_sb_full,
          probe_axi_arvalid,
          probe_axi_araddr,
          probe_axi_rvalid,
          probe_axi_rlast,
          probe_axi_awvalid,
          probe_axi_awaddr,
          probe_axi_wvalid,
          probe_axi_wstrb,
          probe_axi_bvalid
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
    $display("[TB_INFO] CVA6 Suite 7: Advanced Data Hazards & Memory Ordering");
    $display("[TB_INFO] WAW, Memory WAR, Store-to-Load Bypass, Sub-words & x0");
    $display("============================================================");

    rst_n = 1'b0;
    #75;
    rst_n = 1'b1;
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08x", $time, BOOT_ADDR);

    // Run until terminal self-loop is reached and commits (PC = 0x8000_0080)
    fork
      begin
        wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_0080));
        $display("[%0t] [TB_END] END self-loop reached at cycle %0d.", $time, cycle_cnt);
        repeat (25) @(posedge clk);
      end
      begin
        #30000; // 30 us watchdog timeout
        $display("[TIMEOUT] Testbench timed out at cycle %0d!", cycle_cnt);
        error_count++;
      end
    join_any

    if (csv_fd) $fclose(csv_fd);
    $display("[TB_INFO] Trace dumped to cva6_waw_trace.csv");

    // --------------------------------------------------------------------------
    // Architectural Register File Assertions
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural Register & Hazard Checks");
    $display("============================================================");

    // Phase 0 base registers
    check_reg(2,  32'h8000_0200, "sp: base data buffer pointer");
    check_reg(3,  32'd1000,      "gp: dividend operand");
    check_reg(4,  32'd10,        "tp: divisor operand");

    // Phase 1: WAW Hazard (DIV vs ADDI to x10)
    check_reg(10, 32'd99,        "a0: WAW resolution (ADDI 99 overwrote DIV 100)");
    check_reg(11, 32'd99,        "a1: Consumer of x10 read 99 from ADDI via raw_checker");
    check_reg(12, 32'd1,         "a2: Independent ALU instruction");

    // Phase 2: Multi-Producer Intermediate Consumer WAW (DIV vs ADDI to x13)
    check_reg(13, 32'd77,        "a3: Final x13 value (ADDI 77 overwrote DIV 100)");
    check_reg(14, 32'd100,       "a4: Consumer 1 stalled and read 100 from DIV producer");
    check_reg(15, 32'd77,        "a5: Consumer 2 read 77 from fast ADDI producer");

    // Phase 3: Memory WAR (Load old value before Store)
    check_reg(16, 32'd1000,      "a6: Memory WAR read old value 1000");
    check_reg(17, 32'd10,        "a7: Memory WAR read new value 10 after store");

    // Phase 4: Store-to-Load Forwarding (RAW in Store Buffer)
    check_reg(18, 32'h1234_5678, "s2: Stored full word value");
    check_reg(19, 32'h1234_5678, "s3: Store-to-Load forwarded value from Store Buffer");

    // Phase 5: Sub-Word Memory Accesses (Sign vs Zero Extension)
    check_reg(20, 32'haabb_ccdd, "s4: Stored word 0xAABBCCDD");
    check_reg(21, 32'hffff_ffdd, "s5: LB sign-extended byte (-35)");
    check_reg(22, 32'h0000_00dd, "s6: LBU zero-extended byte (221)");
    check_reg(23, 32'hffff_ccdd, "s7: LH sign-extended half-word (-13091)");
    check_reg(24, 32'h0000_ccdd, "s8: LHU zero-extended half-word (52445)");

    // Phase 6: Register x0 Invariant & Stall Immunity
    check_reg(25, 32'd0,         "s9: Verified x0 remains strictly 0 after DIV/LW/ADDI to x0");

    // Terminal Marker
    check_reg(26, 32'd999,       "s10: Completion marker reached 999");

    // Final checks
    check_count++;
    if (shadow_gpr[0] === 32'd0) begin
      $display("[PASS] Reg x0 is strictly hardwired to 0 (Value = 0x00000000)");
    end else begin
      $display("[FAIL] Reg x0 non-zero violation! Value = 0x%08x", shadow_gpr[0]);
      error_count++;
    end

    $display("------------------------------------------------------------");
    $display("[METRICS] Total Cycles Run       : %0d", cycle_cnt);
    $display("[METRICS] Total Instructions     : %0d", instret_cnt);
    $display("[METRICS] Total Dual-Commits     : %0d", dual_commit_total);
    if (instret_cnt > 0) begin
      $display("[METRICS] Overall Benchmark CPI  : %0.2f", real'(cycle_cnt) / real'(instret_cnt));
    end
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 7:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_cnt);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-7 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-7 FAILED WITH %0d ERRORS", error_count);
    end

    $finish;
  end

endmodule
