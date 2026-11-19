# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 20:55:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform generator for Suite 4 (Traps, Exceptions &
#                        Privilege Architecture). Reads cva6_trap_trace.csv and
#                        outputs four publication-grade SVGs in figures/.
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
    0x00A4: "CSRR t3,mcause",
    0x00A8: "CSRR t4,mepc",
    0x00AC: "CSRR t5,mtval",
    0x00B0: "LI t6,1",
    0x00B4: "BEQ sp,t6",
    0x00D4: "MV a0,t3",
    0x00D8: "MV a1,t4",
    0x00DC: "J trap_return",
    0x00E0: "MV a2,t3",
    0x00E4: "MV a3,t4",
    0x00EC: "MV a4,t3",
    0x00F0: "MV a5,t4",
    0x00F4: "MV a6,t5",
    0x00FC: "MV a7,t3",
    0x0100: "MV s2,t4",
    0x0108: "ADDI t4,t4,4",
    0x010C: "CSRW mepc,t4",
    0x0110: "MRET",
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
    width, height = 1200, 380
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="32" font-size="16" font-weight="700" fill="#0f172a">'
        "CVA6 Suite 4: Traps, Exceptions & Privilege Architecture — Execution Timeline"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="50" font-size="11" fill="#475569">'
        "Chronological progression of 4 synchronous traps, CSR state capture, full pipeline flushes, and MRET returns. Total cycles: 615, Committed instrs: 115."
        "</text>"
    )

    x0, y0, total_w = 40, 95, 1120
    phases = [
        (0, 266, "Phase 0: Boot & MTVEC Setup", "#f1f5f9", "#94a3b8", "Cold AXI fetch, deassert reset at cyc 9, set mtvec = 0x8000_00a0"),
        (267, 406, "Phase 1: Trap 1 (ILLEGAL_INSTR)", "#fee2e2", "#dc2626", "Fault at 0x8000_0064 (.word 0). Vector to mtvec, save mcause=2, mepc, MRET at 403"),
        (407, 458, "Phase 2: Trap 2 (BREAKPOINT / EBREAK)", "#ffedd5", "#ea580c", "ebreak at 0x8000_0070. Vector to mtvec, save mcause=3, mepc, mtval, MRET at 454"),
        (459, 518, "Phase 3: Trap 3 (MISALIGNED_JUMP)", "#fef3c7", "#d97706", "jr t6 (0x8000_0402). Cause 0, capture mtval=0x8000_0402, mepc=0x8000_0080, MRET at 514"),
        (519, 563, "Phase 4: Trap 4 (ENV_CALL_MMODE)", "#dbeafe", "#2563eb", "ecall at 0x8000_008c. Cause 11, mepc=0x8000_008c, save to x17/x18, MRET at 559"),
        (564, 615, "Phase 5: Self-Loop & Verification", "#dcfce7", "#16a34a", "li s3,401, li s4,999, commit self-loop at 0x8000_0098 (cyc 575). All 25 checks PASS"),
    ]

    tot_cyc = 615
    cur_x = x0
    for p_start, p_end, title, bg, border, desc in phases:
        pw = max(50, int((p_end - p_start + 1) / tot_cyc * total_w))
        svg.append(f'  <g transform="translate({cur_x}, {y0})">')
        svg.append(f'    <rect width="{pw}" height="60" fill="{bg}" stroke="{border}" stroke-width="1.5" rx="5" />')
        svg.append(f'    <text x="{pw/2}" y="24" class="box-lbl" fill="{border}">{xesc(title)}</text>')
        svg.append(f'    <text x="{pw/2}" y="42" font-size="9" fill="#475569" text-anchor="middle">Cyc {p_start}–{p_end}</text>')
        svg.append("  </g>")
        cur_x += pw

    # Milestones table below
    my0 = 185
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="175" fill="#ffffff" stroke="#cbd5e1" stroke-width="1" rx="6" />')
    svg.append(f'  <rect x="40" y="{my0}" width="1120" height="26" fill="#f1f5f9" rx="6" />')
    svg.append(f'  <text x="55" y="{my0+17}" class="sig-lbl">Trap / Event</text>')
    svg.append(f'  <text x="210" y="{my0+17}" class="sig-lbl">Trigger PC</text>')
    svg.append(f'  <text x="310" y="{my0+17}" class="sig-lbl">Cycle Trigger</text>')
    svg.append(f'  <text x="410" y="{my0+17}" class="sig-lbl">Exception Cause</text>')
    svg.append(f'  <text x="590" y="{my0+17}" class="sig-lbl">CSR State (mcause / mepc / mtval)</text>')
    svg.append(f'  <text x="890" y="{my0+17}" class="sig-lbl">Return Cycle (MRET)</text>')
    svg.append(f'  <text x="1030" y="{my0+17}" class="sig-lbl">Flushes (Full / BP)</text>')

    rows_data = [
        ("Trap 1: ILLEGAL_INSTR", "0x8000_0064", "Cyc 334", "Cause 2 (Illegal instruction)", "mcause=2, mepc=0x8000_0064, mtval=0", "Cyc 403 (mepc+=4 -> 0x8000_0068)", "Full=2, BP=2"),
        ("Trap 2: BREAKPOINT (ebreak)", "0x8000_0070", "Cyc 417", "Cause 3 (Breakpoint)", "mcause=3, mepc=0x8000_0070, mtval=0x8000_0070", "Cyc 454 (mepc+=4 -> 0x8000_0074)", "Full=2, BP=2"),
        ("Trap 3: MISALIGNED_JUMP", "0x8000_0080", "Cyc 470", "Cause 0 (Instr addr misaligned)", "mcause=0, mepc=0x8000_0080, mtval=0x8000_0402", "Cyc 514 (mepc+=4 -> 0x8000_0084)", "Full=2, BP=2"),
        ("Trap 4: ECALL (M-Mode)", "0x8000_008c", "Cyc 523", "Cause 11 (Environment call M-mode)", "mcause=11, mepc=0x8000_008c, mtval=0", "Cyc 559 (mepc+=4 -> 0x8000_0090)", "Full=2, BP=2"),
        ("Terminal Self-Loop Commit", "0x8000_0098", "Cyc 575", "Normal commit (j end_loop)", "Final markers: x19=401, x20=999, trap_cnt=4", "Simulation end @ Cyc 615", "Active CPI = 2.69"),
    ]

    for i, (tname, tpc, cstart, cause, csrs, mret, flushes) in enumerate(rows_data):
        ry = my0 + 44 + (i * 26)
        svg.append(f'  <text x="55" y="{ry}" font-size="10" font-weight="600" fill="#1e293b">{xesc(tname)}</text>')
        svg.append(f'  <text x="210" y="{ry}" font-size="10" font-family="monospace" fill="#0369a1">{xesc(tpc)}</text>')
        svg.append(f'  <text x="310" y="{ry}" font-size="10" fill="#475569">{xesc(cstart)}</text>')
        svg.append(f'  <text x="410" y="{ry}" font-size="10" fill="#334155">{xesc(cause)}</text>')
        svg.append(f'  <text x="590" y="{ry}" font-size="10" font-family="monospace" fill="#7c3aed">{xesc(csrs)}</text>')
        svg.append(f'  <text x="890" y="{ry}" font-size="10" fill="#475569">{xesc(mret)}</text>')
        svg.append(f'  <text x="1030" y="{ry}" font-size="10" font-weight="600" fill="#047857">{xesc(flushes)}</text>')

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "01_execution_timeline.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 2. Trap Entry & MTVEC Redirect Waveform (Cycles 414 - 426)
# ----------------------------------------------------------------------------
def generate_trap_entry_waveform(rows):
    width, height = 1200, 500
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 Trap Entry & MTVEC Vectoring Waveform — EBREAK (Cycles 414 – 426)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Execution of EBREAK at 0x8000_0070 triggers Cause 3 at Cyc 417, asserting full pipeline flushes (BP/IF/ID/EX) and redirecting FetchPC to MTVEC (0x8000_00a0)."
        "</text>"
    )

    w_rows = rows_in_window(rows, 414, 426)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    # Cycle headers
    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_trigger = (cyc == 417)
        is_first_commit = (cyc == 424)
        bg = "#fee2e2" if is_trigger else ("#dbeafe" if is_first_commit else "#ffffff")
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("FetchPC", "Fetch stage PC", lambda r: hex32(r["FetchPC"]), "bus", "#0284c7"),
        ("CommitPC0", "Retired instruction PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Instruction retired", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("ExValid", "Exception valid to CSR", lambda r: int(r["ExValid"]), "bit", "#dc2626"),
        ("ExceptionCause", "Trap cause ID", lambda r: hex32(r["ExceptionCause"]), "bus", "#dc2626"),
        ("FlushBP", "Branch predictor flush", lambda r: int(r["FlushBP"]), "bit", "#e11d48"),
        ("FlushIF", "Instruction fetch flush", lambda r: int(r["FlushIF"]), "bit", "#e11d48"),
        ("FlushID", "Instruction decode flush", lambda r: int(r["FlushID"]), "bit", "#e11d48"),
        ("FlushEX", "Execute stage flush", lambda r: int(r["FlushEX"]), "bit", "#e11d48"),
        ("CsrMepc", "CSR mepc (return PC)", lambda r: hex32(r["CsrMepc"]), "bus", "#9333ea"),
        ("CsrMcause", "CSR mcause (trap cause)", lambda r: hex32(r["CsrMcause"]), "bus", "#9333ea"),
        ("CsrMtval", "CSR mtval (fault address)", lambda r: hex32(r["CsrMtval"]), "bus", "#9333ea"),
    ]

    sig_y = y_top + 10
    row_h = 24
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
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 417 – 424):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 417: Commit unit encounters EBREAK; asserts ExValid=1 with ExceptionCause=3. Simultaneously, controller.sv asserts FlushBP=1, FlushIF=1, FlushID=1, FlushEX=1.\n'
        '• Cyc 418: FetchPC is redirected to MTVEC (0x8000_00a0); CSRs latch mepc=0x8000_0070 and mcause=0x3. In Cyc 424, first handler instruction commits.'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "02_trap_entry_and_mtvec_redirect.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 3. MRET Pipeline Restore Waveform (Cycles 450 - 462)
# ----------------------------------------------------------------------------
def generate_mret_waveform(rows):
    width, height = 1200, 500
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 MRET Instruction Execution & Pipeline Restore Waveform (Cycles 450 – 462)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Execution of MRET at 0x8000_0110 (Cyc 454) asserts Eret=1, flushes the entire pipeline, and restores FetchPC from mepc (0x8000_0074) to resume main code at Cyc 461."
        "</text>"
    )

    w_rows = rows_in_window(rows, 450, 462)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_mret = (cyc == 454)
        is_resume = (cyc == 461)
        bg = "#fef3c7" if is_mret else ("#dcfce7" if is_resume else "#ffffff")
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("FetchPC", "Fetch stage PC", lambda r: hex32(r["FetchPC"]), "bus", "#0284c7"),
        ("CommitPC0", "Retired instruction PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Instruction retired", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("Eret", "MRET instruction retired", lambda r: int(r["Eret"]), "bit", "#d97706"),
        ("CsrEpc", "Exception PC target", lambda r: hex32(r["CsrEpc"]), "bus", "#d97706"),
        ("FlushBP", "Branch predictor flush", lambda r: int(r["FlushBP"]), "bit", "#e11d48"),
        ("FlushIF", "Instruction fetch flush", lambda r: int(r["FlushIF"]), "bit", "#e11d48"),
        ("FlushID", "Instruction decode flush", lambda r: int(r["FlushID"]), "bit", "#e11d48"),
        ("FlushEX", "Execute stage flush", lambda r: int(r["FlushEX"]), "bit", "#e11d48"),
        ("CsrMepc", "CSR mepc (return address)", lambda r: hex32(r["CsrMepc"]), "bus", "#9333ea"),
        ("CsrMstatus", "CSR mstatus register", lambda r: hex32(r["CsrMstatus"]), "bus", "#475569"),
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
                elif sname in ("FetchPC", "CsrEpc", "CsrMepc") and val != 0:
                    sval = f"0x{val & 0xFFFF:04X}"
                svg.append(f'  <rect x="{cx + 2}" y="{sig_y + 2}" width="{col_w - 4}" height="18" fill="#f1f5f9" stroke="{color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sig_y + 14}" font-size="8.5" font-family="monospace" fill="{color}" text-anchor="middle">{xesc(sval)}</text>')

        sig_y += row_h

    # Annotations box at bottom
    ay = height - 70
    svg.append(f'  <rect x="40" y="{ay}" width="1120" height="55" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" rx="4" />')
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 450 – 461):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 451–452: Handler increments return PC (addi t4, t4, 4) and writes mepc=0x8000_0074 via csrw mepc, t4.\n'
        '• Cyc 454: MRET commits at 0x8000_0110. Eret=1 triggers controller.sv to flush all pipeline stages (BP/IF/ID/EX) and vector FetchPC to CsrEpc=0x8000_0074. Main code commits at Cyc 461.'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "03_mret_pipeline_restore.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


# ----------------------------------------------------------------------------
# 4. Unaligned Jump & MTVAL Capture Waveform (Cycles 467 - 479)
# ----------------------------------------------------------------------------
def generate_unaligned_jump_waveform(rows):
    width, height = 1200, 500
    svg = svg_header(width, height)

    svg.append(
        '  <text x="30" y="30" font-size="15" font-weight="700" fill="#0f172a">'
        "CVA6 Misaligned Jump Instruction & MTVAL Capture Waveform (Cycles 467 – 479)"
        "</text>"
    )
    svg.append(
        '  <text x="30" y="48" font-size="11" fill="#475569">'
        "Execution of JR t6 (target 0x8000_0402 with bit 1 set and RVC=0) triggers INSTR_ADDR_MISALIGNED (Cause 0) at Cyc 470, latching fault target into MTVAL and jumping to MTVEC."
        "</text>"
    )

    w_rows = rows_in_window(rows, 467, 479)
    if not w_rows:
        return

    x_left, y_top = 210, 80
    col_w = max(45, int((width - x_left - 40) / len(w_rows)))

    for idx, row in enumerate(w_rows):
        cx = x_left + (idx * col_w)
        cyc = int(row["Cycle"])
        is_fault = (cyc == 470)
        is_vec = (cyc == 471)
        bg = "#fee2e2" if is_fault else ("#dbeafe" if is_vec else "#ffffff")
        svg.append(f'  <rect x="{cx}" y="{y_top}" width="{col_w}" height="{height - y_top - 90}" fill="{bg}" opacity="0.6" />')
        svg.append(f'  <line x1="{cx}" y1="{y_top}" x2="{cx}" y2="{height - 90}" stroke="#e2e8f0" stroke-width="1" />')
        svg.append(f'  <text x="{cx + col_w/2}" y="{y_top - 8}" class="cyc-lbl">{cyc}</text>')

    signals = [
        ("FetchPC", "Fetch stage PC", lambda r: hex32(r["FetchPC"]), "bus", "#0284c7"),
        ("CommitPC0", "Retired instruction PC", lambda r: hex32(r["CommitPC0"]), "bus", "#16a34a"),
        ("CommitAck0", "Instruction retired", lambda r: int(r["CommitAck0"]), "bit", "#16a34a"),
        ("ExValid", "Exception valid signal", lambda r: int(r["ExValid"]), "bit", "#dc2626"),
        ("ExceptionCause", "Trap cause code", lambda r: hex32(r["ExceptionCause"]), "bus", "#dc2626"),
        ("ExceptionTval", "Trap value code", lambda r: hex32(r["ExceptionTval"]), "bus", "#dc2626"),
        ("FlushBP", "Branch predictor flush", lambda r: int(r["FlushBP"]), "bit", "#e11d48"),
        ("FlushIF", "Instruction fetch flush", lambda r: int(r["FlushIF"]), "bit", "#e11d48"),
        ("CsrMepc", "CSR mepc (faulting PC)", lambda r: hex32(r["CsrMepc"]), "bus", "#9333ea"),
        ("CsrMcause", "CSR mcause register", lambda r: hex32(r["CsrMcause"]), "bus", "#9333ea"),
        ("CsrMtval", "CSR mtval register", lambda r: hex32(r["CsrMtval"]), "bus", "#ea580c"),
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
                elif sname in ("FetchPC", "ExceptionTval", "CsrMepc", "CsrMtval") and val != 0:
                    sval = f"0x{val:08X}"
                svg.append(f'  <rect x="{cx + 2}" y="{sig_y + 2}" width="{col_w - 4}" height="18" fill="#f1f5f9" stroke="{color}" stroke-width="1" rx="2" />')
                svg.append(f'  <text x="{cx + col_w/2}" y="{sig_y + 14}" font-size="8" font-family="monospace" fill="{color}" text-anchor="middle">{xesc(sval)}</text>')

        sig_y += row_h

    # Annotations box at bottom
    ay = height - 70
    svg.append(f'  <rect x="40" y="{ay}" width="1120" height="55" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" rx="4" />')
    svg.append(f'  <text x="55" y="{ay + 18}" class="ann-title">Microarchitectural Analysis (Cyc 470 – 477):</text>')
    svg.append(
        f'  <text x="55" y="{ay + 34}" class="ann-body">'
        '• Cyc 470: JR t6 attempts target 0x8000_0402. In branch_unit.sv, target_address[1] != 0 triggers exception with cause=0 and tval=0x8000_0402.\n'
        '• Cyc 471: Core vectors to MTVEC (0x8000_00a0); CSR unit captures mepc=0x8000_0080, mcause=0x0, and mtval=0x8000_0402 into hardware registers for diagnostics.'
        '</text>'
    )

    svg.append("</svg>")
    path = os.path.join(FIG_DIR, "04_unaligned_jump_mtval_capture.svg")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"[SVG] Generated {path}")


def main():
    rows = read_trace()
    print(f"[TRACE] Loaded {len(rows)} cycle rows from {CSV_PATH}")
    generate_execution_timeline(rows)
    generate_trap_entry_waveform(rows)
    generate_mret_waveform(rows)
    generate_unaligned_jump_waveform(rows)
    print("[DONE] All 4 SVG figures generated successfully in figures/")


if __name__ == "__main__":
    main()
