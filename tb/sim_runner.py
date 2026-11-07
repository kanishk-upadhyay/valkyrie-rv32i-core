#!/usr/bin/env python3
"""
===============================================================================
Project: Valkyrie-RV32I Core
Organization: DG Signals / Indian Army Internship Programme (AICTE)
Script: sim_runner.py
Description: Automated regression test runner and verification suite manager.
             Compiles Verilog RTL with iverilog, executes testbench with vvp,
             parses simulation telemetry, and reports verification metrics.
===============================================================================
"""

import os
import sys
import glob
import subprocess
import argparse
import time

# Directory paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
RTL_DIR = os.path.join(PROJECT_ROOT, "rtl")
TB_DIR = os.path.join(PROJECT_ROOT, "tb")
TESTS_DIR = os.path.join(TB_DIR, "tests")
SIM_DIR = os.path.join(PROJECT_ROOT, "sim")
BIN_OUT = os.path.join(SIM_DIR, "sim_core")

def compile_rtl():
    """Compiles all RTL files and testbench into simulator binary."""
    os.makedirs(SIM_DIR, exist_ok=True)
    rtl_files = (
        glob.glob(os.path.join(RTL_DIR, "units", "*.v")) +
        glob.glob(os.path.join(RTL_DIR, "core", "*.v")) +
        glob.glob(os.path.join(RTL_DIR, "bus", "*.v"))
    )
    tb_file = os.path.join(TB_DIR, "tb_core.v")
    cmd = ["iverilog", "-g2012", "-o", BIN_OUT] + rtl_files + [tb_file]

    print("[BUILD] Compiling Valkyrie-RV32I RTL & Testbench with iverilog...")
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"[BUILD ERROR] Compilation failed:\n{result.stderr}")
        sys.exit(1)
    print(f"[BUILD SUCCESS] Simulator compiled: {BIN_OUT}\n")

def run_test(hex_file, dump_vcd=False, verbose=False):
    """Runs a single test hex file through vvp and parses telemetry."""
    test_name = os.path.basename(hex_file)
    vcd_path = os.path.join(SIM_DIR, f"{test_name}.vcd") if dump_vcd else ""
    
    cmd = ["vvp", BIN_OUT, f"+HEX={hex_file}"]
    if dump_vcd:
        cmd.append(f"+VCD={vcd_path}")

    start_time = time.time()
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    elapsed = time.time() - start_time

    output = proc.stdout
    if verbose:
        print(output)

    passed = ">>> [PASSED] <<<" in output
    cycles = 0
    instructions = 0
    cpi = 0.0
    ipc = 0.0

    for line in output.splitlines():
        line_clean = line.strip()
        if "Cycles Elapsed:" in line_clean:
            try:
                cycles = int(line_clean.split(":")[-1].strip())
            except ValueError:
                pass
        elif "Instructions Ret:" in line_clean:
            try:
                instructions = int(line_clean.split(":")[-1].strip())
            except ValueError:
                pass
        elif "CPI:" in line_clean:
            try:
                cpi = float(line_clean.split(":")[-1].strip())
            except ValueError:
                pass
        elif "IPC:" in line_clean:
            try:
                ipc = float(line_clean.split(":")[-1].strip())
            except ValueError:
                pass

    return {
        "name": test_name,
        "passed": passed,
        "cycles": cycles,
        "instructions": instructions,
        "cpi": cpi,
        "ipc": ipc,
        "wall_time": elapsed
    }

def main():
    parser = argparse.ArgumentParser(description="Valkyrie-RV32I Regression Test Runner")
    parser.add_argument("--test", type=str, default=None, help="Run specific test name or hex file")
    parser.add_argument("--vcd", action="store_true", help="Generate VCD waveform dump")
    parser.add_argument("--verbose", action="store_true", help="Print verbose simulation output")
    parser.add_argument("--skip-compile", action="store_true", help="Skip compilation step")
    args = parser.parse_args()

    if not args.skip_compile or not os.path.exists(BIN_OUT):
        compile_rtl()

    if args.test:
        if args.test.endswith(".hex"):
            test_files = [args.test] if os.path.exists(args.test) else [os.path.join(TESTS_DIR, args.test)]
        else:
            test_files = [os.path.join(TESTS_DIR, f"{args.test}.hex")]
    else:
        test_files = sorted(glob.glob(os.path.join(TESTS_DIR, "*.hex")))

    if not test_files:
        print("[ERROR] No test hex files found in", TESTS_DIR)
        sys.exit(1)

    print("=" * 82)
    print("   VALKYRIE-RV32I PROCESSOR CORE - REGRESSION VERIFICATION SUITE")
    print("   Target: DG Signals / Indian Army Tactical Computing Applications")
    print("=" * 82)
    print(f"{'TEST CASE':<26} {'STATUS':<10} {'CYCLES':<10} {'INSTR':<10} {'CPI':<8} {'IPC':<8}")
    print("-" * 82)

    all_passed = True
    total_cycles = 0
    total_inst = 0

    for tf in test_files:
        res = run_test(tf, dump_vcd=args.vcd, verbose=args.verbose)
        status_str = "\033[92mPASS\033[0m" if res["passed"] else "\033[91mFAIL\033[0m"
        if not res["passed"]:
            all_passed = False

        total_cycles += res["cycles"]
        total_inst += res["instructions"]

        print(f"{res['name']:<26} {status_str:<19} {res['cycles']:<10} {res['instructions']:<10} {res['cpi']:<8.2f} {res['ipc']:<8.2f}")

    overall_cpi = (total_cycles / total_inst) if total_inst > 0 else 0.0
    overall_ipc = (total_inst / total_cycles) if total_cycles > 0 else 0.0

    print("-" * 82)
    print(f"{'AGGREGATE TOTALS':<26} {'':<10} {total_cycles:<10} {total_inst:<10} {overall_cpi:<8.2f} {overall_ipc:<8.2f}")
    print("=" * 82)

    if all_passed:
        print(f"\n\033[92m>>> VERIFICATION COMPLETE: ALL {len(test_files)} TEST SUITES PASSED WITH ZERO ERRORS <<<\033[0m\n")
        sys.exit(0)
    else:
        print("\n\033[91m>>> VERIFICATION FAILED: ONE OR MORE TESTS FAILED <<<\033[0m\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
