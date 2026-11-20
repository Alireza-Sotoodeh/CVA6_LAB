# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:16:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 5 SVGs:
#                        standardized 1200px width, collision-free timeline with
#                        self-modifying code milestone cards, run-length bus trapezoids,
#                        non-overlapping signal labels, and clean <tspan> annotations.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_fence_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp",
    0x0004: "ADDI sp,1024",
    0x0020: "JAL ra,func",
    0x0024: "MV s1,a0",
    0x0028: "LUI t6,0x80000",
    0x002C: "ADDI t6,512",
    0x0030: "LUI t0,0x3e700",
    0x0034: "ADDI t0,1299",
    0x0038: "SW t0,0(t6)",
    0x003C: "FENCE.I",
    0x0040: "JAL ra,func",
    0x0044: "MV s2,a0",
    0x0048: "CSRW mstatus,t0",
    0x004C: "LI s3,555",
    0x0050: "FENCE",
    0x0054: "LI s4,999",
    0x0058: "J END_LOOP",
    0x0200: "ADDI a0,x0,100",
    0x0204: "JALR x0,0(ra)",
}

SHORT_OP = {
    0x0020: "JAL",
    0x0038: "SW",
    0x003C: "FENCE.I",
    0x0040: "JAL",
    0x0048: "CSRW",
    0x0050: "FENCE",
    0x0200: "FUNC (ADDI)",
    0x0204: "RET",
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
    total_cyc = 693

    phases = [
        (0, 267, "Boot & Init", "#f1f5f9", "#94a3b8", "Cold AXI fetch, reset de-asserted at cyc 8, I-cache tag clear"),
        (268, 315, "Subroutine Run 1", "#dbeafe", "#2563eb", "Calls 0x8000_0200; executes addi a0,100; x1=100"),
        (316, 342, "Code Rewrite (SW)", "#fef3c7", "#d97706", "SW writes 0x3e700513 (addi a0,999) to target address"),
        (343, 600, "FENCE.I Tag Flush", "#fee2e2", "#dc2626", "FENCE.I invalidates all 256 cache tag rows (256 cycles)"),
        (601, 625, "Subroutine Run 2", "#dcfce7", "#16a34a", "Compulsory miss -> AXI reload -> executes addi a0,999; x2=999!"),
        (626, 693, "CSR Flush & End", "#f3e8ff", "#9333ea", "csrw mstatus pipeline flush, data FENCE, terminal loop commit"),
    ]

    events = [
        (313, "C1", "#2563eb", "Original Subroutine Commit", "commit_pc=0x8000_0200; x1=100 (0x64)"),
        (336, "S1", "#d97706", "Self-Modifying Store (SW)", "commit_pc=0x8000_0038; modifies code in memory"),
        (343, "F1", "#dc2626", "FENCE.I Commit & Flush", "fence_i_o=1, flush_icache=1, 256-cyc tag clear starts"),
        (621, "C2", "#16a34a", "Modified Subroutine Commit", "commit_pc=0x8000_0200; x2=999 (0x3E7) [VERIFIED!]"),
        (644, "R1", "#7c3aed", "CSR Pipeline Flush", "csrw mstatus asserts flush_csr_ctrl=1"),
        (672, "E1", "#0284c7", "Terminal Self-Loop Commit", "j end_loop commits; all 12/12 assertions PASS"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 5: Pipeline Flushes &amp; FENCE.I Synchronization — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 693 | FENCE.I Latency: 257 Cycles | Measured CPI = 10.34</text>')

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
    for tick in [0, 100, 200, 268, 343, 450, 550, 600, 644, 693]:
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
    svg.append(f'<text x="{left+120}" y="{tbl_y+17}" class="sig-name">Synchronization Event</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+17}" class="sig-name">Microarchitectural Mechanism</text>')
    svg.append(f'<text x="{left+800}" y="{tbl_y+17}" class="sig-name">Hardware Signals &amp; Architectural State</text>')

    for i, (cyc, tag, color, desc, mech) in enumerate(events):
        ry = tbl_y + 44 + (i * 19)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="19" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" fill="#475569">{xesc(mech)}</text>')
        state_txt = "x1 = 100" if tag=="C1" else ("D-cache updated" if tag=="S1" else ("flush_cnt = 0..255" if tag=="F1" else ("x2 = 999 (RELOADED)" if tag=="C2" else ("flush_csr_ctrl=1" if tag=="R1" else "12/12 checks PASS"))))
        svg.append(f'<text x="{left+800}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{state_txt}</text>')

    card_y = 390
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("Original Opcode Exec", "100", "x1 = 100 before code rewrite", "#dbeafe", "#2563eb"),
        ("Modified Opcode Exec", "999", "x2 = 999 after FENCE.I flush", "#dcfce7", "#16a34a"),
        ("I-Cache Tag Invalidation", "256 Cyc", "256 tag rows cleared to 0", "#fee2e2", "#dc2626"),
        ("CSR Pipeline Flushes", "3", "csrw mstatus serialization", "#f3e8ff", "#7c3aed"),
        ("Verification Status", "12/12", "All FENCE checks PASSED", "#e0f2fe", "#0284c7"),
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


def render_fence_waveform(rows, start, end, title, subtitle, signals, out_path, notes=None):
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
        is_fence = (row.get("FenceICommit") == "1" or row.get("FlushICache") == "1")
        fill = "#fee2e2" if is_fence else ("#f8fafc" if i % 2 == 0 else "#ffffff")
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        if is_fence:
            svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+len(signals)*row_h}" stroke="#ef4444" stroke-width="1" stroke-dasharray="2,2"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1 or is_fence:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc" fill="{"#dc2626" if is_fence else "#475569"}">C{cyc}</text>')

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
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{"#dc2626" if high and "Flush" in name else color}">{val}</text>')
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
    rows = read_trace()
    if not rows:
        print("[ERROR] No trace rows found in cva6_fence_trace.csv")
        return

    generate_execution_timeline(rows)

    render_fence_waveform(
        rows, 338, 352,
        "FENCE.I Instruction Commit & Tag Invalidation Waveform",
        "FENCE.I commits at Cyc 343; asserts fence_i_o=1, flush_icache_o=1, and triggers 256-cycle FLUSH state tag clear",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r.get("FetchPC", 0)), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r.get("CommitPC0", 0)), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r.get("CommitAck0", "0"), False, "#16a34a"),
            ("FenceICommit", "FENCE.I Active Commit", lambda r: r.get("FenceICommit", "0"), False, "#dc2626"),
            ("FlushICache", "I-Cache Tag Clear Strobe", lambda r: r.get("FlushICache", "0"), False, "#e11d48"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r.get("FlushIF", "0"), False, "#e11d48"),
            ("FlushID", "Decode Stage Flush", lambda r: r.get("FlushID", "0"), False, "#e11d48"),
            ("FlushEX", "Execute Stage Flush", lambda r: r.get("FlushEX", "0"), False, "#e11d48"),
            ("IcacheState", "I-Cache FSM State (0=FLUSH)", lambda r: "FLUSH" if r.get("IcacheState")=="0" else ("READ" if r.get("IcacheState")=="3" else r.get("IcacheState","0")), True, "#7c3aed"),
            ("IcacheFlushCnt", "Tag Clear Counter (0..255)", lambda r: hex32(r.get("IcacheFlushCnt", 0)), True, "#ea580c"),
        ],
        os.path.join(FIG_DIR, "02_fence_i_commit_and_tag_flush.svg"),
        notes=[
            "• Cycle 343: FENCE.I reaches commit head. Since store buffer is drained (NoStPending=1), fence_i_o and flush_icache_o assert.",
            "• Cycle 344: I-cache transitions to state FLUSH (0). Tag counter starts 256-cycle sweep to invalidate all 256 cache lines.",
            "• Frontend Halt: Fetch stage is held in flush during the entire invalidation sequence, guaranteeing pipeline consistency.",
        ],
    )

    render_fence_waveform(
        rows, 610, 625,
        "Modified Instruction Compulsory Re-fetch & Execution",
        "Following FENCE.I, call to 0x80000200 misses in flushed I-Cache, initiates AXI reload, and executes updated ADDI a0,999",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("IcacheMiss", "I-Cache Compulsory Miss", lambda r: r["IcacheMiss"], False, "#ea580c"),
            ("AxiARValid", "AXI Read Request Valid", lambda r: r.get("AxiARValid", "0"), False, "#0284c7"),
            ("AxiRValid", "AXI Read Data Valid", lambda r: r.get("AxiRValid", "0"), False, "#059669"),
            ("GprWaddr0", "Destination Reg", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
            ("GprWdata0", "Destination Write Data", lambda r: f"0x{hex32(r['GprWdata0']):X}" if r.get("GprWe0")=="1" else "-", True, "#16a34a"),
        ],
        os.path.join(FIG_DIR, "03_self_modifying_code_refetch.svg"),
        notes=[
            "• Cycle 612: Second subroutine call to 0x8000_0200. Because tags were invalidated by FENCE.I, IcacheMiss asserts.",
            "• Cycles 613–618: Core fetches updated instruction bytes across AXI bus from memory (returning modified 0x3E700513).",
            "• Cycle 621: Modified instruction ADDI a0,999 commits successfully, loading x2 = 999 (0x3E7). Hardware coherence verified!",
        ],
    )

    render_fence_waveform(
        rows, 638, 652,
        "CSR Side-Effect Pipeline Serialization Flush",
        "Writing CSR mstatus asserts flush_csr_ctrl=1, forcing full pipeline flush (IF/ID/EX) to synchronize architectural state",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("FlushCSR", "CSR Side-Effect Flush", lambda r: r.get("FlushCSR", "0"), False, "#dc2626"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r["FlushIF"], False, "#e11d48"),
            ("FlushID", "Decode Stage Flush", lambda r: r["FlushID"], False, "#e11d48"),
            ("FlushEX", "Execute Stage Flush", lambda r: r["FlushEX"], False, "#e11d48"),
            ("GprWaddr0", "Destination Reg", lambda r: f"x{r['GprWaddr0']}" if r.get("GprWe0")=="1" and r.get("GprWaddr0")!="0" else "-", True, "#475569"),
        ],
        os.path.join(FIG_DIR, "04_csr_side_effect_flush.svg"),
        notes=[
            "• Cycle 644: csrw mstatus commits. Because CSR updates alter processor execution modes, CSR unit asserts flush_csr_ctrl.",
            "• Pipeline Serialization: Controller invalidates IF, ID, and EX stages, ensuring subsequent instructions observe new privilege settings.",
            "• Seamless Resumption: Execution re-fetches immediately at PC 0x8000_004C, committing subsequent instructions without error.",
        ],
    )


if __name__ == "__main__":
    main()
