# Valkyrie-RV32I Instruction Set Architecture Specification

**Project:** `valkyrie-rv32i-core`  
**Standard:** RISC-V RV32I Base Integer Instruction Set (Unprivileged ISA v2.2)  
**Target Applications:** Tactical Edge Processors, Military Software-Defined Radios (SDR), UAV Flight Controllers, Avionics Embedded Systems  
**Organization:** Directorate General of Signals (DG Signals) / Indian Army Internship Programme (AICTE)

---

## 1. Overview & Architecture Summary

The `valkyrie-rv32i-core` implements the complete official RISC-V RV32I Base Integer Instruction Set architecture comprising **37 core user-level computational, memory, control, and immediate instructions** plus foundational system traps (`ECALL`, `EBREAK`).

All operations operate on 32-bit words, 32 general-purpose registers (`x0` - `x31`), and utilize a 32-bit linear byte-addressable address space. Register `x0` is hardwired to constant `0`.

---

## 2. RV32I Instruction Formats

```
           31        25 24        20 19        15 14   12 11         7 6           0
  R-Type  |   funct7   |    rs2     |    rs1     | funct3 |     rd      |    opcode   |
  I-Type  |          imm[11:0]      |    rs1     | funct3 |     rd      |    opcode   |
  S-Type  |  imm[11:5] |    rs2     |    rs1     | funct3 |  imm[4:0]   |    opcode   |
  B-Type  |imm[12|10:5]|    rs2     |    rs1     | funct3 |imm[4:1|11]  |    opcode   |
  U-Type  |                   imm[31:12]                      |     rd      |    opcode   |
  J-Type  |               imm[20|10:1|11|19:12]               |     rd      |    opcode   |
```

---

## 3. Instruction Set Reference Table

| Mnemonic | Type | Opcode | funct3 | funct7 / imm | Operation | Latency | Hazard / Forwarding |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: | :--- |
| **LUI** | U | `0110111` | - | `imm[31:12]` | $rd \leftarrow imm \ll 12$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **AUIPC** | U | `0010111` | - | `imm[31:12]` | $rd \leftarrow PC + (imm \ll 12)$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **JAL** | J | `1101111` | - | `imm[20:1]` | $rd \leftarrow PC + 4; PC \leftarrow PC + imm$ | 2 cycles | 2-cycle flush penalty |
| **JALR** | I | `1100111` | `000` | - | $rd \leftarrow PC + 4; PC \leftarrow (rs1 + imm) \ \& \ \sim 1$ | 2 cycles | 2-cycle flush; $rs1$ forwarded |
| **BEQ** | B | `1100011` | `000` | - | `if (rs1 == rs2) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **BNE** | B | `1100011` | `001` | - | `if (rs1 != rs2) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **BLT** | B | `1100011` | `100` | - | `if ($signed(rs1) < $signed(rs2)) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **BGE** | B | `1100011` | `101` | - | `if ($signed(rs1) >= $signed(rs2)) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **BLTU** | B | `1100011` | `110` | - | `if (rs1 < rs2) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **BGEU** | B | `1100011` | `111` | - | `if (rs1 >= rs2) PC += imm` | 1 / 2 | 2-cycle flush if taken; 1 cycle if not |
| **LB** | I | `0000011` | `000` | - | $rd \leftarrow \text{SignExt}(M[rs1 + imm][7:0])$ | 1 cycle | Load-Use: 1-cycle stall bubble |
| **LH** | I | `0000011` | `001` | - | $rd \leftarrow \text{SignExt}(M[rs1 + imm][15:0])$ | 1 cycle | Load-Use: 1-cycle stall bubble |
| **LW** | I | `0000011` | `010` | - | $rd \leftarrow M[rs1 + imm][31:0]$ | 1 cycle | Load-Use: 1-cycle stall bubble |
| **LBU** | I | `0000011` | `100` | - | $rd \leftarrow \text{ZeroExt}(M[rs1 + imm][7:0])$ | 1 cycle | Load-Use: 1-cycle stall bubble |
| **LHU** | I | `0000011` | `101` | - | $rd \leftarrow \text{ZeroExt}(M[rs1 + imm][15:0])$ | 1 cycle | Load-Use: 1-cycle stall bubble |
| **SB** | S | `0100011` | `000` | - | $M[rs1 + imm][7:0] \leftarrow rs2[7:0]$ | 1 cycle | Full operand forwarding for $rs1, rs2$ |
| **SH** | S | `0100011` | `001` | - | $M[rs1 + imm][15:0] \leftarrow rs2[15:0]$ | 1 cycle | Full operand forwarding for $rs1, rs2$ |
| **SW** | S | `0100011` | `010` | - | $M[rs1 + imm][31:0] \leftarrow rs2[31:0]$ | 1 cycle | Full operand forwarding for $rs1, rs2$ |
| **ADDI** | I | `0010011` | `000` | - | $rd \leftarrow rs1 + imm$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLTI** | I | `0010011` | `010` | - | $rd \leftarrow (\$signed(rs1) < \$signed(imm)) \ ? \ 1 : 0$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLTIU** | I | `0010011` | `011` | - | $rd \leftarrow (rs1 < imm) \ ? \ 1 : 0$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **XORI** | I | `0010011` | `100` | - | $rd \leftarrow rs1 \oplus imm$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **ORI** | I | `0010011` | `110` | - | $rd \leftarrow rs1 \mid imm$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **ANDI** | I | `0010011` | `111` | - | $rd \leftarrow rs1 \ \& \ imm$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLLI** | I | `0010011` | `001` | `0000000` | $rd \leftarrow rs1 \ll shamt[4:0]$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SRLI** | I | `0010011` | `101` | `0000000` | $rd \leftarrow rs1 \gg shamt[4:0]$ (logical) | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SRAI** | I | `0010011` | `101` | `0100000` | $rd \leftarrow \$signed(rs1) \ggg shamt[4:0]$ (arith) | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **ADD** | R | `0110011` | `000` | `0000000` | $rd \leftarrow rs1 + rs2$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SUB** | R | `0110011` | `000` | `0100000` | $rd \leftarrow rs1 - rs2$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLL** | R | `0110011` | `001` | `0000000` | $rd \leftarrow rs1 \ll rs2[4:0]$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLT** | R | `0110011` | `010` | `0000000` | $rd \leftarrow (\$signed(rs1) < \$signed(rs2)) \ ? \ 1 : 0$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SLTU** | R | `0110011` | `011` | `0000000` | $rd \leftarrow (rs1 < rs2) \ ? \ 1 : 0$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **XOR** | R | `0110011` | `100` | `0000000` | $rd \leftarrow rs1 \oplus rs2$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SRL** | R | `0110011` | `101` | `0000000` | $rd \leftarrow rs1 \gg rs2[4:0]$ (logical) | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **SRA** | R | `0110011` | `101` | `0100000` | $rd \leftarrow \$signed(rs1) \ggg rs2[4:0]$ (arith) | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **OR** | R | `0110011` | `110` | `0000000` | $rd \leftarrow rs1 \mid rs2$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **AND** | R | `0110011` | `111` | `0000000` | $rd \leftarrow rs1 \ \& \ rs2$ | 1 cycle | EX $\rightarrow$ EX, MEM $\rightarrow$ EX |
| **FENCE** | I | `0001111` | `000` | - | Memory fence order | 1 cycle | Executed as in-order NOP |
| **ECALL** | I | `1110011` | `000` | `000000000000` | Environment call / OS trap | 1 cycle | Asserts `trap_ecall` signal |
| **EBREAK** | I | `1110011` | `000` | `000000000001` | Debugger breakpoint trap | 1 cycle | Asserts `trap_ebreak` signal |

---

## 4. Execution Timing & Pipeline Behavior

1. **Arithmetic & Logical Instructions:**
   - Single-cycle throughput in steady state ($CPI = 1.0$).
   - RAW dependencies are forwarded with zero bubble overhead ($CPI = 1.0$).

2. **Load-to-Use Hazards:**
   - When an instruction in the Decode (ID) stage depends directly on the output of an immediately preceding Load in the Execute (EX) stage:
   - The Hazard Unit inserts a **1-cycle stall bubble** in the pipeline ($CPI = 2.0$ for the dependent pair).
   - Once the load data enters the Write-Back stage, it is forwarded immediately to the Execute stage.

3. **Branch & Jump Control Hazards:**
   - Branches are evaluated in the Execute (EX) stage using forwarded operands.
   - **Branch Not Taken:** Zero penalty ($CPI = 1.0$). Sequential instructions in IF and ID continue seamlessly.
   - **Branch Taken / JAL / JALR:** 2-cycle flush penalty. Instructions in IF/ID and ID/EX are purged into NOP bubbles.
