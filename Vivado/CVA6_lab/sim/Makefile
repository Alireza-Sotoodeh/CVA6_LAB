# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-16 11:00:00 +03:30
# Status: NEW FILE
# Reason / Modification: Makefile for CVA6 firmware compilation and hex generation
#                        targeting cva6_tb.sv in Vivado XSIM simulation.
# ============================================================================

SRC  ?= main-syn.S
ARCH ?= rv32imac
OUT  ?= firmware_syn.hex

.PHONY: all hex clean dump

all: hex

hex:
	python3 asm2hex.py -i $(SRC) -a $(ARCH) -o $(OUT) -d

clean:
	rm -f firmware_syn.elf firmware_syn.dump firmware_syn.hex
