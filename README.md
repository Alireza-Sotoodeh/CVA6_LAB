---
author: Alireza Sotodeh
date: 2026-11-14 11:42:00 +03:30
status: MODIFIED FILE
reason: Added online web links and remote repository URLs for all CVA6 repositories; added section 5 with the current Vivado XSIM / Verilator verification status and measured CPI
---

# CVA6_LAB

A hands-on learning, architectural analysis, and verification laboratory for the **OpenHW Group CVA6 (Ariane)** RISC-V processor using **Verilator** and **AMD/Xilinx Vivado**.

---

## 1. Primary Reference Repositories & Online Links

All reference repositories are cloned locally under `/home/alireza/GitHub/Mahani/CloneFiles/`:

| Role | Repository & Online Web Link | Local Path | Description |
| :--- | :--- | :--- | :--- |
| **Primary Baseline** | [Amin-Maky/CVA6-Lab](https://github.com/Amin-Maky/CVA6-Lab) | [`/home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab`](file:///home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab) | **Primary codebase for simulation and exploration.** Features modular Verilator C++ testbenches, pre-configured Bender `.f` filelists, benchmark suites (`complex_32.S`, `matmul.c`, `avg.c`), Vivado synthesis scripts, and documented fixes for write-back pipeline stalls. |
| **Full-SoC Reference** | [ThalesGroup/cva6-softcore-contest](https://github.com/ThalesGroup/cva6-softcore-contest) | [`/home/alireza/GitHub/Mahani/CloneFiles/CVA6_ThalesGroup`](file:///home/alireza/GitHub/Mahani/CloneFiles/CVA6_ThalesGroup) | Reference for full-SoC platform infrastructure (`corev_apu/`), UART/peripherals, and Linux boot flows (used in later stages). Branch: `cv32a6_contest_26_27`. |
| **Upstream Lineage** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | [`/home/alireza/GitHub/Mahani/CloneFiles/cva6`](file:///home/alireza/GitHub/Mahani/CloneFiles/cva6) | Canonical OpenHW Group upstream repository (legacy master snapshot), reserved for pure RTL reference. Official documentation: [CVA6 User Manual](https://docs.openhwgroup.org/projects/cva6-user-manual/). |
| **Safety Variant** | [openhwgroup/cva6-safe](https://github.com/openhwgroup/cva6-safe) | [`/home/alireza/GitHub/Mahani/CloneFiles/CVA6_OpenHWSafe`](file:///home/alireza/GitHub/Mahani/CloneFiles/CVA6_OpenHWSafe) | Dual-core lockstep safety variant with cache error detection and correction. |

---

## 2. Target Core Configurations

1. **`cv32a6_imac_sv32` (Default Baseline)**:
   - 32-bit single-issue core (`RV32IMAC`), SV32 MMU / bare-metal.
   - Fast elaboration, minimal memory footprint, ideal for rapid cycle-accurate exploration and achieving target CPI $\approx 1.3 - 1.6$.
2. **`cv64a6_imafdc_sv39` (Standard 64-bit)**:
   - 64-bit single-issue core (`RV64IMAFDC`), SV39 MMU, FPU enabled.
3. **Custom 64-bit (Decoupled Write-Back / Hazard-Resolved)**:
   - Optimized CVA6-Lab variant addressing the Fixed-Latency Unit (FLU) write-back contention (preventing multi-cycle operations like DIV/FDIV from blocking single-cycle ALU instructions).

---

## 3. Microarchitectural Target & Performance Goals

* **Target Throughput**: Standard integer/ALU workloads should achieve **$\text{CPI} \approx 1.3 - 1.6$** ($\text{IPC} \approx 0.6 - 0.75$).
* **Stall Resolution**: Avoid pipeline write-back bottlenecks that cause structural stall degradation ($\text{CPI} \approx 3.5 - 4.5$).
* **Metric Calculation**:
  $$\text{CPI} = \frac{\text{Elapsed Clock Cycles}}{\text{Committed Instructions}}$$

---

## 4. Simulation & EDA Toolchains

* **Verilator (Primary Behavioral Simulation)**:
  - Path: `/usr/bin/verilator` (v5.020)
  - Engine for rapid, cycle-accurate behavioral execution and instruction commit tracing.
* **AMD/Xilinx Vivado (Synthesis & Post-Synthesis Simulation)**:
  - Path: `/home/alireza/App/AMD/2025.1/Vivado/bin/vivado` (v2025.1 64-bit)
  - Used for logic synthesis, FPGA resource/timing exploration, and Post-Synthesis Functional Simulation (`launch_simulation -mode post-synthesis -type functional`).
* **Waveform Viewers**:
  - **GTKWave** (`gtkwave`) for Verilator `.fst` / `.vcd` traces.
  - **Vivado Logic Analyzer / XSIM Waveform Viewer** (`.wdb`).
* **Cross-Compiler**:
  - `riscv64-unknown-elf-gcc` / `riscv-none-elf-gcc` (RV32: `-march=rv32imac -mabi=ilp32`, RV64: `-march=rv64imafdc -mabi=lp64d`).

---

## 5. Current Verification Status — `Vivado/CVA6_Lab` (`cv32a6_imac_sv32`)

Detailed report: [`Documents/CVA6_XSIM_Verilator_Simulation_Report.md`](Documents/CVA6_XSIM_Verilator_Simulation_Report.md)

| Stage | Tool | Status |
| :--- | :--- | :--- |
| Compile (335 design files + `cva6_tb`) | `xvlog` (Vivado 2025.1) | **Passed**, 0 errors |
| Elaborate | `xelab` (Vivado 2025.1) | **Failed** — `[XSIM 43-3316] Signal SIGSEGV` during data-flow analysis |
| Behavioural simulation | `xsim` | **Blocked** — no snapshot |
| Verilate / build / run | Verilator 5.020 | **Passed** |
| Commit-trace cross-check | `scripts/check_commit_trace.py` | **Passed**, 21 checks, 0 errors |

Functional and performance result (Verilator 5.020, self-checking RV32IMAC firmware):

| Metric | Value |
| :--- | ---: |
| Committed instructions | 3544 |
| Cycles reset → `tohost` | 5169 |
| **CPI (steady state)** | **1.383** |
| CPI (reset → exit) | 1.459 |
| CPI (tight ALU loop, 1000 iterations) | 1.336 |
| IPC (steady state) | 0.723 |
| Longest stall run | 18 cycles |

Reproduce with:

```bash
cd Vivado/CVA6_Lab
./scripts/build_firmware.sh     # RV32IMAC self-test image
./scripts/run_verilator.sh      # build + run + CSV + trace check
./scripts/run_vivado_sim.sh     # xvlog / xelab / xsim stages
```
