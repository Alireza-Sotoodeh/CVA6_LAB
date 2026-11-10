.section .data
.align 6
.global tohost
tohost: .dword 0

.global fromhost
fromhost: .dword 0

.section .text
.global _start
_start:
    li s0, 0
    li s1, 100
    li a0, 5
    li a1, 3

loop_body:
    add a2, a0, a1
    sub a3, a2, a1
    xor a4, a3, a0
    mul a5, a4, a1
    addi s0, s0, 1
    blt s0, s1, loop_body

    # Done, write tohost
    la t0, tohost
    li t1, 1
    sw t1, 0(t0)

spin:
    j spin
