# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 21:17:00 +03:30
# Status: NEW FILE
# Reason / Modification: Suite 6 assembly benchmark for testing CVA6 Sustained
#                        Dual-Commit throughput and AXI Memory Subsystem
#                        Latency sensitivity (0, 4, 8, 16 wait cycles).
# ============================================================================

.section .text
.globl _start

_start:
    # ------------------------------------------------------------
    # Phase 0: Setup base registers and data memory pointer
    # ------------------------------------------------------------
    lui   x1, 0x80000
    addi  x1, x1, 512            # x1 = 0x8000_0200 (data buffer)
    li    x2, 0
    li    x3, 0
    li    x4, 0
    li    x5, 42                 # Store value
    li    x6, 0
    li    x7, 0
    li    x8, 0
    li    x9, 0
    li    x10, 0
    li    x11, 0
    li    x12, 0
    li    x13, 0
    li    x14, 0
    li    x15, 0
    li    x16, 0
    li    x21, 1                 # Iteration counter (1, 2, 3, 4)

loop_start:
    # ------------------------------------------------------------
    # Block A: Store paired with independent ALU (Dual-Commit)
    # ------------------------------------------------------------
    sw    x5, 0(x1)              # Store 42 to [0x8000_0200]
    addi  x6, x6, 1              # Independent ALU (Port 1 dual-commit eligible)
    addi  x7, x7, 2              # Independent ALU
    addi  x8, x8, 3              # Independent ALU

    # ------------------------------------------------------------
    # Block B: Load followed by independent ALU (Memory Latency)
    # ------------------------------------------------------------
    lw    x9, 0(x1)              # Load 42 from [0x8000_0200] (sensitive to AXI latency)
    addi  x10, x10, 4            # Independent ALU (Port 1 dual-commit eligible)
    add   x11, x6, x7            # Dependent ALU
    add   x12, x8, x10           # Dependent ALU

    # ------------------------------------------------------------
    # Block C: Independent ALU pairs for high IPC retirement
    # ------------------------------------------------------------
    addi  x13, x11, 10           # x13 = x11 + 10
    addi  x14, x12, 20           # x14 = x12 + 20 (Independent pair with x13!)
    xor   x15, x13, x14          # x15 = x13 ^ x14
    slli  x16, x15, 2            # x16 = x15 << 2

    # ------------------------------------------------------------
    # Loop Control (4 iterations with distinct AXI wait cycles)
    # ------------------------------------------------------------
    addi  x21, x21, 1            # Increment iteration count
    li    x2, 5                  # Target: 4 iterations
    bne   x21, x2, loop_start    # Repeat for iterations 1, 2, 3, 4

    # ------------------------------------------------------------
    # Terminal Completion Marker
    # ------------------------------------------------------------
    li    x20, 999               # Final marker

end_loop:
    j     end_loop
    nop
