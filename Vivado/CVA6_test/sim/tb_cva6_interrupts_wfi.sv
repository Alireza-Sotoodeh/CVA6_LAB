// ============================================================================
// Author: Alireza Sotodeh
// Date & Time: 2026-11-19 22:10:00 +03:30
// Status: NEW FILE
// Reason / Modification: Dedicated SystemVerilog verification testbench for
//                        Suite 8 (Asynchronous Interrupts: Timer MTIP,
//                        Platform External MEIP, mstatus.MIE priority masking,
//                        WFI low-power sleep/wakeup, and MRET return resumption).
// ============================================================================

`timescale 1ns / 1ps

module tb_cva6_interrupts_wfi;

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
    // Suite 8 Benchmark Program (.text loaded from 0x8000_0000)
    // --------------------------------------------------------------------------
    mem[  0] = 32'h80000137; // 0x80000000: lui   sp, 0x80000
    mem[  1] = 32'h20010113; // 0x80000004: addi  sp, sp, 512
    mem[  2] = 32'h00000297; // 0x80000008: auipc t0, 0
    mem[  3] = 32'h04828293; // 0x8000000c: addi  t0, t0, 72 (t0 = 0x80000050)
    mem[  4] = 32'h30529073; // 0x80000010: csrw  mtvec, t0
    mem[  5] = 32'h000012b7; // 0x80000014: lui   t0, 0x1
    mem[  6] = 32'h88028293; // 0x80000018: addi  t0, t0, -1920 (0x880: MTIE | MEIE)
    mem[  7] = 32'h30429073; // 0x8000001c: csrw  mie, t0
    mem[  8] = 32'h30047073; // 0x80000020: csrci mstatus, 8 (MIE = 0: masked)
    mem[  9] = 32'h01100513; // 0x80000024: li    a0, 17 (0x11: Masked marker)
    mem[ 10] = 32'h00100093; // 0x80000028: li    ra, 1
    mem[ 11] = 32'h00108093; // 0x8000002c: addi  ra, ra, 1
    mem[ 12] = 32'h30046073; // 0x80000030: csrsi mstatus, 8 (MIE = 1: unmask -> Trap!)
    mem[ 13] = 32'h02200613; // 0x80000034: li    a2, 34 (0x22: Resumed from Timer ISR)
    mem[ 14] = 32'h03300693; // 0x80000038: li    a3, 51 (0x33: Pre-WFI marker)
    mem[ 15] = 32'h10500073; // 0x8000003c: wfi   (sleep until external interrupt)
    mem[ 16] = 32'h04400793; // 0x80000040: li    a5, 68 (0x44: Post-WFI marker)
    mem[ 17] = 32'h3e700d13; // 0x80000044: li    s10, 999
    mem[ 18] = 32'h0000006f; // 0x80000048: j     end_loop
    mem[ 19] = 32'h00000013; // 0x8000004c: nop

    // 0x80000050: isr_trap_handler
    mem[ 20] = 32'h34202373; // 0x80000050: csrr  t1, mcause
    mem[ 21] = 32'h800003b7; // 0x80000054: lui   t2, 0x80000
    mem[ 22] = 32'h00738393; // 0x80000058: addi  t2, t2, 7 (0x80000007)
    mem[ 23] = 32'h00730c63; // 0x8000005c: beq   t1, t2, handle_timer_irq (0x80000074)
    mem[ 24] = 32'h800003b7; // 0x80000060: lui   t2, 0x80000
    mem[ 25] = 32'h00b38393; // 0x80000064: addi  t2, t2, 11 (0x8000000b)
    mem[ 26] = 32'h00730e63; // 0x80000068: beq   t1, t2, handle_ext_irq (0x80000084)
    mem[ 27] = 32'h00100d93; // 0x8000006c: li    s11, 1
    mem[ 28] = 32'h30200073; // 0x80000070: mret

    // 0x80000074: handle_timer_irq
    mem[ 29] = 32'h0aa00593; // 0x80000074: li    a1, 170 (0xAA)
    mem[ 30] = 32'h08000293; // 0x80000078: li    t0, 128 (0x80)
    mem[ 31] = 32'h3042b073; // 0x8000007c: csrc  mie, t0 (Disable MTIE)
    mem[ 32] = 32'h30200073; // 0x80000080: mret

    // 0x80000084: handle_ext_irq
    mem[ 33] = 32'h0bb00713; // 0x80000084: li    a4, 187 (0xBB)
    mem[ 34] = 32'h000012b7; // 0x80000088: lui   t0, 0x1
    mem[ 35] = 32'h80028293; // 0x8000008c: addi  t0, t0, -2048 (0x800)
    mem[ 36] = 32'h3042b073; // 0x80000090: csrc  mie, t0 (Disable MEIE)
    mem[ 37] = 32'h30200073; // 0x80000094: mret
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
  wire [31:0] probe_commit_res0         = probe_commit_ack0 ? u_dut.commit_instr_id_commit[0].result[31:0] : 32'h0;

  wire        probe_gpr_we0             = u_dut.we_gpr_commit_id[0];
  wire [4:0]  probe_gpr_waddr0          = u_dut.waddr_commit_id[0];
  wire [31:0] probe_gpr_wdata0          = u_dut.wdata_commit_id[0][31:0];

  wire        probe_gpr_we1             = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.we_gpr_commit_id[1] : 1'b0;
  wire [4:0]  probe_gpr_waddr1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.waddr_commit_id[1] : 5'd0;
  wire [31:0] probe_gpr_wdata1          = (CVA6Cfg.NrCommitPorts == 2) ? u_dut.wdata_commit_id[1][31:0] : 32'h0;

  wire [31:0] probe_fetch_pc            = u_dut.i_frontend.icache_dreq_o.vaddr[31:0];
  wire        probe_fetch_valid         = u_dut.icache_dreq_cache_if.valid;

  // CSR & Interrupt Specific Probes
  wire        probe_trap_valid          = u_dut.commit_stage_i.exception_o.valid;
  wire [31:0] probe_trap_cause          = u_dut.commit_stage_i.exception_o.cause[31:0];
  wire        probe_mret                = u_dut.csr_regfile_i.mret;
  wire        probe_wfi_q               = u_dut.csr_regfile_i.wfi_q;
  wire        probe_halt_csr            = u_dut.csr_regfile_i.halt_csr_o;
  wire        probe_mstatus_mie         = u_dut.csr_regfile_i.mstatus_q.mie;
  wire        probe_mie_mtie            = u_dut.csr_regfile_i.mie_q[7];
  wire        probe_mie_meie            = u_dut.csr_regfile_i.mie_q[11];
  wire        probe_mip_mtip            = u_dut.csr_regfile_i.mip_q[7];
  wire        probe_mip_meip            = u_dut.csr_regfile_i.mip_q[11];
  wire [31:0] probe_mepc                = u_dut.csr_regfile_i.mepc_q[31:0];
  wire [31:0] probe_mtvec               = u_dut.csr_regfile_i.mtvec_q[31:0];

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
  int unsigned trap_count = 0;
  int unsigned mret_count = 0;
  int unsigned wfi_cycles = 0;

  int csv_fd;
  initial begin
    csv_fd = $fopen("cva6_interrupt_trace.csv", "w");
    if (csv_fd) begin
      $fdisplay(csv_fd, "Time_ps,Cycle,InstRet,CommitAck0,CommitAck1,DualCommit,CommitPC0,CommitRes0,GprWe0,GprWaddr0,GprWdata0,FetchPC,FetchValid,TrapValid,TrapCause,Mret,WfiQ,HaltCsr,TimeIrq,ExtIrq,MstatusMie,MieMtie,MieMeie,MipMtip,MipMeip,Mepc,Mtvec");
    end else begin
      $display("[TB_ERROR] Failed to open cva6_interrupt_trace.csv for writing!");
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cycle_cnt <= cycle_cnt + 1;
      if (probe_commit_ack0) instret_cnt <= instret_cnt + 1;
      if (probe_commit_ack1) instret_cnt <= instret_cnt + 1;
      if (probe_dual_commit) dual_commit_total <= dual_commit_total + 1;
      if (probe_trap_valid)  trap_count <= trap_count + 1;
      if (probe_mret)        mret_count <= mret_count + 1;
      if (probe_wfi_q)       wfi_cycles <= wfi_cycles + 1;

      if (csv_fd) begin
        $fdisplay(csv_fd, "%0d,%0d,%0d,%0b,%0b,%0b,0x%08x,0x%08x,%0b,%0d,0x%08x,0x%08x,%0b,%0b,0x%08x,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,0x%08x,0x%08x",
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
          probe_fetch_pc,
          probe_fetch_valid,
          probe_trap_valid,
          probe_trap_cause,
          probe_mret,
          probe_wfi_q,
          probe_halt_csr,
          time_irq,
          irq[0],
          probe_mstatus_mie,
          probe_mie_mtie,
          probe_mie_meie,
          probe_mip_mtip,
          probe_mip_meip,
          probe_mepc,
          probe_mtvec
        );
      end
    end
  end

  // ----------------------------------------------------------------------------
  // Dynamic Stimulus Sequencer: Timer Interrupt & External Interrupt
  // ----------------------------------------------------------------------------
  initial begin
    time_irq = 1'b0;
    irq      = '0;

    // Wait for reset release
    @(posedge rst_n);

    // 1. Wait until Phase 1 starts (PC 0x80000020 has executed, interrupts masked)
    wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_0020));
    $display("[%0t] [STIM] PC 0x80000020 committed (mstatus.MIE=0). Asserting time_irq = 1", $time);
    time_irq = 1'b1;

    // 2. Wait until Core unmasks interrupts (PC 0x80000030) and takes trap to mtvec (0x80000050)
    wait (probe_trap_valid && (probe_trap_cause == 32'h8000_0007));
    $display("[%0t] [STIM] Timer Interrupt Trap acknowledged at PC 0x%08x. De-asserting time_irq", $time, probe_commit_pc0);
    repeat (2) @(posedge clk);
    time_irq = 1'b0;

    // 3. Wait until core resumes, executes WFI (PC 0x8000003c) and enters halt
    wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_003c));
    $display("[%0t] [STIM] WFI committed at cycle %0d. Pipeline entering sleep...", $time, cycle_cnt);
    repeat (15) @(posedge clk); // Allow pipeline to settle in WFI halt

    // 4. Assert External Interrupt (irq[0]) to wake up core
    $display("[%0t] [STIM] Asserting External Interrupt irq[0] = 1 to wake core from WFI", $time);
    irq[0] = 1'b1;

    // 5. Wait until core wakes and acknowledges external trap (cause 0x8000000B)
    wait (probe_trap_valid && (probe_trap_cause == 32'h8000_000b));
    $display("[%0t] [STIM] External Interrupt Trap acknowledged. De-asserting irq[0]", $time);
    repeat (2) @(posedge clk);
    irq[0] = 1'b0;
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
    $display("[TB_INFO] CVA6 Suite 8: Asynchronous Interrupts & WFI Sleep");
    $display("[TB_INFO] Timer MTIP, External MEIP, MIE Masking, WFI & MRET");
    $display("============================================================");

    rst_n = 1'b0;
    #75;
    rst_n = 1'b1;
    $display("[%0t] [TB_RESET] Reset de-asserted. Core booting at 0x%08x", $time, BOOT_ADDR);

    // Run until terminal self-loop is reached and commits (PC = 0x8000_0048)
    fork
      begin
        wait (trap_count >= 2);
        wait (mret_count >= 2);
        wait (probe_commit_ack0 && (probe_commit_pc0 == 32'h8000_0048));
        $display("[%0t] [TB_END] All traps handled, both MRETs executed, and END loop reached at cycle %0d.", $time, cycle_cnt);
        repeat (25) @(posedge clk);
      end
      begin
        #40000; // 40 us watchdog timeout
        $display("[TIMEOUT] Testbench timed out at cycle %0d!", cycle_cnt);
        error_count++;
      end
    join_any

    if (csv_fd) $fclose(csv_fd);
    $display("[TB_INFO] Trace dumped to cva6_interrupt_trace.csv");

    // --------------------------------------------------------------------------
    // Architectural Register File & Interrupt Assertions
    // --------------------------------------------------------------------------
    $display("============================================================");
    $display("[SCOREBOARD] Architectural Register & Interrupt Checks");
    $display("============================================================");

    // Base pointer
    check_reg(2,  32'h8000_0200, "sp: base stack pointer");

    // Phase 1: Masked execution
    check_reg(10, 32'd17,        "a0: Masked execution marker (0x11: ran while time_irq asserted)");
    check_reg(1,  32'd2,         "ra: Arithmetic sequence completed under interrupt mask");

    // Phase 2: Timer ISR execution & MRET return
    check_reg(11, 32'd170,       "a1: Timer ISR handled marker (0xAA)");
    check_reg(12, 32'd34,        "a2: Post-Timer-ISR resumption marker (0x22 via MRET)");

    // Phase 3: WFI execution & External ISR execution
    check_reg(13, 32'd51,        "a3: Pre-WFI marker (0x33)");
    check_reg(14, 32'd187,       "a4: External ISR handled marker (0xBB from WFI wake)");
    check_reg(15, 32'd68,        "a5: Post-WFI resumption marker (0x44 via MRET)");

    // Terminal completion marker
    check_reg(26, 32'd999,       "s10: Completion marker reached 999");

    // Microarchitectural checks
    check_count++;
    if (trap_count >= 2) begin
      $display("[PASS] Total Interrupt Traps taken: %0d (Expected >= 2)", trap_count);
    end else begin
      $display("[FAIL] Total Interrupt Traps MISMATCH! Expected >= 2, Got: %0d", trap_count);
      error_count++;
    end

    check_count++;
    if (mret_count >= 2) begin
      $display("[PASS] Total MRET instructions retired: %0d (Expected >= 2)", mret_count);
    end else begin
      $display("[FAIL] Total MRET instructions MISMATCH! Expected >= 2, Got: %0d", mret_count);
      error_count++;
    end

    check_count++;
    if (wfi_cycles > 0) begin
      $display("[PASS] WFI Sleep cycles observed: %0d cycles (Core properly halted)", wfi_cycles);
    end else begin
      $display("[FAIL] WFI Sleep cycles is 0! Core never halted on WFI.");
      error_count++;
    end

    $display("------------------------------------------------------------");
    $display("[METRICS] Total Cycles Run       : %0d", cycle_cnt);
    $display("[METRICS] Total Instructions     : %0d", instret_cnt);
    $display("[METRICS] Total Dual-Commits     : %0d", dual_commit_total);
    $display("[METRICS] Total Interrupt Traps  : %0d", trap_count);
    $display("[METRICS] Total MRETs Executed   : %0d", mret_count);
    $display("[METRICS] Total WFI Sleep Cycles : %0d", wfi_cycles);
    if (instret_cnt > 0) begin
      $display("[METRICS] Overall Benchmark CPI  : %0.2f", real'(cycle_cnt) / real'(instret_cnt));
    end
    $display("------------------------------------------------------------");

    $display("============================================================");
    $display("Verification Summary for CVA6 Suite 8:");
    $display("  Total Checks : %0d", check_count);
    $display("  Errors       : %0d", error_count);
    $display("  Cycles Run   : %0d", cycle_cnt);
    $display("============================================================");

    if (error_count == 0) begin
      $display("[PASS] ALL SUITE-8 CHECKS PASSED");
    end else begin
      $display("[FAIL] SUITE-8 FAILED WITH %0d ERRORS", error_count);
    end

    $finish;
  end

endmodule