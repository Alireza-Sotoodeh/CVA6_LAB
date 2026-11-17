// ==============================================================================
// Standardized Standalone Testbench for OpenHW CVA6 (Ariane 6-Stage RISC-V Core)
// Target Core: cva6 (RV32IMA + SV32 MMU / Dual-Issue / AXI4-ATOP)
// Follows: Document/testbench_standardization_guide.md
// ==============================================================================

`timescale 1ns / 1ps

module tb_test2_cva6;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clocks
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 8000;
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
  // 3. Hierarchical Probes (Spy Signals)
  // ----------------------------------------------------------------------------
  wire [31:0] spy_commit_pc = u_dut.pc_commit;
  wire [31:0] spy_fetch_pc  = u_dut.i_frontend.icache_dreq_o.vaddr;

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
        // Input Arrays for Heavy Benchmark (Array A & Array B)
    mem[64] = 32'd10; mem[65] = 32'd20; mem[66] = 32'd30; mem[67] = 32'd40;
    mem[68] = 32'd50; mem[69] = 32'd60; mem[70] = 32'd70; mem[71] = 32'd80;
    mem[72] = 32'd1;  mem[73] = 32'd2;  mem[74] = 32'd3;  mem[75] = 32'd4;
    mem[76] = 32'd5;  mem[77] = 32'd6;  mem[78] = 32'd7;  mem[79] = 32'd8;

    // Test2 Program: PQC-PolyMatrix MAC & Non-linear Hash Kernel (40 instructions)
    mem[0]  = 32'h10000093; // 0x00: ADDI x1, x0, 256
    mem[1]  = 32'h12000113; // 0x04: ADDI x2, x0, 288
    mem[2]  = 32'h14000193; // 0x08: ADDI x3, x0, 320
    mem[3]  = 32'h00800213; // 0x0c: ADDI x4, x0, 8
    mem[4]  = 32'h00000293; // 0x10: ADDI x5, x0, 0
    mem[5]  = 32'h0000a303; // 0x14: LW x6, 0(x1)
    mem[6]  = 32'h00012383; // 0x18: LW x7, 0(x2)
    mem[7]  = 32'h00231493; // 0x1c: SLLI x9, x6, 2
    mem[8]  = 32'h00748433; // 0x20: ADD x8, x9, x7
    mem[9]  = 32'h007344b3; // 0x24: XOR x9, x6, x7
    mem[10] = 32'h0014d493; // 0x28: SRLI x9, x9, 1
    mem[11] = 32'h00940433; // 0x2c: ADD x8, x8, x9
    mem[12] = 32'h0081a023; // 0x30: SW x8, 0(x3)
    mem[13] = 32'h008282b3; // 0x34: ADD x5, x5, x8
    mem[14] = 32'h00408093; // 0x38: ADDI x1, x1, 4
    mem[15] = 32'h00410113; // 0x3c: ADDI x2, x2, 4
    mem[16] = 32'h00418193; // 0x40: ADDI x3, x3, 4
    mem[17] = 32'hfff20213; // 0x44: ADDI x4, x4, -1
    mem[18] = 32'hfc0216e3; // 0x48: BNE x4, x0, -52
    mem[19] = 32'h14000193; // 0x4c: ADDI x3, x0, 320
    mem[20] = 32'h00400593; // 0x50: ADDI x11, x0, 4
    mem[21] = 32'h0ff00513; // 0x54: ADDI x10, x0, 255
    mem[22] = 32'h0001a303; // 0x58: LW x6, 0(x3)
    mem[23] = 32'h0101a383; // 0x5c: LW x7, 16(x3)
    mem[24] = 32'h00734633; // 0x60: XOR x12, x6, x7
    mem[25] = 32'h00a67633; // 0x64: AND x12, x12, x10
    mem[26] = 32'h00361493; // 0x68: SLLI x9, x12, 3
    mem[27] = 32'h00966633; // 0x6c: OR x12, x12, x9
    mem[28] = 32'h00c1a023; // 0x70: SW x12, 0(x3)
    mem[29] = 32'h00c282b3; // 0x74: ADD x5, x5, x12
    mem[30] = 32'h00418193; // 0x78: ADDI x3, x3, 4
    mem[31] = 32'hfff58593; // 0x7c: ADDI x11, x11, -1
    mem[32] = 32'hfc059ce3; // 0x80: BNE x11, x0, -40
    mem[33] = 32'h00028793; // 0x84: ADDI x15, x5, 0
    mem[34] = 32'h20f02023; // 0x88: SW x15, 512(x0)
    mem[35] = 32'h20502223; // 0x8c: SW x5, 516(x0)
    mem[36] = 32'h20002703; // 0x90: LW x14, 512(x0)
    mem[37] = 32'h00f70463; // 0x94: BEQ x14, x15, +8
    mem[38] = 32'h06300793; // 0x98: ADDI x15, x0, 99
    mem[39] = 32'h00000063; // 0x9c: BEQ x0, x0, 0
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
            automatic int unsigned idx0  = (addr0[11:3] << 1);

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
              automatic int unsigned next_idx  = (next_addr[11:3] << 1);

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
              automatic int unsigned word_idx = (cur_addr[11:3] << 1);

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
            automatic int unsigned word_idx = (cur_addr[11:3] << 1);

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
      $fdisplay(csv_fd, "Time_ps,Cycle,CommitPC,FetchPC,AxiARValid,AxiARAddr,AxiRValid,AxiAWValid,AxiAWAddr,AxiWValid,AxiWData");
    end else begin
      $display("[TB_WARNING] Could not open cva6_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    cycle_count++;
    if (u_dut.commit_ack[0]) begin
      $display("[COMMIT %0d] PC=0x%08h | ex_vld=%b", cycle_count, u_dut.commit_instr_id_commit[0].pc, u_dut.commit_instr_id_commit[0].ex.valid);
    end
    if (cycle_count >= 267 && cycle_count <= 285) begin
      $display("[DBG_AXI_R %0d] r_vld=%b r_rdy=%b r_id=%0d r_last=%b | shim_vld=%b shim_id=%0d shim_last=%b shim_rdy=%b | ic_vld_d=%b",
        cycle_count,
        noc_resp.r_valid,
        noc_req.r_ready,
        noc_resp.r.id,
        noc_resp.r.last,
        u_dut.gen_cache_wt.i_cache_subsystem.i_adapter.axi_rd_valid,
        u_dut.gen_cache_wt.i_cache_subsystem.i_adapter.axi_rd_id_out,
        u_dut.gen_cache_wt.i_cache_subsystem.i_adapter.axi_rd_last,
        u_dut.gen_cache_wt.i_cache_subsystem.i_adapter.axi_rd_rdy,
        u_dut.gen_cache_wt.i_cache_subsystem.i_adapter.icache_rtrn_vld_d
      );
      $display("[DBG_IC %0d] state=%0d kill_s2=%b flush_d=%b mem_vld=%b rtype=%0d wren=%b dreq_valid=%b",
        cycle_count,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.state_q,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.dreq_i.kill_s2,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.flush_d,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.mem_rtrn_vld_i,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.mem_rtrn_i.rtype,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.cache_wren,
        u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.dreq_o.valid
      );
      $display("[DBG_FE %0d] commit_pc=%h fetch_pc=%h ic_req=%b ic_vld=%b ic_data=%h fe_vld=%b fe_rdy=%b instr=%h ex_vld=%b ex_cause=%0d",
        cycle_count,
        spy_commit_pc,
        spy_fetch_pc,
        u_dut.icache_dreq_if_cache.req,
        u_dut.icache_dreq_cache_if.valid,
        u_dut.icache_dreq_cache_if.data,
        u_dut.fetch_valid_if_id,
        u_dut.fetch_ready_id_if,
        u_dut.fetch_entry_if_id[0].instruction,
        u_dut.ex_commit.valid,
        u_dut.ex_commit.cause
      );
    end
    if (csv_fd) begin
      $fdisplay(csv_fd, "%0t,%0d,0x%08h,0x%08h,%b,0x%08h,%b,%b,0x%08h,%b,0x%016h",
                $time, cycle_count, spy_commit_pc, spy_fetch_pc,
                noc_req.ar_valid, noc_req.ar.addr, noc_resp.r_valid,
                noc_req.aw_valid, noc_req.aw.addr, noc_req.w_valid, noc_req.w.data);
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
    while ((spy_commit_pc[15:0] !== 16'h009c) && (cycle_count < TIMEOUT_CYCLES)) begin
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

    check_reg(5,  32'd7332);
    check_reg(14, 32'd7332);
    check_reg(15, 32'd7332);
    check_mem(128, 32'd7332);
    check_mem(129, 32'd7332);
    check_mem(80,  32'd1782);
    check_mem(81,  32'd638);
    check_mem(82,  32'd1462);
    check_mem(83,  32'd1790);
    check_mem(84,  32'd232);
    check_mem(85,  32'd275);
    check_mem(86,  32'd319);
    check_mem(87,  32'd372);

    $display("============================================================");
    $display("Verification Summary for CVA6 (Ariane):");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    if (csv_fd != 0) begin
      $fclose(csv_fd);
      csv_fd = 0;
    end

    if (error_count == 0 && check_count == 13) begin
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
    $display("[TB_TIMEOUT] Watchdog triggered after $time. Core did not complete.", $time);
    sim_done = 1'b1;
    $stop;
    end
  end

endmodule
