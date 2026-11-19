.section .text
.globl _start
_start:
    # 0x8000_0000: Setup
    lui   x1, 0x80000
    addi  x1, x1, 0x200
    addi  x2, x0, 10
    addi  x3, x0, 20

    # Phase 1: RAW ALU-to-ALU Forwarding Burst (7 back-to-back dependent ALU instrs)
    addi  x4, x2, 5
    add   x5, x4, x3
    sub   x6, x5, x2
    and   x7, x6, x4
    or    x8, x7, x5
    xor   x9, x8, x6
    slli  x10, x9, 2

    # Phase 2: Load-Use Hazard Stall
    sw    x10, 0(x1)
    lw    x11, 0(x1)
    addi  x12, x11, 1
    add   x13, x12, x4

    # Phase 3: Store-to-Load Page-Offset Hazard (Store Buffer Stall)
    sw    x13, 4(x1)
    lw    x14, 4(x1)
    addi  x15, x14, 10

    # Phase 4: Multi-Cycle Integer Divider Structural Write-Back Contention
    addi  x16, x0, 100
    addi  x17, x0, 7
    div   x18, x16, x17
    addi  x19, x0, 500
    rem   x20, x16, x17
    addi  x21, x0, 700
    add   x22, x18, x20
    mul   x23, x22, x17
    add   x24, x23, x19

    # Phase 5: Terminal self-loop
end_loop:
    jal   x0, end_loop
