# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-10 23:33:45 +03:30
# Status: NEW FILE
# Reason / Modification: Standalone Verilator simulation Makefile for CVA6 ThalesGroup flavor
# ============================================================================

ARCH             ?= 32
VERILATOR        ?= verilator
TOP_MODULE       = cva6_axi_wrapper
WRAPPER_SV       = tb/wrappers/cva6_axi_wrapper.sv
TB_CPP           = tb/cpp/tb_cva6_direct.cpp
FILE_LIST        = cv32a6_local.f
CVA6_ROOT        ?= $(CURDIR)/rtl
TRACE_FLAG       ?= --trace --trace-structs

VERILATOR_FLAGS  = \
    --cc \
    --exe \
    --build \
    -j 0 \
    $(TRACE_FLAG) \
    -Wno-PINMISSING \
    -Wno-BLKANDNBLK \
    -Wno-fatal \
    -O1 \
    -CFLAGS "-DRV32"

.PHONY: all build run wave_run wave clean firmware

all: run

firmware:
	@echo "--- Assembling simple_smoke.S ---"
	riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -mcmodel=medany \
	    -T /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/benchmarks/linker/link.ld -nostdlib \
	    simple_smoke.S -o firmware_smoke.elf
	riscv64-unknown-elf-objcopy -O binary firmware_smoke.elf firmware.bin

firmware_loop:
	@echo "--- Assembling loop_smoke.S ---"
	riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 -mcmodel=medany \
	    -T /home/alireza/GitHub/Mahani/CloneFiles/CVA6-Lab/benchmarks/linker/link.ld -nostdlib \
	    loop_smoke.S -o firmware_loop.elf
	riscv64-unknown-elf-objcopy -O binary firmware_loop.elf firmware.bin

build: firmware
	@echo "--- Resolving filelist with CVA6_ROOT=$(CVA6_ROOT) ---"
	sed "s|\$${CVA6_ROOT}|$(CVA6_ROOT)|g" $(FILE_LIST) > cv32a6_resolved.f
	@echo "--- Compiling with Verilator ---"
	$(VERILATOR) $(VERILATOR_FLAGS) -f cv32a6_resolved.f $(WRAPPER_SV) --top-module $(TOP_MODULE) $(TB_CPP)
	@echo "--- Build Complete: obj_dir/V$(TOP_MODULE) ---"

run: build
	@echo "--- Running Standalone Simulation (no waveform) ---"
	./obj_dir/V$(TOP_MODULE)

wave_run: build
	@echo "--- Running Standalone Simulation with Waveform ---"
	ENABLE_WAVE=1 ./obj_dir/V$(TOP_MODULE)

wave:
	gtkwave waveform.vcd CVA6_simple_smoke.gtkw

clean:
	rm -rf obj_dir cv32a6_resolved.f waveform.vcd *.elf firmware.bin
