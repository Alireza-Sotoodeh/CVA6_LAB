# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-19 22:50:00 +03:30
# Status: NEW FILE
# Reason / Modification: SVG waveform and architectural timing diagram generator
#                        for Suite 12 (Atomic Memory Operations: LR.W, SC.W,
#                        reservation tracking, broken reservations, AMOSWAP.W,
#                        AMOADD.W, AMOXOR.W, AMOOR.W, AMOAND.W). Reads cva6_atomic_ops_trace.csv.
# ============================================================================

import csv
import os
import xml.sax.saxutils as saxutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "../../../Vivado/CVA6/cva6_atomic_ops_trace.csv"))
FIG_DIR = os.path.join(SCRIPT_DIR, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

PC_MAP = {
    0x0000: "LUI sp,0x80000",
    0x0004: "ADDI sp,512",
    0x0008: "LUI s0,0x80000",
    0x000C: "ADDI s0,1024",
    0x0010: "LUI t1,0x12345",
    0x0014: "ADDI t1,0x678",
    0x0018: "SW t1,0(s0)",
    0x001C: "LUI t2,0xdeadc",
    0x0020: "ADDI t2,-273",
    0x0024: "SC.W a0,t2,(s0)",
    0x0028: "LW a1,0(s0)",
    0x002C: "LR.W a2,(s0)",
    0x0030: "LUI t3,0xcafec",
    0x0034: "ADDI t3,-1346",
    0x0038: "SC.W a3,t3,(s0)",
    0x003C: "LW a4,0(s0)",
    0x0040: "LR.W a5,(s0)",
    0x0044: "LUI t4,0x55555",
    0x0048: "ADDI t4,1365",
    0x004C: "SW t4,0(s0)",
    0x0050: "LUI t5,0x9999a",
    0x0054: "ADDI t5,-1639",
    0x0058: "SC.W a6,t5,(s0)",
    0x005C: "LW a7,0(s0)",
    0x0060: "ADDI s1,s0,4",
    0x0064: "SW t4,0(s1)",
    0x0068: "LUI s2,0x11223",
    0x006C: "ADDI s2,836",
    0x0070: "AMOSWAP.W s3,s2,(s1)",
    0x0074: "LW s4,0(s1)",
    0x0078: "ADDI s1,s0,8",
    0x007C: "LI s5,10",
    0x0080: "SW s5,0(s1)",
    0x0084: "LI s6,25",
    0x0088: "AMOADD.W s7,s6,(s1)",
    0x008C: "LW s8,0(s1)",
    0x0090: "ADDI s1,s0,12",
    0x0094: "LUI s9,0xff0",
    0x0098: "ADDI s9,255",
    0x009C: "SW s9,0(s1)",
    0x00A0: "LUI s10,0xf0f1",
    0x00A4: "ADDI s10,-241",
    0x00A8: "AMOXOR.W s11,s10,(s1)",
    0x00AC: "LW t5,0(s1)",
    0x00B0: "ADDI s1,s0,16",
    0x00B4: "LUI t6,0xaaaab",
    0x00B8: "ADDI t6,-1366",
    0x00BC: "SW t6,0(s1)",
    0x00C0: "LUI gp,0x55555",
    0x00C4: "ADDI gp,1365",
    0x00C8: "AMOOR.W tp,gp,(s1)",
    0x00CC: "LW t1,0(s1)",
    0x00D0: "LUI t2,0x10",
    0x00D4: "ADDI t2,-1",
    0x00D8: "AMOAND.W t3,t2,(s1)",
    0x00DC: "LW t4,0(s1)",
    0x00E0: "LI ra,999",
    0x00E4: "J END_LOOP",
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
    if not os.path.exists(CSV_PATH):
        return []
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
        "    .hex-lbl { font-size: 9px; font-family: monospace; text-anchor: middle; }",
        "  </style>",
        "</defs>",
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
    ]


def draw_digital_wave(rows, key, y_base, h, color, col_w, left_m):
    paths = []
    prev_val = None
    prev_x = left_m

    for i, row in enumerate(rows):
        val = 1 if row.get(key, "0") in ("1", "True", "true", 1) else 0
        cur_x = left_m + i * col_w
        next_x = cur_x + col_w
        cur_y = y_base if val == 1 else y_base + h

        if i == 0:
            paths.append(f"M {cur_x} {cur_y}")
        else:
            if val != prev_val:
                paths.append(f"V {cur_y}")
        paths.append(f"H {next_x}")
        prev_val = val
        prev_x = next_x

    return f'<path d="{" ".join(paths)}" fill="none" stroke="{color}" stroke-width="1.8"/>'


def draw_bus(rows, key, y_base, h, bg_color, border_color, col_w, left_m, fmt=None):
    res = []
    i = 0
    n = len(rows)

    while i < n:
        raw_val = rows[i].get(key, "")
        j = i + 1
        while j < n and rows[j].get(key, "") == raw_val:
            j += 1

        x = left_m + i * col_w
        w = (j - i) * col_w
        y = y_base

        val_str = fmt(raw_val) if fmt else str(raw_val)

        is_idle = raw_val in ("0", "0x00000000", "0x0000", "0x0", "", "0x00", "0x0000000000000000")
        fill = "#f8fafc" if is_idle else bg_color
        stroke = "#cbd5e1" if is_idle else border_color

        res.append(
            f'<rect x="{x+1}" y="{y}" width="{w-2}" height="{h}" rx="2" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'
        )

        if w >= 22 and not is_idle:
            txt = xesc(val_str)
            if len(txt) * 6 > w:
                txt = txt[: max(3, int(w / 7))] + "…"
            res.append(
                f'<text x="{x + w/2}" y="{y + h/2 + 3.5}" class="hex-lbl" fill="#0f172a">{txt}</text>'
            )

        i = j

    return "\n".join(res)


def render_panel(rows, signals, title, subtitle, out_file, cycle_stride=5):
    if not rows:
        print(f"[SKIP] No rows for {out_file}")
        return

    col_w = 26
    left_m = 190
    top_m = 65
    sig_h = 24
    sig_gap = 12
    n_cycles = len(rows)
    width = left_m + n_cycles * col_w + 40
    height = top_m + len(signals) * (sig_h + sig_gap) + 40

    out = svg_header(width, height)

    out.append(f'<text x="24" y="28" font-size="15" font-weight="700" fill="#0f172a">{xesc(title)}</text>')
    out.append(f'<text x="24" y="46" font-size="11" fill="#64748b">{xesc(subtitle)}</text>')

    for i in range(n_cycles):
        cx = left_m + i * col_w
        cyc = rows[i]["Cycle"]
        if i % cycle_stride == 0 or i == n_cycles - 1:
            out.append(f'<line x1="{cx}" y1="{top_m-8}" x2="{cx}" y2="{height-30}" stroke="#e2e8f0" stroke-dasharray="2,3"/>')
            out.append(f'<text x="{cx + col_w/2}" y="{top_m-12}" class="cyc-lbl">C{cyc}</text>')

    cur_y = top_m
    for sig in signals:
        lbl = sig["label"]
        sub = sig.get("sub", "")
        key = sig["key"]
        stype = sig.get("type", "bus")
        color = sig.get("color", "#2563eb")
        border = sig.get("border", "#1d4ed8")

        out.append(f'<text x="24" y="{cur_y + 12}" class="sig-lbl">{xesc(lbl)}</text>')
        if sub:
            out.append(f'<text x="24" y="{cur_y + 22}" class="sig-sub">{xesc(sub)}</text>')

        if stype == "digital":
            out.append(draw_digital_wave(rows, key, cur_y, sig_h - 4, color, col_w, left_m))
        else:
            fmt = sig.get("fmt", None)
            out.append(draw_bus(rows, key, cur_y, sig_h, color, border, col_w, left_m, fmt))

        cur_y += sig_h + sig_gap

    out.append("</svg>")

    with open(out_file, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"[OK] Generated {out_file}")


def main():
    rows = read_trace()
    if not rows:
        print("[WARN] Trace file not found or empty.")
        return

    # Figure 1: Overall Timeline
    render_panel(
        rows,
        [
            {"label": "Commit Ack 0", "sub": "Port 0 retired", "key": "CommitAck0", "type": "digital", "color": "#16a34a"},
            {"label": "Commit PC 0", "sub": "Address & Mnemonic", "key": "CommitPC0", "type": "bus", "color": "#dbeafe", "border": "#3b82f6", "fmt": pc_label},
            {"label": "AR Valid", "sub": "Read request", "key": "ARValid", "type": "digital", "color": "#0284c7"},
            {"label": "AR Lock (LR)", "sub": "Exclusive load", "key": "ARLock", "type": "digital", "color": "#9333ea"},
            {"label": "AW Valid", "sub": "Write request", "key": "AWValid", "type": "digital", "color": "#ea580c"},
            {"label": "AW Lock (SC)", "sub": "Exclusive store", "key": "AWLock", "type": "digital", "color": "#dc2626"},
            {"label": "AW ATOP", "sub": "Atomic operation", "key": "AWAtop", "type": "bus", "color": "#fef08a", "border": "#ca8a04"},
            {"label": "Reservation Valid", "sub": "Core active reservation", "key": "ReservationValid", "type": "digital", "color": "#059669"},
            {"label": "SC Success Cnt", "sub": "Successful SCs", "key": "SCSuccess", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "SC Fail Cnt", "sub": "Failed SCs", "key": "SCFail", "type": "bus", "color": "#fecaca", "border": "#dc2626"},
            {"label": "AMO Cnt", "sub": "Atomic ops counter", "key": "AMOCnt", "type": "bus", "color": "#e0e7ff", "border": "#4f46e5"},
        ],
        "CVA6 Suite 12: Atomic Memory Operations (RV32A) Execution Timeline",
        "Cycle-accurate pipeline progress covering LR.W, SC.W, ATOPs and reservation life-cycle",
        os.path.join(FIG_DIR, "01_execution_timeline.svg"),
        cycle_stride=10,
    )

    # Figure 2: LR / SC Reservation Success and Failure
    lr_sc_rows = [r for r in rows if r["CommitAck0"] == "1" and hex32(r["CommitPC0"]) in range(0x80000018, 0x80000064)]
    if lr_sc_rows:
        min_c = max(1, int(lr_sc_rows[0]["Cycle"]) - 3)
        max_c = int(lr_sc_rows[-1]["Cycle"]) + 3
        sub_rows = rows_in_window(rows, min_c, max_c)
    else:
        sub_rows = rows[:60]

    render_panel(
        sub_rows,
        [
            {"label": "Commit Ack 0", "sub": "Port 0 retirement", "key": "CommitAck0", "type": "digital", "color": "#16a34a"},
            {"label": "Commit PC 0", "sub": "Instruction", "key": "CommitPC0", "type": "bus", "color": "#dbeafe", "border": "#3b82f6", "fmt": pc_label},
            {"label": "Commit WData 0", "sub": "Result to GPR", "key": "CommitWdata0", "type": "bus", "color": "#fed7aa", "border": "#ea580c"},
            {"label": "AR Lock", "sub": "LR exclusive request", "key": "ARLock", "type": "digital", "color": "#9333ea"},
            {"label": "AW Lock", "sub": "SC exclusive request", "key": "AWLock", "type": "digital", "color": "#dc2626"},
            {"label": "B Resp", "sub": "0:OKAY (Fail), 1:EXOKAY (Pass)", "key": "BResp", "type": "bus", "color": "#e0e7ff", "border": "#4f46e5"},
            {"label": "Reservation Valid", "sub": "Active reservation", "key": "ReservationValid", "type": "digital", "color": "#059669"},
            {"label": "Reservation Addr", "sub": "Reserved physical address", "key": "ReservationAddr", "type": "bus", "color": "#f1f5f9", "border": "#94a3b8"},
            {"label": "GPR a0 (Unres SC)", "sub": "Expect 1 (Failure)", "key": "GPR_a0", "type": "bus", "color": "#fecaca", "border": "#dc2626"},
            {"label": "GPR a3 (Valid SC)", "sub": "Expect 0 (Success)", "key": "GPR_a3", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR a6 (Broken SC)", "sub": "Expect 1 (Failure)", "key": "GPR_a6", "type": "bus", "color": "#fecaca", "border": "#dc2626"},
        ],
        "CVA6 LR.W / SC.W Reservation Success, Failure, and Broken Reservation",
        "Demonstrates unreserved SC failure (code 1), valid reservation success (code 0), and intervening store invalidation",
        os.path.join(FIG_DIR, "02_lr_sc_reservation_success_and_failure.svg"),
        cycle_stride=3,
    )

    # Figure 3: AMOSWAP.W and AMOADD.W Operations
    swap_add_rows = [r for r in rows if r["CommitAck0"] == "1" and hex32(r["CommitPC0"]) in range(0x80000060, 0x80000094)]
    if swap_add_rows:
        min_c = max(1, int(swap_add_rows[0]["Cycle"]) - 3)
        max_c = int(swap_add_rows[-1]["Cycle"]) + 3
        sub_rows = rows_in_window(rows, min_c, max_c)
    else:
        sub_rows = rows[60:120]

    render_panel(
        sub_rows,
        [
            {"label": "Commit Ack 0", "sub": "Port 0 retirement", "key": "CommitAck0", "type": "digital", "color": "#16a34a"},
            {"label": "Commit PC 0", "sub": "Instruction", "key": "CommitPC0", "type": "bus", "color": "#dbeafe", "border": "#3b82f6", "fmt": pc_label},
            {"label": "AW Valid", "sub": "Atomic write valid", "key": "AWValid", "type": "digital", "color": "#ea580c"},
            {"label": "AW ATOP", "sub": "0x30:SWAP, 0x20:ADD", "key": "AWAtop", "type": "bus", "color": "#fef08a", "border": "#ca8a04"},
            {"label": "W Data", "sub": "Operand to memory", "key": "WData", "type": "bus", "color": "#fed7aa", "border": "#f97316"},
            {"label": "R Valid", "sub": "Atomic read return valid", "key": "RValid", "type": "digital", "color": "#0284c7"},
            {"label": "R Data", "sub": "Previous memory value", "key": "RData", "type": "bus", "color": "#e0e7ff", "border": "#6366f1"},
            {"label": "GPR s3 (SWAP rd)", "sub": "Expect 0x55555555", "key": "GPR_s3", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR s4 (SWAP mem)", "sub": "Expect 0x11223344", "key": "GPR_s4", "type": "bus", "color": "#dcfce7", "border": "#22c55e"},
            {"label": "GPR s7 (ADD rd)", "sub": "Expect 10", "key": "GPR_s7", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR s8 (ADD mem)", "sub": "Expect 35", "key": "GPR_s8", "type": "bus", "color": "#dcfce7", "border": "#22c55e"},
        ],
        "CVA6 AMOSWAP.W and AMOADD.W Operations & Return Values",
        "Validates atomic write bus transactions (AWATOP), read data returns, and memory update semantics",
        os.path.join(FIG_DIR, "03_amoswap_and_amoadd_operations.svg"),
        cycle_stride=3,
    )

    # Figure 4: AMO Logical Operations (XOR, OR, AND)
    logic_rows = [r for r in rows if r["CommitAck0"] == "1" and hex32(r["CommitPC0"]) in range(0x80000090, 0x800000E4)]
    if logic_rows:
        min_c = max(1, int(logic_rows[0]["Cycle"]) - 3)
        max_c = int(logic_rows[-1]["Cycle"]) + 3
        sub_rows = rows_in_window(rows, min_c, max_c)
    else:
        sub_rows = rows[120:]

    render_panel(
        sub_rows,
        [
            {"label": "Commit Ack 0", "sub": "Port 0 retirement", "key": "CommitAck0", "type": "digital", "color": "#16a34a"},
            {"label": "Commit PC 0", "sub": "Instruction", "key": "CommitPC0", "type": "bus", "color": "#dbeafe", "border": "#3b82f6", "fmt": pc_label},
            {"label": "AW ATOP", "sub": "0x22:EOR, 0x23:SET, 0x21:CLR", "key": "AWAtop", "type": "bus", "color": "#fef08a", "border": "#ca8a04"},
            {"label": "GPR s11 (XOR rd)", "sub": "Expect 0x00FF00FF", "key": "GPR_s11", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR t5 (XOR mem)", "sub": "Expect 0x0FF00FF0", "key": "GPR_t5", "type": "bus", "color": "#dcfce7", "border": "#22c55e"},
            {"label": "GPR tp (OR rd)", "sub": "Expect 0xAAAAAAAA", "key": "GPR_tp", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR t1 (OR mem)", "sub": "Expect 0xFFFFFFFF", "key": "GPR_t1", "type": "bus", "color": "#dcfce7", "border": "#22c55e"},
            {"label": "GPR t3 (AND rd)", "sub": "Expect 0xFFFFFFFF", "key": "GPR_t3", "type": "bus", "color": "#bbf7d0", "border": "#16a34a"},
            {"label": "GPR t4 (AND mem)", "sub": "Expect 0x0000FFFF", "key": "GPR_t4", "type": "bus", "color": "#dcfce7", "border": "#22c55e"},
            {"label": "GPR ra (Marker)", "sub": "Expect 999", "key": "GPR_ra", "type": "bus", "color": "#fef08a", "border": "#eab308"},
        ],
        "CVA6 Atomic Logical Bitwise Operations (AMOXOR, AMOOR, AMOAND)",
        "Demonstrates atomic bit-manipulation in memory and architectural register writeback",
        os.path.join(FIG_DIR, "04_amo_logical_operations.svg"),
        cycle_stride=3,
    )

    print("[SUCCESS] All Suite 12 SVG diagrams generated.")


if __name__ == "__main__":
    main()
