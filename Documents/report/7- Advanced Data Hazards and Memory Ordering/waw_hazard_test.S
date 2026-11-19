# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 21:38:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Assembly benchmark for Suite 7 (Advanced Data Hazards:
#                        WAW out-of-order execution vs in-order commit,
#                        Intermediate consumer dependency routing, Memory WAR,
#                        Store-to-Load forwarding, Sub-word sign/zero extension,
#                        and Register x0 invariant immunity). Corrected register
#                        pointer so sp remains intact.
# ============================================================================

.section .text
.globl _start

_start:
    # ------------------------------------------------------------
    # Phase 0: Setup base pointers and input values
    # ------------------------------------------------------------
    lui   sp, 0x80000
    addi  sp, sp, 512            # sp = 0x8000_0200 (data buffer)
    li    x3, 1000               # Dividend (x3 = 1000)
    li    x4, 10                 # Divisor  (x4 = 10)

    # ------------------------------------------------------------
    # Phase 1: WAW Hazard (Out-of-Order Execution vs In-Order Commit)
    # Long-latency DIV (8-10 cycles) vs Single-cycle ADDI targeting same rd (x10)
    # ------------------------------------------------------------
    div   x10, x3, x4            # Multi-cycle DIV (1000 / 10 = 100) -> rd = x10 (trans_id A)
    addi  x10, x0, 99            # Single-cycle ADDI -> rd = x10 (trans_id B, completes first!)
    add   x11, x10, x0           # Consumer: must read 99 from trans_id B via raw_checker!
    addi  x12, x0, 1             # Independent ALU instruction

    # ------------------------------------------------------------
    # Phase 2: Multi-Producer Intermediate Consumer WAW
    # One consumer reads DIV producer, next consumer reads ADDI producer
    # ------------------------------------------------------------
    div   x13, x3, x4            # Slow DIV -> x13 (1000 / 10 = 100)
    add   x14, x13, x0           # Consumer 1: must stall until DIV finishes -> receives 100!
    addi  x13, x0, 77            # Fast ALU: overwrites x13 with 77
    add   x15, x13, x0           # Consumer 2: must forward from ADDI -> receives 77!

    # ------------------------------------------------------------
    # Phase 3: Memory WAR (Write-After-Read in Store Buffer)
    # Load old data, followed immediately by Store overwriting the address
    # ------------------------------------------------------------
    sw    x3, 0(sp)              # Initial write: [0x8000_0200] = 1000
    lw    x16, 0(sp)             # Load old value: x16 must receive 1000
    sw    x4, 0(sp)              # Store new value: [0x8000_0200] = 10 immediately
    lw    x17, 0(sp)             # Load new value: x17 must receive 10

    # ------------------------------------------------------------
    # Phase 4: Store-to-Load Forwarding (RAW in Store Buffer)
    # Store word followed immediately by Load from same address
    # ------------------------------------------------------------
    lui   x18, 0x12345
    addi  x18, x18, 0x678        # x18 = 0x12345678
    sw    x18, 4(sp)             # Store to [0x8000_0204]
    lw    x19, 4(sp)             # Immediate load: Store Buffer bypass -> x19 = 0x12345678

    # ------------------------------------------------------------
    # Phase 5: Sub-Word Accesses & Aliasing (Byte & Half-Word LSU)
    # Testing sign extension vs zero extension from Store Buffer / Cache
    # ------------------------------------------------------------
    lui   x20, 0xAABBD
    addi  x20, x20, -803         # x20 = 0xAABBCCDD
    sw    x20, 8(sp)             # Store word to [0x8000_0208]
    lb    x21, 8(sp)             # Load byte signed: 0xDD -> sign extended to 0xFFFFFFDD (-35)
    lbu   x22, 8(sp)             # Load byte unsigned: 0xDD -> zero extended to 0x000000DD (221)
    lh    x23, 8(sp)             # Load half signed: 0xCCDD -> sign extended to 0xFFFFCCDD (-13091)
    lhu   x24, 8(sp)             # Load half unsigned: 0xCCDD -> zero extended to 0x0000CCDD (52445)

    # ------------------------------------------------------------
    # Phase 6: Register x0 Invariant & Stall Immunity
    # Verifying that multi-cycle instructions targeting x0 do not stall
    # ------------------------------------------------------------
    div   x0, x3, x4             # DIV targeting x0: result discarded, no stall on raw_checker
    lw    x0, 0(sp)              # Load targeting x0: result discarded
    addi  x0, x0, 555            # ALU targeting x0: result discarded
    add   x25, x0, x0            # x25 = x0 + x0 = 0 (Verify x0 remains strictly zero!)

    # ------------------------------------------------------------
    # Terminal Marker
    # ------------------------------------------------------------
    li    x26, 999               # Completion marker: x26 = 999

end_loop:
    j     end_loop
    nop
