# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:40:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform and architectural timing diagram generator
#                        for Suite 11 (M-Extension Arithmetic Corner Cases:
#                        Division by zero, signed overflow -2^31/-1, magnitude
#                        |opB| > |opA| early termination, and high-word multiplier
#                        operations MULH, MULHU, and MULHSU). Reads cva6_m_extension_trace.csv.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_m_extension_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp,0x80000",
    0x0004: "ADDI sp,512",
    0x0008: "LI gp,1000",
    0x000C: "LI tp,0",
    0x0010: "DIV a0,gp,tp",
    0x0014: "DIVU a1,gp,tp",
    0x0018: "REM a2,gp,tp",
    0x001C: "REMU a3,gp,tp",
    0x0020: "LUI s2,0x80000",
    0x0024: "LI s3,-1",
    0x0028: "DIV a4,s2,s3",
    0x002C: "REM a5,s2,s3",
    0x0030: "DIVU a6,s2,s3",
    0x0034: "REMU a7,s2,s3",
    0x0038: "LI t0,5",
    0x003C: "LI t1,100",
    0x0040: "DIV s4,t0,t1",
    0x0044: "REM s5,t0,t1",
    0x0048: "LI t2,-2",
    0x004C: "LI t3,3",
    0x0050: "MUL s6,t2,t3",
    0x0054: "MULH s7,t2,t3",
    0x0058: "LI t4,-1",
    0x005C: "MUL s8,t4,t4",
    0x0060: "MULHU s9,t4,t4",
    0x0064: "MULHSU s11,t4,t4",
    0x0068: "LUI t5,0x40000",
    0x006C: "MULH t6,t5,s2",
    0x0070: "LI s10,999",
    0x0074: "J END_LOOP",
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
        "GPR Write",
        "Destination reg & result",
        y,
        rows,
        width,
        lambda r: (r["GprWe0"], r["GprWaddr0"], hex32(r["GprWdata0"])),
        lambda v: "#e0f2fe" if v[0] == "1" else "#ffffff",
        lambda v, bw: f"x{v[1]} = 0x{v[2]:X}" if v[0] == "1" and bw > 40 else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "div_valid_op",
        "Divider active request",
        y,
        rows,
        width,
        lambda r: r["DivValidOp"],
        lambda v: "#fed7aa" if v == "1" else "#ffffff",
        lambda v, bw: "DIV_OP" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "mul_valid_op",
        "Multiplier active request",
        y,
        rows,
        width,
        lambda r: r["MulValidOp"],
        lambda v: "#fbcfe8" if v == "1" else "#ffffff",
        lambda v, bw: "MUL_OP" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "serdiv_op_b_zero",
        "Div-by-zero detection",
        y,
        rows,
        width,
        lambda r: r["SerdivOpBZero"],
        lambda v: "#fecaca" if v == "1" else "#ffffff",
        lambda v, bw: "DIV_BY_ZERO" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "serdiv_op_b_neg_one",
        "Signed overflow (-1 divisor)",
        y,
        rows,
        width,
        lambda r: r["SerdivOpBNegOne"],
        lambda v: "#fef08a" if v == "1" else "#ffffff",
        lambda v, bw: "DIV_BY_-1 (OVERFLOW)" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "serdiv_div_res_zero",
        "|opB| > |opA| detected",
        y,
        rows,
        width,
        lambda r: r["SerdivDivResZero"],
        lambda v: "#ddd6fe" if v == "1" else "#ffffff",
        lambda v, bw: "|opB|>|opA| ZERO" if v == "1" else "",
    )
    y += spacing

    draw_digital_bus(
        lines,
        "serdiv_state",
        "0:IDLE, 1:DIVIDE, 2:FINISH",
        y,
        rows,
        width,
        lambda r: int(r["SerdivState"]),
        lambda v: "#ffffff" if v == 0 else ("#fde68a" if v == 1 else "#bbf7d0"),
        lambda v, bw: "IDLE" if v == 0 else ("DIVIDE" if v == 1 else "FINISH"),
    )
    y += spacing

    draw_digital_bus(
        lines,
        "flu_ready",
        "Fixed Latency Unit Ready",
        y,
        rows,
        width,
        lambda r: r["FluReady"],
        lambda v: "#bbf7d0" if v == "1" else "#fee2e2",
        lambda v, bw: "FLU_READY" if v == "1" else "STALLED",
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
            "CVA6 Suite 11: M-Extension Arithmetic Corner Cases Execution Timeline",
            "Overview of Division by Zero, Signed Overflow, |opB|>|opA| Early Termination, and Upper-Word Multiplications",
            os.path.join(FIG_DIR, "01_execution_timeline.svg"),
        )

    # Figure 2: Division by Zero & Early Termination (Cycles 265 to 295)
    fig2_rows = rows_in_window(rows, 265, 295)
    if fig2_rows:
        draw_waveform(
            fig2_rows,
            "CVA6 Suite 11: Division by Zero Corner Cases & Early Termination",
            "div/divu returning -1 (0xFFFFFFFF) and rem/remu returning dividend (1000) with serdiv_op_b_zero early finish",
            os.path.join(FIG_DIR, "02_div_by_zero_early_termination.svg"),
        )

    # Figure 3: Signed Division Overflow Saturation (-2^31 / -1) (Cycles 290 to 320)
    fig3_rows = rows_in_window(rows, 290, 320)
    if fig3_rows:
        draw_waveform(
            fig3_rows,
            "CVA6 Suite 11: Signed Division Overflow (-2^31 / -1) Saturation & Remainder",
            "div(-2^31, -1) saturating to 0x80000000, rem returning 0, and unsigned divu/remu comparison",
            os.path.join(FIG_DIR, "03_signed_division_overflow_saturation.svg"),
        )

    # Figure 4: Multiplier Upper 32-bit Words (MUL, MULH, MULHU, MULHSU) (Cycles 315 to 355)
    fig4_rows = rows_in_window(rows, 315, 355)
    if fig4_rows:
        draw_waveform(
            fig4_rows,
            "CVA6 Suite 11: Multiplier Upper-Word Operations (MUL, MULH, MULHU, MULHSU)",
            "Upper 32-bit products: signed x signed (-1), unsigned x unsigned (0xFFFFFFFE), and signed x unsigned (0xFFFFFFFF)",
            os.path.join(FIG_DIR, "04_multiplier_high_word_operations.svg"),
        )

    print("All Suite 11 SVGs generated successfully.")


if __name__ == "__main__":
    main()
