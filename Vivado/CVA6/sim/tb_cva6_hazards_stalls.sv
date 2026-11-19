// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 20:36:00 +03:30
// Status: NEW FILE
// Reason / Modification: Suite 2 pipeline hazard testbench for CVA6. Exercises
//                        RAW ALU-to-ALU operand forwarding, Load-Use scoreboard
//                        stalls, Store-to-Load page offset matching, serial
//                        divider (~32 cycles) FLU structural write-back contention,
//                        and pipelined multiplication. Logs a 75+ column CSV trace
//                        (cva6_hazard_trace.csv) with dual-commit-port accounting.
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_hazards_stalls;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clock
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 4000;
  localparam int  MEM_WORDS      = 1024;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;
  localparam logic [31:0] END_PC    = 32'h8000_006C; // JAL x0, 0 at END

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

  // Multiplier / Divider Probes
  wire        probe_mult_valid_id   = u_dut.mult_valid_id_ex[0];
  wire        probe_mult_ready      = u_dut.ex_stage_i.mult_ready;
  wire        probe_mult_valid      = u_dut.ex_stage_i.mult_valid;
  wire [CVA6Cfg.TRANS_ID_BITS-1:0] probe_mult_trans_id = u_dut.ex_stage_i.mult_trans_id;
  wire [31:0] probe_mult_result     = u_dut.ex_stage_i.mult_result[31:0];
  wire        probe_div_valid_op    = u_dut.ex_stage_i.i_mult.div_valid_op;
  wire        probe_div_valid       = u_dut.ex_stage_i.i_mult.div_valid;
  wire        probe_mul_valid_op    = u_dut.ex_stage_i.i_mult.mul_valid_op;
  wire        probe_mul_valid       = u_dut.ex_stage_i.i_mult.mul_valid;
  wire [1:0]  probe_serdiv_state    = u_dut.ex_stage_i.i_mult.i_div.state_q;
  wire [4:0]  probe_serdiv_cnt      = u_dut.ex_stage_i.i_mult.i_div.cnt_q;

  // LSU Probes
  wire        probe_lsu_valid_id    = u_dut.lsu_valid_id_ex[0];
  wire [31:0] probe_load_result     = u_dut.load_result_ex_id[31:0];
  wire [CVA6Cfg.TRANS_ID_BITS-1:0] probe_load_trans_id = u_dut.load_trans_id_ex_id;
  wire [3:0]  probe_load_unit_state = u_dut.ex_stage_i.lsu_i.i_load_unit.state_q;
  wire        probe_page_offset_matches = u_dut.ex_stage_i.lsu_i.page_offset_matches;
  wire        probe_store_buf_empty = u_dut.ex_stage_i.lsu_i.store_buffer_empty;

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

    // 28-instruction Pipeline Hazard & Forwarding Benchmark
    // 0x8000_0000: Setup
    mem[0]  = 32'h800000b7; // 0x8000_0000 LUI  x1,  0x80000
    mem[1]  = 32'h20008093; // 0x8000_0004 ADDI x1,  x1, 512      (x1 = 0x8000_0200)
    mem[2]  = 32'h00a00113; // 0x8000_0008 ADDI x2,  x0, 10
    mem[3]  = 32'h01400193; // 0x8000_000c ADDI x3,  x0, 20

    // Phase 1: RAW ALU-to-ALU Forwarding Burst (7 back-to-back dependent ALU instrs)
    mem[4]  = 32'h00510213; // 0x8000_0010 ADDI x4,  x2, 5        (x4 = 15)
    mem[5]  = 32'h003202b3; // 0x8000_0014 ADD  x5,  x4, x3       (x5 = 35, RAW on x4)
    mem[6]  = 32'h40228333; // 0x8000_0018 SUB  x6,  x5, x2       (x6 = 25, RAW on x5)
    mem[7]  = 32'h004373b3; // 0x8000_001c AND  x7,  x6, x4       (x7 = 9,  RAW on x6, x4)
    mem[8]  = 32'h0053e433; // 0x8000_0020 OR   x8,  x7, x5       (x8 = 43, RAW on x7, x5)
    mem[9]  = 32'h006444b3; // 0x8000_0024 XOR  x9,  x8, x6       (x9 = 50, RAW on x8, x6)
    mem[10] = 32'h00249513; // 0x8000_0028 SLLI x10, x9, 2        (x10 = 200, RAW on x9)

    // Phase 2: Load-Use Hazard Stall
    mem[11] = 32'h00a0a023; // 0x8000_002c SW   x10, 0(x1)        (store 200 into [0x8000_0200])
    mem[12] = 32'h0000a583; // 0x8000_0030 LW   x11, 0(x1)        (load 200 into x11)
    mem[13] = 32'h00158613; // 0x8000_0034 ADDI x12, x11, 1       (x12 = 201, LOAD-USE STALL on x11)
    mem[14] = 32'h004606b3; // 0x8000_0038 ADD  x13, x12, x4      (x13 = 216, forwarded from x12)

    // Phase 3: Store-to-Load Page-Offset Hazard (Store Buffer Interaction)
    mem[15] = 32'h00d0a223; // 0x8000_003c SW   x13, 4(x1)        (store 216 into [0x8000_0204])
    mem[16] = 32'h0040a703; // 0x8000_0040 LW   x14, 4(x1)        (load from [0x8000_0204], page_offset match!)
    mem[17] = 32'h00a70793; // 0x8000_0044 ADDI x15, x14, 10      (x15 = 226, RAW on x14)

    // Phase 4: Multi-Cycle Integer Divider Structural Write-Back Contention
    mem[18] = 32'h06400813; // 0x8000_0048 ADDI x16, x0, 100      (dividend = 100)
    mem[19] = 32'h00700893; // 0x8000_004c ADDI x17, x0, 7        (divisor = 7)
    mem[20] = 32'h03184933; // 0x8000_0050 DIV  x18, x16, x17     (x18 = 14, ~32 cycles in serdiv)
    mem[21] = 32'h1f400993; // 0x8000_0054 ADDI x19, x0, 500      (independent ALU, stalled by flu_ready=0!)
    mem[22] = 32'h03186a33; // 0x8000_0058 REM  x20, x16, x17     (x20 = 2, ~32 cycles in serdiv)
    mem[23] = 32'h2bc00a93; // 0x8000_005c ADDI x21, x0, 700      (independent ALU, stalled by flu_ready=0!)
    mem[24] = 32'h01490b33; // 0x8000_0060 ADD  x22, x18, x20     (x22 = 16, dependent on div & rem)
    mem[25] = 32'h031b0bb3; // 0x8000_0064 MUL  x23, x22, x17     (x23 = 112, pipelined multiplier)
    mem[26] = 32'h013b8c33; // 0x8000_0068 ADD  x24, x23, x19     (x24 = 612)

    // Phase 5: Terminal self-loop
    mem[27] = 32'h0000006f; // 0x8000_006c JAL  x0, 0             (END self-loop)
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

  // Hazard event counters
  int raw_forward_count        = 0;
  int load_use_stall_count     = 0;
  int store_buffer_stall_count = 0;
  int div_contention_count     = 0;
  int div_exec_count           = 0;
  int mul_exec_count           = 0;

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      instret_count            <= 0;
      raw_forward_count        <= 0;
      load_use_stall_count     <= 0;
      store_buffer_stall_count <= 0;
      div_contention_count     <= 0;
      div_exec_count           <= 0;
      mul_exec_count           <= 0;
      first_commit_cycle       <= 0;
      end_commit_cycle         <= 0;
    end else begin
      // Dual-port retirement accounting.
      if (probe_commit_ack[0]) instret_count <= instret_count + 1;
      if (probe_commit_ack[1]) instret_count <= instret_count + 1;

      if ((probe_commit_ack[0] || probe_commit_ack[1]) && first_commit_cycle == 0)
        first_commit_cycle <= cycle_count;

      // Operand forwarding events
      if (probe_forward_rs1 || probe_forward_rs2)
        raw_forward_count <= raw_forward_count + 1;

      // Load-use stall events (RAW stall while waiting for load data)
      if (probe_stall_raw && (probe_stall_rs1 || probe_stall_rs2))
        load_use_stall_count <= load_use_stall_count + 1;

      // Store-to-load page offset collision stall
      if (probe_page_offset_matches || probe_load_unit_state == 4'd3) // 3 = WAIT_PAGE_OFFSET
        store_buffer_stall_count <= store_buffer_stall_count + 1;

      // Divider contention (FLU busy stalling issue)
      if (!probe_flu_ready && probe_issue_valid0 && !probe_issue_ack0)
        div_contention_count <= div_contention_count + 1;

      // Division execution count (sample on div_valid pulse at result completion)
      if (probe_div_valid)
        div_exec_count <= div_exec_count + 1;

      // Multiplier execution count
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
    csv_fd = $fopen("cva6_hazard_trace.csv", "w");
    logging_en = 1'b1;
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,IcacheState,IcacheMiss,IcacheReady,IssueValid0,IssueAck0,StallIssue,StallRaw,StallRs1,StallRs2,Rs1HasRaw,Rs2HasRaw,ForwardRs1,ForwardRs2,IsAluBypass,AluBypassRs1,AluBypassRs2,FuBusyAlu,FuBusyMult,FuBusyLoad,FluReady,LsuReady,SbFull,MultValidId,MultReady,MultValid,MultTransId,MultResult,DivValidOp,DivValid,MulValidOp,MulValid,SerDivState,SerDivCnt,LsuValidId,LoadResult,LoadTransId,LoadUnitState,PageOffsetMatches,StoreBufEmpty,RawForwardCount,LoadUseStallCount,StoreBufStallCount,DivContentionCount,DivExecCount,MulExecCount,AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiBValid");
    end else begin
      $display("[TB_WARNING] Could not open cva6_hazard_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    if (csv_fd && logging_en) begin
      $fdisplay(csv_fd, "%0t,%0d,%0d,%b,%b,0x%08h,0x%08h,0x%08h,0x%08h,%b,%0d,0x%08h,%b,%0d,0x%08h,0x%08h,%b,%b,0x%08h,%b,%b,%0d,%0d,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%0d,0x%08h,%b,%b,%b,%b,%0d,%0d,%b,0x%08h,%0d,%0d,%b,%b,%0d,%0d,%0d,%0d,%0d,%0d,%b,0x%08h,%b,%b,%b,0x%08h,%b,%b",
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
                probe_mult_valid_id,
                probe_mult_ready,
                probe_mult_valid,
                probe_mult_trans_id,
                probe_mult_result,
                probe_div_valid_op,
                probe_div_valid,
                probe_mul_valid_op,
                probe_mul_valid,
                probe_serdiv_state,
                probe_serdiv_cnt,
                probe_lsu_valid_id,
                probe_load_result,
                probe_load_trans_id,
                probe_load_unit_state,
                probe_page_offset_matches,
                probe_store_buf_empty,
                raw_forward_count,
                load_use_stall_count,
                store_buffer_stall_count,
                div_contention_count,
                div_exec_count,
                mul_exec_count,
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
    $display("[TB_INFO] CVA6 Suite 2: Pipeline Hazards & Scoreboard Stalls");
    $display("[TB_INFO] RAW Forwarding, Load-Use, Store Buffer, DIV Contention");
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

    check_reg(1,  32'h8000_0200); // Base data memory address
    check_reg(2,  32'd10);         // sp = 10
    check_reg(3,  32'd20);         // gp = 20
    check_reg(4,  32'd15);         // tp = 10 + 5 = 15
    check_reg(5,  32'd35);         // t0 = 15 + 20 = 35 (RAW forwarded)
    check_reg(6,  32'd25);         // t1 = 35 - 10 = 25 (RAW forwarded)
    check_reg(7,  32'd9);          // t2 = 25 & 15 = 9  (RAW forwarded)
    check_reg(8,  32'd43);         // s0 = 9 | 35  = 43 (RAW forwarded)
    check_reg(9,  32'd50);         // s1 = 43 ^ 25 = 50 (RAW forwarded)
    check_reg(10, 32'd200);        // a0 = 50 << 2 = 200 (RAW forwarded)
    check_reg(11, 32'd200);        // a1 = LW 0(x1) = 200
    check_reg(12, 32'd201);        // a2 = a1 + 1 = 201 (after Load-Use stall)
    check_reg(13, 32'd216);        // a3 = 201 + 15 = 216 (forwarded)
    check_reg(14, 32'd216);        // a4 = LW 4(x1) = 216 (after store-to-load stall)
    check_reg(15, 32'd226);        // a5 = 216 + 10 = 226
    check_reg(16, 32'd100);        // a6 = dividend = 100
    check_reg(17, 32'd7);          // a7 = divisor = 7
    check_reg(18, 32'd14);         // s2 = 100 / 7 = 14 (DIV result)
    check_reg(19, 32'd500);        // s3 = 500 (ALU instr issued after DIV contention)
    check_reg(20, 32'd2);          // s4 = 100 % 7 = 2 (REM result)
    check_reg(21, 32'd700);        // s5 = 700 (ALU instr issued after REM contention)
    check_reg(22, 32'd16);         // s6 = 14 + 2 = 16 (ADD of DIV & REM)
    check_reg(23, 32'd112);        // s7 = 16 * 7 = 112 (MUL result)
    check_reg(24, 32'd612);        // s8 = 112 + 500 = 612

    check_cond(spy_end_hit, "END self-loop committed");
    check_cond(raw_forward_count >= 5, "at least 5 RAW operand forwarding events observed");
    check_cond(load_use_stall_count >= 1, "Load-Use scoreboard stall observed");
    check_cond(div_exec_count == 2, "serial divider executed exactly twice (DIV and REM)");
    check_cond(mul_exec_count == 1, "pipelined multiplier executed exactly once (MUL)");
    check_cond(div_contention_count >= 10, "divider FLU structural write-back contention observed (>=10 stall cycles)");

    $display("------------------------------------------------------------");
    $display("[METRICS] Committed instructions    : %0d", instret_count);
    $display("[METRICS] First commit cycle        : %0d", first_commit_cycle);
    $display("[METRICS] End commit cycle          : %0d", end_commit_cycle);
    $display("[METRICS] RAW forwarding events     : %0d", raw_forward_count);
    $display("[METRICS] Load-Use stall cycles     : %0d", load_use_stall_count);
    $display("[METRICS] Store buffer stall cycles : %0d", store_buffer_stall_count);
    $display("[METRICS] Divider contention cycles : %0d", div_contention_count);
    $display("[METRICS] Divider executions        : %0d", div_exec_count);
    $display("[METRICS] Multiplier executions     : %0d", mul_exec_count);
    if (end_commit_cycle > first_commit_cycle && instret_count > 0)
      $display("[METRICS] Active CPI (hazard workload): %0.2f",
               real'(end_commit_cycle - first_commit_cycle + 1) / real'(instret_count));
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 2:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    logging_en = 1'b0;

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-2 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-2 ENCOUNTERED %0d ERROR(S)", error_count);
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
