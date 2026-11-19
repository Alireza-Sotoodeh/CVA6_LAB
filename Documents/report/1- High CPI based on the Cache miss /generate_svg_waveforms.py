# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 12:39:00 +03:30
# Status: MODIFIED FILE
# Reason / Modification: Refined SVG figure generator for pure English text,
#                        numbered phase badges [P1..P8] on timeline, instruction
#                        mnemonic annotations for commits, and clean dual-line labels.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../Vivado/CVA6/cva6_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

MNEMONIC_MAP = {
    "0000": "ADDI x1, 10",
    "0004": "ADDI x2, 20",
    "0008": "ADD x3, x1, x2",
    "000c": "SUB x4, x2, x1",
    "0010": "XOR x5, x1, x2",
    "0014": "OR x6, x1, x2",
    "0018": "AND x7, x1, x6",
    "001c": "SLTI x8, x1, 15",
    "0020": "SLLI x9, x8, 4",
    "0024": "SW x3, 256",
    "0028": "LW x10, 256",
    "002c": "BEQ taken",
    "0034": "ADDI x12, 1",
    "0038": "JAL to 0x40",
    "0040": "ADDI x15, 42",
    "0044": "SW x15, 512",
    "0048": "BEQ self-loop",
}

def xesc(val):
    """Safely escape text for XML/SVG text nodes and attributes."""
    if val is None:
        return ""
    return saxutils.escape(str(val))

def read_trace():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)

def generate_timeline_svg(rows, out_path):
    width = 1200
    height = 470
    margin_l = 80
    margin_r = 60
    margin_t = 60
    plot_w = width - margin_l - margin_r
    total_cycles = 344

    # 8 Phases definition: (id, start, end, title, color, desc)
    phases = [
        ("P1", 0, 10, "Reset Assertion", "#e74c3c", "Active-low reset (rst_ni=0); pipeline registers and control flags cleared"),
        ("P2", 10, 265, "I-Cache Tag Flush", "#e67e22", "Hardware clears 256 Tag SRAM rows sequentially; asserts flush_done=1 at C265"),
        ("P3", 265, 272, "Cold Miss Refill", "#f39c12", "First compulsory miss at 0x80000000; 2-beat 64-bit AXI refill; line written at C271"),
        ("P4", 272, 280, "Initial ALU Burst", "#27ae60", "ADDI, ADD, SUB retired in 5 cycles from filled cache line (Instant CPI = 1.25)"),
        ("P5", 280, 296, "Refills & Logic Ops", "#2980b9", "Lines 1 & 2 refilled; XOR, OR, AND, SLTI, SLLI retired (Instant CPI = 1.00)"),
        ("P6", 296, 311, "Data Memory SW/LW", "#8e44ad", "Store word 30 at addr 256 (SW); Load word 30 into x10 (LW) via AXI bus"),
        ("P7", 311, 320, "Branch BEQ & Jump JAL", "#16a085", "BEQ resolved taken (skips 0x30); JAL taken to 0x40 (skips 0x3c)"),
        ("P8", 320, 344, "Drain & Steady Loop", "#34495e", "Speculative overshoot at 0x50 killed; terminal BEQ self-loop hits at 100%")
    ]

    svg = []
    svg.append('<?xml version="1.0" encoding="UTF-8"?>')
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">')
    svg.append('<defs>')
    svg.append('  <style>')
    svg.append('    .title { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 18px; font-weight: bold; fill: #1e293b; }')
    svg.append('    .subtitle { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 13px; fill: #64748b; }')
    svg.append('    .axis-label { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #334155; font-weight: bold; }')
    svg.append('    .badge-text { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 12px; fill: #ffffff; font-weight: bold; text-anchor: middle; }')
    svg.append('    .badge-sub { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 10px; fill: #f1f5f9; text-anchor: middle; }')
    svg.append('    .legend-title { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 12px; fill: #0f172a; font-weight: bold; }')
    svg.append('    .legend-desc { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #475569; }')
    svg.append('  </style>')
    svg.append('</defs>')

    # Background
    svg.append(f'<rect width="{width}" height="{height}" fill="#fdfdfd" rx="8" stroke="#e2e8f0" stroke-width="1"/>')

    # Title
    svg.append(f'<text x="{width/2}" y="32" class="title" text-anchor="middle">CVA6 Core Execution Lifecycle (Cycles 0 to 344)</text>')
    svg.append(f'<text x="{width/2}" y="50" class="subtitle" text-anchor="middle">Microarchitectural Phase Breakdown: 256-Cycle Tag Flush, Cache Refills, and Instruction Execution</text>')

    # Timeline main bar background
    bar_y = margin_t + 30
    bar_h = 60
    svg.append(f'<rect x="{margin_l}" y="{bar_y}" width="{plot_w}" height="{bar_h}" fill="#f1f5f9" rx="4"/>')

    # Render Phase rects with numbered badges [P1..P8]
    for p_id, p_start, p_end, title, color, desc in phases:
        x1 = margin_l + (p_start / total_cycles) * plot_w
        x2 = margin_l + (p_end / total_cycles) * plot_w
        pw = x2 - x1
        svg.append(f'<rect x="{x1:.1f}" y="{bar_y}" width="{pw:.1f}" height="{bar_h}" fill="{color}" stroke="#ffffff" stroke-width="1.5" opacity="0.95"/>')
        
        cx = x1 + pw / 2
        cy = bar_y + bar_h / 2
        if pw >= 90:
            svg.append(f'<text x="{cx:.1f}" y="{cy - 5:.1f}" class="badge-text">[{p_id}] {xesc(title)}</text>')
            svg.append(f'<text x="{cx:.1f}" y="{cy + 12:.1f}" class="badge-sub">{p_end - p_start} Cycles [{p_start}..{p_end}]</text>')
        elif pw >= 30:
            svg.append(f'<text x="{cx:.1f}" y="{cy + 4:.1f}" class="badge-text">{p_id}</text>')
        else:
            svg.append(f'<text x="{cx:.1f}" y="{cy + 4:.1f}" class="badge-text" font-size="10px">{p_id[1:]}</text>')

    # Axis and ticks
    axis_y = bar_y + bar_h
    svg.append(f'<line x1="{margin_l}" y1="{axis_y}" x2="{margin_l + plot_w}" y2="{axis_y}" stroke="#64748b" stroke-width="2"/>')
    
    ticks = [0, 10, 50, 100, 150, 200, 256, 280, 312, 344]
    for t in ticks:
        tx = margin_l + (t / total_cycles) * plot_w
        svg.append(f'<line x1="{tx:.1f}" y1="{axis_y}" x2="{tx:.1f}" y2="{axis_y + 6}" stroke="#64748b" stroke-width="1.5"/>')
        svg.append(f'<text x="{tx:.1f}" y="{axis_y + 18}" class="axis-label" text-anchor="middle">C{t}</text>')

    # Generous 2-column English legend table at the bottom (540px width each)
    leg_y = axis_y + 42
    svg.append(f'<text x="{margin_l}" y="{leg_y}" class="axis-label" font-size="13px">Summary of Execution Phases (P1 to P8):</text>')

    col1_x = margin_l
    col2_x = margin_l + 540

    for i, (p_id, p_start, p_end, title, color, desc) in enumerate(phases):
        col = col1_x if (i % 2 == 0) else col2_x
        row_idx = i // 2
        item_y = leg_y + 18 + row_idx * 34
        
        svg.append(f'<rect x="{col}" y="{item_y}" width="16" height="16" fill="{color}" rx="3"/>')
        svg.append(f'<text x="{col + 8}" y="{item_y + 12}" class="badge-text" font-size="10px">{p_id}</text>')
        title_str = f"{title} (Cycles {p_start} to {p_end})"
        svg.append(f'<text x="{col + 24}" y="{item_y + 11}" class="legend-title">{xesc(title_str)}</text>')
        svg.append(f'<text x="{col + 24}" y="{item_y + 24}" class="legend-desc">{xesc(desc)}</text>')

    svg.append('</svg>')
    
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg))
    print(f"Generated {out_path}")

def generate_focused_waveform_svg(rows, start_cyc, end_cyc, title_en, subtitle_en, out_path):
    window_rows = [r for r in rows if start_cyc <= int(r["Cycle"]) <= end_cyc]
    n_cycles = len(window_rows)
    if n_cycles == 0:
        return

    width = 1380
    margin_l = 250
    margin_r = 40
    margin_t = 65
    margin_b = 40
    row_h = 32
    plot_w = width - margin_l - margin_r
    col_w = plot_w / n_cycles

    # Clean dual-line English signal labels
    signal_defs = [
        ("CLK", "System Clock", "clk"),
        ("Cycle", "Cycle Number", "cycle_counter"),
        ("IcacheState", "Cache Controller FSM", "state_q [2:0]"),
        ("IcacheMiss", "I-Cache Miss Strobe", "miss_o"),
        ("IcacheWren", "Refill Line Write-En", "cache_wren"),
        ("IcacheClHit", "Way Hit Indicator", "cl_hit [1:0]"),
        ("AxiARValid", "AXI Read Addr Valid", "noc_req.ar_valid"),
        ("AxiARAddr", "AXI Read Fetch Addr", "noc_req.ar.addr [63:0]"),
        ("AxiRValid", "AXI Read Data Beat", "noc_resp.r_valid"),
        ("CommitAck", "Instruction Retired", "commit_ack [0]"),
        ("CommitInstr", "Retired Instruction", "Mnemonic Mapped"),
        ("GprWe", "RegFile Write-Enable", "gpr_we"),
        ("GprWriteback", "Writeback Destination", "rd <= Writeback Data")
    ]

    height = margin_t + len(signal_defs) * row_h + margin_b

    svg = []
    svg.append('<?xml version="1.0" encoding="UTF-8"?>')
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">')
    svg.append('<defs>')
    svg.append('  <style>')
    svg.append('    .title { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 16px; font-weight: bold; fill: #0f172a; }')
    svg.append('    .subtitle { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #64748b; }')
    svg.append('    .sig-name { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #1e293b; font-weight: bold; }')
    svg.append('    .sig-sub { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 9.5px; fill: #64748b; }')
    svg.append('    .bus-text { font-family: "Courier New", monospace, Consolas; font-size: 9.5px; fill: #0f172a; font-weight: bold; text-anchor: middle; }')
    svg.append('    .cycle-num { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Tahoma, Roboto, Arial, sans-serif; font-size: 11px; fill: #334155; font-weight: bold; text-anchor: middle; }')
    svg.append('  </style>')
    svg.append('</defs>')

    svg.append(f'<rect width="{width}" height="{height}" fill="#ffffff" rx="8" stroke="#cbd5e1" stroke-width="1"/>')
    svg.append(f'<text x="{width/2}" y="28" class="title" text-anchor="middle">{xesc(title_en)} (Cycles {start_cyc} to {end_cyc})</text>')
    svg.append(f'<text x="{width/2}" y="46" class="subtitle" text-anchor="middle">{xesc(subtitle_en)}</text>')

    # Background column alternation for clear vertical tracking
    for i in range(n_cycles):
        cx = margin_l + i * col_w
        bg = "#f8fafc" if (i % 2 == 0) else "#ffffff"
        svg.append(f'<rect x="{cx:.1f}" y="{margin_t}" width="{col_w:.1f}" height="{len(signal_defs)*row_h}" fill="{bg}"/>')

    # Draw vertical cycle gridlines
    for i in range(n_cycles + 1):
        x = margin_l + i * col_w
        svg.append(f'<line x1="{x:.1f}" y1="{margin_t}" x2="{x:.1f}" y2="{margin_t + len(signal_defs)*row_h}" stroke="#e2e8f0" stroke-width="1"/>')

    # Draw row headers and signal labels (Clean dual-line English)
    for s_idx, (sig_id, sig_name, sig_sub) in enumerate(signal_defs):
        y = margin_t + s_idx * row_h
        svg.append(f'<text x="20" y="{y + 15}" class="sig-name">{xesc(sig_name)}</text>')
        svg.append(f'<text x="20" y="{y + 26}" class="sig-sub">{xesc(sig_sub)}</text>')
        svg.append(f'<line x1="10" y1="{y + row_h}" x2="{width - 10}" y2="{y + row_h}" stroke="#e2e8f0" stroke-width="0.8"/>')

    # Top cycle numbers with ample space
    for i, r in enumerate(window_rows):
        cx = margin_l + i * col_w
        cyc_val = r["Cycle"]
        svg.append(f'<text x="{cx + col_w/2:.1f}" y="{margin_t - 8}" class="cycle-num">{xesc(cyc_val)}</text>')

    # Render Signals
    for s_idx, (sig_key, _, _) in enumerate(signal_defs):
        sy = margin_t + s_idx * row_h

        if sig_key == "CLK":
            for i in range(n_cycles):
                cx = margin_l + i * col_w
                mid_x = cx + col_w / 2
                hi_y = sy + 6
                lo_y = sy + row_h - 6
                svg.append(f'<polyline points="{cx:.1f},{lo_y} {cx:.1f},{hi_y} {mid_x:.1f},{hi_y} {mid_x:.1f},{lo_y} {cx+col_w:.1f},{lo_y}" fill="none" stroke="#2563eb" stroke-width="1.3"/>')

        elif sig_key in ("IcacheMiss", "IcacheWren", "AxiARValid", "AxiRValid", "CommitAck", "GprWe"):
            for i, r in enumerate(window_rows):
                cx = margin_l + i * col_w
                val = r.get(sig_key, "")
                is_hi = (val == "1")
                col = "#dc2626" if "Miss" in sig_key else "#16a34a" if "Commit" in sig_key or "Wren" in sig_key else "#2563eb"
                if is_hi:
                    svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 5}" width="{col_w - 2:.1f}" height="{row_h - 10}" fill="{col}" opacity="0.9" rx="2"/>')
                    svg.append(f'<text x="{cx + col_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#ffffff">1</text>')
                else:
                    svg.append(f'<line x1="{cx:.1f}" y1="{sy + row_h - 7}" x2="{cx + col_w:.1f}" y2="{sy + row_h - 7}" stroke="#cbd5e1" stroke-width="1.2"/>')

        elif sig_key == "IcacheState":
            # State mapping with uppercase clean text
            st_map = {
                "0": ("FLUSH", "#ea580c"),
                "1": ("IDLE", "#64748b"),
                "2": ("READ", "#16a34a"),
                "3": ("MISS", "#dc2626"),
                "5": ("KILL", "#9333ea")
            }
            i = 0
            while i < n_cycles:
                val = window_rows[i].get("IcacheState", "")
                start_i = i
                while i < n_cycles and window_rows[i].get("IcacheState", "") == val:
                    i += 1
                end_i = i
                block_w = (end_i - start_i) * col_w
                cx = margin_l + start_i * col_w
                name, st_col = st_map.get(val, (val, "#94a3b8"))
                svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 4}" width="{block_w - 2:.1f}" height="{row_h - 8}" fill="{st_col}" opacity="0.9" rx="3"/>')
                svg.append(f'<text x="{cx + block_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#ffffff">{xesc(name)}</text>')

        elif sig_key == "IcacheClHit":
            for i, r in enumerate(window_rows):
                cx = margin_l + i * col_w
                val = r.get("IcacheClHit", "")
                is_hit = (val == "01" or val == "10")
                if is_hit:
                    svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 4}" width="{col_w - 2:.1f}" height="{row_h - 8}" fill="#16a34a" opacity="0.9" rx="2"/>')
                    svg.append(f'<text x="{cx + col_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#ffffff">HIT</text>')
                else:
                    svg.append(f'<line x1="{cx:.1f}" y1="{sy + row_h/2}" x2="{cx + col_w:.1f}" y2="{sy + row_h/2}" stroke="#cbd5e1" stroke-width="1"/>')

        elif sig_key == "AxiARAddr":
            for i, r in enumerate(window_rows):
                cx = margin_l + i * col_w
                val = r.get("AxiARAddr", "")
                is_valid = r.get("AxiARValid", "") == "1" and val not in ("0x00000000", "0", "")
                if is_valid:
                    offset = val[-4:] if len(val) >= 4 else val
                    label = f"0x{offset}"
                    svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 5}" width="{col_w - 2:.1f}" height="{row_h - 10}" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.2" rx="3"/>')
                    svg.append(f'<text x="{cx + col_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#0369a1">{xesc(label)}</text>')
                else:
                    svg.append(f'<line x1="{cx:.1f}" y1="{sy + row_h/2}" x2="{cx + col_w:.1f}" y2="{sy + row_h/2}" stroke="#cbd5e1" stroke-width="1"/>')

        elif sig_key == "CommitInstr":
            for i, r in enumerate(window_rows):
                cx = margin_l + i * col_w
                is_commit = r.get("CommitAck", "") == "1"
                pc_val = r.get("CommitPC", "")
                if is_commit and pc_val:
                    pc_offset = pc_val[-4:] if len(pc_val) >= 4 else pc_val
                    mnemonic = MNEMONIC_MAP.get(pc_offset, f"0x{pc_offset}")
                    svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 4}" width="{col_w - 2:.1f}" height="{row_h - 8}" fill="#dcfce7" stroke="#16a34a" stroke-width="1.2" rx="3"/>')
                    svg.append(f'<text x="{cx + col_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#15803d" font-size="8.5px">{xesc(mnemonic)}</text>')
                else:
                    svg.append(f'<line x1="{cx:.1f}" y1="{sy + row_h/2}" x2="{cx + col_w:.1f}" y2="{sy + row_h/2}" stroke="#cbd5e1" stroke-width="1"/>')

        elif sig_key == "GprWriteback":
            for i, r in enumerate(window_rows):
                cx = margin_l + i * col_w
                we = r.get("GprWe", "") == "1"
                rd = r.get("GprWaddr", "")
                data = r.get("GprWdata", "")
                if we and rd and rd != "0":
                    data_int = int(data, 16) if data.startswith("0x") else int(data) if data.isdigit() else 0
                    wb_label = f"x{rd}&lt;={data_int}"
                    svg.append(f'<rect x="{cx + 1:.1f}" y="{sy + 5}" width="{col_w - 2:.1f}" height="{row_h - 10}" fill="#fef3c7" stroke="#d97706" stroke-width="1.2" rx="3"/>')
                    svg.append(f'<text x="{cx + col_w/2:.1f}" y="{sy + 18}" class="bus-text" fill="#b45309" font-size="9px">{wb_label}</text>')
                else:
                    svg.append(f'<line x1="{cx:.1f}" y1="{sy + row_h/2}" x2="{cx + col_w:.1f}" y2="{sy + row_h/2}" stroke="#cbd5e1" stroke-width="1"/>')

    svg.append('</svg>')

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg))
    print(f"Generated {out_path}")

if __name__ == "__main__":
    rows = read_trace()
    print(f"Read {len(rows)} trace rows from {CSV_PATH}")

    # 1. Overview Timeline
    generate_timeline_svg(rows, os.path.join(FIG_DIR, "cva6_execution_timeline.svg"))

    # 2. Focused Waveform 1: Startup, Cold Miss Refill & First ALU Hits
    generate_focused_waveform_svg(
        rows, 265, 284,
        "Waveform 1: I-Cache Startup Flush Exit & Cold Miss Refill",
        "First Compulsory Miss at 0x80000000, 2-Beat AXI Refill, and Initial Instruction Commit Burst (CPI = 1.25)",
        os.path.join(FIG_DIR, "cva6_wave_01_refill.svg")
    )

    # 3. Focused Waveform 2: Refills, ALU & Data Memory SW/LW
    generate_focused_waveform_svg(
        rows, 285, 312,
        "Waveform 2: Sequential Cache Refills, Logic Ops & Memory SW/LW",
        "ALU Instruction Commits (CPI = 1.00), Store Word 30 to Address 256, and Load Word 30 into x10 via AXI",
        os.path.join(FIG_DIR, "cva6_wave_02_memory.svg")
    )

    # 4. Focused Waveform 3: Branch Resolution, Speculative Kill & Terminal Loop
    generate_focused_waveform_svg(
        rows, 312, 338,
        "Waveform 3: Branch Resolution, Speculative Fetch Kill & Steady Loop",
        "BEQ Taken, JAL Target Resolution, Overshoot Fetch Cancelled (KILL_MISS), and Steady Loop with 100% Cache Hits",
        os.path.join(FIG_DIR, "cva6_wave_03_branch_loop.svg")
    )
