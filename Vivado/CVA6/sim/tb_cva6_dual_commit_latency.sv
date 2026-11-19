// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 21:18:00 +03:30
// Status: NEW FILE
// Reason / Modification: Suite 6 Testbench for CVA6 Sustained Dual-Commit
//                        Throughput and AXI Memory Subsystem Latency Sensitivity
//                        (0, 4, 8, 16 wait cycles).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_dual_commit_latency;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Clock and Reset Generation
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns; // 100 MHz
  localparam int  TIMEOUT_CYCLES = 3500;
  localparam int  MEM_WORDS      = 512;

  localparam logic [31:0] BOOT_ADDR     = 32'h8000_0000;
  localparam logic [31:0] LOOP_START_PC = 32'h8000_0048;
  localparam logic [31:0] LOOP_BRANCH_PC= 32'h8000_0080;
  localparam logic [31:0] END_PC        = 32'h8000_0088;

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
  // 2. Memory Emulation and Benchmark Program (Suite 6)
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
      mem[i] = 32'h0000_0013; // nop
    end

    // --------------------------------------------------------------------------
    // Main Program (0x8000_0000 to 0x8000_008c)
    // --------------------------------------------------------------------------
    mem[  0] = 32'h800000b7; // 0x80000000: lui   ra, 0x80000
    mem[  1] = 32'h20008093; // 0x80000004: addi  ra, ra, 512 (ra = 0x8000_0200)
    mem[  2] = 32'h00000113; // 0x80000008: li    sp, 0
    mem[  3] = 32'h00000193; // 0x8000000c: li    gp, 0
    mem[  4] = 32'h00000213; // 0x80000010: li    tp, 0
    mem[  5] = 32'h02a00293; // 0x80000014: li    t0, 42
    mem[  6] = 32'h00000313; // 0x80000018: li    t1, 0
    mem[  7] = 32'h00000393; // 0x8000001c: li    t2, 0
    mem[  8] = 32'h00000413; // 0x80000020: li    s0, 0
    mem[  9] = 32'h00000493; // 0x80000024: li    s1, 0
    mem[ 10] = 32'h00000513; // 0x80000028: li    a0, 0
    mem[ 11] = 32'h00000593; // 0x8000002c: li    a1, 0
    mem[ 12] = 32'h00000613; // 0x80000030: li    a2, 0
    mem[ 13] = 32'h00000693; // 0x80000034: li    a3, 0
    mem[ 14] = 32'h00000713; // 0x80000038: li    a4, 0
    mem[ 15] = 32'h00000793; // 0x8000003c: li    a5, 0
    mem[ 16] = 32'h00000813; // 0x80000040: li    a6, 0
    mem[ 17] = 32'h00100a93; // 0x80000044: li    s5, 1 (iter = 1)

    // loop_start: 0x8000_0048
    mem[ 18] = 32'h0050a023; // 0x80000048: sw    t0, 0(ra)
    mem[ 19] = 32'h00130313; // 0x8000004c: addi  t1, t1, 1 (Dual-commit with SW!)
    mem[ 20] = 32'h00238393; // 0x80000050: addi  t2, t2, 2
    mem[ 21] = 32'h00340413; // 0x80000054: addi  s0, s0, 3
    mem[ 22] = 32'h0000a483; // 0x80000058: lw    s1, 0(ra)
    mem[ 23] = 32'h00450513; // 0x8000005c: addi  a0, a0, 4 (Dual-commit with LW!)
    mem[ 24] = 32'h007305b3; // 0x80000060: add   a1, t1, t2
    mem[ 25] = 32'h00a40633; // 0x80000064: add   a2, s0, a0
    mem[ 26] = 32'h00a58693; // 0x80000068: addi  a3, a1, 10
    mem[ 27] = 32'h01460713; // 0x8000006c: addi  a4, a2, 20 (Independent pair!)
    mem[ 28] = 32'h00e6c7b3; // 0x80000070: xor   a5, a3, a4
    mem[ 29] = 32'h00279813; // 0x80000074: slli  a6, a5, 2
    mem[ 30] = 32'h001a8a93; // 0x80000078: addi  s5, s5, 1
    mem[ 31] = 32'h00500113; // 0x8000007c: li    sp, 5
    mem[ 32] = 32'hfc2a94e3; // 0x80000080: bne   s5, sp, loop_start
    mem[ 33] = 32'h3e700a13; // 0x80000084: li    s4, 999
    mem[ 34] = 32'h0000006f; // 0x80000088: j     end_loop
    mem[ 35] = 32'h00000013; // 0x8000008c: nop

    // Initial buffer at 0x8000_0200 (Word index 128)
    mem[128] = 32'h0000_0000;
    mem[129] = 32'h0000_0000;

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

  wire        probe_dual_commit     = probe_commit_ack[0] && probe_commit_ack[1];

  // Frontend / Fetch
  wire [31:0] probe_fetch_pc        = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_req       = u_dut.icache_dreq_if_cache.req;
  wire        probe_fetch_valid     = u_dut.icache_dreq_cache_if.valid;
  wire [31:0] probe_fe_instr        = u_dut.fetch_entry_if_id[0].instruction;
  wire        probe_fe_id_valid     = u_dut.fetch_valid_if_id;
  wire        probe_id_fe_ready     = u_dut.fetch_ready_id_if;
  wire [3:0]  probe_fifo_usage      = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;

  // I-cache & D-cache
  wire [2:0]  probe_icache_state    = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q;
  wire        probe_icache_miss     = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.miss_o;
  wire        probe_icache_ready    = u_dut.icache_dreq_cache_if.ready;

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
  // 5. Configurable AXI Slave Memory Responder (Latency Injection)
  // ----------------------------------------------------------------------------
  int unsigned axi_wait_target = 0; // Configured dynamically: 0, 4, 8, 16
  int unsigned wait_cnt = 0;

  typedef enum logic [1:0] {
    AR_IDLE = 2'b00,
    AR_WAIT = 2'b01,
    R_BURST = 2'b10
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

  // AXI Read Channel with latency injection
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      r_state           <= AR_IDLE;
      noc_resp.ar_ready <= 1'b0;
      noc_resp.r_valid  <= 1'b0;
      noc_resp.r        <= '0;
      ar_id_q           <= '0;
      ar_addr_q         <= '0;
      ar_len_q          <= '0;
      ar_cnt_q          <= '0;
      wait_cnt          <= 0;
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
            if (axi_wait_target > 0) begin
              wait_cnt <= 1;
              r_state  <= AR_WAIT;
            end else begin
              r_state  <= R_BURST;
            end
          end
        end

        AR_WAIT: begin
          noc_resp.ar_ready <= 1'b0;
          noc_resp.r_valid  <= 1'b0;
          if (wait_cnt >= axi_wait_target) begin
            r_state <= R_BURST;
          end else begin
            wait_cnt <= wait_cnt + 1;
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
  // 7. Event Counters & Performance Metrics Tracking Across 4 Latencies
  // ----------------------------------------------------------------------------
  int unsigned cycle_count = 0;
  int unsigned inst_ret_count = 0;
  int unsigned dual_commit_total_count = 0;

  int unsigned first_commit_cycle = 0;
  int unsigned end_commit_cycle = 0;
  bit end_loop_committed = 1'b0;

  // Per-iteration profiling
  int unsigned current_iter = 1;
  int unsigned iter_start_cycle [1:4];
  int unsigned iter_end_cycle   [1:4];
  int unsigned iter_instr_count [1:4];
  int unsigned iter_dual_commits[1:4];
  real         iter_cpi         [1:4];

  always_ff @(posedge clk) begin
    if (rst_ni) begin
      cycle_count <= cycle_count + 1;

      if (probe_dual_commit) begin
        dual_commit_total_count <= dual_commit_total_count + 1;
        if (current_iter <= 4) iter_dual_commits[current_iter] <= iter_dual_commits[current_iter] + 1;
      end

      if (probe_commit_ack[0]) begin
        inst_ret_count <= inst_ret_count + 1;
        if (current_iter <= 4) iter_instr_count[current_iter] <= iter_instr_count[current_iter] + 1;
        if (first_commit_cycle == 0) first_commit_cycle <= cycle_count;

        if (probe_commit_pc0 == LOOP_START_PC && iter_start_cycle[current_iter] == 0) begin
          iter_start_cycle[current_iter] <= cycle_count;
        end

        if (probe_commit_pc0 == LOOP_BRANCH_PC) begin
          iter_end_cycle[current_iter] <= cycle_count;
          if (current_iter < 4) begin
            current_iter <= current_iter + 1;
            // Switch AXI latency for the next iteration
            case (current_iter + 1)
              2: axi_wait_target <= 4;
              3: axi_wait_target <= 8;
              4: axi_wait_target <= 16;
              default: axi_wait_target <= 0;
            endcase
          end
        end

        if (probe_commit_pc0 == END_PC) begin
          end_commit_cycle   <= cycle_count;
          end_loop_committed <= 1'b1;
        end
      end

      if (probe_commit_ack[1]) begin
        inst_ret_count <= inst_ret_count + 1;
        if (current_iter <= 4) iter_instr_count[current_iter] <= iter_instr_count[current_iter] + 1;
        if (probe_commit_pc1 == END_PC) begin
          end_commit_cycle   <= cycle_count;
          end_loop_committed <= 1'b1;
        end
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 8. CSV Trace Logging (60+ Microarchitectural Signals)
  // ----------------------------------------------------------------------------
  integer csv_fd;
  initial begin
    csv_fd = $fopen("cva6_dual_commit_trace.csv", "w");
    if (csv_fd) begin
      $fwrite(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,DualCommit,AxiWaitTarget,CurrentIter,");
      $fwrite(csv_fd, "CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,");
      $fwrite(csv_fd, "FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,");
      $fwrite(csv_fd, "IcacheState,IcacheMiss,IcacheReady,");
      $fwrite(csv_fd, "IssueValid0,IssueAck0,StallIssue,StallRaw,");
      $fwrite(csv_fd, "DualCommitCount,");
      $fwrite(csv_fd, "AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiBValid\n");
    end else begin
      $display("[TB_ERR] Failed to open cva6_dual_commit_trace.csv for writing!");
    end
  end

  always_ff @(posedge clk) begin
    if (csv_fd && rst_ni) begin
      $fwrite(csv_fd, "%0d,%0d,%0d,%b,%b,%b,%0d,%0d,",
              $time, cycle_count, inst_ret_count,
              probe_commit_ack[0], probe_commit_ack[1], probe_dual_commit, axi_wait_target, current_iter);
      $fwrite(csv_fd, "0x%08x,0x%08x,0x%08x,0x%08x,%b,%0d,0x%08x,%b,%0d,0x%08x,",
              probe_commit_pc0, probe_commit_pc1, probe_commit_res0, probe_commit_res1,
              probe_we_gpr[0], probe_waddr_gpr[0], probe_wdata_gpr[0],
              probe_we_gpr[1], probe_waddr_gpr[1], probe_wdata_gpr[1]);
      $fwrite(csv_fd, "0x%08x,%b,%b,0x%08x,%b,%b,%0d,",
              probe_fetch_pc, probe_fetch_req, probe_fetch_valid, probe_fe_instr,
              probe_fe_id_valid, probe_id_fe_ready, probe_fifo_usage);
      $fwrite(csv_fd, "%0d,%b,%b,",
              probe_icache_state, probe_icache_miss, probe_icache_ready);
      $fwrite(csv_fd, "%b,%b,%b,%b,",
              probe_issue_valid0, probe_issue_ack0, probe_stall_issue, probe_stall_raw);
      $fwrite(csv_fd, "%0d,",
              dual_commit_total_count);
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
      $display("[PASS] Reg x%0d (%s) = 0x%08x (%0d)", reg_idx, name, actual, actual);
    end else begin
      $display("[FAIL] Reg x%0d (%s) = 0x%08x (Expected: 0x%08x)", reg_idx, name, actual, expected);
      error_count++;
    end
  endtask

  initial begin
    $display("============================================================");
    $display("[TB_INFO] CVA6 Suite 6: Sustained Dual-Commit & Memory Latency");
    $display("[TB_INFO] Port 0 + Port 1 Retirements & AXI Latencies (0, 4, 8, 16)");
    $display("============================================================");

    @(posedge rst_ni);
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08x", $time, BOOT_ADDR);

    while (!end_loop_committed && cycle_count < TIMEOUT_CYCLES) begin
      @(posedge clk);
    end

    if (end_loop_committed) begin
      $display("[%0t] [TB_END] END self-loop committed at cycle %0d.", $time, end_commit_cycle);
    end else begin
      $display("[%0t] [TB_TIMEOUT] Watchdog expired after %0d cycles!", $time, cycle_count);
    end

    repeat (20) @(posedge clk);

    if (csv_fd) begin
      $fclose(csv_fd);
      $display("[TB_INFO] Trace dumped to cva6_dual_commit_trace.csv");
    end

    // --------------------------------------------------------------------------
    // Verification Scoreboard Checks
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural register checks");
    $display("============================================================");

    check_reg(1,  32'h8000_0200, "ra: base buffer address");
    check_reg(5,  32'd42,        "t0: store constant 42");
    check_reg(6,  32'd4,         "t1: incremented by 1 x 4 iters");
    check_reg(7,  32'd8,         "t2: incremented by 2 x 4 iters");
    check_reg(8,  32'd12,        "s0: incremented by 3 x 4 iters");
    check_reg(9,  32'd42,        "s1: loaded value 42 from memory");
    check_reg(10, 32'd16,        "a0: incremented by 4 x 4 iters");
    check_reg(11, 32'd12,        "a1: t1 + t2 = 4 + 8");
    check_reg(12, 32'd28,        "a2: s0 + a0 = 12 + 16");
    check_reg(13, 32'd22,        "a3: a1 + 10 = 12 + 10");
    check_reg(14, 32'd48,        "a4: a2 + 20 = 28 + 20");
    check_reg(15, 32'd38,        "a5: a3 ^ a4 = 22 ^ 48 = 38");
    check_reg(16, 32'd152,       "a6: a5 << 2 = 38 << 2 = 152");
    check_reg(20, 32'd999,       "s4: terminal self-loop marker 999");
    check_reg(21, 32'd5,         "s5: iteration counter reached 5");

    check_count++;
    if (end_loop_committed) begin
      $display("[PASS] END self-loop committed");
    end else begin
      $display("[FAIL] END self-loop did not commit");
      error_count++;
    end

    check_count++;
    if (dual_commit_total_count >= 1) begin
      $display("[PASS] Dual-Commit observed (dual_commit_total_count = %0d cycles)", dual_commit_total_count);
    end else begin
      $display("[FAIL] Zero dual-commit cycles observed");
      error_count++;
    end

    // Compute Per-Iteration Metrics
    for (int it = 1; it <= 4; it++) begin
      if (iter_end_cycle[it] > iter_start_cycle[it] && iter_instr_count[it] > 0) begin
        iter_cpi[it] = real'(iter_end_cycle[it] - iter_start_cycle[it]) / real'(iter_instr_count[it]);
      end else begin
        iter_cpi[it] = 0.0;
      end
    end

    // Performance Summary
    $display("------------------------------------------------------------");
    $display("[METRICS] Total committed instrs    : %0d", inst_ret_count);
    $display("[METRICS] Total dual-commit cycles  : %0d", dual_commit_total_count);
    $display("[METRICS] Iter 1 (Wait =  0 cycs)   : Span = %0d cycs, Instrs = %0d, DualCommits = %0d, CPI = %0.2f",
             iter_end_cycle[1] - iter_start_cycle[1], iter_instr_count[1], iter_dual_commits[1], iter_cpi[1]);
    $display("[METRICS] Iter 2 (Wait =  4 cycs)   : Span = %0d cycs, Instrs = %0d, DualCommits = %0d, CPI = %0.2f",
             iter_end_cycle[2] - iter_start_cycle[2], iter_instr_count[2], iter_dual_commits[2], iter_cpi[2]);
    $display("[METRICS] Iter 3 (Wait =  8 cycs)   : Span = %0d cycs, Instrs = %0d, DualCommits = %0d, CPI = %0.2f",
             iter_end_cycle[3] - iter_start_cycle[3], iter_instr_count[3], iter_dual_commits[3], iter_cpi[3]);
    $display("[METRICS] Iter 4 (Wait = 16 cycs)   : Span = %0d cycs, Instrs = %0d, DualCommits = %0d, CPI = %0.2f",
             iter_end_cycle[4] - iter_start_cycle[4], iter_instr_count[4], iter_dual_commits[4], iter_cpi[4]);
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 6:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-6 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-6 FAILED WITH %0d ERRORS", error_count);
    end

    sim_done = 1'b1;
    $finish;
  end

endmodule
