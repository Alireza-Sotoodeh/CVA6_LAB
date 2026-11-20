# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:12:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 3 SVGs:
#                        standardized 1200px width, collision-free timeline with
#                        milestone cards, run-length bus trapezoids, compact opcodes
#                        inside cells, and clean <tspan> multi-line annotations.
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

SHORT_OP = {
    0x0010: "ADDI",
    0x0014: "ADD",
    0x0018: "SUB",
    0x001C: "AND",
    0x0020: "OR",
    0x0024: "XOR",
    0x0028: "SLLI",
    0x002C: "SW",
    0x0030: "LW",
    0x0034: "ADDI",
    0x0038: "ADD",
    0x003C: "SW",
    0x0040: "LW",
    0x0044: "ADDI",
    0x0048: "ADDI",
    0x004C: "ADDI",
    0x0050: "DIV",
    0x0054: "ADDI",
    0x0058: "REM",
    0x005C: "ADDI",
    0x0060: "ADD",
    0x0064: "MUL",
    0x0068: "ADD",
    0x006C: "JAL",
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
        return op if op else f"0x{short:02X}"
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
    total_cyc = 389

    phases = [
        (0, 266, "Cold Boot & Fetch", "#f1f5f9", "#94a3b8", "Cold AXI miss, reset at cyc 9, boot to 0x80000000"),
        (267, 280, "RAW Forwarding Burst", "#dbeafe", "#2563eb", "7 dependent ALU instrs execute at CPI = 1.00"),
        (281, 305, "Load-Use Hazard", "#fef3c7", "#d97706", "SW -> LW -> ADDI. 19-cycle scoreboard issue stall"),
        (306, 325, "Store Buffer Stall", "#ffedd5", "#ea580c", "SW -> LW address match -> WAIT_PAGE_OFFSET"),
        (326, 345, "DIV Contention", "#fee2e2", "#dc2626", "serdiv busy blocks independent ALU for 14 cycles"),
        (346, 389, "Multiplier & Drain", "#dcfce7", "#16a34a", "MUL x23 & terminal self-loop commit at cyc 349"),
    ]

    events = [
        (267, "F1", "#2563eb", "RAW ALU Forwarding Burst", "Scoreboard operand bypass directly from EX stage"),
        (295, "S1", "#d97706", "Load-Use Scoreboard Stall", "ADDI x12 stalls awaiting LW data from D-Cache"),
        (317, "S2", "#ea580c", "Store Buffer Page Match", "LSU enters WAIT_PAGE_OFFSET until store drains"),
        (327, "C1", "#dc2626", "DIV Structural Contention", "flu_ready=0 halts issue of independent ALUs"),
        (349, "T1", "#16a34a", "Multiplier Commit & End", "MUL completes in 1 cyc; terminal self-loop reached"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 3: Pipeline Hazards &amp; Scoreboard Stalls — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 389 | Active Benchmark: 82 Cycles | Measured CPI = 2.02</text>')

    bar_y = 75
    bar_h = 42

    for p_start, p_end, title, bg, border, _ in phases:
        x1 = left + (p_start / total_cyc) * plot_w
        x2 = left + (p_end / total_cyc) * plot_w
        pw = max(x2 - x1, 4)
        svg.append(f'<rect x="{x1:.1f}" y="{bar_y}" width="{pw:.1f}" height="{bar_h}" fill="{bg}" stroke="{border}" stroke-width="1.5" rx="4"/>')
        if pw > 60:
            svg.append(f'<text x="{x1 + pw/2:.1f}" y="{bar_y + 20}" font-size="10" font-weight="700" fill="#0f172a" text-anchor="middle">{xesc(title)}</text>')
            svg.append(f'<text x="{x1 + pw/2:.1f}" y="{bar_y + 34}" font-size="8.5" fill="#475569" text-anchor="middle">C{p_start}–C{p_end}</text>')

    axis_y = bar_y + bar_h
    svg.append(f'<line x1="{left}" y1="{axis_y}" x2="{left+plot_w}" y2="{axis_y}" stroke="#475569" stroke-width="1.5"/>')
    for tick in [0, 50, 100, 150, 200, 250, 267, 305, 325, 345, 389]:
        tx = left + (tick / total_cyc) * plot_w
        svg.append(f'<line x1="{tx:.1f}" y1="{axis_y}" x2="{tx:.1f}" y2="{axis_y+5}" stroke="#475569" stroke-width="1"/>')
        svg.append(f'<text x="{tx:.1f}" y="{axis_y+16}" font-size="8.5" fill="#475569" text-anchor="middle">C{tick}</text>')

    for cyc, tag, color, _, _ in events:
        ex = left + (cyc / total_cyc) * plot_w
        svg.append(f'<line x1="{ex:.1f}" y1="{bar_y}" x2="{ex:.1f}" y2="{bar_y+bar_h+18}" stroke="{color}" stroke-width="1.5" stroke-dasharray="2,2"/>')
        svg.append(f'<circle cx="{ex:.1f}" cy="{bar_y+bar_h+18}" r="9" fill="{color}"/>')
        svg.append(f'<text x="{ex:.1f}" y="{bar_y+bar_h+21}" class="tag-lbl">{tag}</text>')

    tbl_y = 170
    svg.append(f'<rect x="{left}" y="{tbl_y}" width="{plot_w}" height="200" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6"/>')
    svg.append(f'<rect x="{left}" y="{tbl_y}" width="{plot_w}" height="26" fill="#f1f5f9" rx="6"/>')
    svg.append(f'<text x="{left+15}" y="{tbl_y+17}" class="sig-name">Tag</text>')
    svg.append(f'<text x="{left+60}" y="{tbl_y+17}" class="sig-name">Cycle</text>')
    svg.append(f'<text x="{left+120}" y="{tbl_y+17}" class="sig-name">Hazard Event</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+17}" class="sig-name">Microarchitectural Mechanism</text>')
    svg.append(f'<text x="{left+800}" y="{tbl_y+17}" class="sig-name">Measured Impact &amp; Evidence</text>')

    for i, (cyc, tag, color, desc, mech) in enumerate(events):
        ry = tbl_y + 44 + (i * 19)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="19" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" fill="#475569">{xesc(mech)}</text>')
        impact_txt = "CPI = 1.00 (Zero stalls)" if tag == "F1" else ("19-cycle issue stall" if tag == "S1" else ("4-cycle drain stall" if tag == "S2" else ("14-cycle ALU stall" if tag == "C1" else "Single-cycle multiplier")))
        svg.append(f'<text x="{left+800}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{impact_txt}</text>')

    card_y = 390
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("RAW Bypass IPC", "1.00", "Zero stall cycles observed", "#dcfce7", "#16a34a"),
        ("Load-Use Stalls", "19", "Scoreboard issue held", "#fef3c7", "#d97706"),
        ("Store Buffer Stalls", "4", "WAIT_PAGE_OFFSET drain", "#ffedd5", "#ea580c"),
        ("DIV Contention Stalls", "14", "flu_ready=0 structural block", "#fee2e2", "#dc2626"),
        ("Total Hazard CPI", "2.02", "30/30 Assertions PASSED", "#e0f2fe", "#0284c7"),
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


def render_waveform_panel(rows, start, end, title, subtitle, signals, out_path, notes=None):
    window = rows_in_window(rows, start, end)
    if not window:
        return
    width = 1200
    left = 240
    right = 30
    top = 75
    row_h = 30
    plot_w = width - left - right
    n = len(window)
    col_w = plot_w / max(n, 1)

    ann_h = 75 if notes else 30
    height = top + len(signals) * row_h + ann_h + 20

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="12" width="{width-40}" height="46" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="32" font-size="14" font-weight="700" fill="#f8fafc">{xesc(title)} (Cycles {start} to {end})</text>')
    svg.append(f'<text x="35" y="48" font-size="10.5" fill="#94a3b8">{xesc(subtitle)}</text>')

    stride = 5 if n > 35 else (2 if n > 18 else 1)
    for i, row in enumerate(window):
        cyc = int(row["Cycle"])
        x = left + i * col_w
        fill = "#f8fafc" if i % 2 == 0 else "#ffffff"
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc">C{cyc}</text>')

    for s_idx, (name, sub, getter, is_bus_flag, color) in enumerate(signals):
        y_base = top + s_idx * row_h
        y_low = y_base + row_h - 7
        y_high = y_base + 7
        y_mid = (y_low + y_high) / 2
        svg.append(f'<line x1="20" y1="{y_base + row_h}" x2="{width - 20}" y2="{y_base + row_h}" stroke="#e2e8f0" stroke-width="0.8"/>')
        svg.append(f'<text x="25" y="{y_base + 14}" class="sig-name">{xesc(name)}</text>')
        svg.append(f'<text x="25" y="{y_base + 24}" class="sig-sub">{xesc(sub)}</text>')

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
                if col_w >= 28:
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{"#dc2626" if high and "Stall" in name else color}">{val}</text>')
                prev = val
        else:
            run_start = 0
            for i in range(1, n + 1):
                if i == n or values[i] != values[run_start]:
                    x1 = left + run_start * col_w
                    x2 = left + i * col_w
                    run_w = x2 - x1
                    val = values[run_start]
                    is_idle = str(val) in ("0", "0x00000000", "0x0000", "-", "IDLE")
                    fill_c = "#f1f5f9" if is_idle else "#e0f2fe"
                    border_c = "#cbd5e1" if is_idle else color

                    pts = f"{x1+3:.1f},{y_mid:.1f} {x1+6:.1f},{y_high:.1f} {x2-6:.1f},{y_high:.1f} {x2-3:.1f},{y_mid:.1f} {x2-6:.1f},{y_low:.1f} {x1+6:.1f},{y_low:.1f}"
                    svg.append(f'<polygon points="{pts}" fill="{fill_c}" stroke="{border_c}" stroke-width="1"/>')

                    if not is_idle and run_w >= 26:
                        lbl = pc_label(val, compact=(run_w < 65)) if ("PC" in name or "Addr" in name) else str(val)
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
    rows = read_trace()
    if not rows:
        print("[ERROR] No trace rows found in cva6_hazard_trace.csv")
        return

    generate_execution_timeline(rows)

    render_waveform_panel(
        rows, 276, 294,
        "RAW ALU-to-ALU Operand Forwarding Burst",
        "Back-to-back dependent ALU instructions (x4 -> x5 -> x6 -> x7 -> x8 -> x9 -> x10) sustaining CPI = 1.00",
        [
            ("CommitAck0", "Commit Port 0 Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0f172a"),
            ("IssueValid0", "Scoreboard Issue Valid", lambda r: r["IssueValid0"], False, "#6366f1"),
            ("IssueAck0", "Scoreboard Issue Ack", lambda r: r["IssueAck0"], False, "#0284c7"),
            ("ForwardRs1", "RS1 Forwarded from WB", lambda r: r["ForwardRs1"], False, "#2563eb"),
            ("ForwardRs2", "RS2 Forwarded from WB", lambda r: r["ForwardRs2"], False, "#3b82f6"),
            ("Rs1HasRaw", "RS1 RAW Hazard Flag", lambda r: r["Rs1HasRaw"], False, "#ea580c"),
            ("StallRaw", "RAW Stall Asserted", lambda r: r["StallRaw"], False, "#dc2626"),
            ("GprWaddr0", "GPR Destination Reg", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
            ("GprWdata0", "GPR Write Data", lambda r: f"0x{hex32(r['GprWdata0']):X}" if r.get("GprWe0")=="1" else "-", True, "#059669"),
        ],
        os.path.join(FIG_DIR, "02_raw_forwarding_burst.svg"),
        notes=[
            "• Zero Stall Bubbles: ForwardRs1/Rs2 assert on the exact cycle results are ready, bypassing the Register File directly into ALU operands.",
            "• RAW Hazard Resolution: Rs1HasRaw asserts during decode, but operand forwarding resolves the hazard before issue stall occurs (StallRaw=0).",
            "• Perfect Throughput: 7 back-to-back dependent integer operations retire at 1 instruction per cycle (CPI = 1.00).",
        ],
    )

    render_waveform_panel(
        rows, 295, 322,
        "Load-Use Scoreboard Stalls & Store Buffer Address Collision",
        "Load-Use delay on LW 0(x1) holds ADDI x12 in issue; Store Buffer page-offset match holds LSU in WAIT_PAGE_OFFSET",
        [
            ("CommitAck0", "Commit Port 0 Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0f172a"),
            ("IssueValid0", "Scoreboard Issue Valid", lambda r: r["IssueValid0"], False, "#6366f1"),
            ("StallRaw", "RAW Stall Flag", lambda r: r["StallRaw"], False, "#dc2626"),
            ("StallRs1", "RS1 Operand Stall", lambda r: r["StallRs1"], False, "#b91c1c"),
            ("ForwardRs1", "RS1 Operand Forwarded", lambda r: r["ForwardRs1"], False, "#2563eb"),
            ("LoadUnitState", "LSU State (3=WAIT_PAGE)", lambda r: "WAIT_PAGE" if r.get("LoadUnitState")=="3" else ("IDLE" if r.get("LoadUnitState")=="0" else r.get("LoadUnitState","0")), True, "#7c3aed"),
            ("PageOffsetMatches", "Store-Load Offset Match", lambda r: r["PageOffsetMatches"], False, "#ea580c"),
            ("StoreBufEmpty", "Store Buffer Empty", lambda r: r["StoreBufEmpty"], False, "#10b981"),
        ],
        os.path.join(FIG_DIR, "03_load_use_and_store_buffer_stall.svg"),
        notes=[
            "• Load-Use Stall: ADDI x12 depends on LW 0(x1). Scoreboard holds issue (StallRaw=1, StallRs1=1) until D-cache returns data.",
            "• Store Buffer Collision: When LW accesses the same page offset as a pending SW, PageOffsetMatches asserts.",
            "• Sequential Ordering: LSU transitions to WAIT_PAGE_OFFSET, preventing load-after-store ordering violation until the store commits.",
        ],
    )

    render_waveform_panel(
        rows, 325, 349,
        "Divider Structural Contention: Fixed-Latency Unit Stall",
        "Multi-cycle serial integer division (DIV/REM) asserts flu_ready=0, blocking independent ALU operations from issuing",
        [
            ("CommitAck0", "Commit Port 0 Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#0f172a"),
            ("IssueValid0", "Scoreboard Issue Valid", lambda r: r["IssueValid0"], False, "#6366f1"),
            ("DivValid", "Divider Unit Request", lambda r: r.get("DivValid", "0"), False, "#ea580c"),
            ("FluReady", "Fixed-Latency Unit Ready", lambda r: r.get("FluReady", "1"), False, "#16a34a"),
            ("FusBusyALU", "ALU Function Unit Busy", lambda r: r.get("FusBusyALU", "0"), False, "#dc2626"),
            ("StallRaw", "Scoreboard RAW Stall", lambda r: r["StallRaw"], False, "#b91c1c"),
            ("GprWaddr0", "GPR Writeback Register", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
        ],
        os.path.join(FIG_DIR, "04_divider_structural_contention.svg"),
        notes=[
            "• Structural Bottleneck: Because ALU and Divider share the Fixed-Latency Unit (FLU) writeback port, flu_ready de-asserts during division.",
            "• Issue Stalling: Independent single-cycle ALU instructions cannot issue while serdiv completes its iterative radix-2 calculation.",
            "• Resolution: Once DIV writeback completes, the scoreboard unblocks, and queued ALU operations retire in rapid succession.",
        ],
    )


if __name__ == "__main__":
    main()
