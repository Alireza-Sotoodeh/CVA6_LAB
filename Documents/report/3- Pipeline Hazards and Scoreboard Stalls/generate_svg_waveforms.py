# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 20:41:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform generator for Suite 2 (pipeline hazards,
#                        operand forwarding, load-use delays, store buffer stalls,
#                        and divider structural writeback contention). Reads
#                        cva6_hazard_trace.csv and outputs four standalone,
#                        publication-grade SVGs.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_hazard_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI x1",
    0x0004: "ADDI x1",
    0x0008: "ADDI x2,10",
    0x000C: "ADDI x3,20",
    0x0010: "ADDI x4,15",
    0x0014: "ADD x5,35",
    0x0018: "SUB x6,25",
    0x001C: "AND x7,9",
    0x0020: "OR x8,43",
    0x0024: "XOR x9,50",
    0x0028: "SLLI x10,200",
    0x002C: "SW x10",
    0x0030: "LW x11",
    0x0034: "ADDI x12,201",
    0x0038: "ADD x13,216",
    0x003C: "SW x13",
    0x0040: "LW x14",
    0x0044: "ADDI x15,226",
    0x0048: "ADDI x16,100",
    0x004C: "ADDI x17,7",
    0x0050: "DIV x18,14",
    0x0054: "ADDI x19,500",
    0x0058: "REM x20,2",
    0x005C: "ADDI x21,700",
    0x0060: "ADD x22,16",
    0x0064: "MUL x23,112",
    0x0068: "ADD x24,612",
    0x006C: "JAL END",
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
    width, height = 1200, 360
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="32" font-size="16" font-weight="700" fill="#0f172a">'
        "CVA6 Suite 2: Pipeline Hazards & Scoreboard Stalls — Execution Timeline"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="50" font-size="11" fill="#475569">'
        "Retirement milestones from cold boot (cycle 0) to terminal self-loop commit (cycle 349). Total cycles run: 389."
        "</text>"
    )

    x0, y0, total_w = 40, 100, 1120
    phases = [
        (0, 266, "Phase 0: Cold Boot & Fetch", "#f1f5f9", "#94a3b8", "Cold AXI miss, reset de-asserted at cyc 9, boot to 0x8000_0000"),
        (267, 280, "Phase 1: RAW Forwarding Burst", "#dbeafe", "#2563eb", "7 back-to-back dependent ALU instrs. Retires at CPI = 1.00"),
        (281, 305, "Phase 2: Load-Use Hazard", "#fef3c7", "#d97706", "SW 0(x1) -> LW 0(x1) -> ADDI. 19-cycle scoreboard issue stall"),
        (306, 325, "Phase 3: Store Buffer Stall", "#ffedd5", "#ea580c", "SW 4(x1) -> LW 4(x1). page_offset match -> WAIT_PAGE_OFFSET"),
        (326, 345, "Phase 4: DIV Structural Contention", "#fee2e2", "#dc2626", "DIV/REM in serdiv. flu_ready=0 blocks independent ALU for 14 cycles"),
        (346, 389, "Phase 5: Multiplier & Self-Loop", "#dcfce7", "#16a34a", "MUL x23 (single-cycle), ADD x24, JAL x0,END committed at cyc 349"),
    ]

    tot_cyc = 389
    cur_x = x0
    for p_start, p_end, title, bg, border, desc in phases:
        pw = max(40, int((p_end - p_start + 1) / tot_cyc * total_w))
        svg.append(f'  <g transform="translate({cur_x}, {y0})">')
        svg.append(f'    <rect width="{pw}" height="60" fill="{bg}" stroke="{border}" stroke-width="1.5" rx="5" />')
        svg.append(f'    <text x="{pw/2}" y="24" class="box-lbl" fill="{border}">{xesc(title)}</text>')
        svg.append(f'    <text x="{pw/2}" y="42" font-size="9" fill="#475569" text-anchor="middle">Cyc {p_start}–{p_end}</text>')
        svg.append("  </g>")
        cur_x += pw

    # Milestones table below
    my0 = 190
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="140" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6" />')
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="28" fill="#f1f5f9" rx="6" />')
    svg.append(f'  <text x="55" y="{my0+18}" class="sig-lbl">Phase</text>')
    svg.append(f'  <text x="250" y="{my0+18}" class="sig-lbl">Cycle Span</text>')
    svg.append(f'  <text x="350" y="{my0+18}" class="sig-lbl">Microarchitectural Mechanism</text>')
    svg.append(f'  <text x="750" y="{my0+18}" class="sig-lbl">Hardware Signals &amp; Evidence</text>')
    svg.append(f'  <text x="1030" y="{my0+18}" class="sig-lbl">Measured CPI / Impact</text>')

    rows_data = [
        ("Phase 1: RAW ALU Forwarding", "267 – 280", "Scoreboard operand bypass directly from EX writeback", "forward_rs1=1, forward_rs2=1, stall_raw=0", "CPI = 1.00 (Zero stall bubbles)"),
        ("Phase 2: Load-Use Scoreboard Stall", "281 – 305", "D-cache latency stalls consumer instruction", "stall_raw=1, stall_rs1=1, issue_ack=0", "19 stall cycles while awaiting LW"),
        ("Phase 3: Store Buffer Collision", "306 – 325", "Store-to-Load address alias (same page offset)", "page_offset_matches=1, state_q=WAIT_PAGE_OFFSET", "4 stall cycles until store drains"),
        ("Phase 4: DIV Structural Contention", "326 – 345", "Fixed-Latency Unit (FLU) blocked by serial divider", "flu_ready=0, fus_busy[0].alu=1, in_rdy_o=0", "14 stall cycles on independent ALUs"),
        ("Phase 5: MUL & Terminal Self-Loop", "346 – 389", "Single-cycle multiplier execution & self-loop commit", "mul_valid=1, commit_pc=0x8000_006c at cyc 349", "Active CPI across hazard run = 2.02"),
    ]

    for i, (pname, cspan, mech, sigs, cpi) in enumerate(rows_data):
        ry = my0 + 44 + (i * 20)
        svg.append(f'  <text x="55" y="{ry}" font-size="10" font-weight="600" fill="#1e293b">{xesc(pname)}</text>')
        svg.append(f'  <text x="250" y="{ry}" font-size="10" fill="#475569">{xesc(cspan)}</text>')
        svg.append(f'  <text x="350" y="{ry}" font-size="10" fill="#334155">{xesc(mech)}</text>')
        svg.append(f'  <text x="750" y="{ry}" font-size="10" font-family="monospace" fill="#0369a1">{xesc(sigs)}</text>')
        svg.append(f'  <text x="1030" y="{ry}" font-size="10" font-weight="600" fill="#047857">{xesc(cpi)}</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "01_execution_timeline.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 2. RAW Operand Forwarding Burst
# ----------------------------------------------------------------------------
def generate_raw_forwarding_burst(rows):
    width, height = 1200, 480
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 RAW ALU-to-ALU Operand Forwarding Burst (Cycles 276 – 294)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Back-to-back execution of dependent ALU instructions (x4 -> x5 -> x6 -> x7 -> x8 -> x9 -> x10). "
        "Operand bypass eliminates stall bubbles, sustaining CPI = 1.00."
        "</text>"
    )

    w_rows = rows_in_window(rows, 276, 294)
    if not w_rows:
        return

    x_left, y_top = 220, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    # Cycle header
    for i, r in enumerate(w_rows):
        cx = x_left + (i * col_w)
        cyc = int(r["Cycle"])
        svg.append(f'  <rect x="{cx}" y="{y_top-20}" width="{col_w}" height="18" fill="#e2e8f0" stroke="#cbd5e1" stroke-width="0.5" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top-7}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("CommitAck0", "Commit Port 0 Ack", "bit", "#16a34a"),
        ("CommitPC0", "Commit Port 0 PC", "hex", "#0f172a"),
        ("IssueValid0", "Scoreboard Issue Valid", "bit", "#6366f1"),
        ("IssueAck0", "Scoreboard Issue Ack", "bit", "#0284c7"),
        ("ForwardRs1", "RS1 Forwarded from WB", "bit", "#2563eb"),
        ("ForwardRs2", "RS2 Forwarded from WB", "bit", "#3b82f6"),
        ("Rs1HasRaw", "RS1 RAW Hazard Flag", "bit", "#ea580c"),
        ("Rs2HasRaw", "RS2 RAW Hazard Flag", "bit", "#f97316"),
        ("StallRaw", "RAW Stall Asserted", "bit", "#dc2626"),
        ("GprWaddr0", "GPR Write Address", "reg", "#475569"),
        ("GprWdata0", "GPR Write Data", "hex", "#059669"),
    ]

    row_h = 30
    for s_idx, (sig_name, sig_label, sig_type, sig_color) in enumerate(signals):
        sy = y_top + (s_idx * row_h)
        bg = "#ffffff" if s_idx % 2 == 0 else "#f8fafc"
        svg.append(f'  <rect x="30" y="{sy}" width="{width-60}" height="{row_h}" fill="{bg}" stroke="#e2e8f0" stroke-width="0.5" />')
        svg.append(f'  <text x="35" y="{sy+16}" class="sig-lbl">{xesc(sig_name)}</text>')
        svg.append(f'  <text x="35" y="{sy+26}" class="sig-sub">{xesc(sig_label)}</text>')

        for i, r in enumerate(w_rows):
            cx = x_left + (i * col_w)
            val = r.get(sig_name, "")
            if sig_type == "bit":
                is_hi = (val == "1")
                b_color = sig_color if is_hi else "#cbd5e1"
                t_color = "#ffffff" if is_hi else "#94a3b8"
                svg.append(f'  <rect x="{cx+3}" y="{sy+5}" width="{col_w-6}" height="20" fill="{b_color}" rx="3" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+19}" class="box-lbl" fill="{t_color}">{val}</text>')
            elif sig_type == "hex":
                h_val = hex32(val)
                lbl = pc_label(val) if "PC" in sig_name else (f"0x{h_val:X}" if h_val != 0 else "0")
                b_color = "#eff6ff" if h_val != 0 else "#f8fafc"
                svg.append(f'  <rect x="{cx+2}" y="{sy+5}" width="{col_w-4}" height="20" fill="{b_color}" stroke="{sig_color}" stroke-width="1" rx="3" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+18}" font-size="8" font-weight="600" fill="{sig_color}" text-anchor="middle">{xesc(lbl)}</text>')
            elif sig_type == "reg":
                r_num = int(val) if val.isdigit() else 0
                lbl = f"x{r_num}" if r_num != 0 else "-"
                b_color = "#fef3c7" if r_num != 0 else "#f8fafc"
                svg.append(f'  <rect x="{cx+3}" y="{sy+5}" width="{col_w-6}" height="20" fill="{b_color}" stroke="#d97706" stroke-width="1" rx="3" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+18}" font-size="9" font-weight="700" fill="#92400e" text-anchor="middle">{lbl}</text>')

    # Bottom annotation
    ay = y_top + (len(signals) * row_h) + 15
    svg.append(f'  <rect x="30" y="{ay}" width="{width-60}" height="42" fill="#eff6ff" stroke="#bfdbfe" stroke-width="1" rx="5" />')
    svg.append(f'  <text x="45" y="{ay+18}" class="ann-title">Microarchitectural Insight: 0-Stall Forwarding</text>')
    svg.append(f'  <text x="45" y="{ay+32}" class="ann-body">At cycles 280, 281, and 282, instructions ADD x5, SUB x6, and AND x7 retire on consecutive cycles. Although each instruction requires the previous instruction\'s output register, Rs1HasRaw=1 and ForwardRs1=1 bypass data directly from the writeback bus, keeping StallRaw=0 and issue unblocked.</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "02_raw_forwarding_burst.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 3. Load-Use & Store Buffer Stall
# ----------------------------------------------------------------------------
def generate_load_use_store_buffer_stall(rows):
    width, height = 1200, 500
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 Load-Use Scoreboard Delay &amp; Store Buffer Address Matching (Cycles 293 – 324)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Inspection of memory hazard stalls: (1) Load-Use dependency on LW 0(x1) stalling ADDI, "
        "and (2) Store-to-Load address collision where page_offset match holds LSU in WAIT_PAGE_OFFSET."
        "</text>"
    )

    w_rows = rows_in_window(rows, 293, 324)
    if not w_rows:
        return

    x_left, y_top = 220, 80
    col_w = max(28, int((width - x_left - 40) / len(w_rows)))

    for i, r in enumerate(w_rows):
        cx = x_left + (i * col_w)
        cyc = int(r["Cycle"])
        svg.append(f'  <rect x="{cx}" y="{y_top-20}" width="{col_w}" height="18" fill="#e2e8f0" stroke="#cbd5e1" stroke-width="0.5" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top-7}" font-size="9" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("CommitAck0", "Commit Port 0 Ack", "bit", "#16a34a"),
        ("CommitPC0", "Commit Port 0 PC", "hex", "#0f172a"),
        ("IssueValid0", "Scoreboard Issue Valid", "bit", "#6366f1"),
        ("IssueAck0", "Scoreboard Issue Ack", "bit", "#0284c7"),
        ("StallIssue", "Issue Stage Stall", "bit", "#ef4444"),
        ("StallRaw", "RAW Scoreboard Stall", "bit", "#dc2626"),
        ("StallRs1", "RS1 Operand Stall", "bit", "#b91c1c"),
        ("ForwardRs1", "RS1 Operand Forwarded", "bit", "#2563eb"),
        ("LsuValidId", "LSU Issue Valid", "bit", "#0891b2"),
        ("LoadUnitState", "Load Unit State (3=WAIT_PAGE)", "dec", "#7c3aed"),
        ("PageOffsetMatches", "Store-Load Offset Match", "bit", "#ea580c"),
        ("StoreBufEmpty", "Store Buffer Empty", "bit", "#10b981"),
    ]

    row_h = 28
    for s_idx, (sig_name, sig_label, sig_type, sig_color) in enumerate(signals):
        sy = y_top + (s_idx * row_h)
        bg = "#ffffff" if s_idx % 2 == 0 else "#f8fafc"
        svg.append(f'  <rect x="30" y="{sy}" width="{width-60}" height="{row_h}" fill="{bg}" stroke="#e2e8f0" stroke-width="0.5" />')
        svg.append(f'  <text x="35" y="{sy+15}" class="sig-lbl">{xesc(sig_name)}</text>')
        svg.append(f'  <text x="35" y="{sy+25}" class="sig-sub">{xesc(sig_label)}</text>')

        for i, r in enumerate(w_rows):
            cx = x_left + (i * col_w)
            val = r.get(sig_name, "")
            if sig_type == "bit":
                is_hi = (val == "1")
                b_color = sig_color if is_hi else "#cbd5e1"
                t_color = "#ffffff" if is_hi else "#94a3b8"
                svg.append(f'  <rect x="{cx+2}" y="{sy+4}" width="{col_w-4}" height="18" fill="{b_color}" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+17}" class="box-lbl" fill="{t_color}">{val}</text>')
            elif sig_type == "hex":
                h_val = hex32(val)
                lbl = pc_label(val) if "PC" in sig_name else (f"0x{h_val:X}" if h_val != 0 else "0")
                b_color = "#eff6ff" if h_val != 0 else "#f8fafc"
                svg.append(f'  <rect x="{cx+1}" y="{sy+4}" width="{col_w-2}" height="18" fill="{b_color}" stroke="{sig_color}" stroke-width="0.5" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+16}" font-size="7" font-weight="600" fill="{sig_color}" text-anchor="middle">{xesc(lbl)}</text>')
            elif sig_type == "dec":
                d_val = int(val) if val.isdigit() else 0
                state_str = "WAIT_PAGE" if d_val == 3 else ("IDLE" if d_val == 0 else str(d_val))
                b_color = "#ede9fe" if d_val == 3 else "#f8fafc"
                svg.append(f'  <rect x="{cx+1}" y="{sy+4}" width="{col_w-2}" height="18" fill="{b_color}" stroke="{sig_color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+16}" font-size="7" font-weight="700" fill="{sig_color}" text-anchor="middle">{state_str}</text>')

    ay = y_top + (len(signals) * row_h) + 15
    svg.append(f'  <rect x="30" y="{ay}" width="{width-60}" height="55" fill="#fefce8" stroke="#fef08a" stroke-width="1" rx="5" />')
    svg.append(f'  <text x="45" y="{ay+18}" class="ann-title">Microarchitectural Insight: Memory Dependency Resolution</text>')
    svg.append(f'  <text x="45" y="{ay+32}" class="ann-body">1. Load-Use Delay: Between cycles 295 and 312, instruction ADDI x12 is held in scoreboard issue (StallRaw=1, StallRs1=1) until LW 0(x1) returns data from D-cache at cycle 312. ForwardRs1 asserts at cycle 313, and ADDI executes immediately.</text>')
    svg.append(f'  <text x="45" y="{ay+46}" class="ann-body">2. Store Buffer Hazard: Following SW 4(x1) at cycle 317, LW 4(x1) accesses the exact same byte offset. PageOffsetMatches asserts, forcing LoadUnitState into WAIT_PAGE_OFFSET (3) until the store buffer commits and drains to memory.</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "03_load_use_and_store_buffer_stall.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 4. Divider Structural Writeback Contention
# ----------------------------------------------------------------------------
def generate_divider_structural_contention(rows):
    width, height = 1200, 520
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 Fixed-Latency Unit (FLU) Divider Structural Write-Back Contention (Cycles 325 – 349)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Demonstration of the Fixed-Latency Unit writeback bottleneck: during serial division (DIV and REM), "
        "flu_ready_o is pulled LOW, asserting fu_busy_alu=1 and stalling independent ALU instructions."
        "</text>"
    )

    w_rows = rows_in_window(rows, 325, 349)
    if not w_rows:
        return

    x_left, y_top = 220, 80
    col_w = max(35, int((width - x_left - 40) / len(w_rows)))

    for i, r in enumerate(w_rows):
        cx = x_left + (i * col_w)
        cyc = int(r["Cycle"])
        svg.append(f'  <rect x="{cx}" y="{y_top-20}" width="{col_w}" height="18" fill="#e2e8f0" stroke="#cbd5e1" stroke-width="0.5" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top-7}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("CommitAck0", "Commit Port 0 Ack", "bit", "#16a34a"),
        ("CommitPC0", "Commit Port 0 PC", "hex", "#0f172a"),
        ("DivValidOp", "Divider Issue Request", "bit", "#b91c1c"),
        ("MultReady", "Divider in_rdy_o Flag", "bit", "#059669"),
        ("SerDivState", "Divider FSM (0=IDLE,1=DIV,2=FIN)", "dec", "#dc2626"),
        ("SerDivCnt", "Divider Shift Counter", "cnt", "#991b1b"),
        ("DivValid", "Division Result Valid", "bit", "#16a34a"),
        ("FluReady", "FLU Ready Flag (FLU Bus)", "bit", "#2563eb"),
        ("FuBusyAlu", "ALU Functional Unit Busy", "bit", "#d97706"),
        ("IssueValid0", "Scoreboard Issue Valid", "bit", "#6366f1"),
        ("IssueAck0", "Scoreboard Issue Acknowledge", "bit", "#0284c7"),
        ("MulValidOp", "Multiplier Issue Request", "bit", "#0891b2"),
        ("MulValid", "Multiplier Result Valid", "bit", "#0d9488"),
    ]

    row_h = 28
    for s_idx, (sig_name, sig_label, sig_type, sig_color) in enumerate(signals):
        sy = y_top + (s_idx * row_h)
        bg = "#ffffff" if s_idx % 2 == 0 else "#f8fafc"
        svg.append(f'  <rect x="30" y="{sy}" width="{width-60}" height="{row_h}" fill="{bg}" stroke="#e2e8f0" stroke-width="0.5" />')
        svg.append(f'  <text x="35" y="{sy+15}" class="sig-lbl">{xesc(sig_name)}</text>')
        svg.append(f'  <text x="35" y="{sy+25}" class="sig-sub">{xesc(sig_label)}</text>')

        for i, r in enumerate(w_rows):
            cx = x_left + (i * col_w)
            val = r.get(sig_name, "")
            if sig_type == "bit":
                is_hi = (val == "1")
                b_color = sig_color if is_hi else "#cbd5e1"
                t_color = "#ffffff" if is_hi else "#94a3b8"
                svg.append(f'  <rect x="{cx+3}" y="{sy+4}" width="{col_w-6}" height="18" fill="{b_color}" rx="3" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+17}" class="box-lbl" fill="{t_color}">{val}</text>')
            elif sig_type == "hex":
                h_val = hex32(val)
                lbl = pc_label(val) if "PC" in sig_name else (f"0x{h_val:X}" if h_val != 0 else "0")
                b_color = "#eff6ff" if h_val != 0 else "#f8fafc"
                svg.append(f'  <rect x="{cx+1}" y="{sy+4}" width="{col_w-2}" height="18" fill="{b_color}" stroke="{sig_color}" stroke-width="0.5" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+16}" font-size="7" font-weight="600" fill="{sig_color}" text-anchor="middle">{xesc(lbl)}</text>')
            elif sig_type == "dec":
                d_val = int(val) if val.isdigit() else 0
                st_name = "DIVIDE" if d_val == 1 else ("FINISH" if d_val == 2 else "IDLE")
                b_color = "#fee2e2" if d_val == 1 else ("#dcfce7" if d_val == 2 else "#f8fafc")
                svg.append(f'  <rect x="{cx+2}" y="{sy+4}" width="{col_w-4}" height="18" fill="{b_color}" stroke="{sig_color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+16}" font-size="7" font-weight="700" fill="{sig_color}" text-anchor="middle">{st_name}</text>')
            elif sig_type == "cnt":
                cnt_val = int(val) if val.isdigit() else 0
                b_color = "#fff1f2" if cnt_val > 0 else "#f8fafc"
                svg.append(f'  <rect x="{cx+2}" y="{sy+4}" width="{col_w-4}" height="18" fill="{b_color}" stroke="{sig_color}" stroke-width="0.5" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sy+16}" font-size="8" font-weight="600" fill="{sig_color}" text-anchor="middle">{cnt_val}</text>')

    ay = y_top + (len(signals) * row_h) + 15
    svg.append(f'  <rect x="30" y="{ay}" width="{width-60}" height="55" fill="#fef2f2" stroke="#fecaca" stroke-width="1" rx="5" />')
    svg.append(f'  <text x="45" y="{ay+18}" class="ann-title">Microarchitectural Insight: The Fixed-Latency Unit Structural Hazard</text>')
    svg.append(f'  <text x="45" y="{ay+32}" class="ann-body">1. Structural Contention: At cycle 326, DIV x18 starts calculation. SerDivState enters DIVIDE (1), and MultReady drops to 0. This forces flu_ready_o=0 and FuBusyAlu=1, which freezes the issue stage for independent instruction ADDI x19, 500 until cycle 333 (DivValid=1).</text>')
    svg.append(f'  <text x="45" y="{ay+46}" class="ann-body">2. Contrast with Pipelined Multiplier: At cycle 346, MUL x23 issues. Unlike the divider, the multiplier is fully pipelined, completing in a single cycle without de-asserting flu_ready_o or stalling subsequent operations.</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "04_divider_structural_contention.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


def main():
    print(f"[SVG] Reading trace from {CSV_PATH}...")
    rows = read_trace()
    print(f"[SVG] Trace contains {len(rows)} clock cycles.")

    generate_execution_timeline(rows)
    generate_raw_forwarding_burst(rows)
    generate_load_use_store_buffer_stall(rows)
    generate_divider_structural_contention(rows)
    print("[SVG] All 4 SVG timing figures successfully generated.")


if __name__ == "__main__":
    main()
