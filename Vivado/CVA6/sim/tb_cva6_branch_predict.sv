// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 20:15:00 +03:30
// Status: NEW FILE (reconstructed)
// Reason / Modification: Suite 1 control-flow testbench for CVA6. Exercises
//                        BHT 2-bit training, taken/not-taken branches, JAL,
//                        JALR, BTB update/hit, RAS call/return, and branch
//                        misprediction flushes. Logs a 75-column CSV trace
//                        (cva6_branch_trace.csv) with dual-commit-port
//                        accounting. Verified against RTL: branch
//                        mispredictions assert flush_if + flush_unissued,
//                        NOT flush_bp.
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_branch_predict;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clock
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD     = 10ns;
  localparam int  TIMEOUT_CYCLES = 4000;
  localparam int  MEM_WORDS      = 1024;

  localparam logic [31:0] BOOT_ADDR = 32'h8000_0000;
  localparam logic [31:0] END_PC    = 32'h8000_00A4; // JAL x0, 0 at END

  // Suite-1 BHT / BTB indices (configuration: BHT=128, BTB=32, RVC=0,
  // INSTR_PER_FETCH=1, FpgaEn=0)
  //   BHT index = pc[8:2]   ; loop BNE at 0x8000_004C -> 7'd19
  //   BTB index = pc[6:2]   ; BTB-loop JALR at 0x8000_0080 -> 5'd0
  localparam logic [6:0] BHT_LOOP_IDX = 7'd19;
  localparam logic [4:0] BTB_L6_IDX   = 5'd0;

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
  wire        probe_icache_kill_s1  = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.dreq_i.kill_s1;
  wire        probe_icache_kill_s2  = u_dut.gen_cache_wt.i_cache_subsystem.i_cva6_icache.dreq_i.kill_s2;

  // Branch / pipeline control
  wire        probe_branch_valid        = u_dut.branch_valid_id_ex[0];
  wire        probe_branch_predict      = u_dut.branch_predict_id_ex.valid;
  wire        probe_resolve_branch      = u_dut.resolve_branch_ex_id;
  wire        probe_resolved_valid      = u_dut.resolved_branch.valid;
  wire [31:0] probe_resolved_pc         = u_dut.resolved_branch.pc[31:0];
  wire        probe_resolved_taken      = u_dut.resolved_branch.is_taken;
  wire        probe_resolved_mispredict = u_dut.resolved_branch.is_mispredict;
  wire [31:0] probe_resolved_target     = u_dut.resolved_branch.target_address[31:0];
  wire [3:0]  probe_resolved_cf         = u_dut.resolved_branch.cf_type;

  wire        probe_flush_bp            = u_dut.flush_ctrl_bp;
  wire        probe_flush_if            = u_dut.flush_ctrl_if;
  wire        probe_flush_unissued      = u_dut.flush_unissued_instr_ctrl_id;
  wire        probe_flush_id            = u_dut.flush_ctrl_id;
  wire        probe_flush_ex            = u_dut.flush_ctrl_ex;
  wire        probe_halt_frontend       = u_dut.halt_frontend;
  wire        probe_pipeline_flush      = u_dut.flush_ctrl_ex;

  // BHT / BTB / RAS
  wire        probe_bht_update_valid = u_dut.i_frontend.bht_update.valid;
  wire        probe_bht_update_taken = u_dut.i_frontend.bht_update.taken;
  wire [31:0] probe_bht_update_pc    = u_dut.i_frontend.bht_update.pc[31:0];
  wire        probe_bht_pred_valid   = u_dut.i_frontend.bht_prediction[0].valid;
  wire        probe_bht_pred_taken   = u_dut.i_frontend.bht_prediction[0].taken;

  wire        probe_btb_update_valid  = u_dut.i_frontend.btb_update.valid;
  wire [31:0] probe_btb_update_pc     = u_dut.i_frontend.btb_update.pc[31:0];
  wire [31:0] probe_btb_update_target = u_dut.i_frontend.btb_update.target_address[31:0];
  wire        probe_btb_pred_valid    = u_dut.i_frontend.btb_prediction[0].valid;
  wire [31:0] probe_btb_pred_target   = u_dut.i_frontend.btb_prediction[0].target_address[31:0];

  wire        probe_ras_push          = u_dut.i_frontend.ras_push;
  wire        probe_ras_pop           = u_dut.i_frontend.ras_pop;
  wire        probe_ras_predict_valid = u_dut.i_frontend.ras_predict.valid;
  wire [31:0] probe_ras_predict_addr  = u_dut.i_frontend.ras_predict.ra[31:0];

  // AXI
  wire        probe_axi_arvalid = noc_req.ar_valid;
  wire [31:0] probe_axi_araddr  = noc_req.ar.addr[31:0];
  wire        probe_axi_rvalid  = noc_resp.r_valid;
  wire        probe_axi_rlast   = noc_resp.r.last;
  wire        probe_axi_awvalid = noc_req.aw_valid;
  wire [31:0] probe_axi_awaddr  = noc_req.aw.addr[31:0];
  wire        probe_axi_wvalid  = noc_req.w_valid;
  wire        probe_axi_bvalid  = noc_resp.b_valid;

  // Actual BHT/BTB state (ASIC implementation; config FpgaEn=0)
  function automatic logic bht_loop_valid();
    return u_dut.i_frontend.bht_gen.i_bht.bht_q[BHT_LOOP_IDX][0].valid;
  endfunction

  function automatic logic [1:0] bht_loop_counter();
    return u_dut.i_frontend.bht_gen.i_bht.bht_q[BHT_LOOP_IDX][0].saturation_counter;
  endfunction

  function automatic logic btb_l6_valid();
    return u_dut.i_frontend.btb_gen.i_btb.gen_asic_btb.btb_q[BTB_L6_IDX][0].valid;
  endfunction

  function automatic logic [31:0] btb_l6_target();
    return u_dut.i_frontend.btb_gen.i_btb.gen_asic_btb.btb_q[BTB_L6_IDX][0].target_address[31:0];
  endfunction

  // ----------------------------------------------------------------------------
  // 4. Memory Model Image
  // ----------------------------------------------------------------------------
  logic [31:0] mem[0:MEM_WORDS-1];

  initial begin
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'h00000013; // ADDI x0, x0, 0 (NOP)
    end

    // 42-instruction control-flow benchmark (see layout comments)
    mem[0]  = 32'h00a00093; // 0x8000_0000 ADDI x1,  x0, 10
    mem[1]  = 32'h01400113; // 0x8000_0004 ADDI x2,  x0, 20
    mem[2]  = 32'h00000193; // 0x8000_0008 ADDI x3,  x0, 0
    mem[3]  = 32'h00000213; // 0x8000_000c ADDI x4,  x0, 0
    mem[4]  = 32'h002082b3; // 0x8000_0010 ADD  x5,  x1, x2      = 30
    mem[5]  = 32'h40110333; // 0x8000_0014 SUB  x6,  x2, x1      = 10
    mem[6]  = 32'h0062c3b3; // 0x8000_0018 XOR  x7,  x5, x6      = 20
    mem[7]  = 32'h0020e433; // 0x8000_001c OR   x8,  x1, x2      = 30
    mem[8]  = 32'h0050f4b3; // 0x8000_0020 AND  x9,  x1, x5      = 10
    mem[9]  = 32'h00349513; // 0x8000_0024 SLLI x10, x9, 3       = 80
    mem[10] = 32'h00208463; // 0x8000_0028 BEQ  x1,  x2, +8      (not taken)
    mem[11] = 32'h00100593; // 0x8000_002c ADDI x11, x0, 1
    mem[12] = 32'h00108463; // 0x8000_0030 BEQ  x1,  x1, +8      (taken)
    mem[13] = 32'h06300613; // 0x8000_0034 ADDI x12, x0, 99      (skipped)
    mem[14] = 32'h00200613; // 0x8000_0038 ADDI x12, x0, 2
    mem[15] = 32'h00400693; // 0x8000_003c ADDI x13, x0, 4
    mem[16] = 32'h00000713; // 0x8000_0040 ADDI x14, x0, 0
    mem[17] = 32'h00370713; // 0x8000_0044 ADDI x14, x14, 3     (loop body)
    mem[18] = 32'hfff68693; // 0x8000_0048 ADDI x13, x13, -1
    mem[19] = 32'hfe069ce3; // 0x8000_004c BNE  x13, x0, -8     (BHT training)
    mem[20] = 32'h008007ef; // 0x8000_0050 JAL  x15, +8          (target 0x58)
    mem[21] = 32'h05800813; // 0x8000_0054 ADDI x16, x0, 88      (skipped)
    mem[22] = 32'h00300813; // 0x8000_0058 ADDI x16, x0, 3
    mem[23] = 32'h800008b7; // 0x8000_005c LUI  x17, 0x80000
    mem[24] = 32'h06c88893; // 0x8000_0060 ADDI x17, x17, 0x6c    (target 0x6c)
    mem[25] = 32'h00088967; // 0x8000_0064 JALR x18, 0(x17)       (indirect jump)
    mem[26] = 32'h04d00993; // 0x8000_0068 ADDI x19, x0, 77      (skipped)
    mem[27] = 32'h00400993; // 0x8000_006c ADDI x19, x0, 4
    mem[28] = 32'h00200b13; // 0x8000_0070 ADDI x22, x0, 2       (BTB loop count)
    mem[29] = 32'h00000b93; // 0x8000_0074 ADDI x23, x0, 0       (BTB hit count)
    mem[30] = 32'h80000c37; // 0x8000_0078 LUI  x24, 0x80000
    mem[31] = 32'h084c0c13; // 0x8000_007c ADDI x24, x24, 0x84    (L7 target)
    mem[32] = 32'h000c0967; // 0x8000_0080 JALR x18, 0(x24)       (BTB loop body)
    mem[33] = 32'h001b8b93; // 0x8000_0084 ADDI x23, x23, 1
    mem[34] = 32'hfffb0b13; // 0x8000_0088 ADDI x22, x22, -1
    mem[35] = 32'hfe0b1ae3; // 0x8000_008c BNE  x22, x0, -12     (back to 0x80)
    mem[36] = 32'h00c000ef; // 0x8000_0090 JAL  x1, +12          (call FUNC 0x9c)
    mem[37] = 32'h00500a13; // 0x8000_0094 ADDI x20, x0, 5
    mem[38] = 32'h00c0006f; // 0x8000_0098 JAL  x0, +12          (END 0xa4)
    mem[39] = 32'h007a8a93; // 0x8000_009c ADDI x21, x21, 7     (FUNC body)
    mem[40] = 32'h00008067; // 0x8000_00a0 JALR x0, 0(x1)        (return)
    mem[41] = 32'h0000006f; // 0x8000_00a4 JAL  x0, 0            (END self-loop)
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
  axi_pkg::len_t aw_len_q;
  logic [7:0] aw_cnt_q;

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
            aw_id_q           <= noc_req.aw.id;
            aw_addr_q         <= noc_req.aw.addr;
            aw_len_q          <= noc_req.aw.len;
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

  int mispredict_count     = 0;
  int flush_if_count       = 0;
  int flush_unissued_count = 0;
  int flush_bp_count       = 0;
  int flush_id_count       = 0;
  int flush_ex_count       = 0;
  int bht_update_count     = 0;
  int ras_push_count       = 0;
  int ras_pop_count        = 0;
  int btb_update_count     = 0;
  int icache_kill_s2_count = 0;

  int unsigned mispredict_latency_sum = 0;
  int unsigned mispredict_latency_n   = 0;

  logic        pend_mispredict = 1'b0;
  int          pend_cycle      = 0;
  logic [31:0] pend_target     = 32'h0;

  // Compact one-line event trace for report evidence.
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      instret_count          <= 0;
      mispredict_count       <= 0;
      flush_if_count         <= 0;
      flush_unissued_count   <= 0;
      flush_bp_count         <= 0;
      flush_id_count         <= 0;
      flush_ex_count         <= 0;
      bht_update_count       <= 0;
      ras_push_count         <= 0;
      ras_pop_count          <= 0;
      btb_update_count       <= 0;
      icache_kill_s2_count   <= 0;
      mispredict_latency_sum <= 0;
      mispredict_latency_n   <= 0;
      pend_mispredict        <= 1'b0;
      pend_cycle             <= 0;
      pend_target            <= 32'h0;
      first_commit_cycle     <= 0;
      end_commit_cycle       <= 0;
    end else begin
      // Dual-port retirement accounting.
      if (probe_commit_ack[0]) instret_count <= instret_count + 1;
      if (probe_commit_ack[1]) instret_count <= instret_count + 1;

      if ((probe_commit_ack[0] || probe_commit_ack[1]) && first_commit_cycle == 0)
        first_commit_cycle <= cycle_count;

      if (probe_flush_if)       flush_if_count       <= flush_if_count + 1;
      if (probe_flush_unissued) flush_unissued_count <= flush_unissued_count + 1;
      if (probe_flush_bp)       flush_bp_count       <= flush_bp_count + 1;
      if (probe_flush_id)       flush_id_count       <= flush_id_count + 1;
      if (probe_flush_ex)       flush_ex_count       <= flush_ex_count + 1;
      if (probe_bht_update_valid) bht_update_count   <= bht_update_count + 1;
      if (probe_ras_push)       ras_push_count       <= ras_push_count + 1;
      if (probe_ras_pop)        ras_pop_count        <= ras_pop_count + 1;
      if (probe_btb_update_valid) btb_update_count   <= btb_update_count + 1;
      if (probe_icache_kill_s2) icache_kill_s2_count <= icache_kill_s2_count + 1;

      // Misprediction event + target-commit latency.
      if (probe_resolved_mispredict && probe_resolved_valid) begin
        mispredict_count <= mispredict_count + 1;
        pend_mispredict  <= 1'b1;
        pend_cycle       <= cycle_count;
        pend_target      <= probe_resolved_target;
        $display("[MISPREDICT] cycle=%0d pc=0x%08h target=0x%08h taken=%0b cf=%0d",
                 cycle_count, probe_resolved_pc, probe_resolved_target,
                 probe_resolved_taken, probe_resolved_cf);
      end

      if (pend_mispredict) begin
        if ((probe_commit_ack[0] && probe_commit_pc0 == pend_target) ||
            (probe_commit_ack[1] && probe_commit_pc1 == pend_target)) begin
          mispredict_latency_sum <= mispredict_latency_sum + (cycle_count - pend_cycle);
          mispredict_latency_n   <= mispredict_latency_n + 1;
          $display("[FLUSH_LATENCY] mispredict cycle=%0d -> target 0x%08h commit cycle=%0d latency=%0d cycles",
                   pend_cycle, pend_target, cycle_count, cycle_count - pend_cycle);
          pend_mispredict <= 1'b0;
        end else if ((cycle_count - pend_cycle) > 200) begin
          $display("[FLUSH_LATENCY] timeout waiting for target 0x%08h after cycle %0d",
                   pend_target, pend_cycle);
          pend_mispredict <= 1'b0;
        end
      end
    end
  end

  // Cycle counter (separate block for clean CSV ordering).
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) cycle_count <= 0;
    else         cycle_count <= cycle_count + 1;
  end

  initial begin
    csv_fd = $fopen("cva6_branch_trace.csv", "w");
    logging_en = 1'b1;
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,CommitPC0,CommitPC1,CommitResult0,CommitResult1,GprWe0,GprWaddr0,GprWdata0,GprWe1,GprWaddr1,GprWdata1,FetchPC,FetchReq,FetchValid,FetchInstr,FeIdValid,IdFeReady,InstrQueueUsage,IcacheState,IcacheMiss,IcacheReady,IcacheKillS1,IcacheKillS2,BranchValid,BranchPredict,ResolveBranch,ResolvedBranchPC,ResolvedBranchTaken,ResolvedBranchMispredict,ResolvedBranchTarget,ResolvedBranchCF,FlushBP,FlushIF,FlushUnissued,FlushID,FlushEX,HaltFrontend,PipelineFlush,BhtUpdateValid,BhtUpdateTaken,BhtUpdatePC,BhtPredValid,BhtPredTaken,BhtLoopValid,BhtLoopCounter,BtbUpdateValid,BtbUpdatePC,BtbUpdateTarget,BtbPredValid,BtbPredTarget,BtbL6Valid,BtbL6Target,RasPush,RasPop,RasPredictValid,RasPredictAddr,MispredictCount,FlushIFCount,FlushBPCount,BhtUpdateCount,RasPushCount,RasPopCount,IcacheKillS2Count,AxiARValid,AxiARAddr,AxiRValid,AxiRLast,AxiAWValid,AxiAWAddr,AxiWValid,AxiBValid");
    end else begin
      $display("[TB_WARNING] Could not open cva6_branch_trace.csv for writing.");
    end
  end

  always @(posedge clk) begin
    if (csv_fd && logging_en) begin
      $fdisplay(csv_fd, "%0t,%0d,%0d,%b,%b,0x%08h,0x%08h,0x%08h,0x%08h,%b,%0d,0x%08h,%b,%0d,0x%08h,0x%08h,%b,%b,0x%08h,%b,%b,%0d,%0d,%b,%b,%b,%b,%b,%b,%b,0x%08h,%b,%b,0x%08h,%0d,%b,%b,%b,%b,%b,%b,%b,%b,%b,0x%08h,%b,%b,%b,%0d,%b,0x%08h,0x%08h,%b,0x%08h,%b,0x%08h,%b,%b,%b,0x%08h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%b,0x%08h,%b,%b,%b,0x%08h,%b,%b",
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
                probe_icache_kill_s1,
                probe_icache_kill_s2,
                probe_branch_valid,
                probe_branch_predict,
                probe_resolve_branch,
                probe_resolved_pc,
                probe_resolved_taken,
                probe_resolved_mispredict,
                probe_resolved_target,
                probe_resolved_cf,
                probe_flush_bp,
                probe_flush_if,
                probe_flush_unissued,
                probe_flush_id,
                probe_flush_ex,
                probe_halt_frontend,
                probe_pipeline_flush,
                probe_bht_update_valid,
                probe_bht_update_taken,
                probe_bht_update_pc,
                probe_bht_pred_valid,
                probe_bht_pred_taken,
                bht_loop_valid(),
                bht_loop_counter(),
                probe_btb_update_valid,
                probe_btb_update_pc,
                probe_btb_update_target,
                probe_btb_pred_valid,
                probe_btb_pred_target,
                btb_l6_valid(),
                btb_l6_target(),
                probe_ras_push,
                probe_ras_pop,
                probe_ras_predict_valid,
                probe_ras_predict_addr,
                mispredict_count,
                flush_if_count,
                flush_bp_count,
                bht_update_count,
                ras_push_count,
                ras_pop_count,
                icache_kill_s2_count,
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
    $display("[TB_INFO] CVA6 Suite 1: Branch Prediction & Control Hazards");
    $display("[TB_INFO] BHT training, JAL/JALR, BTB, RAS, misprediction");
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

    check_reg(1,  32'h8000_0094); // call link (JAL x1, FUNC at 0x90)
    check_reg(2,  32'd20);
    check_reg(3,  32'd0);
    check_reg(4,  32'd0);
    check_reg(5,  32'd30);
    check_reg(6,  32'd10);
    check_reg(7,  32'd20);
    check_reg(8,  32'd30);
    check_reg(9,  32'd10);
    check_reg(10, 32'd80);
    check_reg(11, 32'd1);
    check_reg(12, 32'd2);
    check_reg(13, 32'd0);
    check_reg(14, 32'd12);
    check_reg(15, 32'h8000_0054); // JAL link at 0x50
    check_reg(16, 32'd3);
    check_reg(17, 32'h8000_006C); // JALR target L5
    check_reg(18, 32'h8000_0084); // last JALR link (BTB loop)
    check_reg(19, 32'd4);
    check_reg(20, 32'd5);
    check_reg(21, 32'd7);
    check_reg(22, 32'd0);         // BTB loop count
    check_reg(23, 32'd2);         // BTB loop iterations
    check_reg(24, 32'h8000_0084); // L7 address

    check_cond(spy_end_hit, "END self-loop committed");
    check_cond(mispredict_count > 0, "at least one branch misprediction observed");
    check_cond(flush_if_count == mispredict_count,
               "flush_if count equals mispredict count");
    check_cond(flush_unissued_count == mispredict_count,
               "flush_unissued count equals mispredict count");
    check_cond(flush_bp_count == 0,
               "flush_bp never asserted for branch mispredictions");
    check_cond(flush_id_count == 0,
               "flush_id never asserted (no exceptions/CSR/ERET)");
    check_cond(flush_ex_count == 0,
               "flush_ex never asserted (no exceptions/CSR/ERET)");
    check_cond(bht_update_count >= 8,
               "BHT updated for resolved branches");
    check_cond(ras_push_count == 1, "RAS pushed exactly once on call");
    check_cond(ras_pop_count == 1, "RAS popped exactly once on return");
    check_cond(btb_update_count >= 1, "BTB updated on JALR misprediction");
    check_cond(bht_loop_valid() && bht_loop_counter() == 2'b10,
               "loop BHT counter trained to weakly-taken (2'b10)");

    $display("------------------------------------------------------------");
    $display("[METRICS] Committed instructions : %0d", instret_count);
    $display("[METRICS] First commit cycle     : %0d", first_commit_cycle);
    $display("[METRICS] End commit cycle       : %0d", end_commit_cycle);
    $display("[METRICS] Mispredictions         : %0d", mispredict_count);
    $display("[METRICS] Flush IF / Unissued    : %0d / %0d", flush_if_count, flush_unissued_count);
    $display("[METRICS] Flush BP / ID / EX     : %0d / %0d / %0d", flush_bp_count, flush_id_count, flush_ex_count);
    $display("[METRICS] BHT updates            : %0d", bht_update_count);
    $display("[METRICS] BTB updates            : %0d", btb_update_count);
    $display("[METRICS] RAS push / pop         : %0d / %0d", ras_push_count, ras_pop_count);
    $display("[METRICS] IcacheKillS2 events    : %0d", icache_kill_s2_count);
    if (mispredict_latency_n > 0)
      $display("[METRICS] Avg mispredict->target commit latency: %0.2f cycles",
               real'(mispredict_latency_sum) / real'(mispredict_latency_n));
    else
      $display("[METRICS] Avg mispredict->target commit latency: n/a");
    if (end_commit_cycle > first_commit_cycle && instret_count > 0)
      $display("[METRICS] Active CPI (control-flow workload): %0.2f",
               real'(end_commit_cycle - first_commit_cycle + 1) / real'(instret_count));
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 1:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_count);
    $display("============================================================");

    logging_en = 1'b0;

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-1 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-1 ENCOUNTERED %0d ERROR(S)", error_count);
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
