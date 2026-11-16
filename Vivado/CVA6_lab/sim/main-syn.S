# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-16 11:00:00 +03:30
# Status: NEW FILE
# Reason / Modification: Baseline 5-instruction RV32 assembly benchmark for CVA6
#                        simulation in Vivado XSIM (cva6_tb.sv).
# ============================================================================

    .section .text.init
    .global _start

_start:
    li x1, 10           # x1 = 10 (0x0A)
    li x2, 20           # x2 = 20 (0x14)
    add x3, x1, x2      # x3 = 30 (0x1E)

    # Store result into memory address 0x80001000
    li x4, 0x80001000   # Destination memory address
    sw x3, 0(x4)        # Store x3 (30) at [0x80001000]

loop:
    j loop              # Infinite self-loop to conclude simulation
