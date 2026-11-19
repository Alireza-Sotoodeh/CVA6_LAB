# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:45:00 +03:30
# Status: NEW FILE
# Reason / Modification: Assembly benchmark for Suite 10 (Sub-Word memory operations
#   LB, LBU, LH, LHU, SB, SH, and hardware alignment trap exceptions LD_ADDR_MISALIGNED
#   and ST_ADDR_MISALIGNED with mtval validation).
# ============================================================================

.section .text
.globl _start

_start:
    # --------------------------------------------------------------------------
    # Phase 0: Setup Stack, Trap Vector and Pointers
    # --------------------------------------------------------------------------
    lui   sp, 0x80000
    addi  sp, sp, 512          # sp = 0x8000_0200
    la    t0, isr_trap_handler
    csrw  mtvec, t0            # mtvec = isr_trap_handler
    lui   s0, 0x80000
    addi  s0, s0, 1024         # s0 = 0x8000_0400 (Memory test buffer)

    # --------------------------------------------------------------------------
    # Phase 1: Aligned Sub-Word Stores and Sign/Zero-Extended Loads
    # --------------------------------------------------------------------------
    li    t1, 0x11
    sb    t1, 0(s0)            # mem[0x80000400] = 0x11
    li    t1, 0x88             # negative byte (bit 7 = 1)
    sb    t1, 1(s0)            # mem[0x80000401] = 0x88
    li    t1, 0x33
    sb    t1, 2(s0)            # mem[0x80000402] = 0x33
    li    t1, 0xAA             # negative byte (bit 7 = 1)
    sb    t1, 3(s0)            # mem[0x80000403] = 0xAA

    # Test byte loads
    lb    a0, 0(s0)            # a0 = 0x00000011 (positive byte)
    lb    a1, 1(s0)            # a1 = 0xFFFFFF88 (sign-extended negative byte)
    lbu   a2, 1(s0)            # a2 = 0x00000088 (zero-extended byte)

    # Test half-word loads
    lh    a3, 0(s0)            # a3 = 0xFFFF8811 (half-word {0x88, 0x11}, sign-extended)
    lhu   a4, 0(s0)            # a4 = 0x00008811 (zero-extended)
    lh    a5, 2(s0)            # a5 = 0xFFFFAA33 (half-word {0xAA, 0x33}, sign-extended)
    lhu   a6, 2(s0)            # a6 = 0x0000AA33 (zero-extended)

    # Test full 32-bit aligned word load
    lw    a7, 0(s0)            # a7 = 0xAA338811

    # Overwrite half-words with SH
    li    t1, 0x5544
    sh    t1, 0(s0)            # mem[0x80000400..401] = 0x5544
    li    t1, 0x9977
    sh    t1, 2(s0)            # mem[0x80000402..403] = 0x9977
    lw    s1, 0(s0)            # s1 = 0x99775544

    # --------------------------------------------------------------------------
    # Phase 2: Unaligned Word Load Trap (LW from 0x8000_0401)
    # Expected: mcause = 4 (LD_ADDR_MISALIGNED), mtval = 0x80000401
    # --------------------------------------------------------------------------
    li    t3, 1                # Trap phase 1
    lw    t0, 1(s0)            # FAULTING INSTRUCTION: unaligned address 0x80000401
    nop

    # --------------------------------------------------------------------------
    # Phase 3: Unaligned Word Store Trap (SW to 0x8000_0402)
    # Expected: mcause = 6 (ST_ADDR_MISALIGNED), mtval = 0x80000402
    # --------------------------------------------------------------------------
    li    t3, 2                # Trap phase 2
    sw    t0, 2(s0)            # FAULTING INSTRUCTION: unaligned address 0x80000402
    nop

    # --------------------------------------------------------------------------
    # Phase 4: Unaligned Half-word Load Trap (LH from 0x8000_0403)
    # Expected: mcause = 4 (LD_ADDR_MISALIGNED), mtval = 0x80000403
    # --------------------------------------------------------------------------
    li    t3, 3                # Trap phase 3
    lh    t0, 3(s0)            # FAULTING INSTRUCTION: unaligned address 0x80000403
    nop

    # --------------------------------------------------------------------------
    # Phase 5: Unaligned Half-word Store Trap (SH to 0x8000_0401)
    # Expected: mcause = 6 (ST_ADDR_MISALIGNED), mtval = 0x80000401
    # --------------------------------------------------------------------------
    li    t3, 4                # Trap phase 4
    sh    t0, 1(s0)            # FAULTING INSTRUCTION: unaligned address 0x80000401
    nop

    # --------------------------------------------------------------------------
    # Phase 6: Terminal Completion Marker
    # --------------------------------------------------------------------------
    li    ra, 999              # ra (x1) = 999 (PASS marker)

end_loop:
    j     end_loop

# ------------------------------------------------------------------------------
# Interrupt Service Routine (ISR) / Trap Handler
# ------------------------------------------------------------------------------
.align 4
isr_trap_handler:
    csrr  t1, mcause           # Read exception cause
    csrr  t2, mtval            # Read faulting address from mtval

    li    t5, 1
    beq   t3, t5, handle_trap_1
    li    t5, 2
    beq   t3, t5, handle_trap_2
    li    t5, 3
    beq   t3, t5, handle_trap_3
    li    t5, 4
    beq   t3, t5, handle_trap_4
    j     resume_trap

handle_trap_1:
    mv    s4, t1               # s4 = mcause (expected 4)
    mv    s5, t2               # s5 = mtval  (expected 0x80000401)
    j     resume_trap

handle_trap_2:
    mv    s6, t1               # s6 = mcause (expected 6)
    mv    s7, t2               # s7 = mtval  (expected 0x80000402)
    j     resume_trap

handle_trap_3:
    mv    s8, t1               # s8 = mcause (expected 4)
    mv    s9, t2               # s9 = mtval  (expected 0x80000403)
    j     resume_trap

handle_trap_4:
    mv    s10, t1              # s10 = mcause (expected 6)
    mv    s11, t2              # s11 = mtval  (expected 0x80000401)
    j     resume_trap

resume_trap:
    csrr  t4, mepc             # Read faulting PC
    addi  t4, t4, 4            # Advance PC past the faulting load/store
    csrw  mepc, t4
    mret                       # Return to execution
