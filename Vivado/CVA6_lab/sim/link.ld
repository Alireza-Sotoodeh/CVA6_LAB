/* ============================================================================
 * Author: Alireza Sotodeh
 * Date & Time: 2026-11-16 11:00:00 +03:30
 * Status: NEW FILE
 * Reason / Modification: Linker script for CVA6 (Ariane) simulation firmware,
 *                        mapping text, data, and bss sections to boot base 0x80000000.
 * ============================================================================ */

OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    /* CVA6 Hardware Boot Address */
    . = 0x80000000;

    .text : ALIGN(4) {
        *(.text.init)
        *(.text)
        *(.text.*)
    }

    .rodata : ALIGN(4) {
        *(.rodata)
        *(.rodata.*)
    }

    .data : ALIGN(4) {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    }

    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        __bss_end = .;
    }

    /* Provide symbols for stack and end of memory (64KB total capacity) */
    . = ALIGN(16);
    _end = .;
    __stack_top = 0x80000000 + 0x10000; /* Top of 64KB RAM */
}
