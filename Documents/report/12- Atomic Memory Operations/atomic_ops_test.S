# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:42:00 +03:30
# Status: NEW FILE
# Reason / Modification: Comprehensive assembly benchmark for Suite 12 (Atomic
#   Memory Operations: LR.W, SC.W reservation sets, broken reservations,
#   AMOSWAP.W, AMOADD.W, AMOXOR.W, AMOAND.W, AMOOR.W) on OpenHW Group CVA6 (RV32IMA).
# ============================================================================

.section .text
.globl _start

_start:
    # ------------------------------------------------------------------------
    # Phase 0: Initialize Stack and Memory Test Buffer Base
    # ------------------------------------------------------------------------
    lui   sp, 0x80000
    addi  sp, sp, 512              # sp = 0x8000_0200
    lui   s0, 0x80000
    addi  s0, s0, 1024             # s0 = 0x8000_0400 (Memory Test Buffer)

    # ------------------------------------------------------------------------
    # Phase 1: Store-Conditional (SC.W) without prior reservation
    # Expected: SC fails (returns 1 in a0), memory is untouched.
    # ------------------------------------------------------------------------
    li    t1, 0x12345678
    sw    t1, 0(s0)                # Initialize mem[0x80000400] = 0x12345678

    li    t2, 0xDEADBEEF
    sc.w  a0, t2, (s0)             # sc.w without lr.w -> Expect a0 = 1 (Failure)
    lw    a1, 0(s0)                # Expect a1 = 0x12345678 (Memory unchanged)

    # ------------------------------------------------------------------------
    # Phase 2: Load-Reserved (LR.W) followed by SC.W (Reservation Success)
    # Expected: LR loads current value, SC succeeds (returns 0 in a3), memory updated.
    # ------------------------------------------------------------------------
    lr.w  a2, (s0)                 # lr.w -> Expect a2 = 0x12345678 (Acquires reservation)
    li    t3, 0xCAFEBABE
    sc.w  a3, t3, (s0)             # sc.w -> Expect a3 = 0 (Success!)
    lw    a4, 0(s0)                # Expect a4 = 0xCAFEBABE (Memory successfully updated)

    # ------------------------------------------------------------------------
    # Phase 3: LR.W, Intervening SW (Broken Reservation), then SC.W
    # Expected: Intervening store invalidates reservation, SC fails (returns 1 in a6),
    # memory retains the intervening store value.
    # ------------------------------------------------------------------------
    lr.w  a5, (s0)                 # lr.w -> Expect a5 = 0xCAFEBABE (Acquires reservation)
    li    t4, 0x55555555
    sw    t4, 0(s0)                # Intervening SW -> Breaks reservation!
    li    t5, 0x99999999
    sc.w  a6, t5, (s0)             # sc.w -> Expect a6 = 1 (Failure due to broken reservation!)
    lw    a7, 0(s0)                # Expect a7 = 0x55555555 (Intervening value preserved)

    # ------------------------------------------------------------------------
    # Phase 4: Atomic Swap (AMOSWAP.W)
    # Expected: Returns old value in s3, updates memory with new value.
    # ------------------------------------------------------------------------
    addi  s1, s0, 4                # s1 = 0x8000_0404
    sw    t4, 0(s1)                # mem[0x80000404] = 0x55555555
    li    s2, 0x11223344           # s2 = 0x11223344
    amoswap.w s3, s2, (s1)         # Expect s3 = 0x55555555 (old value), mem becomes 0x11223344
    lw    s4, 0(s1)                # Expect s4 = 0x11223344

    # ------------------------------------------------------------------------
    # Phase 5: Atomic Add (AMOADD.W)
    # Expected: Returns old value in s7, updates memory with sum.
    # ------------------------------------------------------------------------
    addi  s1, s0, 8                # s1 = 0x8000_0408
    li    s5, 10
    sw    s5, 0(s1)                # mem[0x80000408] = 10
    li    s6, 25                   # Operand = 25
    amoadd.w s7, s6, (s1)          # Expect s7 = 10 (old value), mem becomes 35
    lw    s8, 0(s1)                # Expect s8 = 35

    # ------------------------------------------------------------------------
    # Phase 6: Atomic XOR (AMOXOR.W)
    # Expected: Returns old value in s11, updates memory with XOR.
    # ------------------------------------------------------------------------
    addi  s1, s0, 12               # s1 = 0x8000_040C
    li    s9, 0x00FF00FF
    sw    s9, 0(s1)                # mem[0x8000040C] = 0x00FF00FF
    li    s10, 0x0F0F0F0F
    amoxor.w s11, s10, (s1)        # Expect s11 = 0x00FF00FF, mem becomes 0x0FF00FF0
    lw    t5, 0(s1)                # Expect t5 = 0x0FF00FF0

    # ------------------------------------------------------------------------
    # Phase 7: Atomic OR (AMOOR.W) and Atomic AND (AMOAND.W)
    # ------------------------------------------------------------------------
    addi  s1, s0, 16               # s1 = 0x8000_0410
    li    t6, 0xAAAAAAAA
    sw    t6, 0(s1)                # mem[0x80000410] = 0xAAAAAAAA
    li    gp, 0x55555555
    amoor.w tp, gp, (s1)           # Expect tp = 0xAAAAAAAA (old value), mem becomes 0xFFFFFFFF
    lw    t1, 0(s1)                # Expect t1 = 0xFFFFFFFF

    li    t2, 0x0000FFFF
    amoand.w t3, t2, (s1)          # Expect t3 = 0xFFFFFFFF (old value), mem becomes 0x0000FFFF
    lw    t4, 0(s1)                # Expect t4 = 0x0000FFFF

    # ------------------------------------------------------------------------
    # Phase 8: Terminal Loop and Completion Marker
    # ------------------------------------------------------------------------
    li    ra, 999                  # ra (x1) = 999 (Benchmark success marker)
end_loop:
    j     end_loop
