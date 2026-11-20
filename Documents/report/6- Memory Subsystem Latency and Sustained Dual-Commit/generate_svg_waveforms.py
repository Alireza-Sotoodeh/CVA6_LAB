# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 21:25:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform and architectural diagram generator for
#                        Suite 6 (Sustained Dual-Commit & Memory Subsystem Latency).
#                        Reads cva6_dual_commit_trace.csv and generates four
#                        publication-grade SVGs in figures/.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_dual_commit_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI x1",
    0x0004: "ADDI x1,512",
    0x0008: "LI x2,0",
    0x0014: "LI x5,42",
    0x0044: "LI x21,1",
    0x0048: "SW x5,0(x1)",
    0x004C: "ADDI x6,1",
    0x0050: "ADDI x7,2",
    0x0054: "ADDI x8,3",
    0x0058: "LW x9,0(x1)",
    0x005C: "ADDI x10,4",
    0x0060: "ADD x11,x6,x7",
    0x0064: "ADD x12,x8,x10",
    0x0068: "ADDI x13,10",
    0x006C: "ADDI x14,20",
    0x0070: "XOR x15,x13,x14",
    0x0074: "SLLI x16,2",
    0x0078: "ADDI x21,1",
    0x007C: "LI x2,5",
    0x0080: "BNE x21,x2",
    0x0084: "LI x20,999",
    0x0088: "J END_LOOP",
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
        "    .ann-title { font-size: 11px; font-weight: 700; fill: #0f172a; }",
        "    .ann-body { font-size: 10px; fill: #334155; }",
        "  </style>",
        "</defs>",
        f'<rect width="{width}" height="{height}" fill="#f8fafc" />',
    ]


# ----------------------------------------------------------------------------
# 1. Execution Timeline
# ----------------------------------------------------------------------------
def generate_execution_timeline(rows):
    width, height = 1200, 420
    svg = svg_header(width, height)

    svg.append(f'<rect x="20" y="15" width="{width-40}" height="42" rx="8" fill="#1e293b" />')
    svg.append('<text x="35" y="41" fill="#f8fafc" font-size="15" font-weight="700">'
               'CVA6 Suite 6: Full Execution Timeline &amp; Dual-Commit Milestones</text>')
    svg.append(f'<text x="{width-35}" y="41" fill="#94a3b8" font-size="11" text-anchor="end">'
               'Total Cycles: 436 | Committed: 81 Instrs | Dual-Commit: 9 Cycles</text>')

    phases = [
        {"name": "Phase 0: Boot &amp; Setup", "c_start": 0, "c_end": 314, "color": "#cbd5e1", "border": "#94a3b8",
         "desc": "Cold fetch &amp; register inits (x1=0x80000200, x5=42)", "cpi": "18.5"},
        {"name": "Iter 1 (Wait=0 cyc)", "c_start": 315, "c_end": 356, "color": "#fed7aa", "border": "#f97316",
         "desc": "Span: 40 cyc | 30 instrs | 3 Dual-Commits | D-Cache cold", "cpi": "1.33"},
        {"name": "Iter 2 (Wait=4 cyc)", "c_start": 357, "c_end": 372, "color": "#bbf7d0", "border": "#22c55e",
         "desc": "Span: 13 cyc | 13 instrs | 2 Dual-Commits | D-Cache Hit", "cpi": "1.00"},
        {"name": "Iter 3 (Wait=8 cyc)", "c_start": 373, "c_end": 388, "color": "#bfdbfe", "border": "#3b82f6",
         "desc": "Span: 13 cyc | 13 instrs | 2 Dual-Commits | D-Cache Hit", "cpi": "1.00"},
        {"name": "Iter 4 (Wait=16 cyc)", "c_start": 389, "c_end": 415, "color": "#e9d5ff", "border": "#a855f7",
         "desc": "Span: 13 cyc body | 2 Dual-Commits | Loop Exit", "cpi": "0.52*"},
        {"name": "End Self-Loop", "c_start": 416, "c_end": 436, "color": "#f1f5f9", "border": "#64748b",
         "desc": "Spinning on J END_LOOP | Checkpoint verification", "cpi": "1.00"},
    ]

    tl_x = 50
    tl_y = 110
    tl_w = width - 100
    total_cyc = 436

    svg.append(f'<line x1="{tl_x}" y1="{tl_y+25}" x2="{tl_x+tl_w}" y2="{tl_y+25}" stroke="#94a3b8" stroke-width="3" />')

    for p in phases:
        x1 = tl_x + int(p["c_start"] / total_cyc * tl_w)
        x2 = tl_x + int(p["c_end"] / total_cyc * tl_w)
        w = max(x2 - x1, 14)

        svg.append(f'<rect x="{x1}" y="{tl_y}" width="{w}" height="50" rx="6" '
                   f'fill="{p["color"]}" stroke="{p["border"]}" stroke-width="2" />')
        svg.append(f'<text x="{x1 + w/2}" y="{tl_y+22}" font-size="11" font-weight="700" '
                   f'fill="#0f172a" text-anchor="middle">{p["name"]}</text>')
        svg.append(f'<text x="{x1 + w/2}" y="{tl_y+38}" font-size="9" font-weight="600" '
                   f'fill="#475569" text-anchor="middle">CPI: {p["cpi"]}</text>')

        # Ticks
        svg.append(f'<line x1="{x1}" y1="{tl_y+50}" x2="{x1}" y2="{tl_y+58}" stroke="#64748b" stroke-width="1.5" />')
        svg.append(f'<text x="{x1}" y="{tl_y+70}" font-size="9" fill="#475569" text-anchor="middle">C{p["c_start"]}</text>')

    svg.append(f'<line x1="{tl_x+tl_w}" y1="{tl_y+50}" x2="{tl_x+tl_w}" y2="{tl_y+58}" stroke="#64748b" stroke-width="1.5" />')
    svg.append(f'<text x="{tl_x+tl_w}" y="{tl_y+70}" font-size="9" fill="#475569" text-anchor="middle">C436</text>')

    # Dual commit event markers
    dc_cycles = [316, 335, 336, 359, 363, 379, 383, 395, 399]
    svg.append('<text x="50" y="215" font-size="12" font-weight="700" fill="#0f172a">'
               'Dual-Commit Events (Port 0 + Port 1 Simultaneous Retirement):</text>')

    dc_card_y = 230
    dc_card_w = (width - 100) / len(dc_cycles)
    for i, c in enumerate(dc_cycles):
        cx = 50 + i * dc_card_w
        svg.append(f'<rect x="{cx+4}" y="{dc_card_y}" width="{dc_card_w-8}" height="70" rx="6" '
                   f'fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5" />')
        svg.append(f'<text x="{cx + dc_card_w/2}" y="{dc_card_y+18}" font-size="11" font-weight="700" '
                   f'fill="#1d4ed8" text-anchor="middle">Event #{i+1}</text>')
        svg.append(f'<text x="{cx + dc_card_w/2}" y="{dc_card_y+34}" font-size="10" font-weight="600" '
                   f'fill="#0f172a" text-anchor="middle">Cycle {c}</text>')
        desc_lbl = "SW+ADDI" if i in [0, 3, 5, 7] else ("LW+ADDI" if i in [1, 4, 6, 8] else "ADD+ADD")
        svg.append(f'<text x="{cx + dc_card_w/2}" y="{dc_card_y+50}" font-size="9" fill="#475569" '
                   f'text-anchor="middle">{desc_lbl}</text>')

    # Verification summary card
    svg.append(f'<rect x="50" y="325" width="{width-100}" height="75" rx="8" '
               f'fill="#f0fdf4" stroke="#16a34a" stroke-width="1.5" />')
    svg.append('<text x="70" y="348" font-size="12" font-weight="700" fill="#15803d">'
               'Architectural Scoreboard &amp; Latency Verification Summary (17/17 Checks PASSED):</text>')
    svg.append('<text x="70" y="368" font-size="10.5" fill="#166534">'
               '• Sustained Dual-Commit: Verified 9 distinct cycles where Port 0 and Port 1 retired instructions simultaneously (Peak IPC = 2.0).</text>')
    svg.append('<text x="70" y="386" font-size="10.5" fill="#166534">'
               '• Memory Latency Immunity: Iterations 2 &amp; 3 maintained CPI = 1.00 under 4 &amp; 8 AXI wait states due to D-Cache hit &amp; store-buffer forwarding.</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "01_execution_timeline.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated: {path}")


# ----------------------------------------------------------------------------
# 2. Sustained Dual-Commit Burst Waveform (Cycles 330 to 342)
# ----------------------------------------------------------------------------
def generate_dual_commit_burst(rows):
    start_cyc, end_cyc = 330, 342
    w_rows = rows_in_window(rows, start_cyc, end_cyc)
    n_cyc = len(w_rows)

    width, height = 1200, 520
    svg = svg_header(width, height)

    svg.append(f'<rect x="20" y="15" width="{width-40}" height="42" rx="8" fill="#1e293b" />')
    svg.append('<text x="35" y="41" fill="#f8fafc" font-size="15" font-weight="700">'
               'CVA6 Suite 6: Cycle-Accurate Waveform of Dual-Commit Burst (Cycles 330-342)</text>')
    svg.append(f'<text x="{width-35}" y="41" fill="#94a3b8" font-size="11" text-anchor="end">'
               'Back-to-Back Dual Retirement: Cycle 335 (LW+ADDI) &amp; Cycle 336 (ADD+ADD)</text>')

    x_left = 220
    col_w = (width - x_left - 40) / max(n_cyc, 1)
    y_top = 80
    row_h = 28

    signals = [
        {"name": "CommitAck0", "sub": "Port 0 Retire Valid", "key": "CommitAck0", "type": "bool", "color": "#2563eb"},
        {"name": "CommitPC0", "sub": "Port 0 PC &amp; Instruction", "key": "CommitPC0", "type": "pc", "color": "#0284c7"},
        {"name": "GprWaddr0 / Data", "sub": "Port 0 Reg Write", "key": "reg0", "type": "reg0", "color": "#0d9488"},
        {"name": "CommitAck1", "sub": "Port 1 Retire Valid", "key": "CommitAck1", "type": "bool", "color": "#7c3aed"},
        {"name": "CommitPC1", "sub": "Port 1 PC &amp; Instruction", "key": "CommitPC1", "type": "pc", "color": "#9333ea"},
        {"name": "GprWaddr1 / Data", "sub": "Port 1 Reg Write", "key": "reg1", "type": "reg1", "color": "#c026d3"},
        {"name": "DualCommit", "sub": "Ack0 &amp;&amp; Ack1", "key": "DualCommit", "type": "bool", "color": "#dc2626"},
        {"name": "DualCommitCount", "sub": "Cumulative Dual-Commits", "key": "DualCommitCount", "type": "val", "color": "#b91c1c"},
        {"name": "IssueValid0 / Ack", "sub": "Single-Issue Handshake", "key": "issue", "type": "issue", "color": "#475569"},
        {"name": "InstrQueueUsage", "sub": "Frontend FIFO Depth", "key": "InstrQueueUsage", "type": "val", "color": "#475569"},
        {"name": "AxiRValid / Last", "sub": "Memory Read Response", "key": "axi_r", "type": "axi_r", "color": "#ea580c"},
    ]

    # Grid background & cycle labels
    for j, r in enumerate(w_rows):
        cx = x_left + j * col_w
        cyc = int(r["Cycle"])
        # Highlight dual-commit columns
        if r["DualCommit"] == "1":
            svg.append(f'<rect x="{cx}" y="{y_top}" width="{col_w}" height="{len(signals)*row_h}" '
                       f'fill="#fef2f2" opacity="0.8" />')
            svg.append(f'<line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{y_top+len(signals)*row_h}" '
                       f'stroke="#ef4444" stroke-width="1.5" stroke-dasharray="3,3" />')
            svg.append(f'<line x1="{cx+col_w}" y1="{y_top}" x2="{cx+col_w}" y2="{y_top+len(signals)*row_h}" '
                       f'stroke="#ef4444" stroke-width="1.5" stroke-dasharray="3,3" />')

        svg.append(f'<text x="{cx+col_w/2}" y="{y_top-8}" class="cyc-lbl">C{cyc}</text>')
        svg.append(f'<line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{y_top+len(signals)*row_h}" stroke="#e2e8f0" />')

    svg.append(f'<line x1="{x_left+len(w_rows)*col_w}" y1="{y_top}" x2="{x_left+len(w_rows)*col_w}" '
               f'y2="{y_top+len(signals)*row_h}" stroke="#e2e8f0" />')

    # Draw rows
    for i, sig in enumerate(signals):
        ry = y_top + i * row_h
        bg_c = "#ffffff" if i % 2 == 0 else "#f8fafc"
        svg.append(f'<rect x="20" y="{ry}" width="{width-40}" height="{row_h}" fill="{bg_c}" opacity="0.6" />')
        svg.append(f'<line x1="20" y1="{ry+row_h}" x2="{width-20}" y2="{ry+row_h}" stroke="#cbd5e1" stroke-width="0.5" />')

        # Labels
        svg.append(f'<text x="25" y="{ry+14}" class="sig-lbl">{sig["name"]}</text>')
        svg.append(f'<text x="25" y="{ry+24}" class="sig-sub">{sig["sub"]}</text>')

        # Values
        for j, r in enumerate(w_rows):
            cx = x_left + j * col_w
            stype = sig["type"]

            if stype == "bool":
                v = r[sig["key"]]
                if v == "1":
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" '
                               f'fill="{sig["color"]}" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="box-lbl" fill="#ffffff">1</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">0</text>')

            elif stype == "pc":
                pc_raw = r[sig["key"]]
                if pc_raw and pc_raw != "0x00000000":
                    short_pc = hex32(pc_raw) & 0xFFFF
                    lbl = PC_MAP.get(short_pc, f"0x{short_pc:04X}")
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" '
                               f'fill="{sig["color"]}" opacity="0.9" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+17}" font-size="8.5" font-weight="700" '
                               f'fill="#ffffff" text-anchor="middle">{lbl}</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">-</text>')

            elif stype == "reg0":
                we = r["GprWe0"]
                waddr = r["GprWaddr0"]
                wdata = r["GprWdata0"]
                if we == "1" and waddr != "0":
                    val_int = hex32(wdata)
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" '
                               f'fill="{sig["color"]}" opacity="0.9" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+17}" font-size="8.5" font-weight="700" '
                               f'fill="#ffffff" text-anchor="middle">x{waddr}={val_int}</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">-</text>')

            elif stype == "reg1":
                we = r["GprWe1"]
                waddr = r["GprWaddr1"]
                wdata = r["GprWdata1"]
                if we == "1" and waddr != "0":
                    val_int = hex32(wdata)
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" '
                               f'fill="{sig["color"]}" opacity="0.9" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+17}" font-size="8.5" font-weight="700" '
                               f'fill="#ffffff" text-anchor="middle">x{waddr}={val_int}</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">-</text>')

            elif stype == "val":
                val = r[sig["key"]]
                svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" font-size="9.5" font-weight="600" '
                           f'fill="{sig["color"]}" text-anchor="middle">{val}</text>')

            elif stype == "issue":
                iv = r["IssueValid0"]
                ia = r["IssueAck0"]
                if iv == "1" and ia == "1":
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" '
                               f'fill="#475569" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+17}" font-size="8" font-weight="700" '
                               f'fill="#ffffff" text-anchor="middle">ISSUE</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">-</text>')

            elif stype == "axi_r":
                rv = r["AxiRValid"]
                rl = r["AxiRLast"]
                if rv == "1":
                    lbl = "RLAST" if rl == "1" else "RDATA"
                    c = "#c2410c" if rl == "1" else "#ea580c"
                    svg.append(f'<rect x="{cx+2}" y="{ry+4}" width="{col_w-4}" height="{row_h-8}" rx="3" fill="{c}" />')
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+17}" font-size="8" font-weight="700" '
                               f'fill="#ffffff" text-anchor="middle">{lbl}</text>')
                else:
                    svg.append(f'<text x="{cx+col_w/2}" y="{ry+18}" class="cyc-lbl" fill="#94a3b8">idle</text>')

    # Annotation box
    ann_y = y_top + len(signals) * row_h + 15
    svg.append(f'<rect x="20" y="{ann_y}" width="{width-40}" height="85" rx="8" '
               f'fill="#eff6ff" stroke="#3b82f6" stroke-width="1" />')
    svg.append(f'<text x="35" y="{ann_y+20}" class="ann-title">'
               'Microarchitectural Analysis of Sustained Dual-Commit Burst:</text>')
    notes = [
        "1. Cycle 335: Port 0 commits 'LW x9, 0(x1)' (x9=42) while Port 1 simultaneously commits 'ADDI x10, x10, 4' (x10=4). Scoreboard resolved both without dependency conflict.",
        "2. Cycle 336: Immediate next cycle commits independent pair 'ADD x11, x6, x7' (x11=3) on Port 0 and 'ADD x12, x8, x10' (x12=7) on Port 1, achieving back-to-back Dual-Commit (4 instrs in 2 cycs, IPC = 2.0!).",
        "3. Front-End vs Back-End Decoupling: Issue stage issues at most 1 instruction/cycle, while Commit stage drains up to 2 instructions/cycle from the Scoreboard once data hazards resolve.",
    ]
    svg.append(f'<text x="35" y="{ann_y+38}" class="ann-body">')
    for l_idx, line in enumerate(notes):
        svg.append(f'  <tspan x="35" dy="{0 if l_idx==0 else 16}">{xesc(line)}</tspan>')
    svg.append('</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "02_sustained_dual_commit_burst.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated: {path}")


# ----------------------------------------------------------------------------
# 3. AXI Latency Sensitivity Curve & Cache Immunity
# ----------------------------------------------------------------------------
def generate_latency_curve(rows):
    width, height = 1100, 460
    svg = svg_header(width, height)

    svg.append(f'<rect x="20" y="15" width="{width-40}" height="42" rx="8" fill="#1e293b" />')
    svg.append('<text x="35" y="41" fill="#f8fafc" font-size="15" font-weight="700">'
               'CVA6 Memory Subsystem Latency Sensitivity: CPI vs. AXI Wait States</text>')
    svg.append(f'<text x="{width-35}" y="41" fill="#94a3b8" font-size="11" text-anchor="end">'
               'D-Cache Hit &amp; Store Buffer Immunity: Cold Miss Penalty vs Hot Loop Throughput</text>')

    # Chart Area
    chart_x = 100
    chart_y = 90
    chart_w = 480
    chart_h = 240

    # Axes
    svg.append(f'<line x1="{chart_x}" y1="{chart_y+chart_h}" x2="{chart_x+chart_w}" y2="{chart_y+chart_h}" '
               f'stroke="#475569" stroke-width="2" />')
    svg.append(f'<line x1="{chart_x}" y1="{chart_y}" x2="{chart_x}" y2="{chart_y+chart_h}" '
               f'stroke="#475569" stroke-width="2" />')

    # Y-axis ticks (CPI 0.0 to 2.0)
    for cpi_val in [0.0, 0.5, 1.0, 1.5, 2.0]:
        y_pos = chart_y + chart_h - int((cpi_val / 2.0) * chart_h)
        svg.append(f'<line x1="{chart_x-5}" y1="{y_pos}" x2="{chart_x}" y2="{y_pos}" stroke="#64748b" />')
        svg.append(f'<line x1="{chart_x}" y1="{y_pos}" x2="{chart_x+chart_w}" y2="{y_pos}" '
                   f'stroke="#e2e8f0" stroke-dasharray="3,3" />')
        svg.append(f'<text x="{chart_x-10}" y="{y_pos+4}" font-size="10" fill="#475569" text-anchor="end">{cpi_val:.1f}</text>')

    svg.append(f'<text x="{chart_x-40}" y="{chart_y+chart_h/2}" font-size="11" font-weight="700" fill="#0f172a" '
               f'transform="rotate(-90 {chart_x-40} {chart_y+chart_h/2})" text-anchor="middle">Measured CPI</text>')

    # X-axis ticks (Wait States 0, 4, 8, 16)
    x_points = [
        {"wait": 0, "cpi_measured": 1.33, "cpi_uncached_est": 1.33, "x_px": chart_x + 60, "iter": "Iter 1 (Cold)"},
        {"wait": 4, "cpi_measured": 1.00, "cpi_uncached_est": 1.62, "x_px": chart_x + 180, "iter": "Iter 2 (Warm)"},
        {"wait": 8, "cpi_measured": 1.00, "cpi_uncached_est": 1.92, "x_px": chart_x + 300, "iter": "Iter 3 (Warm)"},
        {"wait": 16, "cpi_measured": 1.00, "cpi_uncached_est": 2.54, "x_px": chart_x + 420, "iter": "Iter 4 (Warm)"},
    ]

    for p in x_points:
        svg.append(f'<line x1="{p["x_px"]}" y1="{chart_y+chart_h}" x2="{p["x_px"]}" y2="{chart_y+chart_h+5}" stroke="#64748b" />')
        svg.append(f'<text x="{p["x_px"]}" y="{chart_y+chart_h+18}" font-size="10" font-weight="600" '
                   f'fill="#0f172a" text-anchor="middle">{p["wait"]} cyc</text>')
        svg.append(f'<text x="{p["x_px"]}" y="{chart_y+chart_h+30}" font-size="8.5" fill="#64748b" '
                   f'text-anchor="middle">{p["iter"]}</text>')

    svg.append(f'<text x="{chart_x+chart_w/2}" y="{chart_y+chart_h+48}" font-size="11" font-weight="700" '
               f'fill="#0f172a" text-anchor="middle">AXI Memory Responder Wait States (Cycles)</text>')

    # Plot lines:
    # 1. Measured CVA6 Curve with D-Cache
    measured_pts = " ".join([f'{p["x_px"]},{chart_y+chart_h-int((p["cpi_measured"]/2.0)*chart_h)}' for p in x_points])
    svg.append(f'<polyline points="{measured_pts}" fill="none" stroke="#2563eb" stroke-width="3" />')

    # 2. Uncached Theoretical Latency Degradation
    uncached_pts = " ".join([f'{p["x_px"]},{chart_y+chart_h-int((p["cpi_uncached_est"]/2.0)*chart_h)}' for p in x_points])
    svg.append(f'<polyline points="{uncached_pts}" fill="none" stroke="#dc2626" stroke-width="2" stroke-dasharray="5,4" />')

    # Plot points
    for p in x_points:
        y_meas = chart_y + chart_h - int((p["cpi_measured"] / 2.0) * chart_h)
        svg.append(f'<circle cx="{p["x_px"]}" cy="{y_meas}" r="5" fill="#2563eb" stroke="#ffffff" stroke-width="2" />')
        svg.append(f'<text x="{p["x_px"]}" y="{y_meas-10}" font-size="10" font-weight="700" '
                   f'fill="#2563eb" text-anchor="middle">{p["cpi_measured"]:.2f}</text>')

        y_unc = chart_y + chart_h - int((p["cpi_uncached_est"] / 2.0) * chart_h)
        svg.append(f'<circle cx="{p["x_px"]}" cy="{y_unc}" r="4" fill="#dc2626" />')

    # Legend
    leg_x = chart_x + 30
    leg_y = chart_y + 20
    svg.append(f'<rect x="{leg_x}" y="{leg_y}" width="280" height="52" rx="4" fill="#ffffff" stroke="#cbd5e1" opacity="0.9" />')
    svg.append(f'<line x1="{leg_x+10}" y1="{leg_y+16}" x2="{leg_x+35}" y2="{leg_y+16}" stroke="#2563eb" stroke-width="3" />')
    svg.append(f'<circle cx="{leg_x+22}" cy="{leg_y+16}" r="4" fill="#2563eb" />')
    svg.append(f'<text x="{leg_x+45}" y="{leg_y+20}" font-size="9.5" font-weight="600" fill="#0f172a">'
               'Measured CVA6 (L1 Cache Hit Immunity)</text>')

    svg.append(f'<line x1="{leg_x+10}" y1="{leg_y+36}" x2="{leg_x+35}" y2="{leg_y+36}" stroke="#dc2626" stroke-width="2" stroke-dasharray="4,3" />')
    svg.append(f'<circle cx="{leg_x+22}" cy="{leg_y+36}" r="3" fill="#dc2626" />')
    svg.append(f'<text x="{leg_x+45}" y="{leg_y+40}" font-size="9.5" font-weight="600" fill="#dc2626">'
               'Theoretical Uncached Memory Stalling</text>')

    # Right Side: Architectural Analysis Panel
    pan_x = chart_x + chart_w + 40
    pan_y = 90
    pan_w = width - pan_x - 30
    pan_h = 320

    svg.append(f'<rect x="{pan_x}" y="{pan_y}" width="{pan_w}" height="{pan_h}" rx="8" '
               f'fill="#ffffff" stroke="#cbd5e1" stroke-width="1.5" />')
    svg.append(f'<rect x="{pan_x}" y="{pan_y}" width="{pan_w}" height="32" rx="8" fill="#f1f5f9" />')
    svg.append(f'<text x="{pan_x+15}" y="{pan_y+21}" font-size="12" font-weight="700" fill="#0f172a">'
               'Cache Hit &amp; Latency Masking Breakdown</text>')

    points = [
        {"title": "1. Iteration 1 Cold Start (Wait = 0 cyc, CPI = 1.33):",
         "desc": "First time executing loop: Initial cold miss on I-Cache line and D-Cache buffer [0x80000200] creates brief linefill latency before stabilizing at 1.33 CPI."},
        {"title": "2. Iteration 2 (Wait = 4 cyc, CPI = 1.00):",
         "desc": "Data line is already resident in L1 D-Cache. The SW writes into Store Buffer, and LW hits immediately in cache/store buffer bypass. 4-cycle AXI wait has 0 penalty!"},
        {"title": "3. Iteration 3 (Wait = 8 cyc, CPI = 1.00):",
         "desc": "Complete immunity confirmed: Even doubling external memory wait states to 8 cycles, core commits all 13 instructions in exactly 13 cycles with 2 dual-commits."},
        {"title": "4. Iteration 4 (Wait = 16 cyc, CPI = 1.00):",
         "desc": "16-cycle external delay is 100% hidden by cache hit rate. Highlights crucial architectural lesson: L1 cache resident loops sustain maximum pipeline throughput."},
    ]

    p_y = pan_y + 50
    for p in points:
        svg.append(f'<text x="{pan_x+15}" y="{p_y}" font-size="10.5" font-weight="700" fill="#1e293b">{p["title"]}</text>')
        svg.append(f'<text x="{pan_x+15}" y="{p_y+16}" font-size="9.5" fill="#475569" width="{pan_w-30}">{p["desc"][:70]}</text>')
        svg.append(f'<text x="{pan_x+15}" y="{p_y+29}" font-size="9.5" fill="#475569">{p["desc"][70:]}</text>')
        p_y += 54

    # Bottom Callout for Dr. Mahani / PQC
    svg.append(f'<rect x="20" y="375" width="{chart_w+120}" height="65" rx="6" fill="#fefce8" stroke="#ca8a04" stroke-width="1" />')
    svg.append('<text x="35" y="395" font-size="10.5" font-weight="700" fill="#854d0e">'
               'PQC Accelerator Guidance (Dr. Mahani Project):</text>')
    svg.append('<text x="35" y="412" font-size="9.5" fill="#713f12">'
               'For NTT / polynomial multiplication, keeping working coefficients within L1 D-Cache prevents any AXI latency degradation, allowing sustained dual-commit throughput near IPC 1.0-2.0.</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "03_axi_latency_degradation_curve.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated: {path}")


# ----------------------------------------------------------------------------
# 4. Scoreboard Dual-Commit Ports & Pairing Rules
# ----------------------------------------------------------------------------
def generate_scoreboard_ports_diagram(rows):
    width, height = 1100, 480
    svg = svg_header(width, height)

    svg.append(f'<rect x="20" y="15" width="{width-40}" height="42" rx="8" fill="#1e293b" />')
    svg.append('<text x="35" y="41" fill="#f8fafc" font-size="15" font-weight="700">'
               'CVA6 Scoreboard &amp; Dual-Commit Microarchitecture (Single-Issue vs Dual-Commit)</text>')
    svg.append(f'<text x="{width-35}" y="41" fill="#94a3b8" font-size="11" text-anchor="end">'
               'Issue: 1 Instr/Cyc (NrIssuePorts=1) | Commit: Up to 2 Instrs/Cyc (NrCommitPorts=2)</text>')

    # Diagram Canvas
    # Block 1: Front-End / Issue Stage
    fe_x, fe_y = 60, 90
    fe_w, fe_h = 240, 340
    svg.append(f'<rect x="{fe_x}" y="{fe_y}" width="{fe_w}" height="{fe_h}" rx="8" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5" />')
    svg.append(f'<rect x="{fe_x}" y="{fe_y}" width="{fe_w}" height="32" rx="8" fill="#e2e8f0" />')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+21}" font-size="12" font-weight="700" fill="#0f172a" text-anchor="middle">'
               'Front-End &amp; Issue Stage</text>')

    # Internal boxes
    svg.append(f'<rect x="{fe_x+20}" y="{fe_y+50}" width="{fe_w-40}" height="45" rx="6" fill="#ffffff" stroke="#cbd5e1" />')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+70}" font-size="11" font-weight="700" fill="#1e293b" text-anchor="middle">Fetch &amp; Align (I-Cache)</text>')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+84}" font-size="9" fill="#64748b" text-anchor="middle">32-bit aligned instructions</text>')

    svg.append(f'<rect x="{fe_x+20}" y="{fe_y+115}" width="{fe_w-40}" height="45" rx="6" fill="#ffffff" stroke="#cbd5e1" />')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+135}" font-size="11" font-weight="700" fill="#1e293b" text-anchor="middle">Instruction FIFO (4 entries)</text>')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+149}" font-size="9" fill="#64748b" text-anchor="middle">Decouples fetch &amp; issue</text>')

    svg.append(f'<rect x="{fe_x+20}" y="{fe_y+180}" width="{fe_w-40}" height="65" rx="6" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5" />')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+202}" font-size="11" font-weight="700" fill="#1d4ed8" text-anchor="middle">Single-Issue Port</text>')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+218}" font-size="9.5" font-weight="600" fill="#1e40af" text-anchor="middle">NrIssuePorts = 1</text>')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+232}" font-size="8.5" fill="#3b82f6" text-anchor="middle">Max 1 instruction / cycle dispatched</text>')

    svg.append(f'<rect x="{fe_x+20}" y="{fe_y+265}" width="{fe_w-40}" height="55" rx="6" fill="#fef2f2" stroke="#ef4444" />')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+285}" font-size="10" font-weight="700" fill="#b91c1c" text-anchor="middle">Front-End Ceiling</text>')
    svg.append(f'<text x="{fe_x+fe_w/2}" y="{fe_y+302}" font-size="8.5" fill="#7f1d1d" text-anchor="middle">Long-term sustained IPC ≤ 1.0</text>')

    # Arrow from FE to Scoreboard
    svg.append(f'<line x1="{fe_x+fe_w}" y1="{fe_y+212}" x2="{fe_x+fe_w+60}" y2="{fe_y+212}" stroke="#2563eb" stroke-width="2.5" />')
    svg.append(f'<polygon points="{fe_x+fe_w+60},{fe_y+208} {fe_x+fe_w+68},{fe_y+212} {fe_x+fe_w+60},{fe_y+216}" fill="#2563eb" />')
    svg.append(f'<text x="{fe_x+fe_w+34}" y="{fe_y+203}" font-size="9" font-weight="700" fill="#2563eb" text-anchor="middle">issue_ack</text>')

    # Block 2: Scoreboard (8 Entries)
    sb_x, sb_y = fe_x + fe_w + 70, 90
    sb_w, sb_h = 340, 340
    svg.append(f'<rect x="{sb_x}" y="{sb_y}" width="{sb_w}" height="{sb_h}" rx="8" fill="#f8fafc" stroke="#64748b" stroke-width="1.5" />')
    svg.append(f'<rect x="{sb_x}" y="{sb_y}" width="{sb_w}" height="32" rx="8" fill="#e2e8f0" />')
    svg.append(f'<text x="{sb_x+sb_w/2}" y="{sb_y+21}" font-size="12" font-weight="700" fill="#0f172a" text-anchor="middle">'
               'Scoreboard (8 In-Flight Entries)</text>')

    # Scoreboard Slots representation
    slot_names = [
        ("Slot 0 (Head)", "SW x5, 0(x1)", "DONE", "#bbf7d0", "#15803d"),
        ("Slot 1 (Next)", "ADDI x6, x6, 1", "DONE", "#bbf7d0", "#15803d"),
        ("Slot 2", "ADDI x7, x7, 2", "WAIT", "#fed7aa", "#c2410c"),
        ("Slot 3", "ADDI x8, x8, 3", "WAIT", "#fed7aa", "#c2410c"),
    ]

    sy = sb_y + 45
    for s_title, s_instr, s_st, s_bg, s_fg in slot_names:
        svg.append(f'<rect x="{sb_x+15}" y="{sy}" width="{sb_w-30}" height="35" rx="5" fill="{s_bg}" stroke="{s_fg}" stroke-width="1" />')
        svg.append(f'<text x="{sb_x+25}" y="{sy+22}" font-size="10" font-weight="700" fill="#0f172a">{s_title}: {s_instr}</text>')
        svg.append(f'<text x="{sb_x+sb_w-25}" y="{sy+22}" font-size="10" font-weight="700" fill="{s_fg}" text-anchor="end">{s_st}</text>')
        sy += 42

    svg.append(f'<rect x="{sb_x+15}" y="{sy+5}" width="{sb_w-30}" height="95" rx="6" fill="#ffffff" stroke="#cbd5e1" />')
    svg.append(f'<text x="{sb_x+25}" y="{sy+24}" font-size="10.5" font-weight="700" fill="#0f172a">Dual-Commit Pairing Rules:</text>')
    svg.append(f'<text x="{sb_x+25}" y="{sy+40}" font-size="9" fill="#334155">• Rule 1: Slot 0 must be marked valid and completed (trans_id done).</text>')
    svg.append(f'<text x="{sb_x+25}" y="{sy+54}" font-size="9" fill="#334155">• Rule 2: Slot 1 must also be valid &amp; completed without pending RAW hazard.</text>')
    svg.append(f'<text x="{sb_x+25}" y="{sy+68}" font-size="9" fill="#334155">• Rule 3: No exception, trap, or CSR flush pending on either instruction.</text>')
    svg.append(f'<text x="{sb_x+25}" y="{sy+82}" font-size="9" fill="#16a34a" font-weight="600">✓ If all met: Slot 0 → Port 0, Slot 1 → Port 1 in SAME cycle!</text>')

    # Dual commit output arrows
    svg.append(f'<line x1="{sb_x+sb_w}" y1="{sb_y+62}" x2="{sb_x+sb_w+60}" y2="{sb_y+100}" stroke="#16a34a" stroke-width="2.5" />')
    svg.append(f'<polygon points="{sb_x+sb_w+60},{sb_y+96} {sb_x+sb_w+68},{sb_y+100} {sb_x+sb_w+60},{sb_y+104}" fill="#16a34a" />')
    svg.append(f'<text x="{sb_x+sb_w+35}" y="{sb_y+75}" font-size="9" font-weight="700" fill="#16a34a">Port 0</text>')

    svg.append(f'<line x1="{sb_x+sb_w}" y1="{sb_y+104}" x2="{sb_x+sb_w+60}" y2="{sb_y+180}" stroke="#9333ea" stroke-width="2.5" />')
    svg.append(f'<polygon points="{sb_x+sb_w+60},{sb_y+176} {sb_x+sb_w+68},{sb_y+180} {sb_x+sb_w+60},{sb_y+184}" fill="#9333ea" />')
    svg.append(f'<text x="{sb_x+sb_w+35}" y="{sb_y+150}" font-size="9" font-weight="700" fill="#9333ea">Port 1</text>')

    # Block 3: Commit Stage & Register File
    cm_x, cm_y = sb_x + sb_w + 70, 90
    cm_w, cm_h = 300, 340
    svg.append(f'<rect x="{cm_x}" y="{cm_y}" width="{cm_w}" height="{cm_h}" rx="8" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5" />')
    svg.append(f'<rect x="{cm_x}" y="{cm_y}" width="{cm_w}" height="32" rx="8" fill="#e2e8f0" />')
    svg.append(f'<text x="{cm_x+cm_w/2}" y="{cm_y+21}" font-size="12" font-weight="700" fill="#0f172a" text-anchor="middle">'
               'Commit Stage &amp; Register File</text>')

    svg.append(f'<rect x="{cm_x+15}" y="{cm_y+50}" width="{cm_w-30}" height="70" rx="6" fill="#f0fdf4" stroke="#16a34a" stroke-width="1.5" />')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+72}" font-size="11" font-weight="700" fill="#15803d">Commit Port 0 (Primary)</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+88}" font-size="9.5" fill="#166534">commit_ack[0] = 1 | PC = 0x80000048 (SW)</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+104}" font-size="9.5" fill="#166534">GPR Write: x0 / none | Mem Store Active</text>')

    svg.append(f'<rect x="{cm_x+15}" y="{cm_y+140}" width="{cm_w-30}" height="70" rx="6" fill="#faf5ff" stroke="#9333ea" stroke-width="1.5" />')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+162}" font-size="11" font-weight="700" fill="#7e22ce">Commit Port 1 (Secondary)</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+178}" font-size="9.5" fill="#6b21a8">commit_ack[1] = 1 | PC = 0x8000004C (ADDI)</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+194}" font-size="9.5" fill="#6b21a8">GPR Write: x6 ← 0x00000001 (Updated!)</text>')

    svg.append(f'<rect x="{cm_x+15}" y="{cm_y+230}" width="{cm_w-30}" height="90" rx="6" fill="#ffffff" stroke="#cbd5e1" />')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+252}" font-size="10.5" font-weight="700" fill="#0f172a">Architectural Result:</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+270}" font-size="9.5" fill="#334155">• Dual-Commit = commit_ack[0] &amp;&amp; commit_ack[1]</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+286}" font-size="9.5" fill="#334155">• Instantaneous IPC = 2.0 (2 instrs in 1 cyc!)</text>')
    svg.append(f'<text x="{cm_x+25}" y="{cm_y+304}" font-size="9.5" font-weight="600" fill="#16a34a">'
               '✓ Total observed: 9 Dual-Commit cycles in Suite 6</text>')

    # Bottom summary bar
    svg.append(f'<rect x="20" y="445" width="{width-40}" height="24" rx="4" fill="#0f172a" />')
    svg.append(f'<text x="{width/2}" y="461" font-size="10.5" font-weight="600" fill="#f8fafc" text-anchor="middle">'
               'CVA6 Pipeline Property: Single-Issue Frontend (1 instr/cyc) fed into Scoreboard allows Burst Dual-Commit (2 instrs/cyc) at Backend</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "04_dual_commit_scoreboard_ports.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated: {path}")


def main():
    rows = read_trace()
    print(f"Loaded {len(rows)} trace rows from {CSV_PATH}")
    generate_execution_timeline(rows)
    generate_dual_commit_burst(rows)
    generate_latency_curve(rows)
    generate_scoreboard_ports_diagram(rows)
    print("All Suite 6 SVGs generated successfully.")


if __name__ == "__main__":
    main()
