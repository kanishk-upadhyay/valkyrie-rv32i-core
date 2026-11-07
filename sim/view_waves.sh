#!/usr/bin/env bash
# =============================================================================
# GTKWave Waveform Viewer Script
# Project: Valkyrie-RV32I Core
# Organization: DG Signals / Indian Army Internship Programme (AICTE)
# =============================================================================

VCD_FILE="${1:-valkyrie_sim.vcd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/$VCD_FILE" ] && [ ! -f "$VCD_FILE" ]; then
    echo "[WAVES] VCD file '$VCD_FILE' not found. Generating now..."
    cd "$SCRIPT_DIR" && make waves
fi

# Locate file
TARGET_VCD="$SCRIPT_DIR/$VCD_FILE"
[ -f "$TARGET_VCD" ] || TARGET_VCD="$VCD_FILE"

if command -v gtkwave &> /dev/null; then
    echo "[WAVES] Launching GTKWave with $TARGET_VCD..."
    gtkwave "$TARGET_VCD" &
elif [ -d "/Applications/gtkwave.app" ]; then
    echo "[WAVES] Launching macOS GTKWave application..."
    open -a gtkwave "$TARGET_VCD"
else
    echo "[WAVES] GTKWave binary not detected in PATH or Applications."
    echo "[WAVES] The waveform dump is ready at: $TARGET_VCD"
    echo "[WAVES] Install GTKWave (brew install --cask gtkwave) or open $TARGET_VCD with your preferred viewer."
fi
