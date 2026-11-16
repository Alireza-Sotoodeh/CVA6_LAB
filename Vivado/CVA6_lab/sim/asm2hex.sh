#!/usr/bin/env bash
# ============================================================================
# Author: Alireza Sotodeh
# Date & Time: 2026-11-16 11:00:00 +03:30
# Status: NEW FILE
# Reason / Modification: Quick bash launcher for asm2hex.py to compile any
#                        assembly source into firmware_syn.hex for cva6_tb.sv.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/asm2hex.py"

INPUT_SRC="${1:-${SCRIPT_DIR}/main-syn.S}"
ARCH="${2:-rv32imac}"

echo "[INFO] Compiling ${INPUT_SRC} (${ARCH}) -> firmware_syn.hex..."
python3 "${PYTHON_SCRIPT}" -i "${INPUT_SRC}" -a "${ARCH}" "$@"
