# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:15:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform and architectural timing diagram generator
#                        for Suite 8 (Asynchronous Interrupts, Timer MTIP,
#                        External MEIP, mstatus.MIE masking, WFI sleep/wakeup,
#                        and MRET return resumption). Reads cva6_interrupt_trace.csv.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_interrupt_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp,0x80000",
    0x0004: "ADDI sp,512",
    0x0008: "AUIPC t0,0",
    0x000C: "ADDI t0,72",
    0x0010: "CSRW mtvec,t0",
    0x0014: "LUI t0,0x1",
    0x0018: "ADDI t0,-1920",
    0x001C: "CSRW mie,t0",
    0x0020: "CSRCI mstatus,8",
    0x0024: "LI a0,17",
    0x0028: "LI ra,1",
    0x002C: "ADDI ra,ra,1",
    0x0030: "CSRSI mstatus,8",
    0x0034: "LI a2,34",
    0x0038: "LI a3,51",
    0x003C: "WFI",
    0x0040: "LI a5,68",
    0x0044: "LI s10,999",
    0x0048: "J END_LOOP",
    0x0050: "CSRR t1,mcause",
    0x0054: "LUI t2,0x80000",
    0x0058: "ADDI t2,t2,7",
    0x005C: "BEQ t1,t2,TIMER_ISR",
    0x0060: "LUI t2,0x80000",
    0x0064: "ADDI t2,t2,11",
    0x0068: "BEQ t1,t2,EXT_ISR",
    0x0074: "LI a1,170",
    0x0078: "LI t0,128",
    0x007C: "CSRC mie,t0",
    0x0080: "MRET",
    0x0084: "LI a4,187",
    0x0088: "LUI t0,0x1",
    0x008C: "ADDI t0,-2048",
    0x0090: "CSRC mie,t0",
    0x0094: "MRET",
}


def xesc(value):
    return saxutils.escape("" if value is None else str(value))


def hex32(value):
    try:
        return int(str(value), 0)
    except (TypeError, ValueError):
        return 0


def pc_label(value):
    pc = hex32(value)
    short = pc & 0xFFFF
    name = PC_MAP.get(short)
    if pc == 0:
        return "0x0000"
    if name:
        return f"0x{short:04X} {name}"
    return f"0x{short:04X}"


def read_trace():
    if not os.path.exists(CSV_PATH):
        return []
    with open(CSV_PATH, "r", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def rows_in_window(rows, start, end):
    return [row for row in rows if start <= int(row["Cycle"]) <= end]


def svg_header(width, height):
    return [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">',
        "<defs>",
        '  <style type="text/css">',
        "    text { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }",
        "    .sig-lbl { font-size: 11px; font-weight: 600; fill: #1e293b; }",
        "    .sig-sub { font-size: 9px; fill: #64748b; }",
        "    .cyc-lbl { font-size: 10px; fill: #475569; text-anchor: middle; }",
        "    .box-lbl { font-size: 10px; font-weight: 600; text-anchor: middle; }",
        "    .hex-lbl { font-size: 9px; font-family: monospace; text-anchor: middle; }",
        "    .sec-hdr { font-size: 14px; font-weight: 700; fill: #0f172a; }",
        "    .sec-sub { font-size: 11px; fill: #475569; }",
        "  </style>",
        '  <linearGradient id="grid-grad" x1="0" y1="0" x2="0" y2="1">',
        '    <stop offset="0%" stop-color="#f8fafc" />',
        '    <stop offset="100%" stop-color="#f1f5f9" />',
        "  </linearGradient>",
        "</defs>",
        f'<rect width="{width}" height="{height}" fill="#ffffff" />',
    ]


def draw_digital_bus(lines, label, sub, y, rows, width, get_val, get_color, get_text):
    label_w = 200
    grid_w = width - label_w - 30
    n = len(rows)
    slot_w = grid_w / n

    lines.append(f'<text x="20" y="{y+15}" class="sig-lbl">{xesc(label)}</text>')
    if sub:
        lines.append(f'<text x="20" y="{y+26}" class="sig-sub">{xesc(sub)}</text>')

    lines.append(
        f'<rect x="{label_w}" y="{y}" width="{grid_w}" height="28" fill="#f8fafc" stroke="#e2e8f0" rx="3" />'
    )

    prev_val = None
    blk_start = 0

    for i, r in enumerate(rows):
        cur_val = get_val(r)
        if i == 0:
            prev_val = cur_val
            blk_start = 0
            continue
        if cur_val != prev_val:
            bx = label_w + blk_start * slot_w
            bw = (i - blk_start) * slot_w
            color = get_color(prev_val)
            txt = get_text(prev_val, bw)
            lines.append(
                f'<rect x="{bx+1}" y="{y+2}" width="{bw-2}" height="24" rx="2" fill="{color}" stroke="#cbd5e1" />'
            )
            if txt:
                lines.append(
                    f'<text x="{bx + bw/2}" y="{y+16}" class="box-lbl" fill="#1e293b">{xesc(txt)}</text>'
                )
            prev_val = cur_val
            blk_start = i

    bx = label_w + blk_start * slot_w
    bw = (n - blk_start) * slot_w
    color = get_color(prev_val)
    txt = get_text(prev_val, bw)
    lines.append(
        f'<rect x="{bx+1}" y="{y+2}" width="{bw-2}" height="24" rx="2" fill="{color}" stroke="#cbd5e1" />'
    )
    if txt:
        lines.append(
            f'<text x="{bx + bw/2}" y="{y+16}" class="box-lbl" fill="#1e293b">{xesc(txt)}</text>'
        )


def draw_waveform(rows, title, subtitle, out_file):
    width = 1200
    height = 560
    lines = svg_header(width, height)

    lines.append(f'<text x="30" y="32" class="sec-hdr">{xesc(title)}</text>')
    lines.append(f'<text x="30" y="50" class="sec-sub">{xesc(subtitle)}</text>')

    label_w = 200
    grid_w = width - label_w - 30
    n = len(rows)
    slot_w = grid_w / n

    lines.append(
        f'<rect x="{label_w}" y="65" width="{grid_w}" height="20" fill="#f1f5f9" rx="2" />'
    )
    for i, r in enumerate(rows):
        cx = label_w + i * slot_w + slot_w / 2
        cyc = r["Cycle"]
        if n > 40:
            if i % 4 == 0:
                lines.append(
                    f'<text x="{cx}" y="79" class="cyc-lbl">{cyc}</text>'
                )
        elif n > 20:
            if i % 2 == 0:
                lines.append(
                    f'<text x="{cx}" y="79" class="cyc-lbl">{cyc}</text>'
                )
        else:
            lines.append(f'<text x="{cx}" y="79" class="cyc-lbl">{cyc}</text>')

    y = 95
    spacing = 38

    draw_digital_bus(
        lines,
        "Commit PC",
        "Retired instruction PC",
        y,
        rows,
        width,
        lambda r: hex32(r["CommitPC0"]),
        lambda v: "#dcfce7" if v != 0 else "#ffffff",
        lambda v, bw: pc_label(v) if (v != 0 and bw > 30) else ("" if v == 0 else f"0x{v:X}"),
    )
    y += spacing

    draw_digital_bus(
        lines,
        "Trap Valid & Cause",
        "Exception/Interrupt Trigger",
        y,
        rows,
        width,
        lambda r: (r["TrapValid"], hex32(r["TrapCause"])),
        lambda v: "#fecaca" if v[0] == "1" else "#ffffff",
        lambda v, bw: (f"TRAP: 0x{v[1]:08X}" if v[1] == 0x80000007 else (f"EXT_IRQ: 0x{v[1]:08X}" if v[1] == 0x8000000B else f"0x{v[1]:X}")) if v[0] == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "MRET Instruction",
        "Privileged Return Executed",
        y,
        rows,
        width,
        lambda r: r["Mret"],
        lambda v: "#fed7aa" if v == "1" else "#ffffff",
        lambda v, bw: "MRET" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "WFI Sleep & Halt",
        "wfi_q / halt_csr_o",
        y,
        rows,
        width,
        lambda r: (r["WfiQ"], r["HaltCsr"]),
        lambda v: "#e0e7ff" if (v[0] == "1" or v[1] == "1") else "#ffffff",
        lambda v, bw: "WFI SLEEP / HALTED" if (v[0] == "1" or v[1] == "1") and bw > 40 else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "time_irq Pin",
        "Top-level Timer Interrupt",
        y,
        rows,
        width,
        lambda r: r["TimeIrq"],
        lambda v: "#fef08a" if v == "1" else "#ffffff",
        lambda v, bw: "TIME_IRQ=1" if v == "1" else "0",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "irq[0] External Pin",
        "Platform External Interrupt",
        y,
        rows,
        width,
        lambda r: r["ExtIrq"],
        lambda v: "#fef08a" if v == "1" else "#ffffff",
        lambda v, bw: "EXT_IRQ=1" if v == "1" else "0",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "mstatus.MIE",
        "Global Interrupt Enable Flag",
        y,
        rows,
        width,
        lambda r: r["MstatusMie"],
        lambda v: "#bbf7d0" if v == "1" else "#fecdd3",
        lambda v, bw: "MIE=1 (ENABLED)" if v == "1" else "MIE=0 (MASKED)",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "mip.MTIP / MEIP",
        "Pending Interrupt Bits in CSR",
        y,
        rows,
        width,
        lambda r: (r["MipMtip"], r["MipMeip"]),
        lambda v: "#fbcfe8" if (v[0] == "1" or v[1] == "1") else "#ffffff",
        lambda v, bw: ("MTIP=1" if v[0] == "1" else "MEIP=1") if (v[0] == "1" or v[1] == "1") else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "GPR Write",
        "Register File Writeback",
        y,
        rows,
        width,
        lambda r: (r["GprWe0"], r["GprWaddr0"], hex32(r["GprWdata0"])),
        lambda v: "#e2e8f0" if v[0] == "1" else "#ffffff",
        lambda v, bw: f"x{v[1]} = 0x{v[2]:X}" if v[0] == "1" and bw > 40 else "",
    )
    y += spacing

    lines.append("</svg>")
    with open(out_file, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print(f"Generated: {out_file}")


def main():
    rows = read_trace()
    if not rows:
        print(f"Warning: No trace data found at {CSV_PATH}")
        return
    print(f"Loaded {len(rows)} trace rows from {CSV_PATH}")

    # Figure 1: Full Execution Timeline (Cycle 260 to 360)
    fig1_rows = rows_in_window(rows, 260, 360)
    if fig1_rows:
        draw_waveform(
            fig1_rows,
            "CVA6 Suite 8: Asynchronous Interrupts, WFI Sleep & Return Resumption Timeline",
            "Overview of Timer MTIP, mstatus.MIE masking, trap vectoring, WFI halt state, and External MEIP wakeup",
            os.path.join(FIG_DIR, "01_execution_timeline.svg"),
        )

    # Figure 2: Timer Interrupt Masking & Unmasking (Cycles 265 to 305)
    fig2_rows = rows_in_window(rows, 265, 305)
    if fig2_rows:
        draw_waveform(
            fig2_rows,
            "CVA6 Suite 8: Timer Interrupt (MTIP) Masking, Unmasking & Vectored Trap",
            "time_irq asserting while mstatus.MIE=0; delayed trap upon csrsi mstatus, 8; mtvec vectoring and MRET",
            os.path.join(FIG_DIR, "02_timer_interrupt_masking_and_unmasking.svg"),
        )

    # Figure 3: WFI Low-Power Sleep & Wakeup via External Interrupt (Cycles 305 to 345)
    fig3_rows = rows_in_window(rows, 305, 345)
    if fig3_rows:
        draw_waveform(
            fig3_rows,
            "CVA6 Suite 8: WFI Sleep State, Pipeline Halt & External Interrupt (MEIP) Wakeup",
            "Execution of WFI entering halt (halt_csr_o=1); assertion of irq[0]; un-halting and vectoring to mtvec",
            os.path.join(FIG_DIR, "03_wfi_sleep_and_wake_by_external_irq.svg"),
        )

    # Figure 4: MRET Return Resumption & Privilege State Restoration (Cycles 290 to 330)
    fig4_rows = rows_in_window(rows, 290, 330)
    if fig4_rows:
        draw_waveform(
            fig4_rows,
            "CVA6 Suite 8: MRET Return Resumption & Privilege State Restoration",
            "Restoration of mstatus.MIE from MPIE and exact return to mepc PC following trap service routine",
            os.path.join(FIG_DIR, "04_mret_resumption_and_status_restoration.svg"),
        )

    print("All Suite 8 SVGs generated successfully.")


if __name__ == "__main__":
    main()
