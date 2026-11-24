// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 22:45:00 +03:30
// Status: NEW FILE
// Reason / Modification: Comprehensive cycle-accurate SystemVerilog testbench for
//   Suite 12 (Atomic Memory Operations: LR.W, SC.W reservation sets, broken
//   reservations, AMOSWAP.W, AMOADD.W, AMOXOR.W, AMOAND.W, AMOOR.W) with
//   AXI atomic responder and cycle-accurate CSV trace logging.
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_atomic_ops;

  import ariane_pkg::*;
  import cva6_types_pkg::*;

  // ----------------------------------------------------------------------------
  // Clock and Reset Signals
  // ----------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // 100 MHz clock (10 ns period)
  end

  // ----------------------------------------------------------------------------
  // CVA6 Top-Level Interfaces
  // ----------------------------------------------------------------------------
  logic [31:0] boot_addr;
  logic [31:0] hart_id;
  logic [1:0]  irq;
  logic        ipi;
  logic        time_irq;
  logic        debug_req;

  // CVXIF Coprocessor Interface (tied off)
  cvxif_req_t  cvxif_req;
  cvxif_resp_t cvxif_resp;
  assign cvxif_resp = '0;

  // AXI NoC Request/Response
  noc_req_t  noc_req;
  noc_resp_t noc_resp;

  // ----------------------------------------------------------------------------
  // Memory Array (Instructions and Data Buffer)
  // ----------------------------------------------------------------------------
  localparam int MEM_WORDS = 1024;
  logic [31:0] mem [0:MEM_WORDS-1];

  initial begin
    for (int i = 0; i < MEM_WORDS; i++) mem[i] = 32'h00000013; // nop (addi x0, x0, 0)

    // Preloaded instructions from atomic_ops_test.elf
    mem[ 0] = 32'h80000137; // 0x80000000: lui	sp,0x80000
    mem[ 1] = 32'h20010113; // 0x80000004: addi	sp,sp,512
    mem[ 2] = 32'h80000437; // 0x80000008: lui	s0,0x80000
    mem[ 3] = 32'h40040413; // 0x8000000c: addi	s0,s0,1024 (s0 = 0x80000400)
    mem[ 4] = 32'h12345337; // 0x80000010: lui	t1,0x12345
    mem[ 5] = 32'h67830313; // 0x80000014: addi	t1,t1,1656 (0x12345678)
    mem[ 6] = 32'h00642023; // 0x80000018: sw	t1,0(s0)
    mem[ 7] = 32'hdeadc3b7; // 0x8000001c: lui	t2,0xdeadc
    mem[ 8] = 32'heef38393; // 0x80000020: addi	t2,t2,-273 (0xDEADBEEF)
    mem[ 9] = 32'h1874252f; // 0x80000024: sc.w	a0,t2,(s0)
    mem[10] = 32'h00042583; // 0x80000028: lw	a1,0(s0)
    mem[11] = 32'h1004262f; // 0x8000002c: lr.w	a2,(s0)
    mem[12] = 32'hcafece37; // 0x80000030: lui	t3,0xcafec
    mem[13] = 32'habee0e13; // 0x80000034: addi	t3,t3,-1346 (0xCAFEBABE)
    mem[14] = 32'h19c426af; // 0x80000038: sc.w	a3,t3,(s0)
    mem[15] = 32'h00042703; // 0x8000003c: lw	a4,0(s0)
    mem[16] = 32'h100427af; // 0x80000040: lr.w	a5,(s0)
    mem[17] = 32'h55555eb7; // 0x80000044: lui	t4,0x55555
    mem[18] = 32'h555e8e93; // 0x80000048: addi	t4,t4,1365 (0x55555555)
    mem[19] = 32'h01d42023; // 0x8000004c: sw	t4,0(s0)
    mem[20] = 32'h9999af37; // 0x80000050: lui	t5,0x9999a
    mem[21] = 32'h999f0f13; // 0x80000054: addi	t5,t5,-1639 (0x99999999)
    mem[22] = 32'h19e4282f; // 0x80000058: sc.w	a6,t5,(s0)
    mem[23] = 32'h00042883; // 0x8000005c: lw	a7,0(s0)
    mem[24] = 32'h00440493; // 0x80000060: addi	s1,s0,4
    mem[25] = 32'h01d4a023; // 0x80000064: sw	t4,0(s1)
    mem[26] = 32'h11223937; // 0x80000068: lui	s2,0x11223
    mem[27] = 32'h34490913; // 0x8000006c: addi	s2,s2,836 (0x11223344)
    mem[28] = 32'h0924a9af; // 0x80000070: amoswap.w s3,s2,(s1)
    mem[29] = 32'h0004aa03; // 0x80000074: lw	s4,0(s1)
    mem[30] = 32'h00840493; // 0x80000078: addi	s1,s0,8
    mem[31] = 32'h00a00a93; // 0x8000007c: li	s5,10
    mem[32] = 32'h0154a023; // 0x80000080: sw	s5,0(s1)
    mem[33] = 32'h01900b13; // 0x80000084: li	s6,25
    mem[34] = 32'h0164abaf; // 0x80000088: amoadd.w s7,s6,(s1)
    mem[35] = 32'h0004ac03; // 0x8000008c: lw	s8,0(s1)
    mem[36] = 32'h00c40493; // 0x80000090: addi	s1,s0,12
    mem[37] = 32'h00ff0cb7; // 0x80000094: lui	s9,0xff0
    mem[38] = 32'h0ffc8c93; // 0x80000098: addi	s9,s9,255 (0x00FF00FF)
    mem[39] = 32'h0194a023; // 0x8000009c: sw	s9,0(s1)
    mem[40] = 32'h0f0f1d37; // 0x800000a0: lui	s10,0xf0f1
    mem[41] = 32'hf0fd0d13; // 0x800000a4: addi	s10,s10,-241 (0x0F0F0F0F)
    mem[42] = 32'h21a4adaf; // 0x800000a8: amoxor.w s11,s10,(s1)
    mem[43] = 32'h0004af03; // 0x800000ac: lw	t5,0(s1)
    mem[44] = 32'h01040493; // 0x800000b0: addi	s1,s0,16
    mem[45] = 32'haaaabfb7; // 0x800000b4: lui	t6,0xaaaab
    mem[46] = 32'haaaf8f93; // 0x800000b8: addi	t6,t6,-1366 (0xAAAAAAAA)
    mem[47] = 32'h01f4a023; // 0x800000bc: sw	t6,0(s1)
    mem[48] = 32'h555551b7; // 0x800000c0: lui	gp,0x55555
    mem[49] = 32'h55518193; // 0x800000c4: addi	gp,gp,1365 (0x55555555)
    mem[50] = 32'h4034a22f; // 0x800000c8: amoor.w	tp,gp,(s1)
    mem[51] = 32'h0004a303; // 0x800000cc: lw	t1,0(s1)
    mem[52] = 32'h000103b7; // 0x800000d0: lui	t2,0x10
    mem[53] = 32'hfff38393; // 0x800000d4: addi	t2,t2,-1 (0x0000FFFF)
    mem[54] = 32'h6074ae2f; // 0x800000d8: amoand.w t3,t2,(s1)
    mem[55] = 32'h0004ae83; // 0x800000dc: lw	t4,0(s1)
    mem[56] = 32'h3e700093; // 0x800000e0: li	ra,999
    mem[57] = 32'h0000006f; // 0x800000e4: j	800000e4 <end_loop>
  end

  // ----------------------------------------------------------------------------
  // Instantiate CVA6 Processor Core
  // ----------------------------------------------------------------------------
  cva6 u_dut (
    .clk_i         (clk),
    .rst_ni        (rst_n),
    .boot_addr_i   (boot_addr),
    .hart_id_i     (hart_id),
    .irq_i         (irq),
    .ipi_i         (ipi),
    .time_irq_i    (time_irq),
    .debug_req_i   (debug_req),
    .rvfi_probes_o (),
    .cvxif_req_o   (cvxif_req),
    .cvxif_resp_i  (cvxif_resp),
    .noc_req_o     (noc_req),
    .noc_resp_i    (noc_resp)
  );

  // ----------------------------------------------------------------------------
  // Internal Pipeline Probes
  // ----------------------------------------------------------------------------
  wire        probe_commit_ack0         = u_dut.commit_ack[0];
  wire        probe_commit_ack1         = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.commit_ack[1] : 1'b0;
  wire        probe_dual_commit         = probe_commit_ack0 && probe_commit_ack1;
  wire [31:0] probe_commit_pc0          = probe_commit_ack0 ? u_dut.commit_instr_id_commit[0].pc[31:0] : 32'h0;
  wire [31:0] probe_commit_pc1          = probe_commit_ack1 ? u_dut.commit_instr_id_commit[1].pc[31:0] : 32'h0;

  wire        probe_gpr_we0             = u_dut.we_gpr_commit_id[0];
  wire [4:0]  probe_gpr_waddr0          = u_dut.waddr_commit_id[0];
  wire [31:0] probe_gpr_wdata0          = u_dut.wdata_commit_id[0][31:0];

  wire        probe_gpr_we1             = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.we_gpr_commit_id[1] : 1'b0;
  wire [4:0]  probe_gpr_waddr1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.waddr_commit_id[1] : 5'd0;
  wire [31:0] probe_gpr_wdata1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.wdata_commit_id[1][31:0] : 32'd0;

  // Pipeline flush probe
  wire        probe_flush               = u_dut.commit_stage_i.flush_commit_o;

  // ----------------------------------------------------------------------------
  // Shadow Architectural Register File (GPR x0 to x31)
  // ----------------------------------------------------------------------------
  logic [31:0] shadow_gpr [0:31];
  integer r;

  initial begin
    for (r = 0; r < 32; r++) shadow_gpr[r] = 32'h0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) shadow_gpr[i] <= 32'h0;
    end else begin
      // Commit Port 0 writeback
      if (probe_commit_ack0 && probe_gpr_we0 && (probe_gpr_waddr0 != 5'd0)) begin
        shadow_gpr[probe_gpr_waddr0] <= probe_gpr_wdata0;
      end
      // Commit Port 1 writeback
      if (probe_commit_ack1 && probe_gpr_we1 && (probe_gpr_waddr1 != 5'd0)) begin
        shadow_gpr[probe_gpr_waddr1] <= probe_gpr_wdata1;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // AXI Reservation and Atomic Tracking State
  // ----------------------------------------------------------------------------
  logic        reservation_valid;
  logic [63:0] reservation_addr;

  // Atomic event counters
  int unsigned lr_count;
  int unsigned sc_success_count;
  int unsigned sc_fail_count;
  int unsigned amo_count;

  // ----------------------------------------------------------------------------
  // AXI Atomic and Memory Responder
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AR_IDLE,
    R_BURST,
    R_ATOMIC
  } r_state_t;
  r_state_t r_state;

  typedef enum logic [1:0] {
    AW_IDLE,
    W_BURST,
    B_RESP
  } w_state_t;
  w_state_t w_state;

  logic [CVA6Cfg.AxiIdWidth-1:0]   ar_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] ar_addr_q;
  axi_pkg::len_t                   ar_len_q;
  logic [7:0]                      ar_cnt_q;

  logic [CVA6Cfg.AxiIdWidth-1:0]   aw_id_q;
  logic [CVA6Cfg.AxiAddrWidth-1:0] aw_addr_q;
  logic [7:0]                      aw_cnt_q;
  axi_pkg::resp_t                  b_resp_q;

  // Atomic read response holding buffer
  logic                            atomic_r_pending;
  logic [CVA6Cfg.AxiIdWidth-1:0]   atomic_r_id;
  logic [63:0]                     atomic_r_data;

  // Read Channel FSM
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
      reservation_valid <= 1'b0;
      reservation_addr  <= '0;
      lr_count          <= 0;
    end else begin
      case (r_state)
        AR_IDLE: begin
          noc_resp.ar_ready <= !atomic_r_pending;
          noc_resp.r_valid  <= 1'b0;

          // Priority 1: Service pending atomic read response
          if (atomic_r_pending) begin
            noc_resp.ar_ready <= 1'b0;
            noc_resp.r_valid  <= 1'b1;
            noc_resp.r.id     <= atomic_r_id;
            noc_resp.r.data   <= atomic_r_data;
            noc_resp.r.last   <= 1'b1;
            noc_resp.r.resp   <= axi_pkg::RESP_OKAY;
            noc_resp.r.user   <= '0;
            r_state           <= R_ATOMIC;
          end
          // Priority 2: Service normal AR request
          else if (noc_req.ar_valid && noc_resp.ar_ready) begin
            ar_id_q           <= noc_req.ar.id;
            ar_addr_q         <= noc_req.ar.addr;
            ar_len_q          <= noc_req.ar.len;
            ar_cnt_q          <= 8'd0;
            noc_resp.ar_ready <= 1'b0;

            // Exclusive load (LR.W): record reservation
            if (noc_req.ar.lock) begin
              reservation_valid <= 1'b1;
              reservation_addr  <= noc_req.ar.addr;
              lr_count          <= lr_count + 1;
            end

            r_state           <= R_BURST;
          end
        end

        R_ATOMIC: begin
          if (noc_req.r_ready && noc_resp.r_valid) begin
            noc_resp.r_valid  <= 1'b0;
            noc_resp.ar_ready <= 1'b1;
            r_state           <= AR_IDLE;
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
            automatic int unsigned base_word = (cur_addr[11:3] << 1);
            automatic logic [31:0] d0 = (base_word < MEM_WORDS) ? mem[base_word] : 32'h00000013;
            automatic logic [31:0] d1 = (base_word + 1 < MEM_WORDS) ? mem[base_word + 1] : 32'h00000013;
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

  // Write Channel FSM with ATOP and Exclusive SC Support
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_state          <= AW_IDLE;
      noc_resp.aw_ready<= 1'b0;
      noc_resp.w_ready <= 1'b0;
      noc_resp.b_valid <= 1'b0;
      noc_resp.b.id    <= '0;
      noc_resp.b.resp  <= axi_pkg::RESP_OKAY;
      noc_resp.b.user  <= '0;
      aw_id_q          <= '0;
      aw_addr_q        <= '0;
      aw_cnt_q         <= '0;
      b_resp_q         <= axi_pkg::RESP_OKAY;
      atomic_r_pending <= 1'b0;
      atomic_r_id      <= '0;
      atomic_r_data    <= '0;
      sc_success_count <= 0;
      sc_fail_count    <= 0;
      amo_count        <= 0;
    end else begin
      // Clear atomic_r_pending once R_ATOMIC acknowledges transfer
      if ((r_state == R_ATOMIC) && noc_req.r_ready && noc_resp.r_valid) begin
        atomic_r_pending <= 1'b0;
      end

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
              automatic int unsigned base_word = (cur_addr[11:3] << 1);
              automatic logic [31:0] old_val  = cur_addr[2] ? mem[base_word + 1] : mem[base_word];
              automatic logic [31:0] op_val   = cur_addr[2] ? noc_req.w.data[63:32] : noc_req.w.data[31:0];
              automatic axi_pkg::resp_t cur_b_resp = axi_pkg::RESP_OKAY;

              // Case A: Exclusive Store (SC.W)
              if (noc_req.aw.lock) begin
                if (reservation_valid && (reservation_addr[11:2] == cur_addr[11:2])) begin
                  // Successful SC: update memory, return EXOKAY (0), clear reservation
                  for (int b = 0; b < 4; b++) begin
                    if (noc_req.w.strb[b]) mem[base_word][b*8 +: 8] <= noc_req.w.data[b*8 +: 8];
                  end
                  for (int b = 4; b < 8; b++) begin
                    if (noc_req.w.strb[b]) mem[base_word + 1][(b-4)*8 +: 8] <= noc_req.w.data[b*8 +: 8];
                  end
                  cur_b_resp        = axi_pkg::RESP_EXOKAY;
                  reservation_valid <= 1'b0;
                  sc_success_count  <= sc_success_count + 1;
                end else begin
                  // Failed SC: memory untouched, return OKAY (1 in CVA6)
                  cur_b_resp        = axi_pkg::RESP_OKAY;
                  sc_fail_count     <= sc_fail_count + 1;
                end
              end
              // Case B: Atomic Operation with ATOP (AMOSWAP, AMOADD, AMOXOR, AMOAND, AMOOR)
              else if (noc_req.aw.atop != '0) begin
                automatic logic [31:0] new_val;
                amo_count <= amo_count + 1;

                case (noc_req.aw.atop)
                  axi_pkg::ATOP_ATOMICSWAP: begin
                    new_val = op_val;
                  end
                  {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_ADD}: begin
                    new_val = old_val + op_val;
                  end
                  {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_EOR}: begin
                    new_val = old_val ^ op_val;
                  end
                  {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_SET}: begin
                    new_val = old_val | op_val;
                  end
                  {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_CLR}: begin
                    // In wt_axi_adapter, data is inverted, so CLR acts as AND
                    new_val = old_val & ~op_val;
                  end
                  default: new_val = op_val;
                endcase

                // Update memory
                if (cur_addr[2]) mem[base_word + 1] <= new_val;
                else             mem[base_word]     <= new_val;

                // Queue read response beat returning old memory value
                atomic_r_pending <= 1'b1;
                atomic_r_id      <= noc_req.aw.id;
                atomic_r_data    <= {old_val, old_val};

                cur_b_resp = axi_pkg::RESP_OKAY;
              end
              // Case C: Standard Store (SW)
              else begin
                for (int b = 0; b < 4; b++) begin
                  if (noc_req.w.strb[b]) mem[base_word][b*8 +: 8] <= noc_req.w.data[b*8 +: 8];
                end
                for (int b = 4; b < 8; b++) begin
                  if (noc_req.w.strb[b]) mem[base_word + 1][(b-4)*8 +: 8] <= noc_req.w.data[b*8 +: 8];
                end

                // Invalidate reservation if normal store writes to reservation address
                if (reservation_valid && (reservation_addr[11:2] == cur_addr[11:2])) begin
                  reservation_valid <= 1'b0;
                end

                cur_b_resp = axi_pkg::RESP_OKAY;
              end

              b_resp_q <= cur_b_resp;

              if (noc_req.w.last) begin
                noc_resp.w_ready <= 1'b0;
                noc_resp.b_valid <= 1'b1;
                noc_resp.b.id    <= noc_req.aw.id;
                noc_resp.b.resp  <= cur_b_resp;
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
            automatic int unsigned base_word = (cur_addr[11:3] << 1);

            for (int b = 0; b < 4; b++) begin
              if (noc_req.w.strb[b]) mem[base_word][b*8 +: 8] <= noc_req.w.data[b*8 +: 8];
            end
            for (int b = 4; b < 8; b++) begin
              if (noc_req.w.strb[b]) mem[base_word + 1][(b-4)*8 +: 8] <= noc_req.w.data[b*8 +: 8];
            end

            if (noc_req.w.last) begin
              noc_resp.w_ready <= 1'b0;
              noc_resp.b_valid <= 1'b1;
              noc_resp.b.id    <= aw_id_q;
              noc_resp.b.resp  <= b_resp_q;
              noc_resp.b.user  <= '0;
              w_state          <= B_RESP;
            end else begin
              aw_cnt_q <= aw_cnt_q + 8'd1;
            end
          end
        end

        B_RESP: begin
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
  // Cycle Counter and Instruction Retirement Metrics
  // ----------------------------------------------------------------------------
  int unsigned cycle_cnt;
  int unsigned instret_cnt;
  int unsigned dual_commit_total;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt          <= 0;
      instret_cnt        <= 0;
      dual_commit_total  <= 0;
    end else begin
      cycle_cnt <= cycle_cnt + 1;
      if (probe_commit_ack0 && probe_commit_ack1) begin
        instret_cnt       <= instret_cnt + 2;
        dual_commit_total <= dual_commit_total + 1;
      end else if (probe_commit_ack0 || probe_commit_ack1) begin
        instret_cnt       <= instret_cnt + 1;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // Cycle-by-Cycle CSV Trace Logger
  // ----------------------------------------------------------------------------
  integer csv_fd;

  initial begin
    csv_fd = $fopen("cva6_atomic_ops_trace.csv", "w");
    if (csv_fd) begin
      $fdisplay(csv_fd, "Cycle,CommitAck0,CommitPC0,CommitRd0,CommitWe0,CommitWdata0,CommitAck1,CommitPC1,CommitRd1,CommitWe1,CommitWdata1,FlushCommit,ARValid,ARAddr,ARLock,AWValid,AWAddr,AWLock,AWAtop,WValid,WData,BValid,BResp,RValid,RLast,RData,ReservationValid,ReservationAddr,SCSuccess,SCFail,AMOCnt,GPR_sp,GPR_s0,GPR_a0,GPR_a1,GPR_a2,GPR_a3,GPR_a4,GPR_a5,GPR_a6,GPR_a7,GPR_s2,GPR_s3,GPR_s4,GPR_s7,GPR_s8,GPR_s11,GPR_t5,GPR_tp,GPR_t1,GPR_t3,GPR_t4,GPR_ra");
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n && csv_fd) begin
      $fdisplay(csv_fd, "%0d,%b,0x%08x,%0d,%b,0x%08x,%b,0x%08x,%0d,%b,0x%08x,%b,%b,0x%08x,%b,%b,0x%08x,%b,0x%02x,%b,0x%016x,%b,0x%01x,%b,%b,0x%016x,%b,0x%08x,%0d,%0d,%0d,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x",
        cycle_cnt,
        probe_commit_ack0, probe_commit_pc0, probe_gpr_waddr0, probe_gpr_we0, probe_gpr_wdata0,
        probe_commit_ack1, probe_commit_pc1, probe_gpr_waddr1, probe_gpr_we1, probe_gpr_wdata1,
        probe_flush,
        noc_req.ar_valid, noc_req.ar.addr, noc_req.ar.lock,
        noc_req.aw_valid, noc_req.aw.addr, noc_req.aw.lock, noc_req.aw.atop,
        noc_req.w_valid, noc_req.w.data,
        noc_resp.b_valid, noc_resp.b.resp,
        noc_resp.r_valid, noc_resp.r.last, noc_resp.r.data,
        reservation_valid, reservation_addr[31:0],
        sc_success_count, sc_fail_count, amo_count,
        shadow_gpr[2],  // sp
        shadow_gpr[8],  // s0
        shadow_gpr[10], // a0
        shadow_gpr[11], // a1
        shadow_gpr[12], // a2
        shadow_gpr[13], // a3
        shadow_gpr[14], // a4
        shadow_gpr[15], // a5
        shadow_gpr[16], // a6
        shadow_gpr[17], // a7
        shadow_gpr[18], // s2
        shadow_gpr[19], // s3
        shadow_gpr[20], // s4
        shadow_gpr[23], // s7
        shadow_gpr[24], // s8
        shadow_gpr[27], // s11
        shadow_gpr[30], // t5
        shadow_gpr[4],  // tp
        shadow_gpr[6],  // t1
        shadow_gpr[28], // t3
        shadow_gpr[29], // t4
        shadow_gpr[1]   // ra
      );
    end
  end

  // ----------------------------------------------------------------------------
  // Self-Checking Scoreboard Assertions
  // ----------------------------------------------------------------------------
  int unsigned check_count = 0;
  int unsigned error_count = 0;

  task automatic check_reg(input int reg_idx, input logic [31:0] expected_val, input string tag);
    check_count++;
    if (shadow_gpr[reg_idx] === expected_val) begin
      $display("[PASS] Check %0d: %s | shadow_gpr[%0d] = 0x%08x (Expected: 0x%08x)",
               check_count, tag, reg_idx, shadow_gpr[reg_idx], expected_val);
    end else begin
      error_count++;
      $display("[FAIL] Check %0d: %s | shadow_gpr[%0d] = 0x%08x (Expected: 0x%08x)",
               check_count, tag, reg_idx, shadow_gpr[reg_idx], expected_val);
    end
  endtask

  task automatic check_val(input int actual_val, input int expected_val, input string tag);
    check_count++;
    if (actual_val === expected_val) begin
      $display("[PASS] Check %0d: %s | actual = %0d (Expected: %0d)",
               check_count, tag, actual_val, expected_val);
    end else begin
      error_count++;
      $display("[FAIL] Check %0d: %s | actual = %0d (Expected: %0d)",
               check_count, tag, actual_val, expected_val);
    end
  endtask

  initial begin
    $display("============================================================");
    $display("Starting CVA6 Suite 12: Atomic Memory Operations (RV32A)");
    $display("============================================================");

    // Initialize inputs
    rst_n     = 1'b0;
    boot_addr = 32'h8000_0000;
    hart_id   = 32'h0;
    irq       = 2'b0;
    ipi       = 1'b0;
    time_irq  = 1'b0;
    debug_req = 1'b0;

    // Reset sequence
    #50;
    @(posedge clk);
    rst_n = 1'b1;
    $display("[%0t] [RESET_DEASSERTED] Core released from reset.", $time);

    // Run until terminal self-loop is reached
    fork
      begin
        wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_00e4));
        $display("[%0t] [TB_END] END self-loop reached at cycle %0d.", $time, cycle_cnt);
        repeat (30) @(posedge clk);
      end
      begin
        #40000; // 40 us watchdog timeout
        $display("[TIMEOUT] Testbench timed out at cycle %0d!", cycle_cnt);
        error_count++;
      end
    join_any

    if (csv_fd) $fclose(csv_fd);
    $display("[TB_INFO] Trace dumped to cva6_atomic_ops_trace.csv");

    // --------------------------------------------------------------------------
    // Architectural Register File Assertions
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural Register File & Atomics Checks");
    $display("============================================================");

    // Phase 0: Setup
    check_reg(2,  32'h8000_0200, "sp: base stack pointer");
    check_reg(8,  32'h8000_0400, "s0: memory test buffer base");

    // Phase 1: SC without prior LR
    check_reg(10, 32'd1,         "a0: SC.W without LR.W -> failure code 1");
    check_reg(11, 32'h1234_5678, "a1: memory readback untouched after failed SC");

    // Phase 2: LR followed by SC (Success)
    check_reg(12, 32'h1234_5678, "a2: LR.W loaded original value 0x12345678");
    check_reg(13, 32'd0,         "a3: SC.W with valid reservation -> success code 0");
    check_reg(14, 32'hcafe_babe, "a4: memory readback updated to 0xCAFEBABE");

    // Phase 3: LR, intervening SW, then SC (Broken Reservation)
    check_reg(15, 32'hcafe_babe, "a5: LR.W loaded 0xCAFEBABE");
    check_reg(16, 32'd1,         "a6: SC.W with broken reservation -> failure code 1");
    check_reg(17, 32'h5555_5555, "a7: memory retained intervening store value 0x55555555");

    // Phase 4: AMOSWAP.W
    check_reg(19, 32'h5555_5555, "s3: AMOSWAP.W returned old value 0x55555555");
    check_reg(20, 32'h1122_3344, "s4: memory readback contains swapped value 0x11223344");

    // Phase 5: AMOADD.W
    check_reg(23, 32'd10,        "s7: AMOADD.W returned old value 10");
    check_reg(24, 32'd35,        "s8: memory readback contains sum 35 (10 + 25)");

    // Phase 6: AMOXOR.W
    check_reg(27, 32'h00ff_00ff, "s11: AMOXOR.W returned old value 0x00FF00FF");
    check_reg(30, 32'h0ff0_0ff0, "t5: memory readback contains XOR result 0x0FF00FF0");

    // Phase 7: AMOOR.W and AMOAND.W
    check_reg(4,  32'haaaa_aaaa, "tp: AMOOR.W returned old value 0xAAAAAAAA");
    check_reg(6,  32'hffff_ffff, "t1: memory readback contains OR result 0xFFFFFFFF");
    check_reg(28, 32'hffff_ffff, "t3: AMOAND.W returned old value 0xFFFFFFFF");
    check_reg(29, 32'h0000_ffff, "t4: memory readback contains AND result 0x0000FFFF");

    // Phase 8: Completion Marker
    check_reg(1,  32'd999,       "ra: completion marker 999");

    // Hardware Event Assertions
    check_val(sc_success_count, 1, "Total Successful SC.W Operations");
    check_val(sc_fail_count,    2, "Total Failed SC.W Operations (Unreserved + Broken)");
    check_val(lr_count,         2, "Total LR.W Reservation Operations");
    check_val(amo_count,        5, "Total Atomic Arithmetic/Logic Operations (SWAP, ADD, XOR, OR, AND)");

    $display("------------------------------------------------------------");
    $display("[METRICS] Total Cycles Run       : %0d", cycle_cnt);
    $display("[METRICS] Total Instructions     : %0d", instret_cnt);
    $display("[METRICS] Total Dual-Commits     : %0d", dual_commit_total);
    $display("[METRICS] SC Success Count       : %0d", sc_success_count);
    $display("[METRICS] SC Failure Count       : %0d", sc_fail_count);
    $display("[METRICS] LR Count               : %0d", lr_count);
    $display("[METRICS] AMO Operations Count   : %0d", amo_count);
    if (instret_cnt > 0) begin
      $display("[METRICS] Overall Benchmark CPI  : %0.2f", real'(cycle_cnt) / real'(instret_cnt));
    end
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 12:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_cnt);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-12 CHECKS PASSED");
    end else begin
      $display("[FAIL] %0d CHECKS FAILED IN SUITE-12", error_count);
    end

    $finish;
  end

endmodule
