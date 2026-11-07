# Valkyrie-RV32I Microarchitecture & Pipeline Specification

**Project:** `valkyrie-rv32i-core`  
**Classification:** Synthesizable VLSI Hardware Core  
**Application Target:** Directorate General of Signals (DG Signals) / Indian Army AICTE Programme  
**Target Domains:** Tactical Edge Avionics, Software-Defined Radio (SDR) Digital Baseband, Drone Navigation & Guidance Computers

---

## 1. Architectural Overview

The **Valkyrie-RV32I** is an industry-grade, synthesizable 32-bit RISC-V processor core implementing the standard 5-stage classic RISC pipeline:

$$\text{IF} \longrightarrow \text{ID} \longrightarrow \text{EX} \longrightarrow \text{MEM} \longrightarrow \text{WB}$$

The core features **hardware data forwarding**, **dynamic load-use hazard detection**, **early branch resolution with automatic pipeline flushing**, and a **Wishbone-compatible unified memory-mapped bus architecture**.

```
+==================================================================================================================+
|                                           VALKYRIE-RV32I PIPELINE SCHEMATIC                                      |
+==================================================================================================================+

       +------------------+     +------------------+     +------------------+     +------------------+
       |   IF/ID Reg      |     |   ID/EX Reg      |     |   EX/MEM Reg     |     |   MEM/WB Reg     |
       +------------------+     +------------------+     +------------------+     +------------------+
                |                        |                        |                        |
 [IF Stage]     v         [ID Stage]     v         [EX Stage]     v        [MEM Stage]     v         [WB Stage]
+----------+          +--------------+          +--------------+         +--------------+          +------------+
|  PC Reg  |--------->| Register File|--------->| Operand MUXs |-------->|  Load/Store  |--------->| Write-Back |
|    +4    |          | (32x32, x0=0)|          |  (Forwarding)|         |  Alignment   |          |    MUX     |
| BranchMUX|          |  Imm Gen     |          |  32-bit ALU  |         |  Mask Gen    |          |            |
+----------+          | Control Unit |          | Branch Comp  |         | Memory Req   |          +------------+
     ^                +--------------+          +--------------+         +--------------+                 |
     |                       |                         |                        |                         |
     |                       v                         |                        |                         |
     |               +---------------+                 |                        |                         |
     |               | Hazard Unit   |                 |                        |                         |
     |               | (Stall/Flush) |                 |                        |                         |
     |               +---------------+                 |                        |                         |
     |                       |                         v                        |                         |
     |                       |                 +---------------+                |                         |
     |                       |                 | Forwarding    |<---------------+                         |
     |                       |                 | Unit          |<-----------------------------------------+
     |                       |                 +---------------+
     |                       |                         |
     +-----------------------+-------------------------+ (Branch Target & PC Redirect)
```

---

## 2. Stage-by-Stage Detailed Specification

### 2.1 Instruction Fetch (IF Stage)
- **Program Counter (`pc_reg`):** 32-bit synchronous register with asynchronous active-low reset to `RESET_VECTOR` (`0x0000_0000`).
- **Next PC Selection:**
  - If `branch_taken == 1`: Selects `branch_target` (from EX stage).
  - Else if `stall_pc == 1`: Freezes `pc_reg` (Load-Use hazard bubble).
  - Else: Increments PC by $+4$ (`pc_reg + 32'd4`).
- **Memory Addressing:** Directly drives `imem_addr` to the instruction memory bus.

### 2.2 Instruction Decode & Register File (ID Stage)
- **Register File (`regfile.v`):** 32 general-purpose 32-bit registers.
  - Register `x0` is permanently wired to `32'd0`.
  - Dual asynchronous read ports (`rdata1`, `rdata2`).
  - Single synchronous write port (`waddr`, `wdata`, `wen`).
  - **Internal Write-Through Bypass:** If write and read addresses coincide in the same clock cycle, write data is immediately bypassed to the read ports without a pipeline stall.
- **Immediate Generator:** Extracts and sign/zero-extends immediates for all RV32I formats:
  - I-Type: $\text{SignExt}(inst[31:20])$
  - S-Type: $\text{SignExt}(\{inst[31:25], inst[11:7]\})$
  - B-Type: $\text{SignExt}(\{inst[31], inst[7], inst[30:25], inst[11:8], 1'b0\})$
  - U-Type: $\{inst[31:12], 12'b0\}$
  - J-Type: $\text{SignExt}(\{inst[31], inst[19:12], inst[20], inst[30:21], 1'b0\})$
- **Control Unit:** Decodes opcode, funct3, and funct7 to generate ALU controls, memory read/write strobes, write-back multiplexer selectors, and register usage flags (`uses_rs1`, `uses_rs2`).

### 2.3 Execute Stage (EX Stage)
- **Operand Forwarding MUXes:** Selects between ID/EX register data, EX/MEM forwarded result, and MEM/WB write-back data.
- **32-Bit Arithmetic Logic Unit (`alu.v`):** Purely combinational with zero latch inference:
  - Addition (`ADD`, `ADDI`), Subtraction (`SUB`)
  - Shifts: Logical Left (`SLL`, `SLLI`), Logical Right (`SRL`, `SRLI`), Arithmetic Right (`SRA`, `SRAI`)
  - Set Less Than: Signed (`SLT`, `SLTI`), Unsigned (`SLTU`, `SLTIU`)
  - Bitwise: `AND`/`ANDI`, `OR`/`ORI`, `XOR`/`XORI`
  - Pass Immediate: `PASS_B` (for `LUI`)
- **Branch Evaluation Unit (`branch_unit.v`):**
  - Compares forwarded operands for `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
  - Determines if unconditional jumps (`JAL`, `JALR`) or conditional branches are taken.
- **Branch Target Calculator:**
  - JAL / Branch: $Target = PC_{EX} + Imm_{EX}$
  - JALR: $Target = (ForwardedA + Imm_{EX}) \ \& \ \sim 1$
  - Return address $PC_{EX} + 4$ is passed down the pipeline for `rd` commit.

### 2.4 Data Memory Stage (MEM Stage)
- **Load/Store Alignment Logic (`mem_stage.v`):**
  - **Stores:** Generates 4-bit byte write mask (`dmem_wmask`) and rotates write data to align with target byte lanes ($0, 1, 2, 3$).
  - **Loads:** Dynamically extracts the target byte or halfword based on address bits $A[1:0]$ and applies sign-extension (`LB`, `LH`) or zero-extension (`LBU`, `LHU`). Full 32-bit words are passed transparently (`LW`).
- **Bus Framing:** Generates unified memory request strobes (`dmem_req`, `dmem_wen`).

### 2.5 Write-Back Stage (WB Stage)
- **Commit MUX:** Selects between:
  - ALU / EX Result (Computational instructions, LUI, AUIPC, and PC+4 for JAL/JALR)
  - Aligned Memory Read Data (Load instructions)
- Routes committed value to `regfile` write port in the ID stage.

---

## 3. Data Forwarding Unit (RAW Hazard Resolution)

The forwarding unit eliminates Read-After-Write (RAW) data hazards by multiplexing results directly to the ALU inputs in the EX stage before they are committed to the register file.

### Forwarding Priority Table

| Forwarding Condition | Source Stage | Forward Signal | Forwarded Data |
| :--- | :---: | :---: | :--- |
| `reg_write_mem && (rd_mem != 0) && (rd_mem == rs_ex)` | **EX/MEM** | `2'b10` | `ex_result_mem` |
| `reg_write_wb && (rd_wb != 0) && (rd_wb == rs_ex)` | **MEM/WB** | `2'b01` | `wb_data` |
| Default (No hazard) | **ID/EX** | `2'b00` | `reg_rdata_ex` |

> **Priority Rule:** If both EX/MEM and MEM/WB stages target the same destination register ($rd_{mem} == rd_{wb} == rs_{ex}$), the **EX/MEM stage takes priority** because it contains the most recent value in program order.

### Timing Diagram: EX-to-EX Forwarding (Distance 1)
```
Cycle:       1      2      3      4      5      6
Inst 1:    [IF]   [ID]   [EX]   [MEM]  [WB]
Inst 2:           [IF]   [ID]   [EX]   [MEM]  [WB]
                                 ^
                                 | Forwarded from Inst 1 (EX/MEM)
```

---

## 4. Hazard Detection Unit (Load-Use Hazards & Control Hazards)

### 4.1 Load-Use Data Hazard
A load-to-use hazard occurs when an instruction immediately following a `LOAD` requires the loaded data:

```assembly
lw   x1, 0(x2)    # Inst in EX stage (mem_read_ex == 1, rd_ex == x1)
addi x3, x1, 10   # Inst in ID stage (uses_rs1 == 1, rs1_id == x1)
```

Because load data is only available at the end of the MEM stage, the result cannot be forwarded into EX in the immediately following cycle without stalling.

**Resolution Mechanism:**
1. `stall_pc = 1`: Program counter is frozen.
2. `stall_if_id = 1`: Instruction in the IF/ID register is preserved.
3. `flush_id_ex = 1`: A NOP bubble is injected into the ID/EX register.
4. On the subsequent cycle, the load instruction reaches the MEM/WB stage, and data is forwarded directly to the dependent instruction now in the EX stage.

### Timing Diagram: Load-Use 1-Cycle Stall Bubble
```
Cycle:       1      2      3        4      5      6      7
LW x1:     [IF]   [ID]   [EX]     [MEM]  [WB]
ADDI x3:          [IF]   [ID]--+  [ID]   [EX]   [MEM]  [WB]
                               |    ^     ^
                           (STALL)  |     | Forwarded from WB stage
Bubble:                             |    [EX]   [MEM]  [WB] (NOP)
```

### 4.2 Control Hazards (Branch Misprediction)
- Branches are resolved in the **EX stage**.
- When `branch_taken == 1`:
  - `flush_if_id = 1`: Purges instruction fetched speculatively at $PC+4$.
  - `flush_id_ex = 1`: Purges instruction decoded speculatively at $PC+8$.
  - `pc_next = branch_target`: Program Counter redirects immediately to target address.
- **Taken branch penalty:** Exactly 2 clock cycles.
- **Not-taken branch penalty:** Exactly 0 clock cycles ($CPI = 1.0$).

---

## 5. Memory Map & Tactical Bus Integration

The core utilizes `memory_bus_adapter.v` to connect instruction fetch and data memory to an address-decoded memory map:

| Address Range | Size | Peripheral / Device | Description |
| :--- | :---: | :--- | :--- |
| `0x0000_0000` - `0x0FFF_FFFF` | 256 MB | **On-Chip SRAM** | Shared Instruction & Data Memory (Default 64 KB populated) |
| `0x1000_0000` | 4 B | **Tactical UART TX** | Write: Transmits byte to military tactical terminal console |
| `0x1000_0004` | 4 B | **Tactical UART Status** | Read: Bit 0 indicates TX Ready |
| `0x2000_0000` | 4 B | **Hardware Timer (`mtime`)** | Read: 32-bit low real-time hardware cycle/nanosecond counter |
| `0x2000_0004` | 4 B | **Hardware Timer (`mtimeh`)**| Read: 32-bit high real-time hardware cycle counter |
| `0x3000_0000` | 4 B | **Core Status / Sim Halt** | Write `0x1`: Pass/Halt; Read: "VALK" signature (`0x56414C4B`) |
| `0x4000_0000`+ | - | **Wishbone Master Bus** | Off-chip coprocessor / FPGA peripheral expansion |

---

## 6. Synthesis & VLSI Implementation Metrics

- **Language Standard:** IEEE 1364-2001 / IEEE 1800-2012 SystemVerilog compatible.
- **Latch Count:** 0 (Fully verified combinational completeness on all `always @(*)` paths).
- **Clock Domains:** 1 primary clock (`clk`), active-low asynchronous reset (`rst_n`).
- **Target Frequency:** $> 100\text{ MHz}$ on TSMC 65nm / GlobalFoundries 22FDX / Xilinx Artix-7/Kintex-7 UltraScale+ FPGA.
