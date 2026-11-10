.section .data
.align 6
.global tohost
tohost: .dword 0

.global fromhost
fromhost: .dword 0

.section .text
.global _start
_start:
    li x1, 10
    li x2, 20
    add x3, x1, x2
    sub x4, x3, x1
    mul x5, x1, x2
    xor x6, x4, x5
    or  x7, x6, x1
    and x8, x7, x2

    # Exit sequence
    la t0, tohost
    li t1, 1
    sw t1, 0(t0)

loop:
    j loop
