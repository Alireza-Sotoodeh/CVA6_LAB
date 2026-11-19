# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 21:01:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Dedicated t6 register for subroutine pointer 0x8000_0200
#                        to avoid clobbering x1 (ra) when saving return value.
# ============================================================================

.section .text
.globl _start

_start:
    # ------------------------------------------------------------
    # Phase 0: Setup base registers and pointer to subroutine
    # ------------------------------------------------------------
    lui   t6, 0x80000
    addi  t6, t6, 512            # t6 = 0x8000_0200 (subroutine address)
    li    sp, 0
    li    gp, 0
    li    tp, 0
    li    t0, 0
    li    t1, 0
    li    t2, 0
    li    s0, 0
    li    s1, 0
    li    a0, 0
    li    a1, 0

    # ------------------------------------------------------------
    # Phase 1: First call to subroutine at 0x8000_0200
    # Subroutine initial code at 0x8000_0200:
    #   addi a0, zero, 100   (0x06400513)
    #   jr   s0              (0x00040067)
    # ------------------------------------------------------------
    jalr  s0, t6, 0              # Call subroutine at 0x8000_0200, save return PC in s0
    mv    x1, a0                 # x1 = a0 (must be 100)

    # ------------------------------------------------------------
    # Phase 2: Modify code via Store (Self-Modifying Code)
    # Overwrite instruction at 0x8000_0200 with new opcode:
    #   addi a0, zero, 999   (0x3e700513)
    # ------------------------------------------------------------
    lui   t0, 0x3e700
    addi  t0, t0, 0x513          # t0 = 0x3e700513
    sw    t0, 0(t6)              # Store new instruction at 0x8000_0200

    # ------------------------------------------------------------
    # Phase 3: Synchronize Instruction Stream via FENCE.I
    # Drains store buffer, asserts flush_icache_o, clears tag valid bits
    # ------------------------------------------------------------
    fence.i

    # ------------------------------------------------------------
    # Phase 4: Second call to subroutine at 0x8000_0200
    # Because FENCE.I flushed I-Cache, core takes cache miss,
    # re-fetches new opcode 0x3e700513 from memory, sets a0 = 999!
    # ------------------------------------------------------------
    jalr  s0, t6, 0              # Call subroutine at 0x8000_0200 again
    mv    x2, a0                 # x2 = a0 (must be 999!)

    # ------------------------------------------------------------
    # Phase 5: CSR Side-Effect Pipeline Flush (flush_csr)
    # Writing to mstatus triggers flush_o in csr_regfile, asserting
    # flush_if, flush_id, flush_ex, and flush_unissued in controller
    # ------------------------------------------------------------
    csrr  t1, mstatus
    csrw  mstatus, t1            # Modifies mstatus -> triggers flush_csr_ctrl
    li    x3, 555                # Marker verifying execution resumes properly

    # ------------------------------------------------------------
    # Phase 6: Standard Data FENCE instruction
    # ------------------------------------------------------------
    fence
    li    x4, 777                # Marker verifying execution resumes after FENCE

    # ------------------------------------------------------------
    # Phase 7: Terminal self-loop
    # ------------------------------------------------------------
    li    x20, 999               # Final completion marker

end_loop:
    j     end_loop
    nop
