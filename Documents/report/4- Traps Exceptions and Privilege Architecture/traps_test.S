.section .text
.globl _start

_start:
    # -------------------------------------------------------------
    # 0. Setup and initialize registers
    # -------------------------------------------------------------
    lui   x1, 0x80000
    addi  x1, x1, 1024           # x1 = 0x8000_0400 (Data base)

    # Setup mtvec to point to trap_handler (direct mode)
    la    x31, trap_handler
    csrw  mtvec, x31

    # Initialize test markers & trap records
    addi  x2,  x0, 0             # Total trap count
    addi  x3,  x0, 0
    addi  x4,  x0, 0
    addi  x5,  x0, 0
    addi  x6,  x0, 0
    addi  x7,  x0, 0
    addi  x8,  x0, 0
    addi  x9,  x0, 0
    addi  x10, x0, 0             # Trap 1 mcause
    addi  x11, x0, 0             # Trap 1 mepc
    addi  x12, x0, 0             # Trap 2 mcause
    addi  x13, x0, 0             # Trap 2 mepc
    addi  x14, x0, 0             # Trap 3 mcause
    addi  x15, x0, 0             # Trap 3 mepc
    addi  x16, x0, 0             # Trap 3 mtval
    addi  x17, x0, 0             # Trap 4 mcause
    addi  x18, x0, 0             # Trap 4 mepc
    addi  x19, x0, 0
    addi  x20, x0, 0

    # -------------------------------------------------------------
    # Phase 1: Trigger ILLEGAL_INSTR (Cause 2)
    # -------------------------------------------------------------
    addi  x3, x0, 100            # Marker before Trap 1
trap1_trigger:
    .word 0x00000000             # Invalid instruction -> triggers ILLEGAL_INSTR (cause 2)
trap1_resume:
    addi  x4, x0, 101            # Marker after Trap 1 resume!

    # -------------------------------------------------------------
    # Phase 2: Trigger BREAKPOINT / EBREAK (Cause 3)
    # -------------------------------------------------------------
    addi  x5, x0, 200            # Marker before Trap 2
trap2_trigger:
    ebreak                       # EBREAK -> triggers BREAKPOINT (cause 3)
trap2_resume:
    addi  x6, x0, 201            # Marker after Trap 2 resume!

    # -------------------------------------------------------------
    # Phase 3: Trigger INSTR_ADDR_MISALIGNED (Cause 0)
    # -------------------------------------------------------------
    addi  x7, x0, 300            # Marker before Trap 3
    addi  x31, x1, 2             # x31 = 0x8000_0402 (Unaligned target address!)
trap3_trigger:
    jalr  x0, 0(x31)             # Unaligned JALR -> triggers INSTR_ADDR_MISALIGNED (cause 0)
trap3_resume:
    addi  x8, x0, 301            # Marker after Trap 3 resume!

    # -------------------------------------------------------------
    # Phase 4: Trigger ENV_CALL_MMODE / ECALL (Cause 11)
    # -------------------------------------------------------------
    addi  x9, x0, 400            # Marker before Trap 4
trap4_trigger:
    ecall                        # ECALL in M-mode -> triggers ENV_CALL_MMODE (cause 11)
trap4_resume:
    addi  x19, x0, 401           # Marker after Trap 4 resume!

    # -------------------------------------------------------------
    # Phase 5: Verification & Terminal Halt
    # -------------------------------------------------------------
    addi  x20, x0, 999           # Final completion flag
end_loop:
    jal   x0, end_loop

# -----------------------------------------------------------------
# Trap Handler
# -----------------------------------------------------------------
.align 4
trap_handler:
    # Increment total trap count
    addi  x2, x2, 1

    # Read CSRs using temporary registers x28, x29, x30
    csrr  x28, mcause
    csrr  x29, mepc
    csrr  x30, mtval

    # Branch based on trap count
    addi  x31, x0, 1
    beq   x2, x31, handle_trap1
    addi  x31, x0, 2
    beq   x2, x31, handle_trap2
    addi  x31, x0, 3
    beq   x2, x31, handle_trap3
    addi  x31, x0, 4
    beq   x2, x31, handle_trap4
    j     trap_return

handle_trap1:
    addi  x10, x28, 0            # x10 = mcause (2)
    addi  x11, x29, 0            # x11 = mepc (trap1_trigger)
    j     trap_return

handle_trap2:
    addi  x12, x28, 0            # x12 = mcause (3)
    addi  x13, x29, 0            # x13 = mepc (trap2_trigger)
    j     trap_return

handle_trap3:
    addi  x14, x28, 0            # x14 = mcause (0)
    addi  x15, x29, 0            # x15 = mepc (trap3_trigger)
    addi  x16, x30, 0            # x16 = mtval (0x8000_0402)
    j     trap_return

handle_trap4:
    addi  x17, x28, 0            # x17 = mcause (11)
    addi  x18, x29, 0            # x18 = mepc (trap4_trigger)
    j     trap_return

trap_return:
    # Advance mepc by 4 bytes to skip the faulting instruction
    addi  x29, x29, 4
    csrw  mepc, x29
    mret
