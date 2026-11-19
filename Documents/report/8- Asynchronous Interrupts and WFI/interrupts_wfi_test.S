# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:05:00 +03:30
# Status: NEW FILE
# Reason / Modification: Assembly benchmark for Suite 8 (Asynchronous Interrupts,
#                        Timer MTIP, External MEIP, mstatus.MIE masking, WFI
#                        sleep/wakeup, and MRET return resumption).
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 0. Setup Stack Pointer and Trap Vector (mtvec)
    # -------------------------------------------------------------------------
    lui   sp, 0x80000
    addi  sp, sp, 512          # sp = 0x8000_0200

    la    t0, isr_trap_handler
    csrw  mtvec, t0            # mtvec = isr_trap_handler (Direct mode)

    # Enable Timer (MTIE: bit 7 = 0x80) and External (MEIE: bit 11 = 0x800) in mie
    li    t0, 0x880            # 0x800 | 0x80 = 0x880
    csrw  mie, t0

    # Ensure global interrupts are initially disabled (MIE: bit 3 = 0)
    csrci mstatus, 8

    # -------------------------------------------------------------------------
    # Phase 1: Interrupt Masking Test (time_irq_i asserted while MIE = 0)
    # -------------------------------------------------------------------------
    addi  x10, zero, 17        # x10 = 17 (0x11: Masked execution marker)
    addi  x1, zero, 1
    addi  x1, x1, 1

    # -------------------------------------------------------------------------
    # Phase 2: Unmask Interrupts (Set mstatus.MIE = 1) -> Takes Timer Trap!
    # -------------------------------------------------------------------------
    csrsi mstatus, 8           # MIE = 1 -> core immediately vectors to isr_trap_handler!
    addi  x12, zero, 34        # x12 = 34 (0x22: Resumed from Timer ISR marker)

    # -------------------------------------------------------------------------
    # Phase 3: Wait For Interrupt (WFI) & External Interrupt Wakeup
    # -------------------------------------------------------------------------
    addi  x13, zero, 51        # x13 = 51 (0x33: Pre-WFI marker)
    wfi                        # Core enters low-power sleep / halt until interrupt
    addi  x15, zero, 68        # x15 = 68 (0x44: Post-WFI resumption marker)

    # Completion marker
    li    x26, 999             # x26 = 999

end_loop:
    j     end_loop
    nop

# -----------------------------------------------------------------------------
# ISR / Trap Handler
# -----------------------------------------------------------------------------
.align 4
isr_trap_handler:
    csrr  t1, mcause
    # Check if timer interrupt: mcause == 0x80000007
    li    t2, 0x80000007
    beq   t1, t2, handle_timer_irq

    # Check if external interrupt: mcause == 0x8000000B
    li    t2, 0x8000000B
    beq   t1, t2, handle_ext_irq

    # Default unexpected trap
    addi  x27, zero, 1
    mret

handle_timer_irq:
    addi  x11, zero, 170       # x11 = 170 (0xAA: Timer ISR handled marker)
    li    t0, 0x80             # Bit 7 (MTIE)
    csrc  mie, t0              # Disable MTIE
    mret

handle_ext_irq:
    addi  x14, zero, 187       # x14 = 187 (0xBB: External ISR handled marker)
    li    t0, 0x800            # Bit 11 (MEIE)
    csrc  mie, t0              # Disable MEIE
    mret
