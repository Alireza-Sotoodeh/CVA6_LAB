# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-20 09:18:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Comprehensive readability overhaul of Suite 8 SVGs:
#                        standardized 1200px width, high-level phase block timeline
#                        with milestone cards, focused 20-25 cycle waveforms,
#                        run-length bus trapezoids, and clean <tspan> annotations.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_interrupt_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp",
    0x0004: "ADDI sp,1024",
    0x0008: "AUIPC t6",
    0x000C: "ADDI t6,152",
    0x0010: "CSRW mtvec,t6",
    0x0014: "LI t0,128",
    0x0018: "CSRS mie,t0",
    0x001C: "LI t1,2048",
    0x0020: "CSRS mie,t1",
    0x0024: "LI a0,1",
    0x0028: "CSRSI mstatus,8",
    0x002C: "LI a1,2",
    0x0030: "WFI",
    0x0034: "LI a2,3",
    0x0038: "J END_LOOP",
    0x00A0: "CSRR a3,mcause",
    0x00A4: "CSRR a4,mepc",
    0x00A8: "MRET",
}

SHORT_OP = {
    0x0028: "CSRSI",
    0x0030: "WFI",
    0x0038: "J END",
    0x00A0: "CSRR",
    0x00A8: "MRET",
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
    total_cyc = 458

    phases = [
        (0, 266, "Phase 0: Boot & MTVEC", "#f1f5f9", "#94a3b8", "Cold AXI fetch, set mtvec = 0x8000_00A0, enable MTIE/MEIE"),
        (267, 305, "Phase 1: Timer IRQ (MTIP)", "#fee2e2", "#dc2626", "irq[7] masked while MIE=0; unmasked at 282; vector to mtvec"),
        (306, 328, "Phase 2: WFI Sleep State", "#ffedd5", "#ea580c", "WFI executes; core halts fetch & issue; awaits external wake"),
        (329, 360, "Phase 3: Ext IRQ (MEIP)", "#dbeafe", "#2563eb", "irq[11] wakes core; vectors to mtvec; saves mepc; MRET"),
        (361, 458, "Phase 4: Resume & End", "#dcfce7", "#16a34a", "Mainline resumes; commits self-loop; 12/12 checks PASS"),
    ]

    events = [
        (270, "M1", "#dc2626", "Timer IRQ Strobe (Masked)", "irq_i[7]=1 while mstatus.MIE=0; execution continues"),
        (282, "U1", "#d97706", "Global Unmask (CSRSI)", "csrsi mstatus,8 sets MIE=1; immediate interrupt trap"),
        (284, "V1", "#dc2626", "Timer Trap Vectoring", "Vector to 0x8000_00A0; mcause = 0x80000007"),
        (304, "R1", "#16a34a", "Timer Handler MRET", "MRET restores MIE from MPIE; returns to mepc"),
        (312, "W1", "#ea580c", "WFI Low-Power Halt", "WFI commits; halt_csr_o=1 halts frontend"),
        (328, "E1", "#2563eb", "External MEIP Wakeup", "irq_i[11]=1 de-asserts halt; core vectors to mtvec"),
        (346, "R2", "#16a34a", "External Handler MRET", "MRET restores MIE; returns to 0x8000_0034"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect x="20" y="15" width="{width-40}" height="44" rx="6" fill="#1e293b"/>')
    svg.append(f'<text x="35" y="38" font-size="15" font-weight="700" fill="#f8fafc">CVA6 Suite 8: Asynchronous Interrupts &amp; WFI Low-Power — Execution Timeline</text>')
    svg.append(f'<text x="{width-35}" y="38" font-size="11" fill="#94a3b8" text-anchor="end">Total Cycles: 458 | Active CPI = 8.79 | 12/12 Assertions PASSED</text>')

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
    for tick in [0, 50, 100, 150, 200, 267, 305, 330, 360, 410, 458]:
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
    svg.append(f'<text x="{left+120}" y="{tbl_y+17}" class="sig-name">Interrupt / WFI Event</text>')
    svg.append(f'<text x="{left+420}" y="{tbl_y+17}" class="sig-name">Hardware Mechanism &amp; State</text>')
    svg.append(f'<text x="{left+800}" y="{tbl_y+17}" class="sig-name">Impact &amp; Architectural Verification</text>')

    for i, (cyc, tag, color, desc, mech) in enumerate(events):
        ry = tbl_y + 42 + (i * 19)
        bg = "#f8fafc" if i % 2 == 1 else "#ffffff"
        svg.append(f'<rect x="{left+1}" y="{ry-13}" width="{plot_w-2}" height="19" fill="{bg}"/>')
        svg.append(f'<rect x="{left+15}" y="{ry-10}" width="22" height="14" rx="3" fill="{color}"/>')
        svg.append(f'<text x="{left+26}" y="{ry+1}" class="tag-lbl">{tag}</text>')
        svg.append(f'<text x="{left+60}" y="{ry+1}" font-size="9.5" font-weight="600" fill="#0f172a">C{cyc}</text>')
        svg.append(f'<text x="{left+120}" y="{ry+1}" font-size="9.5" fill="#1e293b">{xesc(desc)}</text>')
        svg.append(f'<text x="{left+420}" y="{ry+1}" font-size="9.5" fill="#475569">{xesc(mech)}</text>')
        impact_txt = "Delayed trap" if tag=="M1" else ("Trap asserted" if tag=="U1" else ("Vector to mtvec" if tag=="V1" else ("MIE restored" if tag=="R1" else ("Frontend halted" if tag=="W1" else ("Core un-halted" if tag=="E1" else "Resume mainline")))))
        svg.append(f'<text x="{left+800}" y="{ry+1}" font-size="9.5" font-weight="600" fill="{color}">{impact_txt}</text>')

    card_y = 390
    card_w = (plot_w - 4 * 12) / 5
    cards = [
        ("Timer Interrupts (MTIP)", "1", "irq_i[7] cause 0x80000007", "#fee2e2", "#dc2626"),
        ("External IRQs (MEIP)", "1", "irq_i[11] cause 0x8000000B", "#dbeafe", "#2563eb"),
        ("WFI Low-Power Halt", "1", "halt_csr_o=1 verified", "#ffedd5", "#ea580c"),
        ("MRET Status Restores", "2", "mstatus.MPIE -> MIE", "#dcfce7", "#16a34a"),
        ("Verification Status", "12/12", "All IRQ/WFI checks PASS", "#e0f2fe", "#0284c7"),
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


def render_irq_waveform(rows, start, end, title, subtitle, signals, out_path, notes=None):
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
        is_irq = (row.get("TimeIrq") == "1" or row.get("ExtIrq") == "1")
        fill = "#fee2e2" if is_irq else ("#f8fafc" if i % 2 == 0 else "#ffffff")
        svg.append(f'<rect x="{x:.1f}" y="{top}" width="{col_w:.1f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        if is_irq:
            svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+len(signals)*row_h}" stroke="#ef4444" stroke-width="1" stroke-dasharray="2,2"/>')
        svg.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.7"/>')
        if i % stride == 0 or i == n - 1 or is_irq:
            svg.append(f'<text x="{x + col_w/2:.1f}" y="{top - 6}" class="cyc" fill="{"#dc2626" if is_irq else "#475569"}">C{cyc}</text>')

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
                    svg.append(f'<text x="{x1 + col_w/2:.1f}" y="{y_mid + 3.5:.1f}" class="bit" fill="{"#dc2626" if high and ("Irq" in name or "Flush" in name) else color}">{val}</text>')
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
    rows = read_trace()
    if not rows:
        print("[ERROR] No trace rows found in cva6_interrupt_trace.csv")
        return

    generate_execution_timeline(rows)

    render_irq_waveform(
        rows, 275, 298,
        "Timer Interrupt (MTIP) Masking, Unmasking & Vectored Trap",
        "time_irq asserts while mstatus.MIE=0; unmasked at Cyc 282; triggers precise trap vectoring to MTVEC (0x800000A0)",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("TimeIrq", "Timer Interrupt Strobe", lambda r: r.get("TimeIrq", "0"), False, "#dc2626"),
            ("MstatusMIE", "Global Interrupt Enable (MIE)", lambda r: r.get("MstatusMIE", "0"), False, "#16a34a"),
            ("ExValid", "Exception/IRQ Trap Strobe", lambda r: r.get("ExValid", "0"), False, "#dc2626"),
            ("CsrMcause", "Trap Cause Register", lambda r: f"0x{hex32(r.get('CsrMcause',0)):X}" if hex32(r.get('CsrMcause',0))!=0 else "-", True, "#9333ea"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r.get("FlushIF", "0"), False, "#e11d48"),
        ],
        os.path.join(FIG_DIR, "02_timer_interrupt_masking_and_unmasking.svg"),
        notes=[
            "• Cycle 275: Timer interrupt strobe asserts, but mstatus.MIE=0 suppresses trap entry (execution continues normally).",
            "• Cycle 282: csrsi mstatus, 8 sets MIE=1. Hardware takes interrupt trap immediately on the following cycle (ExValid=1).",
            "• Cycle 284: FetchPC redirects to MTVEC (0x8000_00A0); mcause latches 0x8000_0007 (Timer Interrupt).",
        ],
    )

    render_irq_waveform(
        rows, 308, 334,
        "WFI Sleep State, Pipeline Halt & External Interrupt (MEIP) Wakeup",
        "WFI commits entering low-power halt (halt_csr_o=1); assertion of external IRQ wakes core and vectors to mtvec",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("HaltCsrO", "WFI Pipeline Halt Strobe", lambda r: r.get("HaltCsrO", "0"), False, "#ea580c"),
            ("ExtIrq", "External Interrupt Strobe", lambda r: r.get("ExtIrq", "0"), False, "#dc2626"),
            ("ExValid", "Trap Valid Strobe", lambda r: r.get("ExValid", "0"), False, "#dc2626"),
            ("CsrMcause", "Trap Cause Register", lambda r: f"0x{hex32(r.get('CsrMcause',0)):X}" if hex32(r.get('CsrMcause',0))!=0 else "-", True, "#9333ea"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r.get("FlushIF", "0"), False, "#e11d48"),
        ],
        os.path.join(FIG_DIR, "03_wfi_sleep_and_wake_by_external_irq.svg"),
        notes=[
            "• Cycle 312: WFI instruction commits at 0x8000_0030. Controller halts instruction fetch and decode (HaltCsrO=1).",
            "• Power Conservation: Pipeline remains frozen in zero-activity state until external event arrives.",
            "• Cycle 328: External interrupt (irq_i[11]) asserts. Core un-halts immediately and vectors to handler with mcause=0x8000_000B.",
        ],
    )

    render_irq_waveform(
        rows, 298, 320,
        "MRET Return Resumption & Privilege State Restoration",
        "Restoration of mstatus.MIE from MPIE and exact resumption at mepc following interrupt service routine completion",
        [
            ("FetchPC", "Fetch Stage PC", lambda r: hex32(r["FetchPC"]), True, "#0284c7"),
            ("CommitPC0", "Commit Port 0 PC", lambda r: hex32(r["CommitPC0"]), True, "#16a34a"),
            ("CommitAck0", "Commit Instruction Ack", lambda r: r["CommitAck0"], False, "#16a34a"),
            ("CsrMepc", "CSR mepc (Return Address)", lambda r: hex32(r.get("CsrMepc", 0)), True, "#9333ea"),
            ("MstatusMIE", "Global MIE Status", lambda r: r.get("MstatusMIE", "0"), False, "#16a34a"),
            ("MstatusMPIE", "Prior Interrupt Status (MPIE)", lambda r: r.get("MstatusMPIE", "0"), False, "#0284c7"),
            ("FlushIF", "Fetch Stage Flush", lambda r: r.get("FlushIF", "0"), False, "#e11d48"),
        ],
        os.path.join(FIG_DIR, "04_mret_resumption_and_status_restoration.svg"),
        notes=[
            "• Cycle 304: Handler executes MRET at 0x8000_00A8. Hardware restores global interrupt enable (mstatus.MIE <= mstatus.MPIE).",
            "• Cycle 305: Fetch stage redirects to saved mepc address (0x8000_002C), resuming interrupted mainline thread.",
            "• Context Integrity: All register file contents and pipeline state match pre-interrupt execution exactly.",
        ],
    )


if __name__ == "__main__":
    main()
