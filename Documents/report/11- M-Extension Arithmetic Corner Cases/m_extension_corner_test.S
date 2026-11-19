# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:30:00 +03:30
# Status: NEW FILE
# Reason / Modification: Assembly benchmark for Suite 11 (M-Extension Arithmetic
#                        Corner Cases: Division by zero, signed overflow -2^31/-1,
#                        |opB| > |opA| early termination, and high-word multiplier
#                        operations MULH, MULHU, and MULHSU).
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 0. Setup Stack Pointer and Base Operands
    # -------------------------------------------------------------------------
    lui   sp, 0x80000
    addi  sp, sp, 512          # sp = 0x8000_0200

    li    gp, 1000             # gp (x3) = 1000
    li    tp, 0                # tp (x4) = 0 (Zero divisor)

    # -------------------------------------------------------------------------
    # Phase 1: Division by Zero Corner Cases (DIV, DIVU, REM, REMU)
    # RISC-V Spec: DIV(x,0) = -1, DIVU(x,0) = 2^32-1, REM(x,0) = x, REMU(x,0) = x
    # -------------------------------------------------------------------------
    div   a0, gp, tp           # a0 (x10) = -1 (0xFFFFFFFF)
    divu  a1, gp, tp           # a1 (x11) = -1 (0xFFFFFFFF)
    rem   a2, gp, tp           # a2 (x12) = 1000 (0x000003E8)
    remu  a3, gp, tp           # a3 (x13) = 1000 (0x000003E8)

    # -------------------------------------------------------------------------
    # Phase 2: Signed Division Overflow Corner Cases (-2^31 / -1)
    # RISC-V Spec: DIV(-2^31, -1) = -2^31, REM(-2^31, -1) = 0
    # -------------------------------------------------------------------------
    lui   s2, 0x80000          # s2 (x18) = -2147483648 (0x80000000)
    li    s3, -1               # s3 (x19) = -1 (0xFFFFFFFF)
    div   a4, s2, s3           # a4 (x14) = 0x80000000 (Overflow saturated)
    rem   a5, s2, s3           # a5 (x15) = 0x00000000
    divu  a6, s2, s3           # a6 (x16) = 2147483648 / 4294967295 = 0
    remu  a7, s2, s3           # a7 (x17) = 2147483648 % 4294967295 = 0x80000000

    # -------------------------------------------------------------------------
    # Phase 3: Magnitude OpB > OpA (|opB| > |opA| Early Termination)
    # -------------------------------------------------------------------------
    li    t0, 5                # t0 (x5) = 5
    li    t1, 100              # t1 (x6) = 100
    div   s4, t0, t1           # s4 (x20) = 0
    rem   s5, t0, t1           # s5 (x21) = 5

    # -------------------------------------------------------------------------
    # Phase 4: Multiplier Upper 32-bit Words (MULH, MULHU, MULHSU)
    # -------------------------------------------------------------------------
    # Case A: Signed x Signed (-2 * 3 = -6)
    li    t2, -2               # t2 (x7) = -2 (0xFFFFFFFE)
    li    t3, 3                # t3 (x28) = 3 (0x00000003)
    mul   s6, t2, t3           # s6 (x22) = -6 (0xFFFFFFFA)
    mulh  s7, t2, t3           # s7 (x23) = -1 (0xFFFFFFFF)

    # Case B: Unsigned x Unsigned (0xFFFFFFFF * 0xFFFFFFFF)
    # Product = 0xFFFFFFFE_00000001
    li    t4, -1               # t4 (x29) = 0xFFFFFFFF
    mul   s8, t4, t4           # s8 (x24) = 0x00000001
    mulhu s9, t4, t4           # s9 (x25) = 0xFFFFFFFE

    # Case C: Signed x Unsigned (MULHSU: rs1 signed, rs2 unsigned)
    # (-1) * (0xFFFFFFFF) = -1 * (2^32 - 1) = -2^32 + 1 = 0xFFFFFFFF_00000001
    mulhsu s11, t4, t4         # s11 (x27) = 0xFFFFFFFF

    # Case D: Large Signed Positive x Large Signed Negative
    # (+2^30) * (-2^31) = -2^61 = 0xE0000000_00000000
    lui   t5, 0x40000          # t5 (x30) = +2^30 (0x40000000)
    mulh  t6, t5, s2           # t6 (x31) = 0xE0000000

    # -------------------------------------------------------------------------
    # Completion Marker
    # -------------------------------------------------------------------------
    li    s10, 999             # s10 (x26) = 999

end_loop:
    j     end_loop
    nop
