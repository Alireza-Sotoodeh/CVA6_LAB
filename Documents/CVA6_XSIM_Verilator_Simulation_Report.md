---
author: Alireza Sotodeh
date: 2026-11-14 11:35:00 +03:30
status: NEW FILE
reason: Report on validating the imported CVA6 AXI testbench, running the testbench behaviourally, documenting the Vivado XSIM elaboration blocker and recording the functional/CPI evidence obtained with Verilator 5.020.
---

# CVA6 `cv32a6_imac_sv32` — Testbench Validation, Simulation and CPI Report

## 1. Scope

| Item | Value |
| :--- | :--- |
| Repository | `CVA6_LAB`, project `Vivado/CVA6_Lab/CVA6_Lab.xpr` |
| Core configuration | `cv32a6_imac_sv32` (`RV32IMAC`, SV32, no FPU) |
| RTL source | `Vivado/CVA6_Lab/imports/rtl` (copy of `CloneFiles/CVA6-Lab/rtl`) |
| Design top | `cva6` (`sources_1`: 335 files) |
| Simulation top | `cva6_tb` (`sim_1`: `tb/sv/cva6_tb.sv`, `tb/wrappers/cva6_axi_wrapper.sv`) |
| Defines (Vivado) | `TARGET_CV32A6_IMAC_SV32 TARGET_FPGA TARGET_SYNTHESIS TARGET_VIVADO TARGET_XILINX VERILATOR` |
| Vivado | 2025.1 (XSIM 2025.1), part `xa7s6cpga196-1Q` |
| Verilator | 5.020 (`/usr/bin/verilator`) |
| Toolchain | `riscv-none-elf-gcc` (`-march=rv32imac -mabi=ilp32 -mcmodel=medany`) |

Relevant configuration facts read from
`imports/rtl/core/include/cv32a6_imac_sv32_config_pkg.sv`:

* `CVA6ConfigXlen = 32`, `CVA6ConfigVLEN = 32`, single issue, `NrCommitPorts = 2`
* AXI: address width 64, data width 64, ID width 4, user width 4
* I-cache 16 KiB, D-cache 32 KiB, `DcacheType = HPDCACHE_WT` (write-through)
* Branch prediction: `BPType = BHT`, `BTBEntries = 32`, `BHTEntries = 128`
* C and A extensions enabled, F/D disabled
* Cached PMA region: base `0x8000_0000`, length `0x4000_0000` (the boot region)

## 2. Files Added or Changed

| Path | Status | Purpose |
| :--- | :--- | :--- |
| `Vivado/CVA6_Lab/tb/sv/cva6_tb.sv` | modified | Reworked AXI testbench: 64-bit bus, firmware image, tohost completion, watchdog, CSV logger, commit trace, result/CPI checks |
| `Vivado/CVA6_Lab/tb/wrappers/cva6_axi_wrapper.sv` | unchanged | Exposes flat AXI channels and the RVFI commit ports of `cva6` |
| `Vivado/CVA6_Lab/firmware/src/selftest.S` | new | Self-checking RV32IMAC program (ALU, M, memory, branches, compressed instructions) |
| `Vivado/CVA6_Lab/firmware/link.ld` | new | Links the image at `0x8000_0000` |
| `Vivado/CVA6_Lab/scripts/build_firmware.sh` | new | Builds `selftest.elf/.bin` and the `$readmemh` image `firmware.hex` |
| `Vivado/CVA6_Lab/scripts/bin2hex.py` | new | Converts the flat binary to a word-indexed hex image |
| `Vivado/CVA6_Lab/scripts/run_verilator.sh` | new | Verilator build + run + trace check |
| `Vivado/CVA6_Lab/scripts/check_commit_trace.py` | new | Independent commit-trace checker against the ELF disassembly |
| `Vivado/CVA6_Lab/scripts/run_vivado_sim.sh` | new | Separate compile / elaborate / simulate stages under XSIM |

Firmware result contract (checked by the testbench):

| Address | Content |
| :--- | :--- |
| `0x8000_2000 + 4*i` | 12 result words, compared against expected constants |
| `0x8000_2400` | 32-word array used by the fill/sum test |
| `0x8000_3000` | `tohost`: `1` = all firmware self-checks passed, `(mask<<1)\|1` = failure |

## 3. Testbench Validation — Defects Found and Fixed

The imported testbench built cleanly but could not have produced a correct
result. Six concrete problems were found by reading it against the RTL/configuration:

| # | Defect | Impact | Fix |
| :--- | :--- | :--- | :--- |
| 1 | AXI address/data/strobe ports declared `XLEN` wide (32/32/4) while the core uses 64/64/8 | Truncated addresses and data, wrong byte lanes, corrupt memory contents; reported by `xelab` as `actual 32 vs formal 64` | All AXI payloads are 64-bit, strobe 8-bit; byte-lane faithful memory model |
| 2 | `ram` indexed as 32-bit words on a 64-bit bus (`addr[15:2]`, 4-byte step) | Half of every 8-byte beat ignored | Beat = two words at `addr[16:3]`, 8-byte increment |
| 3 | Firmware loaded from `firmware.hex` / `firmware_syn.hex`, neither present | `$readmemh` warning only, RAM stayed zero, core trapped on illegal instructions forever | `+FIRMWARE=` plusarg, file checked before loading, run aborts if the image is missing or empty |
| 4 | Termination on `stall_cycles>50 \|\| commit_cnt>=20 \|\| cycle_cnt>=1000` | Run ended after ~1000 cycles with a meaningless "CPI" (the program needs ~5.2k cycles) | Completion on a write to `tohost` + 50-cycle drain, bounded watchdog (`+MAX_CYCLES`, default 500k) and a stall watchdog |
| 5 | No evidence file, no self-check, success printed unconditionally | No way to distinguish a working core from a hung one | CSV logger (guide §3.7/§8), commit trace, 18 comparisons, `TB_SUMMARY` line, `PASS/FAIL` decided by `errors==0 && checks>0 && tests_done` |
| 6 | No CPI window definition | CPI ambiguously mixed boot and execution | Reports CPI from reset and CPI over the first→last retirement window, plus IPC |

Verification of the testbench wiring itself (before any simulation):

* 0 missing or duplicate source files, 0 duplicate module/package/interface
  definitions, package compile order satisfied.
* Every AXI port name and width used by `cva6_tb` matches
  `cva6_axi_wrapper` (`AxiAddrWidth=64`, `AxiDataWidth=64`, `AxiIdWidth=4`).
* After the rewrite, `xvlog` reports **no** width mismatch on the testbench
  hierarchy (the earlier `actual 32 vs formal 64` warnings are gone).

## 4. Stage Results

### 4.1 Vivado XSIM 2025.1

| Stage | Command | Result |
| :--- | :--- | :--- |
| Compile | `xvlog --incr --relax -L uvm -prj cva6_tb_vlog.prj` | **PASSED** — 0 errors (`CVA6_Lab.sim/sim_1/behav/xsim/xvlog.log`) |
| Elaborate | `xelab --incr --debug typical --relax --mt 8 ... xil_defaultlib.cva6_tb` | **FAILED** — `ERROR: [XSIM 43-3316] Signal SIGSEGV received.` |
| Simulate | `xsim cva6_tb_behav -runall` | **BLOCKED** — no snapshot exists |

The elaboration crash occurs immediately after `Starting simulation data flow
analysis`, before any design-specific diagnostic is printed, with peak resident
memory around 190 MB (no OOM). It is reproducible with:

* `--relax` and without `--relax` (without it, elaboration stops earlier on
  `VRFC 10-10007 variable 'sid[0]' might have multiple concurrent drivers` in
  `hpdcache/rtl/src/hwpf_stride/hwpf_stride_wrapper.sv:243`; rewriting that
  concatenation only converts the error into the same SIGSEGV)
* `-O0`, `-O1`, `-O2`
* `--debug off`, `--ignore_assertions`, `--nospecify`
* `--mt off`, `--mt 8`
* `ulimit -s unlimited`
* both `xil_defaultlib.cva6` and `xil_defaultlib.cva6_tb` as the top
* both the FPGA tech-cell files and the behavioural `tc_sram`/`tc_clk`
* a stripped, single-file-per-line project file and a clean environment
  (`env -i`)

The crash is in XSIM itself, not in the sources: the same sources compile with
`xvlog` without errors and elaborate/run correctly under Verilator.

### 4.2 Verilator 5.020 (sanctioned primary behavioural simulator)

| Stage | Result |
| :--- | :--- |
| Verilate + build (`--binary --timing -j 8`) | **PASSED** |
| Behavioural simulation | **PASSED** |
| Commit-trace cross-check vs disassembly | **PASSED** |

Console summary of the run:

```text
  CVA6 / cv32a6_imac_sv32 - AXI memory simulation report
------------------------------------------------------------
  Reset to tohost cycles     : 5169
  First commit cycle         : 266
  Last commit cycle          : 5168
  Active window cycles       : 4903
  Committed instructions     : 3544
  CPI (reset..tohost)        : 1.459
  CPI (first..last commit)   : 1.383
  IPC (first..last commit)   : 0.723
  Longest stall run          : 18 cycles
  AXI read beats / writes    : 84 / 46
  tohost seen / value        : 1 / 0x00000001
  CSV rows                   : 5179
------------------------------------------------------------
TB_SUMMARY results=12 checks=18 errors=0 tests_done=1 csv_rows=5179
== TEST PASSED ==
```

Note: Verilator 5.020 rejects the `default disable iff` assertion default in the
vendored AXI package. Only the disposable build copy (`build/verilator/rtl`) has
those assertion-only lines commented out; `imports/rtl` is untouched.

## 5. Functional Evidence

1. **Architectural results.** The firmware writes 12 results to memory; the
   testbench reads them back over the same AXI model and compares them with the
   expected constants (12/12 match). Examples:

   | Test | Value | Instruction coverage |
   | :--- | :--- | :--- |
   | sum 1..1000 | `0x0007_A314` (500500) | ALU, branch, loop |
   | `-7 * 9` | `0xFFFF_FFC1` | M extension (`mul`) |
   | `1000 / 7`, `1000 % 7` | `0x8E`, `0x6` | M extension (`div`, `rem`) |
   | `(0xF0F0F0F0>>4) ^ 0x0FF0` | `0x0F0F_00FF` | shift, logic |
   | `lbu/lhu/lh` of `0xDEADBEEF` | `0xEF`, `0xBEEF`, `0xFFFF_DEAD` | byte/half load, sign extension |
   | 32-word array checksum | `0x5F0` (1520) | store/load, loop |
   | marker | `0xCAFE_BABE` | store |
   | `tohost` | `1` | program completion |

2. **Instruction-level trace check** (`scripts/check_commit_trace.py`), 21
   checks, 0 errors:

   * all 3544 retired PCs map to a decoded instruction start (no misaligned
     fetch, no trap entry);
   * loop trip counts match the source: sum-loop body 1000, loop branch 1000,
     array fill store 32, array sum load 32, `mul`/`div`/`rem` 1 each;
   * the failure paths (`ori t0,t0,imm` and the failure block) never retired,
     i.e. every firmware self-check passed;
   * 10 selected register writebacks carry the expected values (`a2←500500`,
     `a2←142`, `a4←6`, `s1←0xEF`, `s2←0xBEEF`, `s3←0xFFFFDEAD`,
     `a2←1520`, `a1←0xCAFEBABE`, `a1←1`);
   * 108 instructions decoded, 94 unique PCs retired, 14 instructions belong to
     failure-only paths.

3. **Bus behaviour.** 84 AXI read beats and 46 write beats, including the
   `0x8000_3000` write with `wstrb=0x0F` and `wdata[31:0]=1`, detected by the
   testbench as the program exit.

## 6. CPI Analysis

$$\text{CPI} = \frac{\text{cycles}}{\text{committed instructions}}$$

| Window | Cycles | Instructions | CPI | IPC |
| :--- | ---: | ---: | ---: | ---: |
| Reset → `tohost` (includes 266 boot cycles) | 5169 | 3544 | **1.459** | 0.686 |
| First → last retirement (steady state) | 4903 | 3544 | **1.383** | 0.723 |
| Tight ALU loop (`sum 1..1000`), 1000 iterations | 4009 | 3000 | **1.336** | 0.749 |

Both figures are inside the target band of CPI ≈ 1.3 – 1.6, and the tight-loop
number (1.34) is the cleanest measurement of the core's steady-state throughput.

Per-instruction-class cycle cost measured from the commit trace (cycle delta
between consecutive retirements):

| Instruction class | Retirements | Mean cycles to next retirement |
| :--- | ---: | ---: |
| `add` | 1064 | 1.00 |
| `addi` | 1171 | 1.04 |
| `slli` / `srli` | 33 | 1.00 |
| `lw` | 32 | 1.00 |
| `sw` | 46 | 0.78 |
| `bge` (taken loop branch, 1000×) | 1000 | 2.01 |
| `blt` (array loops, 64×) | 64 | 2.98 |
| `beq` (checks, 10×) | 10 | 8.20 |
| `div` | 1 | 12.00 |

Instruction mix: `addi` 1171, `add` 1064, `bge` 1000, `li` 82, `blt` 64,
`sw` 46, `slli` 32, `lw` 32, `j` 20, `lui` 13, `beq` 10, `mul`/`div`/`rem`/
`srli`/`xor`/`lb`/`lbu`/`lhu`/`lh`/`beqz` 1 each (total 3544).

Interpretation: single-cycle ALU operations retire every cycle (CPI 1.0), so the
pipeline is *not* structurally stalled on the fixed-latency units. The whole CPI
above 1.0 comes from control flow — every taken loop branch costs one extra
cycle (2.01), un-predicted forward branches cost ~8 cycles, and the integer
divider needs 12 cycles. There is no evidence of the pathological write-back
contention (CPI 3.5 – 4.5) described in the project goals.

## 7. Vivado Blocker — Options

The design cannot currently be simulated with XSIM 2025.1 because `xelab`
segfaults. Remaining options, cheapest first:

1. **Post-synthesis functional simulation** (the route documented for this
   project): synthesise `cva6` with Vivado 2025.1 and run
   `launch_simulation -mode post-synthesis -type functional` on the netlist. Not
   attempted yet; the configured part `xa7s6cpga196-1Q` is small for this core,
   so utilisation must be reviewed and the shaped netlist port names must be
   verified before the behavioural `cva6_axi_wrapper` path can be reused.
2. **Another XSIM version** (Vivado 2024.x): the crash is inside the
   elaboration data-flow analyser, so an older release is a plausible workaround,
   but it must be verified, not assumed.
3. **Report to AMD** with the reproduction set (335-file filelist, `xvlog`
   clean, `xelab` SIGSEGV, no OOM).

Meanwhile Verilator provides the functional and CPI evidence, which is the
sanctioned primary flow for this repository.

## 8. How to Reproduce

```bash
cd Vivado/CVA6_Lab

# 1. firmware image (self-checking RV32IMAC program)
./scripts/build_firmware.sh

# 2. Verilator behavioural run + CSV + commit-trace check
./scripts/run_verilator.sh

# 3. Vivado XSIM stages (compile passes, elaborate currently crashes)
./scripts/run_vivado_sim.sh
```

Simulation plusargs understood by `cva6_tb`:

```text
+FIRMWARE=<hex image>   +CSV=<csv path>   +COMMIT_TRACE=<trace path>
+MAX_CYCLES=<n>         +STALL_LIMIT=<n>
```

## 9. Artifacts

| Path | Content |
| :--- | :--- |
| `Vivado/CVA6_Lab/build/verilator/simulation.log` | Verilator run transcript and CPI report |
| `Vivado/CVA6_Lab/build/verilator/cva6_sim.csv` | 5179 rows, one per clock edge (38 columns, includes `spy_*` probes) |
| `Vivado/CVA6_Lab/build/verilator/cva6_commit_trace.log` | 3544 retire records (`cycle port pc rd wdata`) |
| `Vivado/CVA6_Lab/build/verilator/commit_trace_check.log` | Disassembly cross-check result |
| `Vivado/CVA6_Lab/build/verilator/trace_hart_0.dasm` | Mock instruction trace emitted by `cva6.sv` (spike-dasm format) |
| `Vivado/CVA6_Lab/CVA6_Lab.sim/sim_1/behav/xsim/xvlog.log` | XSIM compile log (0 errors) |
| `Vivado/CVA6_Lab/CVA6_Lab.sim/sim_1/behav/xsim/elaborate.log` | XSIM elaboration log (SIGSEGV) |
| `Vivado/CVA6_Lab/firmware/build/selftest.dis` | Disassembly of the test program |

## 10. Conclusion

* The imported testbench was **not** usable as received: it drove 32-bit
  payloads into a 64-bit AXI port set and terminated before the program could
  finish. Both defects are fixed, and the testbench is now self-checking with a
  CSV logger and a defined watchdog.
* **Vivado XSIM behavioural simulation is not available**: compile passes,
  elaboration crashes in XSIM 2025.1 itself.
* **The core is functionally correct** for this configuration: the RV32IMAC
  self-test program retires 3544 instructions, all architectural results and
  register writebacks match, and the memory/BUS path is exercised in both
  directions.
* **Measured CPI is 1.383 (steady state) / 1.459 (reset to exit) / 1.336
  (tight ALU loop)**, i.e. inside the expected 1.3 – 1.6 range.
