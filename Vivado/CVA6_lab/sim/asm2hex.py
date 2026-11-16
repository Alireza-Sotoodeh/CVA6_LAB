#!/usr/bin/env python3
# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-16 11:00:00 +03:30
# Status: NEW FILE
# Reason / Modification: Automated RISC-V assembly/C to Verilog $readmemh .hex
#                        converter for CVA6 testbench (cva6_tb.sv) in Vivado XSIM.
# ============================================================================

import argparse
import os
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)  # Vivado/CVA6_lab


def find_tool(candidates):
    """Search for the first available binary from a list of tool names."""
    for tool in candidates:
        path = shutil.which(tool)
        if path:
            return path
    return None


def get_default_tools():
    """Identify host RISC-V toolchain executables."""
    gcc = find_tool([
        "riscv-none-elf-gcc",
        "riscv64-unknown-elf-gcc",
        "riscv32-unknown-elf-gcc"
    ])
    objcopy = find_tool([
        "riscv-none-elf-objcopy",
        "riscv64-unknown-elf-objcopy",
        "riscv32-unknown-elf-objcopy"
    ])
    objdump = find_tool([
        "riscv64-unknown-elf-objdump",
        "riscv-none-elf-objdump",
        "riscv32-unknown-elf-objdump"
    ])
    return gcc, objcopy, objdump


def format_hex_content(raw_hex_text):
    """
    Format objcopy verilog hex into strictly padded 32-bit (8-hex-character)
    words with standard Verilog @word_address indexing.
    """
    formatted_lines = []
    current_addr = 0

    for line in raw_hex_text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("@"):
            # Address token in words (objcopy --verilog-data-width=4 already divides by 4)
            addr_hex = line[1:].strip()
            current_addr = int(addr_hex, 16)
            formatted_lines.append(f"@{current_addr:08X}")
        else:
            tokens = line.split()
            for tok in tokens:
                padded_word = tok.zfill(8).upper()
                formatted_lines.append(padded_word)
                current_addr += 1

    return "\n".join(formatted_lines) + "\n"


def sync_to_vivado_sim_dirs(hex_path):
    """
    Copy the generated hex file into all possible directories where
    cva6_tb.sv ($readmemh("../../sim/firmware_syn.hex", ram)) or XSIM
    searches for simulation data files.
    """
    basename = os.path.basename(hex_path)
    sync_destinations = [
        os.path.join(PROJECT_DIR, "sim", basename),
        os.path.join(PROJECT_DIR, basename),
        os.path.join(PROJECT_DIR, "CVA6_lab.sim", "sim_1", "sim", basename),
        os.path.join(PROJECT_DIR, "CVA6_lab.sim", "sim_1", "behav", "xsim", basename),
        os.path.join(PROJECT_DIR, "CVA6_lab.sim", "sim_1", "synth", "func", "xsim", basename),
        os.path.join(PROJECT_DIR, "CVA6_lab.sim", "sim_1", "synth", "func", "sim", basename),
    ]

    synced_count = 0
    abs_src = os.path.abspath(hex_path)
    for dst in sync_destinations:
        if os.path.abspath(dst) == abs_src:
            continue
        dst_dir = os.path.dirname(dst)
        os.makedirs(dst_dir, exist_ok=True)
        try:
            shutil.copy2(hex_path, dst)
            synced_count += 1
        except Exception as e:
            print(f"[WARN] Failed to copy to {dst}: {e}")

    return synced_count, sync_destinations


def main():
    parser = argparse.ArgumentParser(
        description="Convert RISC-V assembly (.S/.s) to Verilog $readmemh .hex for CVA6 Vivado simulation (cva6_tb.sv)."
    )
    parser.add_argument(
        "-i", "--input",
        default=os.path.join(SCRIPT_DIR, "main-syn.S"),
        help="Input assembly (.S/.s) or C (.c) source file (default: main-syn.S)."
    )
    parser.add_argument(
        "-o", "--output",
        default=os.path.join(SCRIPT_DIR, "firmware_syn.hex"),
        help="Output .hex file path (default: sim/firmware_syn.hex)."
    )
    parser.add_argument(
        "-a", "--arch",
        default="rv32imac",
        help="RISC-V architecture string (e.g. rv32imac, rv32i, rv64imafdc; default: rv32imac)."
    )
    parser.add_argument(
        "-m", "--abi",
        default=None,
        help="RISC-V ABI string (default: ilp32 for rv32, lp64d for rv64)."
    )
    parser.add_argument(
        "-l", "--linker",
        default=os.path.join(SCRIPT_DIR, "link.ld"),
        help="Linker script path (default: sim/link.ld)."
    )
    parser.add_argument(
        "-b", "--boot-addr",
        default="0x80000000",
        help="Core boot address in hex (default: 0x80000000)."
    )
    parser.add_argument(
        "-d", "--dump",
        action="store_true",
        help="Generate human-readable disassembly dump (.dump)."
    )
    parser.add_argument(
        "--no-sync",
        action="store_true",
        help="Do not copy the generated .hex file to Vivado XSIM simulation directories."
    )

    args = parser.parse_args()

    # Determine ABI if not specified
    if not args.abi:
        args.abi = "lp64d" if args.arch.startswith("rv64") else "ilp32"

    gcc, objcopy, objdump = get_default_tools()

    if not gcc:
        print("[ERROR] No RISC-V GCC cross-compiler found (checked riscv-none-elf-gcc, riscv64-unknown-elf-gcc).")
        sys.exit(1)
    if not objcopy:
        print("[ERROR] No RISC-V objcopy found (checked riscv-none-elf-objcopy, riscv64-unknown-elf-objcopy).")
        sys.exit(1)

    input_path = os.path.abspath(args.input)
    if not os.path.exists(input_path):
        print(f"[ERROR] Input file does not exist: {input_path}")
        sys.exit(1)

    linker_path = os.path.abspath(args.linker)
    if not os.path.exists(linker_path):
        print(f"[ERROR] Linker script does not exist: {linker_path}")
        sys.exit(1)

    output_path = os.path.abspath(args.output)
    output_dir = os.path.dirname(output_path)
    os.makedirs(output_dir, exist_ok=True)

    base_name = os.path.splitext(output_path)[0]
    elf_path = base_name + ".elf"
    raw_hex_path = base_name + ".raw.hex"
    dump_path = base_name + ".dump"

    print("============================================================")
    print(" CVA6 Assembly to Verilog Hex Converter")
    print("============================================================")
    print(f" Source File  : {input_path}")
    print(f" Architecture : {args.arch} (ABI: {args.abi})")
    print(f" Linker Script: {linker_path}")
    print(f" Boot Address : {args.boot_addr}")
    print(f" Compiler     : {gcc}")
    print(f" Objcopy      : {objcopy}")
    print(f" Output Hex   : {output_path}")
    print("------------------------------------------------------------")

    # 1. Compile and link to ELF
    compile_cmd = [
        gcc,
        f"-march={args.arch}",
        f"-mabi={args.abi}",
        "-mcmodel=medany",
        "-nostdlib",
        "-nostartfiles",
        "-ffreestanding",
        "-T", linker_path,
        input_path,
        "-o", elf_path
    ]

    print(f"[CMD] {' '.join(compile_cmd)}")
    try:
        subprocess.run(compile_cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Compilation failed: {e}")
        sys.exit(1)

    # 2. Generate disassembly if objdump is available and requested
    if args.dump or True:
        if objdump:
            dump_cmd = [objdump, "-d", elf_path]
            try:
                res = subprocess.run(dump_cmd, stdout=subprocess.PIPE, text=True, check=True)
                with open(dump_path, "w") as f_dump:
                    f_dump.write(res.stdout)
                print(f"[INFO] Disassembly saved to: {dump_path}")
            except Exception as e:
                print(f"[WARN] Failed to generate disassembly: {e}")

    # 3. Convert ELF to Verilog hex with objcopy
    # Subtract boot address so memory word index starts at 0x00000000 (ram[0])
    boot_val = int(args.boot_addr, 16)
    objcopy_cmd = [
        objcopy,
        "-O", "verilog",
        "--verilog-data-width=4",
        f"--change-addresses=-{boot_val:#x}",
        elf_path,
        raw_hex_path
    ]

    print(f"[CMD] {' '.join(objcopy_cmd)}")
    try:
        subprocess.run(objcopy_cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Objcopy failed: {e}")
        sys.exit(1)

    # 4. Standardize word widths (8 hex characters per word)
    with open(raw_hex_path, "r") as f_raw:
        raw_hex_content = f_raw.read()

    formatted_hex = format_hex_content(raw_hex_content)

    with open(output_path, "w") as f_out:
        f_out.write(formatted_hex)

    # Clean up intermediate raw hex
    if os.path.exists(raw_hex_path):
        os.remove(raw_hex_path)

    print(f"[SUCCESS] Generated: {output_path}")

    # Print summary of words
    lines = [l for l in formatted_hex.strip().splitlines() if not l.startswith("@")]
    print(f"[INFO] Total 32-bit instructions/words: {len(lines)}")

    # 5. Sync to simulation search paths
    if not args.no_sync:
        synced_count, dsts = sync_to_vivado_sim_dirs(output_path)
        print(f"[SYNC] Synced hex file to {synced_count} Vivado simulation search paths.")
        for d in dsts:
            print(f"       -> {d}")

    print("============================================================")
    print(" Conversion Completed Successfully.")
    print("============================================================")


if __name__ == "__main__":
    main()
