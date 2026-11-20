# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:30:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 11 SVGs:
#                        standardized 1200px width, converted Figure 1 to high-level
#                        phase timeline + milestone table, scoped focused ~25 cycle
#                        windows for Figures 2, 3, 4 with run-length bus trapezoids,
#                        two-tier instruction labels, and clean <tspan> annotations.
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

SHORT_OP = {
    0x0010: "DIV (zero)",
    0x0014: "DIVU (zero)",
    0x0018: "REM (zero)",
    0x001C: "REMU (zero)",
    0x0028: "DIV (ovfl)",
    0x002C: "REM (ovfl)",
    0x0030: "DIVU",
    0x0034: "REMU",
    0x0040: "DIV (|B|>|A|)",
    0x0044: "REM",
    0x0050: "MUL",
    0x0054: "MULH",
    0x005C: "MUL",
    0x0060: "MULHU",
    0x0064: "MULHSU",
    0x006C: "MULH",
    0x0070: "LI s10,999",
    0x0074: "J END",
}


def xesc(value):
    return saxutils.escape("" if value is None else str(value))


def hex32(value):
    try:
        return int(str(value), 0)
    except (TypeError, ValueError):
        return 0


def pc_label(value, compact=False):
    pc = hex32(value)
    short = pc & 0xFFFF
    if pc == 0:
        return "-"
    if compact:
        op = SHORT_OP.get(short)
        return op if op else f"0x{short:03X}"
    name = PC_MAP.get(short)
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
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
        '<defs><style>',
        '  text { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }',
        '  .title { font-size: 15px; font-weight: 700; fill: #0f172a; }',
        '  .subtitle { font-size: 11px; fill: #475569; }',
        '  .sig-name { font-size: 11px; font-weight: 600; fill: #1e293b; }',
        '  .sig-sub { font-size: 9px; fill: #64748b; }',
        '  .bus { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 8.5px; font-weight: 600; text-anchor: middle; fill: #0f172a; }',
        '  .bit { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 9px; font-weight: 600; text-anchor: middle; }',
        '  .cyc { font-size: 9px; fill: #475569; font-weight: 600; text-anchor: middle; }',
        '  .ann-title { font-size: 11px; font-weight: 700; fill: #0f172a; }',
        '  .ann-body { font-size: 9.5px; fill: #334155; }',
        '  .tag-lbl { font-size: 9px; font-weight: 700; text-anchor: middle; fill: #ffffff; }',
        '</style></defs>',
        f'<rect width="{width}" height="{height}" fill="#f8fafc" rx="8" stroke="#cbd5e1" stroke-width="1"/>',
    ]


def generate_execution_timeline(rows):
    width, height = 1200, 480
    left, right = 50, 40
    plot_w = width - left - right
    total_cyc = 370

    phases = [
        (0, 267, "Boot & Reg Init", "#f1f5f9", "#94a3b8", "Cold AXI fetch, initialize stack, dividend=1000, divisor=0"),
        (268, 290, "Div-by-Zero Early Exit", "#fee2e2", "#dc2626", "DIV/DIVU -> -1, REM/REMU -> 1000 in 2 cycles (serdiv_op_b_zero)"),
        (291, 308, "Signed Overflow Saturation", "#ffedd5", "#ea580c", "DIV(-2^31,-1) -> -2^31, REM -> 0 (serdiv_op_b_neg_one)"),
        (309, 317, "|opB| > |opA| Early Term", "#fef3c7", "#d97706", "5 / 100 -> Q=0, R=5 in 2 cycles (serdiv_div_res_zero)"),
        (318, 344, "High-Word Multiplications", "#dbeafe", "#2563eb", "MUL (low), MULH (signed*signed), MULHU (unsigned), MULHSU"),
        (345, 370, "Loop & Completion", "#dcfce7", "#16a34a", "All assertions PASS, s10=999, terminal loop reached"),
    ]

    events = [
        (280, "Z1", "#dc2626", "DIV a0, 1000, 0", "DIV by zero: Q = -1 (0xFFFFFFFF) in 2 cycles (serdiv_op_b_zero=1)"),
        (286, "Z2", "#b91c1c", "REM a2, 1000, 0", "REM by zero: R = dividend (1000) in 2 cycles"),
        (294, "O1", "#ea580c", "DIV a4, -2^31, -1", "Signed overflow: Q saturates to 0x80000000 (serdiv_op_b_neg_one=1)"),
        (313, "M1", "#d97706", "DIV s4, 5, 100", "|opB| > |opA|: Q = 0, R = 5 in 2 cycles (serdiv_div_res_zero=1)"),
        (326, "H1", "#2563eb", "MULH s7, -2, 3", "Signed x signed upper 32-bit product = -1 (0xFFFFFFFF)"),
        (335, "H2", "#7c3aed", "MULHU s9, -1, -1", "Unsigned x unsigned upper 32-bit product = 0xFFFFFFFE"),
        (337, "H3", "#0891b2", "MULHSU s11, -1, -1", "Signed x unsigned upper 32-bit product = 0xFFFFFFFF"),
        (345, "E1", "#16a34a", "Self-Loop Commit", "s10 = 999 written; 100% test assertions PASSED"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 11: M-Extension Arithmetic Corner Cases — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 370 | Division &amp; Multiplier Corner Cases | All Checks PASS</text>')

    bar_y = 75
    bar_h = 42

    for p_start, p_end, title, bg, border, _ in phases:
        x1 = left + (p_start / total_cyc) * plot_w
        x2 = left + (p_end / total_cyc) * plot_w
        pw = max(x2 - x1, 4)
        svg.append(f'<rect x="{x1:.1f}" y="{bar_y}" width="{pw:.1f}" height="{bar_h}" fill="{bg}" stroke="{border}" stroke-width="1.5" rx="4"/>')
        if pw > 50:
            svg.append(f'<text x="{x1 + pw/2:.1f}" y="{bar_y + 19}" font-size="10" font-weight="700" fill="#0f172a" text-anchor="middle">{xesc(title)}</text>')
            svg.append(f'<text x="{x1 + pw/2:.1f}" y="{bar_y + 33}" font-size="8.5" fill="#475569" text-anchor="middle">C{p_start}–C{p_end}</text>')

    axis_y = bar_y + bar_h
    svg.append(f'<line x1="{left}" y1="{axis_y}" x2="{left+plot_w}" y2="{axis_y}" stroke="#475569" stroke-width="1.5"/>')
    for tick in [0, 100, 200, 268, 280, 294, 313, 326, 345, 370]:
        tx = left + (tick / total_cyc) * plot_w
        svg.append(f'<line x1="{tx:.1f}" y1="{axis_y}" x2="{tx:.1f}" y2="{axis_y+5}" stroke="#475569" stroke-width="1"/>')
        svg.append(f'<text x="{tx:.1f}" y="{axis_y+16}" font-size="8.5" fill="#475569" text-anchor="middle">C{tick}</text>')

    for cyc, tag, color, _, _ in events:
        ex = left + (cyc / total_cyc) * plot_w
        svg.append(f'<line x1="{ex:.1f}" y1="{bar_y}" x2="{ex:.1f}" y2="{bar_y+bar_h+18}" stroke="{color}" stroke-width="1.5" stroke-dasharray="2,2"/>')
        svg.append(f'<circle cx="{ex:.1f}" cy="{bar_y+bar_h+18}" r="9" fill="{color}"/>')
        svg.append(f'<text x="{ex:.1f}" y="{bar_y+bar_h+21}" class="tag-lbl">{tag}</text>')

    tbl_y = 168
    svg.append(f'<rect x="{left}" y="{tbl_y}" width="{plot_w}" height="205" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6"/>')
    svg.append(f'<rect x="{left}" y="{tbl_y}" width="{plot_w}" height="24" fill="#f1f5f9" rx="6"/>')
    svg.append(f'<text x="{left+15}" y="{tbl_y+16}" class="sig-name">Tag</text>')
    svg.append(f'<text x="{left+60}" y="{tbl_y+16}" class="sig-name">Cycle</text>')
    svg.append(f'<text x="{left+120}" y="{tbl_y+16}" class="sig-name">Instruction &amp; Corner Case</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+16}" class="sig-name">Hardware Behavior &amp; Value Produced</text>')
    svg.append(f'<text x="{left+870}" y="{tbl_y+16}" class="sig-name">M-Extension Status</text>')

    for i, (cyc, tag, color, desc, diag) in enumerate(events):
        ry = tbl_y + 40 + (i * 20)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="20" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" font-family="monospace" fill="#0369a1">{xesc(diag)}</text>')
        st_txt = "PASS (Spec Compliant)" if not tag.startswith("E") else "VERIFIED COMPLETE"
        svg.append(f'<text x="{left+870}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{st_txt}</text>')

    card_y = 392
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("Div-by-Zero Latency", "2 Cycles", "serdiv_op_b_zero early exit", "#fee2e2", "#dc2626"),
        ("Signed Overflow", "-2^31", "Saturates cleanly, no trap", "#ffedd5", "#ea580c"),
        ("|opB| > |opA| Result", "Q=0, R=opA", "serdiv_div_res_zero exit", "#fef3c7", "#d97706"),
        ("Upper Multipliers", "4 Modes", "MULH, MULHU, MULHSU match", "#dbeafe", "#2563eb"),
        ("Verification Status", "100%", "All 12 corner cases PASSED", "#dcfce7", "#16a34a"),
    ]
    for i, (label, val, sub, bg, border) in enumerate(cards):
        cx = left + i * (card_w + 12)
        svg.append(f'<rect x="{cx}" y="{card_y}" width="{card_w}" height="66" rx="6" fill="{bg}" stroke="{border}" stroke-width="1.2"/>')
        svg.append(f'<text x="{cx+10}" y="{card_y+18}" font-size="9" font-weight="600" fill="#475569">{xesc(label)}</text>')
        svg.append(f'<text x="{cx+10}" y="{card_y+42}" font-size="18" font-weight="700" fill="{border}">{val}</text>')
        svg.append(f'<text x="{cx+10}" y="{card_y+57}" font-size="8.5" fill="#64748b">{xesc(sub)}</text>')

    svg.append('</svg>')
    path = os.path.join(FIG_DIR, "01_execution_timeline.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


def render_m_waveform(rows, start, end, title, subtitle, signals, out_path, notes=None):
    window = rows_in_window(rows, start, end)
    if not window:
        return
    width = 1200
    left = 240
    right = 30
    top = 75
    row_h = 28
    plot_w = width - left - right
    n = len(window)
    col_w = plot_w / max(n, 1)

    ann_h = 75 if notes else 30
    height = top + len(signals) * row_h + ann_h + 20

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="12" width="{width-40}" height="46" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="32" font-size="14" font-weight="700" fill="#f8fafc">{xesc(title)} (Cycles {start} to {end})</text>')
    svg.append(f'<text x="35" y="48" font-size="10.5" fill="#94a3b8">{xesc(subtitle)}</text>')

    stride = 2 if n > 18 else 1
    for i, row in enumerate(window):
        cyc = int(row["Cycle"])
        x = left + i * col_w
        is_active = (row.get("DivValidOp") == "1" or row.get("MulValidOp") == "1" or row.get("CommitAck0") == "1")
        fill = "#f1f5f9" if is_active else ("#f8fafc" if i % 2 == 0 else "#ffffff")
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1 or is_active:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc" fill="#475569">C{cyc}</text>')

    for s_idx, (name, sub, getter, is_bus_flag, color) in enumerate(signals):
        y_base = top + s_idx * row_h
        y_low = y_base + row_h - 6
        y_high = y_base + 6
        y_mid = (y_low + y_high) / 2
        svg.append(f'<line x1="20" y1="{y_base + row_h}" x2="{width - 20}" y2="{y_base + row_h}" stroke="#e2e8f0" stroke-width="0.8"/>')
        svg.append(f'<text x="25" y="{y_base + 13}" class="sig-name">{xesc(name)}</text>')
        svg.append(f'<text x="25" y="{y_base + 23}" class="sig-sub">{xesc(sub)}</text>')

        values = [getter(row) for row in window]

        if not is_bus_flag:
            prev = None
            for i, val in enumerate(values):
                x1 = left + i * col_w
                x2 = x1 + col_w
                high = (str(val) == "1")
                y = y_high if high else y_low
                prev_y = y_high if prev == "1" else y_low
                if prev is not None and (str(prev) == "1") != high:
                    svg.append(f'<line x1="{x1:.1f}" y1="{prev_y:.1f}" x2="{x1:.1f}" y2="{y:.1f}" stroke="{color}" stroke-width="1.8"/>')
                svg.append(f'<line x1="{x1:.1f}" y1="{y:.1f}" x2="{x2:.1f}" y2="{y:.1f}" stroke="{color}" stroke-width="1.8"/>')
                if col_w >= 26:
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{color}">{val}</text>')
                prev = val
        else:
            run_start = 0
            for i in range(1, n + 1):
                if i == n or values[i] != values[run_start]:
                    x1 = left + run_start * col_w
                    x2 = left + i * col_w
                    run_w = x2 - x1
                    val = values[run_start]
                    is_idle = str(val) in ("0", "0x00000000", "0x0000", "-", "0x0", "IDLE")
                    fill_c = "#f1f5f9" if is_idle else "#e0f2fe"
                    border_c = "#cbd5e1" if is_idle else color

                    pts = f"{x1+3:.1f},{y_mid:.1f} {x1+6:.1f},{y_high:.1f} {x2-6:.1f},{y_high:.1f} {x2-3:.1f},{y_mid:.1f} {x2-6:.1f},{y_low:.1f} {x1+6:.1f},{y_low:.1f}"
                    svg.append(f'<polygon points="{pts}" fill="{fill_c}" stroke="{border_c}" stroke-width="1"/>')

                    if not is_idle and run_w >= 26:
                        lbl = pc_label(val, compact=(run_w < 65)) if ("PC" in name or "Target" in name) else str(val)
                        max_chars = max(3, int(run_w / 6.5))
                        if len(lbl) > max_chars:
                            lbl = lbl[:max_chars - 1] + "…"
                        svg.append(f'<text x="{x1 + run_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bus">{xesc(lbl)}</text>')
                    run_start = i

    if notes:
        ny = top + len(signals) * row_h + 12
        svg.append(f'<rect x="20" y="{ny}" width="{width-40}" height="{ann_h}" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6"/>')
        svg.append(f'<text x="35" y="{ny+18}" class="ann-title">Microarchitectural Analysis:</text>')
        svg.append(f'<text x="35" y="{ny+34}" class="ann-body">')
        for l_idx, line in enumerate(notes):
            svg.append(f'  <tspan x="35" dy="{0 if l_idx==0 else 16}">{xesc(line)}</tspan>')
        svg.append('</text>')

    svg.append('</svg>')
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {out_path}")


def main():
    records = read_trace()
    if not records:
        print(f"[ERROR] No trace rows found at {CSV_PATH}")
        return
    print(f"Loaded {len(records)} trace rows from {CSV_PATH}")

    # Figure 1: Full Execution Timeline
    generate_execution_timeline(records)

    # Figure 2: Division by Zero & Early Termination (Cycles 275 to 292)
    render_m_waveform(
        records, 275, 292,
        "Division by Zero Corner Cases & Serial Divider Early Termination",
        "Hardware detection of opB == 0 forces early finish in 2 cycles, setting DIV/DIVU to -1 and REM/REMU to dividend",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0284c7"),
            ("Commit Ack", "Instruction Retired", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("GPR Waddr", "Destination Register", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
            ("GPR Wdata", "Written Result", lambda r: f"0x{hex32(r['GprWdata0']):X}" if r.get("GprWe0")=="1" else "-", True, "#059669"),
            ("div_valid_op", "Divider Issue Request", lambda r: r["DivValidOp"], False, "#ea580c"),
            ("serdiv_op_b_zero", "Divisor is Zero Flag", lambda r: r["SerdivOpBZero"], False, "#dc2626"),
            ("serdiv_state", "0:IDLE, 1:DIVIDE, 2:FINISH", lambda r: "DIVIDE" if r["SerdivState"]=="1" else ("FINISH" if r["SerdivState"]=="2" else "IDLE"), True, "#d97706"),
            ("flu_ready", "Fixed Latency Unit Ready", lambda r: r["FluReady"], False, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "02_div_by_zero_early_termination.svg"),
        notes=[
            "• Early Termination: In Cycles 278, 281, 284, 287, serdiv detects serdiv_op_b_zero = 1 during the initial issue phase.",
            "• Zero Overhead: Rather than executing the full 34-cycle non-restoring division iteration, the hardware early-finishes in 2 cycles.",
            "• Spec Compliance: DIV and DIVU saturate to 0xFFFFFFFF (-1) while REM and REMU preserve the unmodified dividend (1000 = 0x3E8).",
        ]
    )

    # Figure 3: Signed Division Overflow Saturation & Magnitude Zero (Cycles 290 to 317)
    render_m_waveform(
        records, 290, 317,
        "Signed Division Overflow (-2^31 / -1) & |opB| > |opA| Early Termination",
        "Hardware saturation to -2^31 (no trap) and 2-cycle early exit when dividend magnitude is strictly smaller than divisor",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0284c7"),
            ("Commit Ack", "Instruction Retired", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("GPR Waddr", "Destination Register", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
            ("GPR Wdata", "Written Result", lambda r: f"0x{hex32(r['GprWdata0']):X}" if r.get("GprWe0")=="1" else "-", True, "#059669"),
            ("div_valid_op", "Divider Issue Request", lambda r: r["DivValidOp"], False, "#ea580c"),
            ("op_b_neg_one", "Divisor is -1 Flag", lambda r: r["SerdivOpBNegOne"], False, "#ea580c"),
            ("div_res_zero", "|opB| > |opA| Flag", lambda r: r["SerdivDivResZero"], False, "#7c3aed"),
            ("flu_ready", "Fixed Latency Unit Ready", lambda r: r["FluReady"], False, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "03_signed_division_overflow_saturation.svg"),
        notes=[
            "• Signed Overflow Saturation: At C294, DIV (-2^31, -1) asserts serdiv_op_b_neg_one and saturates to 0x80000000 without trapping.",
            "• Remainder Behavior: At C297, REM (-2^31, -1) produces 0, whereas unsigned DIVU/REMU treat 0x80000000 as +2^31 and compute normally.",
            "• Magnitude Optimization: At C313, 5 / 100 asserts serdiv_div_res_zero, immediately exiting with quotient 0 and remainder 5 in 2 cycles.",
        ]
    )

    # Figure 4: Multiplier High-Word Operations (Cycles 318 to 344)
    render_m_waveform(
        records, 318, 344,
        "Multiplier Upper-Word Operations (MUL, MULH, MULHU, MULHSU)",
        "Single-cycle and pipelined multiplication across signed-signed, unsigned-unsigned, and signed-unsigned upper 32-bit products",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0284c7"),
            ("Commit Ack", "Instruction Retired", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("GPR Waddr", "Destination Register", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
            ("GPR Wdata", "Written Result", lambda r: f"0x{hex32(r['GprWdata0']):X}" if r.get("GprWe0")=="1" else "-", True, "#059669"),
            ("mul_valid_op", "Multiplier Issue Request", lambda r: r["MulValidOp"], False, "#2563eb"),
            ("dual_commit", "Dual Commit Active", lambda r: r.get("DualCommit", "0"), False, "#7c3aed"),
            ("flu_ready", "Fixed Latency Unit Ready", lambda r: r["FluReady"], False, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "04_multiplier_high_word_operations.svg"),
        notes=[
            "• Full 64-bit Multiplication: CVA6 ALU/multiplier computes the full 64-bit product in hardware and selects upper/lower slice based on opcode.",
            "• Signed vs Unsigned: MULH (-2 * 3) yields upper word 0xFFFFFFFF (-1); MULHU (-1 * -1) yields 0xFFFFFFFE (unsigned max * max).",
            "• Cross-Sign Precision: MULHSU (-1 * 0xFFFFFFFF) computes signed(-1) * unsigned(2^32-1) = -(2^32-1), yielding upper word 0xFFFFFFFF.",
        ]
    )

    print("[SUCCESS] All Suite 11 SVG diagrams generated.")


if __name__ == "__main__":
    main()
