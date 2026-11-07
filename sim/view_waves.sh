#!/usr/bin/env bash
# =============================================================================
# GTKWave Waveform Viewer Script
# Project: Valkyrie-RV32I Core
# Organization: DG Signals / Indian Army Internship Programme (AICTE)
# =============================================================================

VCD_FILE="${1:-valkyrie_sim.vcd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate file (either in SCRIPT_DIR or current directory)
if [ -f "$SCRIPT_DIR/$VCD_FILE" ]; then
    TARGET_VCD="$SCRIPT_DIR/$VCD_FILE"
elif [ -f "$VCD_FILE" ]; then
    TARGET_VCD="$VCD_FILE"
else
    echo "[WAVES] Error: VCD file '$VCD_FILE' not found."
    exit 1
fi

if command -v surfer &> /dev/null; then
    echo "[WAVES] Launching Surfer waveform viewer with $TARGET_VCD..."
    surfer "$TARGET_VCD" &
elif command -v gtkwave &> /dev/null; then
    echo "[WAVES] Launching GTKWave with $TARGET_VCD..."
    gtkwave "$TARGET_VCD" &
elif [ -d "/Applications/gtkwave.app" ]; then
    echo "[WAVES] Launching macOS GTKWave application..."
    open -a gtkwave "$TARGET_VCD"
else
    echo "[WAVES] No native waveform viewer (surfer or gtkwave) detected."
    echo "[WAVES] The waveform dump is ready at: $TARGET_VCD"
    echo "[WAVES] Recommended viewer options on macOS:"
    echo "        1. Install Surfer (Modern Rust-based VCD viewer): brew install surfer"
    echo "        2. VS Code: Install the 'WaveTrace' extension to open .vcd files directly"
    echo "        3. Community GTKWave tap: brew install randomplum/gtkwave/gtkwave"
fi
