<div align="center">

# 🛡️ Valkyrie-RV32I Core
### Industry-Grade 5-Stage Pipelined RV32I RISC-V Processor Core in Verilog

[![CI Status](https://github.com/kanishk-upadhyay/valkyrie-rv32i-core/actions/workflows/ci.yml/badge.svg)](https://github.com/kanishk-upadhyay/valkyrie-rv32i-core)
[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I%20Base%20Integer-blue.svg)](https://riscv.org/)
[![Language](https://img.shields.io/badge/Language-Verilog%20(IEEE%201364--2001)-green.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Verification](https://img.shields.io/badge/Verification-100%25%20Passing%20(13%2F13)-brightgreen.svg)](tb/)
[![Synthesis](https://img.shields.io/badge/Synthesis-12.74%20kGE%20%7C%20Zero%20Latches-orange.svg)](sim/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

**Developed for the Indian Army Internship Programme (AICTE)**  
*Targeting the Directorate General of Signals (DG Signals) — Military Embedded Computing, Tactical Edge Processors for Avionics, Autonomous UAV Guidance, and Software-Defined Radios (SDR).*

> 💡 **Live Interactive Visual Simulator:** Open [`docs/interactive_explainer.html`](docs/interactive_explainer.html) in any browser to step cycle-by-cycle through pipeline stages, inspect live data forwarding paths, observe stall bubble injections, and visualize hardware interrupt preemption in real-time.

</div>

---

## 🎖️ Strategic Military & Defense Context

Modern electronic warfare, military avionics, and autonomous unmanned aerial vehicle (UAV) swarms require sovereign, auditable, high-performance tactical edge microprocessors. Proprietary architectures carry vulnerabilities and embargo risks. 

The **Valkyrie-RV32I** processor core delivers an open, robust, synthesizable RISC-V computing engine tailored for **DG Signals** operational requirements:
- **Tactical Avionics & Drone Flight Computers:** Deterministic 5-stage RISC pipeline execution with single-cycle ALU throughput.
- **Software-Defined Radio (SDR) Digital Baseband:** High IPC execution with full hardware data forwarding to eliminate pipeline pipeline bubbles in time-critical signal filtering and modulation loops.
- **Hardware-Level Precision Timing:** Integrated 64-bit real-time hardware cycle/nanosecond timer (`mtime`/`mtimeh`) for tactical frequency hopping and encrypted packet scheduling.
- **Military Tactical Console (UART):** Memory-mapped serial communications interface for real-time telemetry streaming and situational awareness displays.
- **Sovereign VLSI Readiness:** 100% vendor-neutral, synthesizable Verilog with **zero latch inferences**, ready for fabrication on military-spec silicon or implementation on defense-grade FPGAs (e.g., Xilinx Defense-Grade Kintex/Artix UltraScale+).

---

## 🏛️ Microarchitecture Overview

Valkyrie-RV32I implements the classic 5-stage Harvard-style RISC pipeline with unified memory mapping and dynamic hazard mitigation:

```
=====================================================================================================================
                                       VALKYRIE-RV32I PIPELINE ARCHITECTURE
=====================================================================================================================

  +------------------+       +------------------+       +------------------+       +------------------+
  |   IF/ID Reg      |       |   ID/EX Reg      |       |   EX/MEM Reg     |       |   MEM/WB Reg     |
  +------------------+       +------------------+       +------------------+       +------------------+
           |                          |                          |                          |
           v                          v                          v                          v
    [ IF Stage ]               [ ID Stage ]               [ EX Stage ]               [ MEM Stage ]          [ WB Stage ]
 +------------------+       +------------------+       +------------------+       +------------------+    +--------------+
 | Program Counter  |       | 32x32 Regfile    |       | Forwarding MUXs  |       | Load Alignment   |    | Write-Back   |
 |   (PC Register)  |====>  | (x0 = 0, Bypass) |====>  | 32-bit ALU       |====>  | Store Byte Mask  |===>| Result MUX   |
 | PC+4 Adder       |       | Imm Generator    |       | Branch Evaluator |       | Data Bus Framing |    | (ALU/MEM/PC4)|
 | Branch Target MUX|       | Control Decoder  |       | Target Adder     |       | Peripheral Bus   |    +--------------+
 +------------------+       +------------------+       +------------------+       +------------------+           |
          ^                          |                          |                          |                     |
          |                          v                          |                          |                     |
          |                  +---------------+                  |                          |                     |
          |                  | Hazard Unit   |                  |                          |                     |
          |                  | (Stall/Flush) |                  |                          |                     |
          |                  +---------------+                  v                          |                     |
          |                          |                  +---------------+                  |                     |
          |                          |                  | Forwarding    |<-----------------+                     |
          |                          |                  | Unit          |<---------------------------------------+
          |                          |                  +---------------+
          |                          |                          |
          +--------------------------+--------------------------+ (Branch Redirect & Flush)
```

### Pipeline Stages
1. **IF (Instruction Fetch):**
   - Synchronous Program Counter (`pc_reg`) with configurable `RESET_VECTOR` (`0x0000_0000`).
   - PC+4 incrementer and Branch Target MUX.
   - Stall-aware PC freeze during Load-Use hazards.
2. **ID (Instruction Decode):**
   - 32 general-purpose 32-bit registers (`x0` hardwired to zero).
   - **Internal write-through bypass** eliminating same-cycle register write-read hazards.
   - Comprehensive immediate decoding across all RV32I instruction types (I, S, B, U, J).
   - Central control decoder for execution, memory access, and hazard classification.
3. **EX (Execute):**
   - High-speed 32-bit ALU supporting addition, subtraction, shifts (logical/arithmetic), set-less-than (signed/unsigned), and bitwise Boolean logic.
   - Dynamic branch comparator evaluating conditional jumps (`BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`) and unconditional jumps (`JAL`, `JALR`).
   - Dedicated branch target adder ($PC + Imm$ or $(RS1 + Imm) \ \& \ \sim 1$).
4. **MEM (Data Memory):**
   - Load alignment logic with sign/zero extension (`LB`, `LH`, `LW`, `LBU`, `LHU`).
   - Store alignment logic and byte-enable strobe generation (`SB`, `SH`, `SW`).
   - Memory request framing.
5. **WB (Write-Back):**
   - Low-latency write-back selector multiplexing between ALU/EX result, memory data, and return address ($PC + 4$).

---

## ⚡ Hazard Management & Data Forwarding

### 1. Data Forwarding Unit (RAW Hazards)
To prevent stalling on Read-After-Write (RAW) data dependencies, the Forwarding Unit multiplexes intermediate results directly to the ALU inputs:
- **EX-to-EX Forwarding (Distance 1):** Bypasses results from the `EX/MEM` pipeline register to the `EX` stage ($CPI = 1.0$).
- **MEM-to-EX Forwarding (Distance 2):** Bypasses results from the `MEM/WB` pipeline register to the `EX` stage ($CPI = 1.0$).
- **Priority Resolution:** When both `EX/MEM` and `MEM/WB` stages write to the same register, `EX/MEM` takes precedence, preserving strict program semantics.

### 2. Hazard Detection Unit (Load-Use Hazards)
When an instruction in the Decode (`ID`) stage depends on the result of an immediately preceding Load instruction in the Execute (`EX`) stage:
- The data is not yet available from memory.
- The Hazard Unit automatically:
  1. **Freezes the Program Counter (`stall_pc = 1`)**.
  2. **Freezes the IF/ID pipeline register (`stall_if_id = 1`)**.
  3. **Injects a 1-cycle NOP bubble into ID/EX (`flush_id_ex = 1`)**.
- Once the load data reaches `MEM/WB`, it is forwarded directly to `EX` on the next cycle with zero data corruption.

### 3. Branch & Control Hazards
- Branches are resolved in the **Execute (EX) stage** using forwarded operands.
- **Branch Not Taken:** Zero penalty ($CPI = 1.0$).
- **Branch Taken / JAL / JALR:** The core redirects the Program Counter to the target address and purges the speculative instructions in `IF/ID` and `ID/EX` ($2$-cycle flush penalty).

---

## 🔔 Machine-Mode CSR & Asynchronous Interrupt Controller

To support real-time military RTOS preemption and hardware event handling for tactical edge avionics, Valkyrie-RV32I integrates a dedicated **Machine-Mode CSR Unit & Interrupt Subsystem** (`rtl/units/csr_unit.v`) adhering to the RISC-V Privileged Architecture v1.12:

- **Supported Machine-Mode Registers:**
  - `mstatus` (`0x300`): Machine status register managing global interrupt enable (`MIE`, bit 3) and previous interrupt enable (`MPIE`, bit 7).
  - `mie` (`0x304`): Individual interrupt enable mask for external interrupts (`MEIE`, bit 11) and timer interrupts (`MTIE`, bit 7).
  - `mtvec` (`0x305`): Trap vector base address register (4-byte aligned ISR vector).
  - `mscratch` (`0x340`): Machine-mode scratch register for RTOS context save pointers.
  - `mepc` (`0x341`): Machine exception program counter recording the return address of preempted tasks.
  - `mcause` (`0x342`): Trap cause register recording event type (`0x8000_000B` for External IRQ, `0x8000_0007` for Timer IRQ).
  - `mip` (`0x344`): Read-only interrupt pending register monitoring `MEIP` and `MTIP`.
- **Full Atomic CSR Instructions:** Supports `csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`, `csrr`, `csrw`, `csrs`, `csrc`.
- **Hardware Interrupt Preemption:** Asynchronous external IRQ (`irq_external`) and timer IRQ (`irq_timer`) preempt background tasks without software intervention:
  - Automatically backs up interrupted PC into `mepc`.
  - Backs up `mstatus.MIE` into `mstatus.MPIE` and clears `mstatus.MIE` (atomic interrupt disable).
  - Flushes speculatively fetched instructions and redirects execution to `mtvec` in a single clock cycle.
- **Atomic Trap Return (`mret`):** Restores global interrupts (`mstatus.MIE <= mstatus.MPIE`) and redirects PC to `mepc` to cleanly resume interrupted mission workloads.

---

## 🗺️ Memory Map & Tactical Bus Integration

The core includes an integrated Wishbone-compatible `memory_bus_adapter.v` with built-in memory-mapped peripherals:

| Address Range | Size | Peripheral / Device | Description |
| :--- | :---: | :--- | :--- |
| `0x0000_0000` - `0x0FFF_FFFF` | 256 MB | **On-Chip SRAM** | Unified Instruction & Data Memory (64 KB populated in default testbench) |
| `0x1000_0000` | 4 B | **Tactical UART TX** | Write: Transmits 8-bit character to mission terminal console |
| `0x1000_0004` | 4 B | **Tactical UART Status** | Read: Bit 0 indicates TX Ready (`1'b1`) |
| `0x1000_0008` | 4 B | **Hardware IRQ Inject** | Write: Bit 0 injects external asynchronous hardware interrupt for self-test |
| `0x2000_0000` | 4 B | **Hardware Timer (`mtime`)** | Read: Lower 32 bits of 64-bit continuous real-time cycle counter |
| `0x2000_0004` | 4 B | **Hardware Timer (`mtimeh`)**| Read: Upper 32 bits of 64-bit continuous real-time cycle counter |
| `0x2000_0008` | 4 B | **Timer Compare (`mtimecmp`)**| Read/Write: 32-bit comparator triggering real-time timer interrupt |
| `0x3000_0000` | 4 B | **Sim Control / Status** | Write `0x1`: Mission PASS / Halt; Read: Core Build Signature (`0x56414C4B` = "VALK") |
| `0x4000_0000`+ | - | **Wishbone Master** | Off-chip military avionics / FPGA coprocessor expansion bus |

---

## 📊 Verification & Regression Results

The core has undergone rigorous verification across **13 comprehensive test suites** (including military tactical edge computing algorithms, hardware interrupts, and traps) using Icarus Verilog (`iverilog`), `vvp`, and the automated Python regression runner (`sim_runner.py`):

```
==================================================================================
   VALKYRIE-RV32I PROCESSOR CORE - REGRESSION VERIFICATION SUITE
   Target: DG Signals / Indian Army Tactical Computing Applications
==================================================================================
TEST CASE                  STATUS     CYCLES     INSTR      CPI      IPC     
----------------------------------------------------------------------------------
test_arithmetic.hex        PASS       45         40         1.12     0.89    
test_branch.hex            PASS       35         16         2.19     0.46    
test_crc32_radio.hex       PASS       30         23         1.30     0.77    
test_drone_flight_pid.hex  PASS       23         18         1.28     0.78    
test_forwarding.hex        PASS       29         24         1.21     0.83    
test_full_suite.hex        PASS       61         51         1.20     0.84    
test_interrupt_trap.hex    PASS       54         41         1.32     0.76    
test_jump.hex              PASS       35         18         1.94     0.51    
test_load_store.hex        PASS       41         33         1.24     0.80    
test_load_use.hex          PASS       26         15         1.73     0.58    
test_matrix_rotation.hex   PASS       30         24         1.25     0.80    
test_tactical_telemetry.hex PASS       37         27         1.37     0.73    
test_uart_timer.hex        PASS       224        118        1.90     0.53    
----------------------------------------------------------------------------------
AGGREGATE TOTALS                      670        448        1.50     0.67    
==================================================================================

>>> VERIFICATION COMPLETE: ALL 13 TEST SUITES PASSED WITH ZERO ERRORS <<<
```

### Verification Highlights
- **Full RV32I ISA Coverage:** 100% of arithmetic, bitwise shifts, upper immediates, loads/stores, jumps, and branches verified.
- **Machine-Mode IRQ Preemption (`test_interrupt_trap`):** Verifies hardware interrupt injection, preemption of active background loops, trap vector redirection to `mtvec`, `mepc`/`mcause` context preservation, and clean pipeline resumption via `mret`.
- **Autonomous Drone Flight PID (`test_drone_flight_pid`):** Real-time fixed-point quadcopter error correction and motor actuator loop executing at 0.78 IPC.
- **SDR Tactical Packet Verification (`test_crc32_radio`):** Bitwise frame reduction and polynomial verification for secure communication packets.
- **Avionics 3D Transformation (`test_matrix_rotation`):** Multi-dimensional coordinate vector multiplication for aircraft/missile inertial guidance.
- **Electronic Warfare Peak Detection (`test_tactical_telemetry`):** In-place sorting and RF spectrum channel power peak scanner.
- **Hardware Hazard Resolution:** Zero pipeline corruption across back-to-back RAW forwarding, load-use stall bubbles, and branch misprediction purges.

---

## 🔬 Silicon Synthesis & PPA Benchmark Analysis

The core has been synthesized using the **Yosys Open-Source Synthesis Suite v0.70** to establish silicon complexity, gate-equivalence, and maximum clock frequency ($F_{max}$):

### Synthesis PPA Benchmark Summary

| Parameter | Synthesis Value | Unit / Equivalent Metric |
| :--- | :--- | :--- |
| **Target Top-Level Core** | `rv32i_core` | 5-stage pipelined RV32I processor |
| **Total Standard Cells** | **10,166** | physical standard cells |
| **Sequential Flip-Flops (DFF / DFFE)** | **1,682** | flip-flops (registers & pipeline buffers) |
| **Combinational Logic Gates** | **8,484** | logic gates |
| **Estimated Transistor Count** | **50,964** | CMOS transistors |
| **Equivalent Gate Count (NAND2)** | **12.74** | **kGE (Kilo-Gate Equivalents)** |
| **Critical Path Depth** | **166** | topological AIG logic nodes |
| **Critical Path Bottleneck** | `Forwarding MUX -> 32-bit ALU Adder/Sub -> EX Result MUX` |

### Multi-Node Silicon Projections

| Process Technology Node | Target Application | Estimated Core Area | Est. Critical Path | Max Frequency ($F_{max}$) |
| :--- | :--- | :---: | :---: | :---: |
| **SkyWater 130nm CMOS** | Sovereign Open-Source Silicon | $\sim 0.127\text{ mm}^2$ | $\sim 6.8\text{ ns}$ | **147 MHz** |
| **TSMC 65nm LP** | Tactical Defense Avionics | $\sim 0.023\text{ mm}^2$ | $\sim 2.7\text{ ns}$ | **370 MHz** |
| **TSMC 28nm HPC+** | Military SDR & Drone Swarm | $\sim 0.007\text{ mm}^2$ | $\sim 1.3\text{ ns}$ | **769 MHz** |

---

## 💡 Key Architectural Trade-Offs & Engineering Decisions

| Design Decision | Alternative Considered | Engineering Rationale & Silicon Impact |
| :--- | :--- | :--- |
| **Branch Evaluation in EX Stage** | Branch Evaluation in ID Stage | Evaluating branches in ID requires dedicated 32-bit comparators and an extra forwarding network to ID, widening critical path timing in decode. Resolving in EX reuses the existing ALU and forwarding multiplexers with a minimal 2-cycle penalty on taken branches, maximizing achievable $F_{max}$ (up to 769 MHz on 28nm). |
| **Write-Through Register File Bypass** | Stall-on-Write-Read Conflict | Implemented internal bypass logic within `regfile.v` ($RData = (WAddr == RAddr\ \&\&\ WEn) \ ?\ WData : Reg[RAddr]$). Eliminates same-cycle WAW/RAW hazards, maintaining sustained single-cycle throughput without injecting pipeline bubbles. |
| **Priority-Encoded Forwarding Unit** | Strict Pipeline Stalls | Prioritizes `EX/MEM` over `MEM/WB` forwarding when both stages target the same destination register. Guarantees that the chronologically most recent instruction data is supplied to the ALU without pipeline stalls. |
| **Hardware Interrupt Preemption with Single-Cycle Vectoring** | Software-Polled Interrupts | Dedicated `csr_unit.v` monitors `irq_external` and `irq_timer` continuously. Upon trigger, the core automatically saves `mepc`, updates `mcause`, disables `mstatus.MIE`, purges speculative instructions, and jumps to `mtvec` in a single cycle—guaranteeing deterministic, microsecond-grade reaction time for tactical edge avionics. |

---

## 📁 Repository Structure

```
valkyrie-rv32i-core/
├── rtl/
│   ├── core/
│   │   ├── rv32i_core.v            # Top-level core wiring pipeline stages & hazard logic
│   │   ├── if_stage.v              # Instruction Fetch (PC, PC+4, Branch MUX)
│   │   ├── id_stage.v              # Instruction Decode (Regfile, Imm Gen, Control Unit)
│   │   ├── ex_stage.v              # Execute (ALU, Branch Unit, Forwarding MUXs, CSR Write)
│   │   ├── mem_stage.v             # Memory Access (Load/Store alignment, Byte Masks)
│   │   └── wb_stage.v              # Write-Back (Register Commit Multiplexer)
│   ├── units/
│   │   ├── alu.v                   # 32-bit Arithmetic Logic Unit
│   │   ├── branch_unit.v           # Branch condition evaluator
│   │   ├── csr_unit.v              # Machine-mode CSR & interrupt controller
│   │   ├── forwarding_unit.v       # EX/MEM to EX and MEM/WB to EX forwarding
│   │   ├── hazard_unit.v           # Load-use hazard detection & branch flush
│   │   └── regfile.v               # 32x32 register file with internal bypass
│   └── bus/
│       └── memory_bus_adapter.v    # Wishbone adapter & tactical MMIO (UART/Timer/IRQ)
├── tb/
│   ├── tb_core.v                   # Top-level testbench with 64KB SRAM model
│   ├── sim_runner.py               # Automated Python regression test runner
│   └── tests/                      # Assembly test suites & hex binaries
│       ├── test_arithmetic.s / .hex
│       ├── test_branch.s / .hex
│       ├── test_forwarding.s / .hex
│       ├── test_full_suite.s / .hex
│       ├── test_interrupt_trap.s / .hex  # Asynchronous IRQ & trap return
│       ├── test_jump.s / .hex
│       ├── test_load_store.s / .hex
│       ├── test_load_use.s / .hex
│       ├── test_uart_timer.s / .hex
│       ├── test_drone_flight_pid.s / .hex
│       ├── test_crc32_radio.s / .hex
│       ├── test_matrix_rotation.s / .hex
│       ├── test_tactical_telemetry.s / .hex
│       ├── asm_tool.py             # Built-in RV32I & CSR assembler
│       └── generate_test_hexes.py  # Test generator script
├── sim/
│   ├── Makefile                    # Automated compilation, regression & synthesis
│   ├── synth.ys                    # Yosys open-source silicon synthesis script
│   ├── synth_report.py             # Silicon PPA and cell breakdown analyzer
│   └── view_waves.sh               # Waveform launcher (Surfer / GTKWave)
├── docs/
│   ├── pipeline_architecture.md    # Microarchitecture, CSR & forwarding path diagrams
│   └── instruction_set.md          # 37 RV32I instructions & timing reference
├── .github/workflows/
│   └── ci.yml                      # GitHub Actions automated regression CI
├── LICENSE                         # Apache 2.0 Open-Source License
└── README.md                       # Master Documentation
```

---

## 🚀 Quick Start Guide

### Prerequisites
- **Icarus Verilog (`iverilog`) & `vvp`:** Open-source Verilog simulator.
  - macOS: `brew install icarus-verilog`
  - Linux (Ubuntu/Debian): `sudo apt-get install iverilog`
- **Yosys (v0.70+):** Open-source logic synthesis suite for silicon gate-level analysis.
  - macOS: `brew install yosys`
  - Linux: `sudo apt-get install yosys`
- **Surfer / GTKWave (Optional):** For visualizing `.vcd` waveform dumps.
  - macOS: `brew install surfer`
- **Python 3 (3.8+):** For running the automated test suite and PPA analyzer.

### 1. Run Complete Automated Regression (13 Test Suites)
```bash
# Clone the repository
git clone https://github.com/kanishk-upadhyay/valkyrie-rv32i-core.git
cd valkyrie-rv32i-core

# Execute automated regression runner
python3 tb/sim_runner.py
```

### 2. Using the Makefile
```bash
cd sim

# Compile and run all 13 test suites
make test-all

# Run specific test suite (e.g. Interrupt & Trap suite)
make test-test_interrupt_trap
make test-test_drone_flight_pid

# Generate and view simulation waveforms in Surfer
make waves

# Run open-source silicon synthesis and print PPA benchmark report
make synth
```

---

## 🛠️ Synthesis & VLSI Quality Checklist

- [x] **Fully Synthesizable:** Written in standard synthesizable Verilog (IEEE 1364-2001).
- [x] **Zero Latch Inferences:** Every combinational `always @(*)` block includes default assignments and complete sensitivity paths.
- [x] **Clock Discipline:** Single clock domain with synchronous active-low asynchronous reset assertions.
- [x] **FPGA & ASIC Portability:** Compatible with Xilinx Vivado, Intel Quartus Prime, OpenLane (SkyWater 130nm / GF180MCU), and commercial EDA flows (Synopsys Design Compiler, Cadence Genus).

---

## 📜 License

This project is licensed under the **Apache License 2.0** — see the [LICENSE](LICENSE) file for details. Open for defense research, academic, and industrial VLSI computing applications.

---

## 🇮🇳 Acknowledgements & Attribution

Developed under the **Indian Army Internship Programme (AICTE)** targeting the **Directorate General of Signals (DG Signals)**. Dedicated to advancing indigenous, secure, and sovereign computing hardware for India's tactical defense infrastructure.
