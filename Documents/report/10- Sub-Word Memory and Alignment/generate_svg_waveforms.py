# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:20:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 10 SVGs:
#                        standardized 1200px width, eliminated 8.35px cycle squashing
#                        by scoping focused 20-25 cycle fault windows, run-length
#                        bus trapezoids, two-tier opcodes, and clean <tspan> annotations.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_subword_alignment_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp,0x80000",
    0x0004: "ADDI sp,512",
    0x0008: "AUIPC t0,0",
    0x000C: "ADDI t0,168",
    0x0010: "CSRW mtvec,t0",
    0x0014: "LUI s0,0x80000",
    0x0018: "ADDI s0,1024",
    0x001C: "LI t1,17",
    0x0020: "SB t1,0(s0)",
    0x0024: "LI t1,136",
    0x0028: "SB t1,1(s0)",
    0x002C: "LI t1,51",
    0x0030: "SB t1,2(s0)",
    0x0034: "LI t1,170",
    0x0038: "SB t1,3(s0)",
    0x003C: "LB a0,0(s0)",
    0x0040: "LB a1,1(s0)",
    0x0044: "LBU a2,1(s0)",
    0x0048: "LH a3,0(s0)",
    0x004C: "LHU a4,0(s0)",
    0x0050: "LH a5,2(s0)",
    0x0054: "LHU a6,2(s0)",
    0x0058: "LW a7,0(s0)",
    0x005C: "LUI t1,0x5",
    0x0060: "ADDI t1,1348",
    0x0064: "SH t1,0(s0)",
    0x0068: "LUI t1,0xa",
    0x006C: "ADDI t1,-1673",
    0x0070: "SH t1,2(s0)",
    0x0074: "LW s1,0(s0)",
    0x0078: "LI t3,1",
    0x007C: "LW t0,1(s0) [FAULT]",
    0x0080: "NOP",
    0x0084: "LI t3,2",
    0x0088: "SW t0,2(s0) [FAULT]",
    0x008C: "NOP",
    0x0090: "LI t3,3",
    0x0094: "LH t0,3(s0) [FAULT]",
    0x0098: "NOP",
    0x009C: "LI t3,4",
    0x00A0: "SH t0,1(s0) [FAULT]",
    0x00A4: "NOP",
    0x00A8: "LI ra,999",
    0x00AC: "J END_LOOP",
    0x00B0: "CSRR t1,mcause",
    0x00B4: "CSRR t2,mtval",
    0x00B8: "LI t5,1",
    0x00BC: "BEQ t3,t5,TRAP1",
    0x00DC: "MV s4,t1",
    0x00E0: "MV s5,t2",
    0x010C: "CSRR t4,mepc",
    0x0110: "ADDI t4,4",
    0x0114: "CSRW mepc,t4",
    0x0118: "MRET",
}

SHORT_OP = {
    0x0020: "SB",
    0x0028: "SB",
    0x0030: "SB",
    0x0038: "SB",
    0x003C: "LB",
    0x0040: "LB",
    0x0044: "LBU",
    0x0048: "LH",
    0x004C: "LHU",
    0x0050: "LH",
    0x0054: "LHU",
    0x0058: "LW",
    0x0064: "SH",
    0x0070: "SH",
    0x007C: "LW (fault)",
    0x0088: "SW (fault)",
    0x0094: "LH (fault)",
    0x00A0: "SH (fault)",
    0x0118: "MRET",
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
    return [row for row in rows if start <= int(row["cycle"]) <= end]


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
    total_cyc = 603

    phases = [
        (0, 310, "Boot & Init", "#f1f5f9", "#94a3b8", "Cold AXI fetch, set mtvec = 0x8000_00B0"),
        (311, 350, "Sub-Word Accesses", "#dbeafe", "#2563eb", "SB/SH byte enables; LB/LBU/LH/LHU sign/zero extensions"),
        (351, 415, "Unaligned Word Load", "#fee2e2", "#dc2626", "LW from 0x80000401; cause 4; mtval=0x80000401; MRET"),
        (416, 470, "Unaligned Word Store", "#ffedd5", "#ea580c", "SW to 0x80000402; cause 6; mtval=0x80000402; MRET"),
        (471, 525, "Unaligned Half Load", "#fef3c7", "#d97706", "LH from 0x80000403; cause 4; mtval=0x80000403; MRET"),
        (526, 603, "Unaligned Half Store & End", "#dcfce7", "#16a34a", "SH to 0x80000401; cause 6; mtval=0x80000401; self-loop"),
    ]

    events = [
        (351, "T1", "#dc2626", "Unaligned Load (LW 0x401)", "data_misaligned=1, cause=4, mtval=0x80000401"),
        (423, "T2", "#ea580c", "Unaligned Store (SW 0x402)", "data_misaligned=1, cause=6, mtval=0x80000402"),
        (483, "T3", "#d97706", "Unaligned Half Load (LH 0x403)", "data_misaligned=1, cause=4, mtval=0x80000403"),
        (534, "T4", "#7c3aed", "Unaligned Half Store (SH 0x401)", "data_misaligned=1, cause=6, mtval=0x80000401"),
        (578, "E1", "#16a34a", "Terminal Loop Commit", "j end_loop commits; 22/22 assertions PASS"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 10: Sub-Word Memory &amp; Alignment Traps — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 603 | 4 Traps &amp; MRET Recoveries | Active CPI = 5.58</text>')

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
    for tick in [0, 100, 200, 310, 351, 423, 483, 534, 578, 603]:
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
    svg.append(f'<text x="{left+120}" y="{tbl_y+17}" class="sig-name">Alignment Trap Event</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+17}" class="sig-name">Diagnostic Captured into CSR mtval</text>')
    svg.append(f'<text x="{left+850}" y="{tbl_y+17}" class="sig-name">Trap Cause &amp; Hardware Action</text>')

    for i, (cyc, tag, color, desc, diag) in enumerate(events):
        ry = tbl_y + 44 + (i * 20)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="20" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" font-family="monospace" fill="#0369a1">{xesc(diag)}</text>')
        act_txt = "Pipeline flush; mepc+=4 MRET" if tag.startswith("T") else "Simulation end, all assertions PASS"
        svg.append(f'<text x="{left+850}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{act_txt}</text>')

    card_y = 390
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("Sub-Word Extensions", "100%", "LB/LBU/LH/LHU sign/zero match", "#dbeafe", "#2563eb"),
        ("Misaligned Loads (Cause 4)", "2", "mtval=0x401 & 0x403 captured", "#fee2e2", "#dc2626"),
        ("Misaligned Stores (Cause 6)", "2", "mtval=0x402 & 0x401 captured", "#ffedd5", "#ea580c"),
        ("MRET Resumptions", "4", "Correct return to fault PC+4", "#dcfce7", "#16a34a"),
        ("Verification Status", "22/22", "All checks PASSED", "#e0f2fe", "#0284c7"),
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


def render_subword_waveform(rows, start, end, title, subtitle, signals, out_path, notes=None):
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
        cyc = int(row["cycle"])
        x = left + i * col_w
        is_fault = (row.get("data_misaligned") == "1" or row.get("ex_valid") == "1")
        fill = "#fee2e2" if is_fault else ("#f8fafc" if i % 2 == 0 else "#ffffff")
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        if is_fault:
            svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+len(signals)*row_h}" stroke="#ef4444" stroke-width="1" stroke-dasharray="2,2"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1 or is_fault:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc" fill="{"#dc2626" if is_fault else "#475569"}">C{cyc}</text>')

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
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{"#dc2626" if high and ("misalign" in name.lower() or "ex" in name.lower()) else color}">{val}</text>')
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
                        lbl = pc_label(val, compact=(run_w < 65)) if ("PC" in name or "Target" in name or "mepc" in name) else str(val)
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
        print("[ERROR] No trace rows found in cva6_subword_alignment_trace.csv")
        return

    generate_execution_timeline(records)

    render_subword_waveform(
        records, 310, 335,
        "Sub-Word Memory Accesses: Byte & Halfword Formatting",
        "Sign and zero extensions for byte (LB/LBU) and halfword (LH/LHU) instructions with byte-lane write strobes",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["pc_commit0"]), True, "#0284c7"),
            ("Commit Ack", "Commit Port 0 Ack", lambda r: r["commit_ack0"], False, "#16a34a"),
            ("GPR Waddr", "Destination Register", lambda r: f"x{r['gpr_waddr0']}" if r.get("gpr_we0")=="1" and r.get("gpr_waddr0")!="0" else "-", True, "#475569"),
            ("GPR Wdata", "Written Value", lambda r: f"0x{hex32(r['gpr_wdata0']):X}" if r.get("gpr_we0")=="1" else "-", True, "#059669"),
            ("Dual Commit", "Dual Commit Active", lambda r: r.get("dual_commit", "0"), False, "#7c3aed"),
        ],
        os.path.join(FIG_DIR, "02_subword_memory_byte_halfword_extensions.svg"),
        notes=[
            "• Byte-Lane Masking: SB and SH instructions assert write strobes (wstrb) matching unaligned byte offsets.",
            "• Sign vs Zero Extension: LB produces sign-extended 32-bit values (e.g. 0xFFFFFF88), while LBU zero-extends (0x00000088).",
            "• High Throughput: Subword memory accesses hit the L1 D-Cache with zero misalignment bubbles when addresses match word lanes.",
        ],
    )

    render_subword_waveform(
        records, 345, 365,
        "Unaligned Word Load Trap: LD_ADDR_MISALIGNED & mtval",
        "LW from unaligned address 0x80000401 asserts data_misaligned=1; vectors to mtvec with cause 4 and mtval=0x80000401",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["pc_commit0"]), True, "#0284c7"),
            ("Commit Ack", "Commit Instruction Ack", lambda r: r["commit_ack0"], False, "#16a34a"),
            ("Misaligned", "LSU Misaligned Signal", lambda r: r["data_misaligned"], False, "#dc2626"),
            ("ExValid", "Exception Valid Strobe", lambda r: r["ex_valid"], False, "#dc2626"),
            ("CSR mtval", "Faulting Address", lambda r: f"0x{hex32(r['csr_mtval']):X}" if hex32(r['csr_mtval'])!=0 else "-", True, "#dc2626"),
            ("CSR mcause", "Exception Cause ID", lambda r: f"Cause {r['csr_mcause']}" if r['csr_mcause'] not in ("0", "X", "-") else "-", True, "#9333ea"),
            ("MRET", "MRET Executed", lambda r: r["mret"], False, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "03_unaligned_word_fault_and_mtval.svg"),
        notes=[
            "• Cycle 351: Execution unit encounters LW targeting unaligned address 0x8000_0401 (addr[1:0] == 2'b01).",
            "• Precise Exception: LSU asserts data_misaligned=1; commit unit vectors to MTVEC with Cause 4 (LD_ADDR_MISALIGNED).",
            "• Diagnostic Fidelity: Faulting target 0x8000_0401 is captured exactly in CSR mtval for OS software recovery.",
        ],
    )

    render_subword_waveform(
        records, 418, 438,
        "Unaligned Word Store Trap & Handler Recovery Flow",
        "SW to unaligned address 0x80000402 triggers Cause 6 (ST_ADDR_MISALIGNED); handler increments mepc and issues MRET",
        [
            ("Commit PC", "Commit Port 0 PC", lambda r: hex32(r["pc_commit0"]), True, "#0284c7"),
            ("Commit Ack", "Commit Instruction Ack", lambda r: r["commit_ack0"], False, "#16a34a"),
            ("Misaligned", "LSU Misaligned Signal", lambda r: r["data_misaligned"], False, "#dc2626"),
            ("ExValid", "Exception Valid Strobe", lambda r: r["ex_valid"], False, "#dc2626"),
            ("CSR mtval", "Faulting Address", lambda r: f"0x{hex32(r['csr_mtval']):X}" if hex32(r['csr_mtval'])!=0 else "-", True, "#dc2626"),
            ("CSR mcause", "Exception Cause ID", lambda r: f"Cause {r['csr_mcause']}" if r['csr_mcause'] not in ("0", "X", "-") else "-", True, "#9333ea"),
            ("MRET", "MRET Executed", lambda r: r["mret"], False, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "04_unaligned_halfword_fault_and_recovery.svg"),
        notes=[
            "• Cycle 423: SW targeting 0x8000_0402 triggers Cause 6 (ST_ADDR_MISALIGNED) with mtval=0x8000_0402.",
            "• Handler Emulation / Skip: Exception handler reads mtval, logs the fault, increments mepc by 4, and executes MRET.",
            "• Smooth Resumption: Cycle 430 resumes execution cleanly at the next instruction without data cache corruption.",
        ],
    )


if __name__ == "__main__":
    main()
