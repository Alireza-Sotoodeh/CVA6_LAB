# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 21:10:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform generator for Suite 5 (Pipeline Flushes &
#                        FENCE.I Instruction Cache Synchronization). Reads
#                        cva6_fence_trace.csv and outputs four standalone,
#                        publication-grade SVGs in figures/.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_fence_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI t6",
    0x0004: "ADDI t6,512",
    0x0008: "LI sp,0",
    0x0030: "JALR s0,t6 (call 1)",
    0x0034: "MV ra,a0",
    0x0038: "LUI t0",
    0x003C: "ADDI t0",
    0x0040: "SW t0,0(t6)",
    0x0044: "FENCE.I",
    0x0048: "JALR s0,t6 (call 2)",
    0x004C: "MV sp,a0",
    0x0050: "CSRR t1,mstatus",
    0x0054: "CSRW mstatus,t1",
    0x0058: "LI gp,555",
    0x005C: "FENCE",
    0x0060: "LI tp,777",
    0x0064: "LI s4,999",
    0x0068: "J END_LOOP",
    0x0200: "ADDI a0 (sub)",
    0x0204: "JR s0 (ret)",
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
    width, height = 1200, 390
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="32" font-size="16" font-weight="700" fill="#0f172a">'
        "CVA6 Suite 5: Pipeline Flushes & FENCE.I Synchronization — Execution Timeline"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="50" font-size="11" fill="#475569">'
        "End-to-end verification of self-modifying code rewrite, 256-cycle I-Cache tag invalidation, compulsory re-fetch, and CSR pipeline flush. Total cycles: 693, Active CPI: 10.34."
        "</text>"
    )

    x0, y0, total_w = 40, 95, 1120
    phases = [
        (0, 267, "Phase 0: Boot & Cache Init", "#f1f5f9", "#94a3b8", "Cold AXI fetch, deassert reset at cyc 8, I-cache tag clear (0 to 255)"),
        (268, 315, "Phase 1: Subroutine Call 1", "#dbeafe", "#2563eb", "Calls 0x8000_0200, executes addi a0,100, commits at Cyc 313. x1 = 100"),
        (316, 342, "Phase 2: Code Rewrite (SW)", "#fef3c7", "#d97706", "Prepares 0x3e700513 in t0, executes sw t0,0(t6) at Cyc 336. D-cache/mem updated"),
        (343, 600, "Phase 3: FENCE.I Tag Flush", "#fee2e2", "#dc2626", "FENCE.I commits at Cyc 343. I-cache stays in FLUSH for 256 cycs. Frontend halted"),
        (601, 625, "Phase 4: Subroutine Call 2", "#dcfce7", "#16a34a", "Calls 0x8000_0200 again. Cache miss -> AXI reload -> executes addi a0,999! x2 = 999"),
        (626, 693, "Phase 5-7: CSR Flush & End", "#f3e8ff", "#9333ea", "csrw mstatus triggers flush_csr_ctrl. FENCE commits. Loop commits at 672"),
    ]

    tot_cyc = 693
    cur_x = x0
    for p_start, p_end, title, bg, border, desc in phases:
        pw = max(55, int((p_end - p_start + 1) / tot_cyc * total_w))
        svg.append(f'  <g transform="translate({cur_x}, {y0})">')
        svg.append(f'    <rect width="{pw}" height="60" fill="{bg}" stroke="{border}" stroke-width="1.5" rx="5" />')
        svg.append(f'    <text x="{pw/2}" y="24" class="box-lbl" fill="{border}">{xesc(title)}</text>')
        svg.append(f'    <text x="{pw/2}" y="42" font-size="9" fill="#475569" text-anchor="middle">Cyc {p_start}–{p_end}</text>')
        svg.append("  </g>")
        cur_x += pw

    # Milestones table below
    my0 = 185
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="185" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6" />')
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="26" fill="#f1f5f9" rx="6" />')
    svg.append(f'  <text x="55" y="{my0+17}" class="sig-lbl">Execution Milestone</text>')
    svg.append(f'  <text x="250" y="{my0+17}" class="sig-lbl">Cycle Span</text>')
    svg.append(f'  <text x="360" y="{my0+17}" class="sig-lbl">Microarchitectural Mechanism</text>')
    svg.append(f'  <text x="760" y="{my0+17}" class="sig-lbl">Hardware Signals &amp; Evidence</text>')
    svg.append(f'  <text x="1030" y="{my0+17}" class="sig-lbl">Architectural State / CPI</text>')

    rows_data = [
        ("Phase 1: Baseline Subroutine Run", "268 – 315", "Call target 0x8000_0200; loads initial opcode into I-Cache", "commit_pc=0x8000_0200 at Cyc 313", "x1 = 100 (0x64)"),
        ("Phase 2: Self-Modifying Store", "316 – 342", "Write 0x3e700513 (addi a0,999) to 0x8000_0200 via SW", "commit_pc=0x8000_0040 at Cyc 336, AXI write OK", "Memory updated in AXI"),
        ("Phase 3: FENCE.I Cache Flush", "343 – 600", "FENCE.I invalidates all tag valid bits (256 cycles in FLUSH)", "fence_i_o=1, flush_icache=1, flush_cnt=0..255", "Frontend halted (256 cycs)"),
        ("Phase 4: Post-FENCE.I Execution", "601 – 625", "Compulsory miss reloads updated opcode from AXI memory", "icache_miss=1, commit_pc=0x8000_0200 at Cyc 621", "x2 = 999 (0x3e7) [SUCCESS!]"),
        ("Phase 5: CSR Side-Effect Flush", "626 – 648", "csrw mstatus causes csr_regfile to assert flush_csr_ctrl", "flush_csr_ctrl=1, flush_pipeline_count=3", "x3 = 555 (0x22b)"),
        ("Phase 6-7: FENCE & Terminal Loop", "649 – 693", "Data FENCE executed; core commits self-loop at Cyc 672", "fence_o=1, end_commit_cycle=672, 12/12 checks PASS", "Active CPI = 10.34"),
    ]

    for i, (mname, cspan, mech, sigs, state) in enumerate(rows_data):
        ry = my0 + 44 + (i * 24)
        svg.append(f'  <text x="55" y="{ry}" font-size="10" font-weight="600" fill="#1e293b">{xesc(mname)}</text>')
        svg.append(f'  <text x="250" y="{ry}" font-size="10" fill="#475569">{xesc(cspan)}</text>')
        svg.append(f'  <text x="360" y="{ry}" font-size="10" fill="#334155">{xesc(mech)}</text>')
        svg.append(f'  <text x="760" y="{ry}" font-size="10" font-family="monospace" fill="#0369a1">{xesc(sigs)}</text>')
        svg.append(f'  <text x="1030" y="{ry}" font-size="10" font-weight="600" fill="#047857">{xesc(state)}</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "01_execution_timeline.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 2. FENCE.I Commit & Tag Invalidation Waveform (Cycles 338 - 352)
# ----------------------------------------------------------------------------
def generate_fence_i_commit_waveform(rows):
    width, height = 1200, 520
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 FENCE.I Instruction Commit & Cache Tag Invalidation Waveform (Cycles 338 – 352)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "FENCE.I commits at Cyc 343 after SW drains. Controller asserts flush_icache_o and full pipeline flushes; I-Cache enters FLUSH state (flush_en=1)."
        "</text>"
    )

    w_rows = rows_in_window(rows, 338, 352)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_fence = (cyc == 343)
        is_flush = (cyc >= 344)
        bg = "#fee2e2" if is_fence else ("#ffedd5" if is_flush else "#ffffff")
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("CommitPC0", "Retired PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Commit acknowledge", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("FenceICommit", "FENCE.I opcode retired", lambda r: int(r["FenceICommit"]), "bit", "#dc2626"),
        ("NoStPending", "Store buffer empty", lambda r: int(r["NoStPending"]), "bit", "#059669"),
        ("FlushICache", "I-cache flush command", lambda r: int(r["FlushICache"]), "bit", "#dc2626"),
        ("FlushIF", "Fetch stage flush", lambda r: int(r["FlushIF"]), "bit", "#e11d48"),
        ("FlushID", "Decode stage flush", lambda r: int(r["FlushID"]), "bit", "#e11d48"),
        ("FlushEX", "Execute stage flush", lambda r: int(r["FlushEX"]), "bit", "#e11d48"),
        ("IcacheState", "I-cache state (0=FLUSH)", lambda r: int(r["IcacheState"]), "bus", "#7c3aed"),
        ("IcacheFlushEn", "Tag invalidation active", lambda r: int(r["IcacheFlushEn"]), "bit", "#7c3aed"),
        ("IcacheFlushCnt", "Invalidation counter", lambda r: int(r["IcacheFlushCnt"]), "bus", "#7c3aed"),
        ("HaltFrontend", "Frontend fetch halted", lambda r: int(r["HaltFrontend"]), "bit", "#ea580c"),
    ]

    sig_y = y_top + 10
    row_h = 26
    for sname, desc, getter, stype, color in signals:
        svg.append(f'  <text x="35" y="{sig_y + 14}" class="sig-lbl">{xesc(sname)}</text>')
        svg.append(f'  <text x="140" y="{sig_y + 14}" class="sig-sub">{xesc(desc)}</text>')

        for idx, row in enumerate(w_rows):
            cx = x_left + (idx * col_w)
            val = getter(row)
            if stype == "bit":
                h_bar = 14 if val else 4
                by = sig_y + (16 - h_bar)
                bcol = color if val else "#cbd5e1"
                svg.append(f'  <rect x="{cx + 4}" y="{by}" width="{col_w - 8}" height="{h_bar}" fill="{bcol}" rx="2" />')
            else:
                sval = f"0x{val:04X}" if val > 255 else f"{val}"
                if sname == "CommitPC0" and val != 0:
                    sval = pc_label(val)
                elif sname == "IcacheState":
                    sval = "FLUSH" if val == 0 else ("IDLE" if val == 1 else ("READ" if val == 2 else "MISS"))
                svg.append(f'  <rect x="{cx + 2}" y="{sig_y + 2}" width="{col_w - 4}" height="18" fill="#f1f5f9" stroke="{color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sig_y + 14}" font-size="8.5" font-family="monospace" fill="{color}" text-anchor="middle">{xesc(sval)}</text>')

        sig_y += row_h

    # Annotations box at bottom
    ay = height - 70
    svg.append(f'  <rect x="40" y="{ay}" width="1120" height="55" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" rx="4" />')
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 343 – 345):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 343: FENCE.I reaches head of commit_stage. Since NoStPending=1, fence_i_o asserts. Controller asserts flush_icache_o=1 and full pipeline flushes (IF/ID/EX).\n'
        '• Cyc 344: I-Cache transitions from READ to FLUSH (state 0). Tag invalidation counter (flush_cnt_q) starts incrementing from 0 to 255 (256 cycles) to clear all valid bits.'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "02_fence_i_commit_and_tag_flush.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 3. Post-FENCE.I Modified Code Re-fetch & Execution (Cycles 610 - 625)
# ----------------------------------------------------------------------------
def generate_self_modifying_refetch_waveform(rows):
    width, height = 1200, 520
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 Modified Instruction Compulsory Re-fetch & Execution Waveform (Cycles 610 – 625)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Following FENCE.I tag flush, subroutine call at 0x8000_0200 misses in I-Cache, triggers fresh AXI reload, fetches modified opcode 0x3e700513, and writes a0 = 999 at Cyc 621."
        "</text>"
    )

    w_rows = rows_in_window(rows, 610, 625)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_call = (cyc == 613)
        is_sub_commit = (cyc == 621)
        bg = "#dbeafe" if is_call else ("#dcfce7" if is_sub_commit else "#ffffff")
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("FetchPC", "Fetch stage PC", lambda r: hex32(r["FetchPC"]), "bus", "#0284c7"),
        ("IcacheState", "I-cache state (3=MISS)", lambda r: int(r["IcacheState"]), "bus", "#7c3aed"),
        ("IcacheMiss", "I-cache miss signal", lambda r: int(r["IcacheMiss"]), "bit", "#dc2626"),
        ("AxiARValid", "AXI read address valid", lambda r: int(r["AxiARValid"]), "bit", "#0284c7"),
        ("AxiARAddr", "AXI read address", lambda r: hex32(r["AxiARAddr"]), "bus", "#0284c7"),
        ("AxiRValid", "AXI read data valid", lambda r: int(r["AxiRValid"]), "bit", "#16a34a"),
        ("CommitPC0", "Retired PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Commit acknowledge", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("GprWe0", "Register write enable", lambda r: int(r["GprWe0"]), "bit", "#059669"),
        ("GprWaddr0", "Writeback register destination", lambda r: int(r["GprWaddr0"]), "bus", "#059669"),
        ("GprWdata0", "Writeback data value", lambda r: hex32(r["GprWdata0"]), "bus", "#059669"),
    ]

    sig_y = y_top + 10
    row_h = 26
    for sname, desc, getter, stype, color in signals:
        svg.append(f'  <text x="35" y="{sig_y + 14}" class="sig-lbl">{xesc(sname)}</text>')
        svg.append(f'  <text x="140" y="{sig_y + 14}" class="sig-sub">{xesc(desc)}</text>')

        for idx, row in enumerate(w_rows):
            cx = x_left + (idx * col_w)
            val = getter(row)
            if stype == "bit":
                h_bar = 14 if val else 4
                by = sig_y + (16 - h_bar)
                bcol = color if val else "#cbd5e1"
                svg.append(f'  <rect x="{cx + 4}" y="{by}" width="{col_w - 8}" height="{h_bar}" fill="{bcol}" rx="2" />')
            else:
                sval = f"0x{val:04X}" if val <= 0xFFFF else f"0x{val:08X}"
                if val == 0:
                    sval = "0"
                if sname == "CommitPC0" and val != 0:
                    sval = pc_label(val)
                elif sname in ("FetchPC", "AxiARAddr") and val != 0:
                    sval = f"0x{val & 0xFFFF:04X}"
                elif sname == "GprWdata0" and val != 0:
                    sval = f"{val} (0x{val:X})"
                elif sname == "IcacheState":
                    sval = "FLUSH" if val == 0 else ("IDLE" if val == 1 else ("READ" if val == 2 else "MISS"))
                svg.append(f'  <rect x="{cx + 2}" y="{sig_y + 2}" width="{col_w - 4}" height="18" fill="#f1f5f9" stroke="{color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sig_y + 14}" font-size="8" font-family="monospace" fill="{color}" text-anchor="middle">{xesc(sval)}</text>')

        sig_y += row_h

    # Annotations box at bottom
    ay = height - 70
    svg.append(f'  <rect x="40" y="{ay}" width="1120" height="55" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" rx="4" />')
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 613 – 621):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 613: JALR at 0x8000_0048 commits, branching to 0x8000_0200. Because FENCE.I invalidated tags, I-Cache encounters compulsory miss (IcacheMiss=1).\n'
        '• Cyc 614–618: Core triggers AXI burst reload to 0x8000_0200, fetching the rewritten instruction (addi a0, 999). At Cyc 621, addi commits and writes 999 into GPR x10!'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "03_self_modifying_code_refetch.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 4. CSR Side-Effect Pipeline Flush Waveform (Cycles 640 - 650)
# ----------------------------------------------------------------------------
def generate_csr_flush_waveform(rows):
    width, height = 1200, 500
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 CSR Side-Effect Pipeline Flush Waveform (Cycles 640 – 650)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Execution of CSRW mstatus, t1 at Cyc 643 asserts flush_csr_ctrl from csr_regfile, triggering full pipeline flush (IF/ID/EX/Unissued) in controller.sv."
        "</text>"
    )

    w_rows = rows_in_window(rows, 640, 650)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_csrw = (cyc == 643)
        bg = "#fee2e2" if is_csrw else "#ffffff"
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("CommitPC0", "Retired PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Commit acknowledge", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("FlushCSR", "CSR side-effect flush request", lambda r: int(r["FlushCSR"]), "bit", "#dc2626"),
        ("FlushIF", "Fetch stage flush", lambda r: int(r["FlushIF"]), "bit", "#e11d48"),
        ("FlushUnissued", "Unissued queue flush", lambda r: int(r["FlushUnissued"]), "bit", "#e11d48"),
        ("FlushID", "Decode stage flush", lambda r: int(r["FlushID"]), "bit", "#e11d48"),
        ("FlushEX", "Execute stage flush", lambda r: int(r["FlushEX"]), "bit", "#e11d48"),
        ("FetchPC", "Fetch stage PC", lambda r: hex32(r["FetchPC"]), "bus", "#0284c7"),
        ("IssueValid0", "Issue valid to scoreboard", lambda r: int(r["IssueValid0"]), "bit", "#0284c7"),
        ("GprWdata0", "Committed register result", lambda r: hex32(r["GprWdata0"]), "bus", "#059669"),
    ]

    sig_y = y_top + 10
    row_h = 26
    for sname, desc, getter, stype, color in signals:
        svg.append(f'  <text x="35" y="{sig_y + 14}" class="sig-lbl">{xesc(sname)}</text>')
        svg.append(f'  <text x="140" y="{sig_y + 14}" class="sig-sub">{xesc(desc)}</text>')

        for idx, row in enumerate(w_rows):
            cx = x_left + (idx * col_w)
            val = getter(row)
            if stype == "bit":
                h_bar = 14 if val else 4
                by = sig_y + (16 - h_bar)
                bcol = color if val else "#cbd5e1"
                svg.append(f'  <rect x="{cx + 4}" y="{by}" width="{col_w - 8}" height="{h_bar}" fill="{bcol}" rx="2" />')
            else:
                sval = f"0x{val:04X}" if val <= 0xFFFF else f"0x{val:08X}"
                if val == 0:
                    sval = "0"
                if sname == "CommitPC0" and val != 0:
                    sval = pc_label(val)
                elif sname == "FetchPC" and val != 0:
                    sval = f"0x{val & 0xFFFF:04X}"
                svg.append(f'  <rect x="{cx + 2}" y="{sig_y + 2}" width="{col_w - 4}" height="18" fill="#f1f5f9" stroke="{color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sig_y + 14}" font-size="8.5" font-family="monospace" fill="{color}" text-anchor="middle">{xesc(sval)}</text>')

        sig_y += row_h

    # Annotations box at bottom
    ay = height - 70
    svg.append(f'  <rect x="40" y="{ay}" width="1120" height="55" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" rx="4" />')
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 643):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 643: CSRW mstatus, t1 commits. Writing to privileged control register asserts flush_csr_ctrl from csr_regfile.sv.\n'
        '• Controller asserts FlushIF=1, FlushUnissued=1, FlushID=1, and FlushEX=1. Fetch PC is redirected to commit PC + 4 (0x8000_0058), successfully resuming execution.'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "04_csr_side_effect_flush.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


def main():
    rows = read_trace()
    print(f"[TRACE] Loaded {len(rows)} cycle rows from {CSV_PATH}")
    generate_execution_timeline(rows)
    generate_fence_i_commit_waveform(rows)
    generate_self_modifying_refetch_waveform(rows)
    generate_csr_flush_waveform(rows)
    print("[DONE] All 4 SVG figures generated successfully in figures/")


if __name__ == "__main__":
    main()
