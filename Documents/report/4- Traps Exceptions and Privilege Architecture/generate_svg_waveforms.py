# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:14:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 4 SVGs:
#                        standardized 1200px width, collision-free timeline with
#                        CSR trap state cards, run-length bus trapezoids, non-overlapping
#                        signal labels, and clean <tspan> multi-line annotations.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_trap_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI ra",
    0x0004: "ADDI ra,1024",
    0x0008: "AUIPC t6",
    0x000C: "ADDI t6,152",
    0x0010: "CSRW mtvec,t6",
    0x0060: "LI gp,100",
    0x0064: "ILLEGAL_INSTR",
    0x0068: "LI tp,101",
    0x006C: "LI t0,200",
    0x0070: "EBREAK",
    0x0074: "LI t1,201",
    0x0078: "LI t2,300",
    0x007C: "ADDI t6,ra,2",
    0x0080: "JR t6 (misalign)",
    0x0084: "LI s0,301",
    0x0088: "LI s1,400",
    0x008C: "ECALL",
    0x0090: "LI s3,401",
    0x0094: "LI s4,999",
    0x0098: "J END_LOOP",
    0x00A0: "ADDI sp,sp,1",
    0x00A4: "CSRR a0,mcause",
    0x00A8: "CSRR a1,mepc",
    0x00AC: "CSRR a2,mtval",
    0x00B0: "CSRR a3,mstatus",
    0x00B4: "ADDI a1,a1,4",
    0x00B8: "CSRW mepc,a1",
    0x00BC: "MRET",
}

SHORT_OP = {
    0x0064: "ILLEGAL",
    0x0070: "EBREAK",
    0x0080: "JR (mis)",
    0x008C: "ECALL",
    0x00BC: "MRET",
    0x00A0: "HANDLER",
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
    total_cyc = 615

    phases = [
        (0, 266, "Phase 0: Boot & MTVEC", "#f1f5f9", "#94a3b8", "Cold AXI fetch, set mtvec = 0x8000_00a0"),
        (267, 406, "Phase 1: ILLEGAL_INSTR", "#fee2e2", "#dc2626", "Fault at 0x64 (.word 0). mcause=2, mepc=0x64, MRET at 403"),
        (407, 458, "Phase 2: BREAKPOINT", "#ffedd5", "#ea580c", "ebreak at 0x70. mcause=3, mepc=0x70, mtval=0x70, MRET at 454"),
        (459, 518, "Phase 3: MISALIGNED_JUMP", "#fef3c7", "#d97706", "jr t6 (0x8000_0402). mcause=0, mtval=0x402, MRET at 514"),
        (519, 563, "Phase 4: ECALL M-Mode", "#dbeafe", "#2563eb", "ecall at 0x8C. mcause=11, mepc=0x8C, MRET at 559"),
        (564, 615, "Phase 5: Drain & Loop", "#dcfce7", "#16a34a", "li s3,401, li s4,999, commit self-loop at 0x98 (Cyc 575)"),
    ]

    events = [
        (334, "T1", "#dc2626", "ILLEGAL_INSTR (Cause 2)", "mcause=2, mepc=0x8000_0064, MRET @ C403"),
        (417, "T2", "#ea580c", "BREAKPOINT (Cause 3)", "mcause=3, mepc=0x8000_0070, MRET @ C454"),
        (470, "T3", "#d97706", "MISALIGNED_JUMP (Cause 0)", "mcause=0, mtval=0x8000_0402, MRET @ C514"),
        (523, "T4", "#2563eb", "ECALL M-Mode (Cause 11)", "mcause=11, mepc=0x8000_008C, MRET @ C559"),
        (575, "E1", "#16a34a", "Terminal Loop Commit", "j end_loop commits; 25/25 checks PASS"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 4: Traps, Exceptions &amp; Privilege Architecture — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 615 | 4 Precise Traps Handled | Measured CPI = 2.69</text>')

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
    for tick in [0, 100, 200, 267, 334, 417, 470, 523, 575, 615]:
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
    svg.append(f'<text x="{left+120}" y="{tbl_y+17}" class="sig-name">Trap Exception Event</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+17}" class="sig-name">CSR Context Capture (mcause / mepc / mtval)</text>')
    svg.append(f'<text x="{left+850}" y="{tbl_y+17}" class="sig-name">MRET &amp; Pipeline Impact</text>')

    for i, (cyc, tag, color, desc, csr_info) in enumerate(events):
        ry = tbl_y + 44 + (i * 20)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="20" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" font-family="monospace" fill="#0369a1">{xesc(csr_info)}</text>')
        impact_txt = "Full pipeline flush; handler vector to mtvec" if tag.startswith("T") else "Simulation end, all assertions PASS"
        svg.append(f'<text x="{left+850}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{impact_txt}</text>')

    card_y = 390
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("Synchronous Traps", "4 / 4", "Illegal, Break, Misalign, ECALL", "#fee2e2", "#dc2626"),
        ("mtvec Redirects", "4", "Vector to 0x8000_00A0", "#fef3c7", "#d97706"),
        ("MRET Resumptions", "4", "mepc+4 restoration to caller", "#dcfce7", "#16a34a"),
        ("Total Pipeline Flushes", "8", "FlushBP/IF/ID/EX asserted", "#f3e8ff", "#7c3aed"),
        ("Verification Status", "25/25", "100% Assertions PASSED", "#e0f2fe", "#0284c7"),
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


def render_trap_waveform(rows, start, end, title, subtitle, signals, out_path, notes=None):
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
        is_trig = (row.get("ExValid") == "1")
        fill = "#fef2f2" if is_trig else ("#f8fafc" if i % 2 == 0 else "#ffffff")
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        if is_trig:
            svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+len(signals)*row_h}" stroke="#ef4444" stroke-width="1" stroke-dasharray="2,2"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1 or is_trig:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc" fill="{"#dc2626" if is_trig else "#475569"}">C{cyc}</text>')

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
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{"#dc2626" if high and ("Ex" in name or "Flush" in name) else color}">{val}</text>')
                prev = val
        else:
            run_start = 0
            for i in range(1, n + 1):
                if i == n or values[i] != values[run_start]:
                    x1 = left + run_start * col_w
                    x2 = left + i * col_w
                    run_w = x2 - x1
                    val = values[run_start]
                    is_idle = str(val) in ("0", "0x00000000", "0x0000", "-", "0x0")
                    fill_c = "#f1f5f9" if is_idle else "#e0f2fe"
                    border_c = "#cbd5e1" if is_idle else color

                    pts = f"{x1+3:.1f},{y_mid:.1f} {x1+6:.1f},{y_high:.1f} {x2-6:.1f},{y_high:.1f} {x2-3:.1f},{y_mid:.1f} {x2-6:.1f},{y_low:.1f} {x1+6:.1f},{y_low:.1f}"
                    svg.append(f'<polygon points="{pts}" fill="{fill_c}" stroke="{border_c}" stroke-width="1"/>')

                    if not is_idle and run_w >= 26:
                        lbl = pc_label(val, compact=(run_w < 65)) if ("PC" in name or "mepc" in name or "mtval" in name) else str(val)
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
        print("[ERROR] No trace rows found in cva6_trap_trace.csv")
        return

    generate_execution_timeline(rows)

    render_trap_waveform(
        rows, 414, 426,
        "Trap Entry & MTVEC Redirect Waveform: EBREAK",
        "EBREAK at 0x80000070 triggers Cause 3 at Cyc 417, asserting full pipeline flushes and redirecting to MTVEC (0x800000A0)",
        [
            ("FetchPC", "Instruction Fetch Address", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("ExValid", "Exception Valid to CSR", lambda r: r["ExValid"], False, "#dc2626"),
            ("ExceptionCause", "Trap Cause ID", lambda r: f"Cause {hex32(r['ExceptionCause'])}" if r.get("ExValid")=="1" or hex32(r['ExceptionCause'])!=0 else "-", True, "#dc2626"),
            ("FlushBP", "Branch Predictor Flush", lambda r: r["FlushBP"], False, "#e11d48"),
            ("FlushIF", "Instruction Fetch Flush", lambda r: r["FlushIF"], False, "#e11d48"),
            ("FlushID", "Instruction Decode Flush", lambda r: r["FlushID"], False, "#e11d48"),
            ("FlushEX", "Execute Stage Flush", lambda r: r["FlushEX"], False, "#e11d48"),
            ("CsrMepc", "CSR mepc (Return Address)", lambda r: hex32(r["CsrMepc"]), True, "#9333ea"),
            ("CsrMcause", "CSR mcause (Trap Cause)", lambda r: hex32(r["CsrMcause"]), True, "#9333ea"),
            ("CsrMtval", "CSR mtval (Trap Diagnostic)", lambda r: hex32(r["CsrMtval"]), True, "#9333ea"),
        ],
        os.path.join(FIG_DIR, "02_trap_entry_and_mtvec_redirect.svg"),
        notes=[
            "• Cycle 417: EBREAK encounters commit; asserts ExValid=1 with ExceptionCause=3. Controller asserts full flushes (BP/IF/ID/EX).",
            "• Cycle 418: FetchPC redirects to MTVEC (0x8000_00A0). CSR unit latches mepc=0x8000_0070 and mcause=3.",
            "• Cycle 424: Pipeline re-fills and first exception handler instruction commits cleanly.",
        ],
    )

    render_trap_waveform(
        rows, 450, 462,
        "MRET Pipeline State Restoration Waveform",
        "Handler executes MRET at Cyc 454; hardware restores mstatus.MPIE -> MIE, clears privilege stack, and returns to mepc+4 (0x80000074)",
        [
            ("FetchPC", "Instruction Fetch Address", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r["FlushIF"], False, "#e11d48"),
            ("FlushID", "Decode Stage Flush", lambda r: r["FlushID"], False, "#e11d48"),
            ("FlushEX", "Execute Stage Flush", lambda r: r["FlushEX"], False, "#e11d48"),
            ("CsrMepc", "CSR mepc (Target PC)", lambda r: hex32(r["CsrMepc"]), True, "#9333ea"),
            ("CsrMstatus", "CSR mstatus Register", lambda r: f"0x{hex32(r['CsrMstatus']):X}", True, "#9333ea"),
        ],
        os.path.join(FIG_DIR, "03_mret_pipeline_restore.svg"),
        notes=[
            "• Cycle 454: MRET instruction commits at 0x8000_00BC. Controller flushes speculative instructions following MRET.",
            "• Cycle 455: FetchPC redirects to restored mepc (0x8000_0074), successfully stepping over the faulting instruction.",
            "• Cycle 460: Mainline user/kernel code resumes execution with full hardware context integrity.",
        ],
    )

    render_trap_waveform(
        rows, 467, 479,
        "Unaligned Jump Address Capture into mtval",
        "JR t6 to unaligned target 0x80000402 triggers Cause 0 (INSTR_ADDR_MISALIGNED); faulting target captured in mtval",
        [
            ("FetchPC", "Instruction Fetch Address", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("ExValid", "Exception Valid to CSR", lambda r: r["ExValid"], False, "#dc2626"),
            ("ExceptionCause", "Trap Cause ID", lambda r: f"Cause {hex32(r['ExceptionCause'])}" if r.get("ExValid")=="1" or hex32(r['ExceptionCause'])!=0 else "-", True, "#dc2626"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r["FlushIF"], False, "#e11d48"),
            ("CsrMtval", "CSR mtval (Fault Target)", lambda r: hex32(r["CsrMtval"]), True, "#dc2626"),
            ("CsrMepc", "CSR mepc (Faulting Instr PC)", lambda r: hex32(r["CsrMepc"]), True, "#9333ea"),
            ("CsrMcause", "CSR mcause", lambda r: hex32(r["CsrMcause"]), True, "#9333ea"),
        ],
        os.path.join(FIG_DIR, "04_unaligned_jump_mtval_capture.svg"),
        notes=[
            "• Diagnostic Fidelity: When indirect jump JR t6 branches to unaligned target 0x8000_0402, branch unit detects addr[1:0] != 0.",
            "• mtval Capture: Cycle 470 captures exact bad target address 0x8000_0402 directly into mtval for software diagnosis.",
            "• Clean Recovery: Handler reads mtval, increments mepc, and issues MRET returning smoothly to 0x8000_0084.",
        ],
    )


if __name__ == "__main__":
    main()
