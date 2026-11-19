# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 20:10:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG generator for Suite 1 (branch prediction and
#                        control hazards). Produces a phase timeline plus three
#                        focused dual-line annotated timing figures from
#                        Vivado/CVA6/cva6_branch_trace.csv.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_branch_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)


PC_MAP = {
    0x0000: "ADDI x1,10",
    0x0004: "ADDI x2,20",
    0x0008: "ADDI x3,0",
    0x000C: "ADDI x4,0",
    0x0010: "ADD x5",
    0x0014: "SUB x6",
    0x0018: "XOR x7",
    0x001C: "OR x8",
    0x0020: "AND x9",
    0x0024: "SLLI x10",
    0x0028: "BEQ x1,x2",
    0x002C: "ADDI x11,1",
    0x0030: "BEQ x1,x1",
    0x0034: "ADDI x12,99",
    0x0038: "ADDI x12,2",
    0x003C: "ADDI x13,4",
    0x0040: "ADDI x14,0",
    0x0044: "ADDI x14,3",
    0x0048: "ADDI x13,-1",
    0x004C: "BNE loop",
    0x0050: "JAL x15",
    0x0054: "ADDI x16,88",
    0x0058: "ADDI x16,3",
    0x005C: "LUI x17",
    0x0060: "ADDI x17",
    0x0064: "JALR x18",
    0x0068: "ADDI x19,77",
    0x006C: "ADDI x19,4",
    0x0070: "ADDI x22,2",
    0x0074: "ADDI x23,0",
    0x0078: "LUI x24",
    0x007C: "ADDI x24",
    0x0080: "JALR x18",
    0x0084: "ADDI x23,1",
    0x0088: "ADDI x22,-1",
    0x008C: "BNE loop",
    0x0090: "JAL x1",
    0x0094: "ADDI x20,5",
    0x0098: "JAL x0,END",
    0x009C: "ADDI x21,7",
    0x00A0: "JALR ret",
    0x00A4: "JAL self",
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
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
        '<defs><style>',
        '  .title { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 18px; font-weight: bold; fill: #0f172a; }',
        '  .subtitle { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 12px; fill: #475569; }',
        '  .sig-name { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; font-weight: bold; fill: #1e293b; }',
        '  .sig-sub { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 9.5px; fill: #64748b; }',
        '  .bus { font-family: "Courier New", Consolas, monospace; font-size: 9px; fill: #0f172a; font-weight: bold; text-anchor: middle; }',
        '  .bit { font-family: "Courier New", Consolas, monospace; font-size: 9px; fill: #0f172a; font-weight: bold; text-anchor: middle; }',
        '  .cyc { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 10px; fill: #334155; font-weight: bold; text-anchor: middle; }',
        '  .legend { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #334155; }',
        '</style></defs>',
    ]


def render_waveform(rows, start, end, title, subtitle, signals, out_path):
    window = rows_in_window(rows, start, end)
    if not window:
        return
    width = 1540
    left = 290
    right = 40
    top = 78
    bottom = 44
    row_h = 36
    plot_w = width - left - right
    n = len(window)
    col_w = plot_w / n
    height = top + len(signals) * row_h + bottom

    svg = svg_header(width, height)
    svg.append(f'<rect width="{width}" height="{height}" fill="#fbfdff" rx="10" stroke="#cbd5e1"/>')
    svg.append(f'<text x="{width/2}" y="28" class="title" text-anchor="middle">{xesc(title)} (Cycles {start} to {end})</text>')
    svg.append(f'<text x="{width/2}" y="48" class="subtitle" text-anchor="middle">{xesc(subtitle)}</text>')
    svg.append(f'<text x="{width/2}" y="64" class="subtitle" text-anchor="middle">Source: Vivado/CVA6/cva6_branch_trace.csv | highlighted columns mark recorded events</text>')

    # Highlight event cycles.
    event_cycles = set()
    for row in window:
        if row["ResolvedBranchMispredict"] == "1":
            event_cycles.add(int(row["Cycle"]))
        if row["RasPush"] == "1" or row["RasPop"] == "1":
            event_cycles.add(int(row["Cycle"]))
        if row["BtbUpdateValid"] == "1":
            event_cycles.add(int(row["Cycle"]))

    for i, row in enumerate(window):
        cyc = int(row["Cycle"])
        x = left + i * col_w
        fill = "#f8fafc" if i % 2 == 0 else "#ffffff"
        svg.append(f'<rect x="{x:.2f}" y="{top}" width="{col_w:.2f}" height="{len(signals)*row_h}" fill="{fill}"/>')
        if cyc in event_cycles:
            svg.append(f'<rect x="{x:.2f}" y="{top}" width="{col_w:.2f}" height="{len(signals)*row_h}" fill="#fef3c7" opacity="0.55"/>')
        svg.append(f'<line x1="{x:.2f}" y1="{top}" x2="{x:.2f}" y2="{top + len(signals)*row_h}" stroke="#e2e8f0" stroke-width="0.8"/>')
        if n <= 60 or i % 5 == 0:
            svg.append(f'<text x="{x + col_w/2:.2f}" y="{top - 8}" class="cyc">{cyc}</text>')

    for s_idx, (name, sub, getter) in enumerate(signals):
        y_base = top + s_idx * row_h
        y_low = y_base + row_h - 10
        y_high = y_base + 10
        y_mid = (y_low + y_high) / 2
        svg.append(f'<line x1="12" y1="{y_base + row_h}" x2="{width - 12}" y2="{y_base + row_h}" stroke="#e2e8f0" stroke-width="0.8"/>')
        svg.append(f'<text x="18" y="{y_base + 14}" class="sig-name">{xesc(name)}</text>')
        svg.append(f'<text x="18" y="{y_base + 27}" class="sig-sub">{xesc(sub)}</text>')

        values = [getter(row) for row in window]
        is_bus = any(len(str(v)) > 1 for v in values)
        if not is_bus:
            prev = None
            for i, val in enumerate(values):
                x1 = left + i * col_w
                x2 = x1 + col_w
                high = (str(val) == "1")
                y = y_high if high else y_low
                if prev is None:
                    svg.append(f'<line x1="{x1:.2f}" y1="{y:.2f}" x2="{x2:.2f}" y2="{y:.2f}" stroke="#0f766e" stroke-width="2"/>')
                else:
                    prev_high = (str(prev) == "1")
                    y_prev = y_high if prev_high else y_low
                    if prev_high != high:
                        svg.append(f'<line x1="{x1:.2f}" y1="{y_prev:.2f}" x2="{x1:.2f}" y2="{y:.2f}" stroke="#0f766e" stroke-width="2"/>')
                    svg.append(f'<line x1="{x1:.2f}" y1="{y:.2f}" x2="{x2:.2f}" y2="{y:.2f}" stroke="#0f766e" stroke-width="2"/>')
                if (i == 0 or prev != val) and n <= 45:
                    svg.append(f'<text x="{x1 + col_w/2:.2f}" y="{y - 3:.2f}" class="bit">{xesc(val)}</text>')
                prev = val

        else:
            run_start = 0
            for i in range(1, n + 1):
                if i == n or values[i] != values[run_start]:
                    x1 = left + run_start * col_w
                    x2 = left + i * col_w
                    label = str(values[run_start])
                    if not label or label in ("0x00000000", "0"):
                        label = "-"
                    if label.startswith("0x"):
                        label = pc_label(label) if (
                            "PC" in name or "Addr" in name or "addr" in name or "Target" in name
                        ) else label
                    run_w = x2 - x1
                    svg.append(f'<rect x="{x1+1:.2f}" y="{y_high:.2f}" width="{max(run_w-2,1):.2f}" height="{y_low-y_high:.2f}" fill="#e0f2fe" stroke="#0284c7" stroke-width="0.8" rx="2"/>')
                    if run_w > 42:
                        max_chars = max(3, int(run_w / 6.2))
                        text = label if len(label) <= max_chars else label[:max_chars - 1] + "…"
                        svg.append(f'<text x="{x1 + run_w/2:.2f}" y="{y_mid + 3:.2f}" class="bus">{xesc(text)}</text>')
                    run_start = i

    svg.append('</svg>')
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated {out_path}")


def render_timeline(rows, out_path):
    width = 1440
    height = 610
    left = 70
    right = 40
    plot_w = width - left - right
    total = 442

    phases = [
        (0, 10, "Reset", "#94a3b8", "rst_ni held low; all pipeline state cleared"),
        (10, 265, "I-Cache flush + cold fetch", "#f59e0b", "256 tag rows invalidated; first line refilled from AXI"),
        (265, 335, "Forward branches + BHT training", "#10b981", "BEQ not-taken/taken; 4-iteration BNE loop trains the 2-bit counter"),
        (335, 405, "JALR, BTB and RAS", "#3b82f6", "Indirect JALR updates BTB; call/return pair exercises RAS"),
        (405, 442, "Drain + END self-loop", "#8b5cf6", "Final JAL x0,0 commits; pipeline drains and scoreboard checks run"),
    ]
    events = [
        (291, "M1", "BEQ taken mispredict (0x30→0x38)"),
        (312, "M2", "BNE 2nd iteration mispredict (0x4C→0x44)"),
        (326, "M3", "BNE exit mispredict (0x4C→0x50)"),
        (346, "M4", "JALR mispredict + BTB update (0x64→0x6C)"),
        (369, "M5", "JALR mispredict + BTB update (0x80→0x84)"),
        (377, "H1", "BTB hit for second L6 JALR (target 0x84)"),
        (386, "P",  "RAS push on JAL x1, FUNC"),
        (393, "R",  "RAS pop on JALR return; target 0x94"),
    ]

    svg = svg_header(width, height)
    svg.append(f'<rect width="{width}" height="{height}" fill="#fbfdff" rx="10" stroke="#cbd5e1"/>')
    svg.append(f'<text x="{width/2}" y="34" class="title" text-anchor="middle">CVA6 Suite 1 Execution Timeline: Branch Prediction and Control Hazards</text>')
    svg.append(f'<text x="{width/2}" y="56" class="subtitle" text-anchor="middle">442 simulated cycles, 71 retired instructions, 5 mispredictions; all event positions are taken from the CSV trace</text>')

    bar_y = 95
    bar_h = 66
    svg.append(f'<rect x="{left}" y="{bar_y}" width="{plot_w}" height="{bar_h}" fill="#f1f5f9" rx="5"/>')
    for p_start, p_end, title, color, desc in phases:
        x1 = left + (p_start / total) * plot_w
        x2 = left + (p_end / total) * plot_w
        svg.append(f'<rect x="{x1:.1f}" y="{bar_y}" width="{max(x2-x1,2):.1f}" height="{bar_h}" fill="{color}" opacity="0.92" stroke="#ffffff" stroke-width="1.5"/>')
        if x2 - x1 > 78:
            svg.append(f'<text x="{(x1+x2)/2:.1f}" y="{bar_y + 26}" class="cyc" fill="#ffffff">{xesc(title)}</text>')
            svg.append(f'<text x="{(x1+x2)/2:.1f}" y="{bar_y + 44}" class="cyc" fill="#f8fafc">{p_start}..{p_end}</text>')

    axis_y = bar_y + bar_h
    svg.append(f'<line x1="{left}" y1="{axis_y}" x2="{left+plot_w}" y2="{axis_y}" stroke="#475569" stroke-width="1.5"/>')
    for tick in [0, 50, 100, 150, 200, 250, 265, 300, 335, 369, 405, 442]:
        x = left + (tick / total) * plot_w
        svg.append(f'<line x1="{x:.1f}" y1="{axis_y}" x2="{x:.1f}" y2="{axis_y+6}" stroke="#475569"/>')
        svg.append(f'<text x="{x:.1f}" y="{axis_y+20}" class="cyc">C{tick}</text>')

    # Event markers.
    marker_y = axis_y + 48
    svg.append(f'<text x="{left}" y="{marker_y - 12}" class="sig-name">Recorded branch events</text>')
    for idx, (cyc, tag, desc) in enumerate(events):
        x = left + (cyc / total) * plot_w
        color = "#dc2626" if tag.startswith("M") else ("#2563eb" if tag.startswith("H") else "#7c3aed")
        row = idx % 2
        y = marker_y + row * 34
        svg.append(f'<line x1="{x:.1f}" y1="{bar_y+bar_h}" x2="{x:.1f}" y2="{y-6}" stroke="{color}" stroke-width="1" stroke-dasharray="3,3"/>')
        svg.append(f'<circle cx="{x:.1f}" cy="{y-9}" r="4" fill="{color}"/>')
        svg.append(f'<text x="{x+8:.1f}" y="{y-5}" class="legend" fill="{color}"><tspan font-weight="bold">{tag}</tspan> C{cyc}: {xesc(desc)}</text>')

    # Summary cards.
    card_y = 520
    cards = [
        ("Mispredictions", "5", "flush_if = flush_unissued = 5"),
        ("flush_bp", "0", "not used for branch mispredicts"),
        ("BHT updates", "8", "2-bit counter reaches 2'b10"),
        ("BTB updates", "2", "JALR targets cached"),
        ("RAS push / pop", "1 / 1", "return predicted, no flush"),
        ("Active CPI", "1.94", "control-flow workload, not steady-state"),
    ]
    card_w = (plot_w - 5 * 12) / 6
    for i, (label, value, sub) in enumerate(cards):
        x = left + i * (card_w + 12)
        svg.append(f'<rect x="{x:.1f}" y="{card_y}" width="{card_w:.1f}" height="62" rx="6" fill="#ffffff" stroke="#e2e8f0"/>')
        svg.append(f'<text x="{x+10:.1f}" y="{card_y+20}" class="sig-sub">{xesc(label)}</text>')
        svg.append(f'<text x="{x+10:.1f}" y="{card_y+42}" class="title" font-size="20px">{xesc(value)}</text>')
        svg.append(f'<text x="{x+10:.1f}" y="{card_y+56}" class="sig-sub">{xesc(sub)}</text>')

    svg.append('</svg>')
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))
    print(f"Generated {out_path}")


def main():
    rows = read_trace()

    render_timeline(rows, os.path.join(FIG_DIR, "01_execution_timeline.svg"))

    render_waveform(
        rows, 280, 335,
        "BHT 2-bit Training on the Four-Iteration BNE Loop",
        "Static backward-taken prediction handles iteration 1; the BHT then learns 00→01→10→11 and mispredicts at 01→10 and on loop exit",
        [
            ("FetchPC", "front-end fetch address", lambda r: r["FetchPC"]),
            ("ResolvedBranchPC", "EX-stage resolved PC", lambda r: r["ResolvedBranchPC"]),
            ("ResolvedBranchTaken", "actual branch outcome", lambda r: r["ResolvedBranchTaken"]),
            ("ResolvedBranchMispredict", "misprediction strobe", lambda r: r["ResolvedBranchMispredict"]),
            ("BhtPredValid", "BHT entry valid at fetch", lambda r: r["BhtPredValid"]),
            ("BhtPredTaken", "BHT prediction bit", lambda r: r["BhtPredTaken"]),
            ("BhtUpdateValid", "resolved branch updates BHT", lambda r: r["BhtUpdateValid"]),
            ("BhtUpdateTaken", "update direction", lambda r: r["BhtUpdateTaken"]),
            ("BhtLoopCounter", "counter for PC 0x4C", lambda r: r["BhtLoopCounter"]),
            ("FlushIF", "front-end flush", lambda r: r["FlushIF"]),
            ("FlushUnissued", "unissued-flush", lambda r: r["FlushUnissued"]),
            ("IcacheKillS2", "speculative fetch kill", lambda r: r["IcacheKillS2"]),
            ("CommitPC0", "commit port 0 PC", lambda r: r["CommitPC0"]),
            ("CommitPC1", "commit port 1 PC", lambda r: r["CommitPC1"]),
        ],
        os.path.join(FIG_DIR, "02_bht_training.svg"),
    )

    render_waveform(
        rows, 305, 340,
        "Branch Misprediction Flush: Partial Front-End Kill",
        "Mispredictions assert flush_if and flush_unissued; flush_bp, flush_id and flush_ex stay low. Target commits are highlighted.",
        [
            ("FetchPC", "front-end fetch address", lambda r: r["FetchPC"]),
            ("ResolvedBranchPC", "resolved branch PC", lambda r: r["ResolvedBranchPC"]),
            ("ResolvedBranchTarget", "recovery target", lambda r: r["ResolvedBranchTarget"]),
            ("ResolvedBranchMispredict", "misprediction strobe", lambda r: r["ResolvedBranchMispredict"]),
            ("FlushIF", "flush front-end", lambda r: r["FlushIF"]),
            ("FlushUnissued", "flush unissued", lambda r: r["FlushUnissued"]),
            ("FlushBP", "branch-predictor flush", lambda r: r["FlushBP"]),
            ("FlushID", "decode flush", lambda r: r["FlushID"]),
            ("FlushEX", "execute flush", lambda r: r["FlushEX"]),
            ("IcacheKillS1", "I-cache kill S1", lambda r: r["IcacheKillS1"]),
            ("IcacheKillS2", "I-cache kill S2", lambda r: r["IcacheKillS2"]),
            ("CommitPC0", "commit port 0 PC", lambda r: r["CommitPC0"]),
            ("CommitPC1", "commit port 1 PC", lambda r: r["CommitPC1"]),
        ],
        os.path.join(FIG_DIR, "03_mispredict_flush.svg"),
    )

    render_waveform(
        rows, 360, 402,
        "BTB Update/Hit and RAS Call-Return",
        "First JALR at 0x80 updates BTB; second execution hits with target 0x84. JAL pushes 0x94 and the return JALR pops it without a misprediction.",
        [
            ("FetchPC", "front-end fetch address", lambda r: r["FetchPC"]),
            ("ResolvedBranchPC", "resolved control-flow PC", lambda r: r["ResolvedBranchPC"]),
            ("ResolvedBranchTarget", "resolved target", lambda r: r["ResolvedBranchTarget"]),
            ("ResolvedBranchMispredict", "misprediction strobe", lambda r: r["ResolvedBranchMispredict"]),
            ("BtbUpdateValid", "BTB write strobe", lambda r: r["BtbUpdateValid"]),
            ("BtbUpdatePC", "BTB update PC", lambda r: r["BtbUpdatePC"]),
            ("BtbUpdateTarget", "BTB update target", lambda r: r["BtbUpdateTarget"]),
            ("BtbL6Valid", "BTB entry for PC 0x80", lambda r: r["BtbL6Valid"]),
            ("BtbL6Target", "BTB target for PC 0x80", lambda r: r["BtbL6Target"]),
            ("BtbPredValid", "BTB prediction valid", lambda r: r["BtbPredValid"]),
            ("BtbPredTarget", "BTB predicted target", lambda r: r["BtbPredTarget"]),
            ("RasPush", "RAS push strobe", lambda r: r["RasPush"]),
            ("RasPop", "RAS pop strobe", lambda r: r["RasPop"]),
            ("RasPredictValid", "RAS prediction valid", lambda r: r["RasPredictValid"]),
            ("RasPredictAddr", "RAS predicted address", lambda r: r["RasPredictAddr"]),
            ("CommitPC0", "commit port 0 PC", lambda r: r["CommitPC0"]),
        ],
        os.path.join(FIG_DIR, "04_btb_ras_call_return.svg"),
    )


if __name__ == "__main__":
    main()
