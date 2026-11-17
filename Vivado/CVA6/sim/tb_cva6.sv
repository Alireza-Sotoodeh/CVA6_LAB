// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-10 11:10:00 +03:30
// Status: MODIFIED FILE
// Reason / Modification: Added dual-commit port support (NrCommitPorts=2) to spy_commit_pc,
//                        spy_loop_hit, and widened probe_fifo_usage for FETCH_FIFO_DEPTH=8.
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clocks
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 1500;
  localparam int  MEM_WORDS      = 1024;

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

  // ----------------------------------------------------------------------------
  // Clock Generator (RFC 2119: Initialized inside initial block)
  // Stops clock when sim_done is asserted to prevent extra cycles.
  // ----------------------------------------------------------------------------
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
  // 3. Hierarchical Probes (Spy Signals for Architectural Diagnosis)
  // ----------------------------------------------------------------------------
  wire [31:0] spy_commit_pc = u_dut.commit_ack[0] ? u_dut.commit_instr_id_commit[0].pc :
                             (CVA6Cfg.NrCommitPorts > 1 && u_dut.commit_ack[1]) ? u_dut.commit_instr_id_commit[1].pc :
                             u_dut.pc_commit;
  wire        spy_loop_hit  = (u_dut.commit_ack[0] && u_dut.commit_instr_id_commit[0].pc[15:0] == 16'h0048) ||
                             (CVA6Cfg.NrCommitPorts > 1 && u_dut.commit_ack[1] && u_dut.commit_instr_id_commit[1].pc[15:0] == 16'h0048);
  wire [31:0] spy_fetch_pc  = u_dut.i_frontend.icache_dreq_o.vaddr;

  // Group 1: 256-Cycle I-Cache Startup Flush Probes
  wire [2:0]  probe_icache_state      = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q;
  wire [7:0]  probe_icache_flush_cnt  = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_cnt_q;
  wire        probe_icache_flush_en   = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_en;
  wire        probe_icache_flush_done = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_done;
  wire        probe_icache_wren       = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.cache_wren;
  wire        probe_icache_miss       = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.miss_o;

  // Group 2: Front-End & Fetch Latency Probes
  wire        probe_fetch_req         = u_dut.icache_dreq_if_cache.req;
  wire        probe_fetch_valid       = u_dut.icache_dreq_cache_if.valid;
  wire [31:0] probe_fetch_data        = u_dut.icache_dreq_cache_if.data;
  wire        probe_fe_id_valid       = u_dut.fetch_valid_if_id;
  wire        probe_id_fe_ready       = u_dut.fetch_ready_id_if;
  wire [31:0] probe_fe_instr          = u_dut.fetch_entry_if_id[0].instruction;
  wire [31:0] probe_fe_addr           = u_dut.fetch_entry_if_id[0].address;

  // Group 3: AXI4 External Memory Bus Probes
  wire        probe_axi_arvalid       = noc_req.ar_valid;
  wire        probe_axi_arready       = noc_resp.ar_ready;
  wire [31:0] probe_axi_araddr        = noc_req.ar.addr[31:0];
  wire [7:0]  probe_axi_arlen         = noc_req.ar.len;
  wire        probe_axi_rvalid        = noc_resp.r_valid;
  wire        probe_axi_rready        = noc_req.r_ready;
  wire        probe_axi_rlast         = noc_resp.r.last;
  wire [63:0] probe_axi_rdata         = noc_resp.r.data;

  wire        probe_axi_awvalid       = noc_req.aw_valid;
  wire        probe_axi_awready       = noc_resp.aw_ready;
  wire [31:0] probe_axi_awaddr        = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid        = noc_req.w_valid;
  wire        probe_axi_wready        = noc_resp.w_ready;
  wire        probe_axi_wlast         = noc_req.w.last;
  wire [63:0] probe_axi_wdata         = noc_req.w.data;
  wire        probe_axi_bvalid        = noc_resp.b_valid;
  wire        probe_axi_bready        = noc_req.b_ready;

  // Group 4: LSU Uncached Stall & Store Buffer Probes
  wire        probe_lsu_valid         = u_dut.lsu_valid_id_ex;
  wire        probe_lsu_ready         = u_dut.lsu_ready_ex_id;
  wire        probe_stall_st_pending  = u_dut.stall_st_pending_ex;
  wire        probe_wbuffer_empty     = u_dut.dcache_commit_wbuffer_empty;
  wire        probe_load_valid        = u_dut.load_valid_ex_id;
  wire [31:0] probe_load_result       = u_dut.load_result_ex_id;

  // Group 5: Execution & Commit Probes
  wire [CVA6Cfg.NrCommitPorts-1:0] probe_commit_ack = u_dut.commit_ack;
  wire [31:0] probe_commit_pc         = u_dut.commit_ack[0] ? u_dut.commit_instr_id_commit[0].pc :
                                        (CVA6Cfg.NrCommitPorts > 1 && u_dut.commit_ack[1]) ? u_dut.commit_instr_id_commit[1].pc : 32'h0;
  wire        probe_we_gpr            = |u_dut.we_gpr_commit_id;
  wire [4:0]  probe_waddr_gpr         = u_dut.waddr_commit_id[0];
  wire [31:0] probe_wdata_gpr         = u_dut.wdata_commit_id[0];

  // Group 6: Instruction Queue, Fetch FIFO & Scoreboard Depth Probes
  wire        probe_icache_ready      = u_dut.icache_dreq_cache_if.ready;
  wire        probe_fifo_ready        = u_dut.i_frontend.i_instr_queue.ready_o;
  wire        probe_fifo_full         = u_dut.i_frontend.i_instr_queue.instr_queue_full[0];
  wire        probe_fifo_empty        = u_dut.i_frontend.i_instr_queue.instr_queue_empty[0];
  wire [3:0]  probe_fifo_usage        = u_dut.i_frontend.i_instr_queue.gen_instr_fifo[0].i_fifo_instr_data.usage_o;
  wire        probe_sb_full           = u_dut.issue_stage_i.i_scoreboard.sb_full_o;

  // ----------------------------------------------------------------------------
  // 4. Memory Preload with Standard 19-Instruction RV32I Test Program
  // ----------------------------------------------------------------------------
  logic [31:0] mem[0:MEM_WORDS-1];

  initial begin
    // Fill memory with NOPs (ADDI x0, x0, 0)
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h00000013;
    end

    // Instruction sequence (code in words 0..18, data in words 64 and 128)
    mem[0]  = 32'h00a00093; // 0x00: ADDI x1, x0, 10
    mem[1]  = 32'h01400113; // 0x04: ADDI x2, x0, 20
    mem[2]  = 32'h002081b3; // 0x08: ADD  x3, x1, x2  (= 30)
    mem[3]  = 32'h40110233; // 0x0c: SUB  x4, x2, x1  (= 10)
    mem[4]  = 32'h0041c2b3; // 0x10: XOR  x5, x3, x4  (= 20)
    mem[5]  = 32'h0020e333; // 0x14: OR   x6, x1, x2  (= 30)
    mem[6]  = 32'h0060f3b3; // 0x18: AND  x7, x1, x6  (= 10)
    mem[7]  = 32'h00f0a413; // 0x1c: SLTI x8, x1, 15  (= 1)
    mem[8]  = 32'h00441493; // 0x20: SLLI x9, x8, 4   (= 16)
    mem[9]  = 32'h10302023; // 0x24: SW   x3, 256(x0) (Store 30 at addr 256 = word 64)
    mem[10] = 32'h10002503; // 0x28: LW   x10, 256(x0)(Load 30 into x10 from addr 256)
    mem[11] = 32'h00a18463; // 0x2c: BEQ  x3, x10, +8 (Branch over next instr)
    mem[12] = 32'h06300593; // 0x30: ADDI x11, x0, 99 (SKIPPED!)
    mem[13] = 32'h00100613; // 0x34: ADDI x12, x0, 1   (Target of BEQ)
    mem[14] = 32'h008006ef; // 0x38: JAL  x13, +8     (Jump over next instr)
    mem[15] = 32'h05800713; // 0x3c: ADDI x14, x0, 88 (SKIPPED!)
    mem[16] = 32'h02a00793; // 0x40: ADDI x15, x0, 42  (Target of JAL)
    mem[17] = 32'h20f02023; // 0x44: SW   x15, 512(x0)(Store 42 at addr 512 = word 128)
    mem[18] = 32'h00000063; // 0x48: BEQ  x0, x0, 0   (Infinite self-loop)
  end

  // ----------------------------------------------------------------------------
  // 5. AXI4 Memory Slave Responder (Synchronous & Burst-Capable)
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AR_IDLE,
    R_BURST
  } r_state_t;

  typedef enum logic [1:0] {
    AW_IDLE,
    W_BURST,
    B_RESP
  } w_state_t;

  r_state_t r_state;
  w_state_t w_state;

  logic [CVA6Cfg.AxiIdWidth-1:0]   ar_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] ar_addr_q;
  axi_pkg::len_t                   ar_len_q;
  logic [7:0]                      ar_cnt_q;

  logic [CVA6Cfg.AxiIdWidth-1:0]   aw_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] aw_addr_q;
  axi_pkg::len_t                   aw_len_q;
  logic [7:0]                      aw_cnt_q;

  // AXI Read Channel FSM
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
    end else begin
      case (r_state)
        AR_IDLE: begin
          noc_resp.ar_ready <= 1'b1;
          noc_resp.r_valid  <= 1'b0;
          noc_resp.r.last   <= 1'b0;
          if (noc_req.ar_valid && noc_resp.ar_ready) begin
            automatic logic [63:0] addr0 = noc_req.ar.addr;
            automatic int unsigned idx0  = (addr0[11:0] >> 2);

            ar_id_q           <= noc_req.ar.id;
            ar_addr_q         <= noc_req.ar.addr;
            ar_len_q          <= noc_req.ar.len;
            ar_cnt_q          <= 8'd0;
            noc_resp.ar_ready <= 1'b0;

            // Set up first beat (beat 0) for next cycle
            noc_resp.r_valid  <= 1'b1;
            noc_resp.r.id     <= noc_req.ar.id;
            noc_resp.r.resp   <= axi_pkg::RESP_OKAY;
            noc_resp.r.user   <= '0;
            noc_resp.r.data   <= {mem[idx0 + 1], mem[idx0]};
            noc_resp.r.last   <= (noc_req.ar.len == 8'd0);
            r_state           <= R_BURST;
          end
        end

        R_BURST: begin
          if (noc_req.r_ready && noc_resp.r_valid) begin
            if (ar_cnt_q == ar_len_q) begin
              noc_resp.r_valid  <= 1'b0;
              noc_resp.r.last   <= 1'b0;
              noc_resp.ar_ready <= 1'b1;
              r_state           <= AR_IDLE;
            end else begin
              automatic logic [7:0] next_cnt   = ar_cnt_q + 8'd1;
              automatic logic [63:0] next_addr = ar_addr_q + (next_cnt * 8);
              automatic int unsigned next_idx  = (next_addr[11:0] >> 2);

              ar_cnt_q        <= next_cnt;
              noc_resp.r.data <= {mem[next_idx + 1], mem[next_idx]};
              noc_resp.r.last <= (next_cnt == ar_len_q);
            end
          end
        end

        default: r_state <= AR_IDLE;
      endcase
    end
  end

  // AXI Write Channel FSM
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      w_state           <= AW_IDLE;
      noc_resp.aw_ready <= 1'b0;
      noc_resp.w_ready  <= 1'b0;
      noc_resp.b_valid  <= 1'b0;
      noc_resp.b        <= '0;
      aw_id_q           <= '0;
      aw_addr_q         <= '0;
      aw_len_q          <= '0;
      aw_cnt_q          <= '0;
    end else begin
      case (w_state)
        AW_IDLE: begin
          noc_resp.aw_ready <= 1'b1;
          noc_resp.w_ready  <= 1'b1;
          noc_resp.b_valid  <= 1'b0;
          if (noc_req.aw_valid && noc_resp.aw_ready) begin
            aw_id_q   <= noc_req.aw.id;
            aw_addr_q <= noc_req.aw.addr;
            aw_len_q  <= noc_req.aw.len;
            aw_cnt_q  <= 8'd0;

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
                noc_resp.aw_ready <= 1'b0;
                noc_resp.w_ready  <= 1'b0;
                noc_resp.b_valid  <= 1'b1;
                noc_resp.b.id     <= noc_req.aw.id;
                noc_resp.b.resp   <= axi_pkg::RESP_OKAY;
                noc_resp.b.user   <= '0;
                w_state           <= B_RESP;
              end else begin
                aw_cnt_q          <= 8'd1;
                noc_resp.aw_ready <= 1'b0;
                w_state           <= W_BURST;
              end
            end else begin
              noc_resp.aw_ready <= 1'b0;
              w_state           <= W_BURST;
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

            aw_cnt_q <= aw_cnt_q + 1;

            if (noc_req.w.last) begin
              noc_resp.w_ready <= 1'b0;
              noc_resp.b_valid <= 1'b1;
              noc_resp.b.id    <= aw_id_q;
              noc_resp.b.resp  <= axi_pkg::RESP_OKAY;
              noc_resp.b.user  <= '0;
              w_state          <= B_RESP;
            end
          end
        end

        B_RESP: begin
          noc_resp.b_valid <= 1'b1;
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
  // 6. Architectural Register Read Function
  // ----------------------------------------------------------------------------
  function logic [31:0] read_arch_reg(input int r);
    if (r == 0) return 32'h0;
    return u_dut.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[r];
  endfunction

  // ----------------------------------------------------------------------------
  // 7. Cycle Counting & CSV Execution Trace
  // ----------------------------------------------------------------------------
  int check_count = 0;
  int error_count = 0;
  int cycle_count = 0;
  int csv_fd;

  initial begin
    csv_fd = $fopen("cva6_trace.csv", "w");
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,CommitAck,CommitPC,WAddr,WData,FetchPC,IcacheState,IcacheMiss,IcacheReq,IcacheRdy,IcacheVld,FifoRdy,FifoFull,FifoEmpty,FifoUsage,FeIdVld,IdFeRdy,IdPC,AxiARValid,AxiARAddr,AxiRValid,LsuValid,LsuReady,StallStPending,WbufEmpty,SbFull");
    end else begin
      $display("[TB_WARNING] Could not open cva6_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    cycle_count++;

    if (csv_fd) begin
      $fdisplay(csv_fd, "%0t,%0d,%b,0x%08h,%0d,0x%08h,0x%08h,%0d,%b,%b,%b,%b,%b,%b,%b,%0d,%b,%b,0x%08h,%b,0x%08h,%b,%b,%b,%b,%b,%b",
                $time, cycle_count,
                probe_commit_ack,
                probe_commit_ack ? probe_commit_pc : 32'h0,
                probe_we_gpr ? probe_waddr_gpr : 5'd0,
                probe_we_gpr ? probe_wdata_gpr : 32'd0,
                spy_fetch_pc,
                probe_icache_state,
                probe_icache_miss,
                probe_fetch_req,
                probe_icache_ready,
                probe_fetch_valid,
                probe_fifo_ready,
                probe_fifo_full,
                probe_fifo_empty,
                probe_fifo_usage,
                probe_fe_id_valid,
                probe_id_fe_ready,
                probe_fe_addr,
                noc_req.ar_valid,
                noc_req.ar.addr[31:0],
                noc_resp.r_valid,
                probe_lsu_valid,
                probe_lsu_ready,
                probe_stall_st_pending,
                probe_wbuffer_empty,
                probe_sb_full);
    end
  end

  // ----------------------------------------------------------------------------
  // 8. Test Scenario Driver & Checker Routine
  // ----------------------------------------------------------------------------
  initial begin
    // Tie-off subsystem inputs
    boot_addr  = 32'h8000_0000;
    hart_id    = '0;
    irq        = 2'b00;
    ipi        = 1'b0;
    time_irq   = 1'b0;
    debug_req  = 1'b0;
    cvxif_resp = '0;

    // Reset sequence
    rst_ni = 1'b0;

    $display("============================================================");
    $display("[TB_INFO] Starting CVA6 (Ariane) Core Behavioral Simulation");
    $display("============================================================");

    // Hold reset for 10 clock cycles
    repeat (10) @(posedge clk);
    rst_ni = 1'b1;
    $display("[%0t] [TB_RESET] Reset de-asserted (rst_ni = 1). Core initializing...", $time);

    // Wait until core commits the final infinite loop instruction at 0x8000_0048 (or 0x0000_0048)
    while (!spy_loop_hit && (cycle_count < TIMEOUT_CYCLES)) begin
      @(posedge clk);
    end

    // Allow 20 additional cycles for pipeline drainage and memory write-back
    repeat (20) @(posedge clk);

    // Run Scoreboard Checks on Register File and Memory
    $display("============================================================");
    $display("[%0t] [SCOREBOARD] Evaluating CPU Execution Results...", $time);
    $display("============================================================");

    // Register checks (x1..x15)
    for (int r = 1; r <= 15; r++) begin
      $display("[REG_DUMP] x%0d: actual=0x%08h (%0d)", r, read_arch_reg(r), read_arch_reg(r));
    end

    check_reg(1, 32'd10);
    check_reg(2, 32'd20);
    check_reg(3, 32'd30);
    check_reg(4, 32'd10);
    check_reg(5, 32'd20);
    check_reg(6, 32'd30);
    check_reg(7, 32'd10);
    check_reg(8, 32'd1);
    check_reg(9, 32'd16);
    check_reg(10, 32'd30);
    check_reg(11, 32'd0);
    check_reg(12, 32'd1);
    check_reg(13, 32'h3c);
    check_reg(14, 32'd0);
    check_reg(15, 32'd42);

    // Memory checks (word 64 = addr 256, word 128 = addr 512)
    check_mem(64, 32'd30);
    check_mem(128, 32'd42);

    $display("============================================================");
    $display("Verification Summary for CVA6 (Ariane):");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    if (csv_fd) begin
      $fclose(csv_fd);
      csv_fd = 0;
    end

    if (error_count == 0 && check_count == 17) begin
      $display("============================================================");
      $display("[PASS] ALL 17 ASSERTION CHECKS PASSED!");
      $display("Simulation finished successfully at time %0t", $time);
      $display("============================================================");
    end else begin
      $display("============================================================");
      $display("[FAIL] SIMULATION ENCOUNTERED %0d ERRORS!", error_count);
      $display("============================================================");
    end

    $display("[%0t] [TB_INFO] Reached infinite loop (end of program). Halting and pausing simulation ($stop).", $time);
    sim_done = 1'b1;
    $stop;
  end

  // Check register task
  task check_reg(input int reg_idx, input logic [31:0] expected_val);
    logic [31:0] actual_val;
    actual_val = read_arch_reg(reg_idx);
    check_count++;
    if (actual_val === expected_val || (reg_idx == 13 && (actual_val === 32'h8000_003c || actual_val === 32'h0000_003c))) begin
      $display("[PASS] Reg Check [%0d] x%0d: actual=0x%08h (expected=0x%08h)",
               check_count, reg_idx, actual_val, actual_val);
    end else begin
      error_count++;
      $display("[FAIL] Reg Check [%0d] x%0d: actual=0x%08h != expected=0x%08h",
               check_count, reg_idx, actual_val, expected_val);
    end
  endtask

  // Check memory task
  task check_mem(input int word_addr, input logic [31:0] expected_val);
    logic [31:0] actual_val;
    actual_val = mem[word_addr];
    check_count++;
    if (actual_val === expected_val) begin
      $display("[PASS] Mem Check [%0d] word %0d: actual=0x%08h (expected=0x%08h)",
               check_count, word_addr, actual_val, expected_val);
    end else begin
      error_count++;
      $display("[FAIL] Mem Check [%0d] word %0d: actual=0x%08h != expected=0x%08h",
               check_count, word_addr, actual_val, expected_val);
    end
  endtask

  // Global watchdog timeout
  initial begin
    #(TIMEOUT_CYCLES * CLK_PERIOD * 2);
    if (!sim_done) begin
      $display("[TB_TIMEOUT] Watchdog triggered after %0d ns. Core did not complete.", $time);
      sim_done = 1'b1;
      $stop;
    end
  end

endmodule
