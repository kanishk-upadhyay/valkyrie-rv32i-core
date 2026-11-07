#!/usr/bin/env python3
"""
Test Suite Generator for Valkyrie-RV32I Core
Project: Valkyrie-RV32I Core
Organization: DG Signals / Indian Army Internship Programme (AICTE)
"""

import os
from asm_tool import assemble

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))

# -----------------------------------------------------------------------------
# Test 1: Arithmetic & Logic (R-type and I-type)
# -----------------------------------------------------------------------------
ASM_ARITHMETIC = """
# Test 1: Full RV32I Arithmetic & Logic
_start:
    # ADDI, ADD, SUB
    addi x1, x0, 15
    addi x2, x0, 25
    add  x3, x1, x2      # x3 = 40
    sub  x4, x2, x1      # x4 = 10
    
    # Check x3 == 40
    addi x5, x0, 40
    bne  x3, x5, fail
    # Check x4 == 10
    addi x5, x0, 10
    bne  x4, x5, fail

    # Shift operations
    slli x6, x1, 2       # 15 << 2 = 60
    addi x5, x0, 60
    bne  x6, x5, fail

    srli x7, x6, 1       # 60 >> 1 = 30
    addi x5, x0, 30
    bne  x7, x5, fail

    addi x8, x0, -16     # 0xFFFFFFF0
    srai x9, x8, 2       # -4 (0xFFFFFFFC)
    addi x5, x0, -4
    bne  x9, x5, fail

    # Bitwise: AND, OR, XOR
    andi x10, x1, 7      # 15 & 7 = 7
    addi x5, x0, 7
    bne  x10, x5, fail

    ori  x11, x1, 16     # 15 | 16 = 31
    addi x5, x0, 31
    bne  x11, x5, fail

    xori x12, x1, 15     # 15 ^ 15 = 0
    bne  x12, x0, fail

    # Set Less Than: SLT, SLTU, SLTI, SLTIU
    slti x13, x8, 0      # -16 < 0 -> 1
    addi x5, x0, 1
    bne  x13, x5, fail

    sltiu x14, x8, 10    # unsigned(-16) < 10 -> 0
    bne  x14, x0, fail

    slt  x15, x8, x1     # -16 < 15 -> 1
    addi x5, x0, 1
    bne  x15, x5, fail

    sltu x16, x8, x1     # unsigned(-16) < 15 -> 0
    bne  x16, x0, fail

    # Upper immediates: LUI, AUIPC
    lui  x17, 0x12345    # 0x12345000
    # auipc test
    auipc x18, 0x0       # current PC

    # Pass
    lui  x30, 0x30000    # Sim status address 0x30000000
    addi x31, x0, 1      # Status 1 = PASS
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB    # Status 0xDEADBEEF
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 2: Branch Instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
# -----------------------------------------------------------------------------
ASM_BRANCH = """
# Test 2: Branch Evaluation & Pipeline Flushes
_start:
    addi x1, x0, 10
    addi x2, x0, 10
    addi x3, x0, 20
    addi x4, x0, -5

    # 1. BEQ taken
    beq  x1, x2, beq_pass
    beq  x0, x0, fail
beq_pass:

    # 2. BEQ not taken (must continue sequentially)
    beq  x1, x3, fail

    # 3. BNE taken
    bne  x1, x3, bne_pass
    beq  x0, x0, fail
bne_pass:

    # 4. BNE not taken
    bne  x1, x2, fail

    # 5. BLT taken (signed: -5 < 10)
    blt  x4, x1, blt_pass
    beq  x0, x0, fail
blt_pass:

    # 6. BLT not taken (10 not < -5)
    blt  x1, x4, fail

    # 7. BGE taken (10 >= -5 and 10 >= 10)
    bge  x1, x4, bge_pass1
    beq  x0, x0, fail
bge_pass1:
    bge  x1, x2, bge_pass2
    beq  x0, x0, fail
bge_pass2:

    # 8. BLTU taken (10 < unsigned(-5))
    bltu x1, x4, bltu_pass
    beq  x0, x0, fail
bltu_pass:

    # 9. BGEU taken (unsigned(-5) >= 10)
    bgeu x4, x1, bgeu_pass
    beq  x0, x0, fail
bgeu_pass:

    # All branches passed!
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 3: Jump & Link (JAL, JALR) Subroutine Calls
# -----------------------------------------------------------------------------
ASM_JUMP = """
# Test 3: Unconditional Jumps & Subroutines
_start:
    addi s1, x0, 0       # Call counter (use s1 so ra/x1 is preserved for link)

    # Call sub1 with JAL
    jal  ra, sub1
    # Check that return was reached and s1 == 1
    addi x5, x0, 1
    bne  s1, x5, fail

    # Call sub2 with JAL
    jal  ra, sub2
    addi x5, x0, 3
    bne  s1, x5, fail

    # Call sub3
    jal  ra, sub3
    addi x5, x0, 7
    bne  s1, x5, fail

    # Success
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

sub1:
    addi s1, s1, 1       # s1 = 1
    jalr x0, ra, 0       # Return to caller

sub2:
    addi s1, s1, 2       # s1 = 3
    jalr x0, ra, 0       # Return to caller

sub3:
    addi s1, s1, 4       # s1 = 7
    jalr x0, ra, 0       # Return to caller

fail:
    lui  x30, 0x30000
    addi x31, x0, 0      # 0 = FAIL
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 4: Memory Load & Store Alignment (SB, SH, SW, LB, LH, LW, LBU, LHU)
# -----------------------------------------------------------------------------
ASM_LOAD_STORE = """
# Test 4: Memory Byte Alignment & Sign/Zero Extension
_start:
    lui  s0, 0x00001     # Base address: 0x00001000 in RAM
    
    # Test SW & LW
    lui  t0, 0x12345
    ori  t0, t0, 0x678   # 0x12345678
    sw   t0, 0(s0)
    lw   t1, 0(s0)
    bne  t0, t1, fail

    # Test SB across byte offsets 0, 1, 2, 3
    addi t2, x0, 0xAA
    addi t3, x0, 0xBB
    addi t4, x0, 0xCC
    addi t5, x0, 0x77
    sb   t2, 4(s0)       # Byte 0
    sb   t3, 5(s0)       # Byte 1
    sb   t4, 6(s0)       # Byte 2
    sb   t5, 7(s0)       # Byte 3

    # Read back byte 0 signed (0xAA is negative: 0xFFFFFFAA)
    lb   a0, 4(s0)
    addi s2, x0, -86     # 0xAA as signed 8-bit is -86
    bne  a0, s2, fail

    # Read back byte 0 unsigned (0x000000AA)
    lbu  a1, 4(s0)
    addi s3, x0, 0xAA
    bne  a1, s3, fail

    # Read back byte 3 signed (0x77 is positive: 0x00000077)
    lb   a2, 7(s0)
    addi s4, x0, 0x77
    bne  a2, s4, fail

    # Test SH & LH / LHU
    addi t6, x0, -1234   # Negative 16-bit
    sh   t6, 8(s0)
    lh   a3, 8(s0)
    bne  t6, a3, fail

    # Halfword offset 2
    addi s1, x0, 0x1234
    sh   s1, 10(s0)
    lhu  a4, 10(s0)
    bne  s1, a4, fail

    # All load/store operations verified!
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 5: Forwarding Unit (RAW Data Hazards)
# -----------------------------------------------------------------------------
ASM_FORWARDING = """
# Test 5: Back-to-Back RAW Data Forwarding
_start:
    # EX-to-EX forwarding (distance 1)
    addi x1, x0, 10
    addi x2, x1, 20      # x1 forwarded from EX: x2 = 30
    addi s2, x0, 30
    bne  x2, s2, fail

    # MEM-to-EX forwarding (distance 2)
    addi x3, x0, 100
    addi x0, x0, 0       # 1 bubble / independent inst
    addi x4, x3, 50      # x3 forwarded from MEM: x4 = 150
    addi s3, x0, 150
    bne  x4, s3, fail

    # Dual forwarding: both operands forwarded in same cycle
    addi x5, x0, 5
    addi x6, x0, 7
    add  x7, x5, x6      # x5 forwarded from MEM, x6 forwarded from EX: x7 = 12
    addi s4, x0, 12
    bne  x7, s4, fail

    # Consecutive accumulator chain (EX-to-EX stress test)
    addi x8, x0, 1
    add  x8, x8, x8      # 2
    add  x8, x8, x8      # 4
    add  x8, x8, x8      # 8
    add  x8, x8, x8      # 16
    add  x8, x8, x8      # 32
    addi s5, x0, 32
    bne  x8, s5, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 6: Hazard Detection Unit (Load-Use Stall Bubbles)
# -----------------------------------------------------------------------------
ASM_LOAD_USE = """
# Test 6: Load-Use Hazard Detection & Pipeline Stall
_start:
    lui  s0, 0x00001     # Base address 0x1000
    addi t0, x0, 99
    sw   t0, 0(s0)

    # 1. Load followed IMMEDIATELY by dependent arithmetic
    # Hazard unit MUST insert 1-cycle stall bubble!
    lw   t1, 0(s0)
    addi t2, t1, 1       # Dependent on t1! t2 must be 100
    addi s2, x0, 100
    bne  t2, s2, fail

    # 2. Load followed immediately by dependent store
    lw   t3, 0(s0)
    sw   t3, 4(s0)       # Dependent on t3!
    lw   t4, 4(s0)
    bne  t4, t0, fail

    # 3. Load followed immediately by dependent branch
    lw   t5, 0(s0)
    beq  t5, t0, branch_ok
    beq  x0, x0, fail
branch_ok:

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 7: Tactical Peripherals (UART Console & Hardware Timer)
# -----------------------------------------------------------------------------
ASM_UART_TIMER = """
# Test 7: Tactical MMIO Peripherals (UART & Timer)
_start:
    lui  s0, 0x10000     # UART Base: 0x10000000
    lui  s1, 0x20000     # Timer Base: 0x20000000

    # Print 'V' (0x56)
    addi t0, x0, 86
    sw   t0, 0(s0)
    # Print 'A' (0x41)
    addi t0, x0, 65
    sw   t0, 0(s0)
    # Print 'L' (0x4C)
    addi t0, x0, 76
    sw   t0, 0(s0)
    # Print 'K' (0x4B)
    addi t0, x0, 75
    sw   t0, 0(s0)
    # Print '\\n' (0x0A)
    addi t0, x0, 10
    sw   t0, 0(s0)

    # Read initial mtime counter
    lw   t1, 0(s1)

    # Spin loop to let timer advance
    addi t2, x0, 50
delay_loop:
    addi t2, t2, -1
    bne  t2, x0, delay_loop

    # Read second mtime counter
    lw   t3, 0(s1)

    # Verify t3 > t1 (timer advanced!)
    bltu t1, t3, timer_ok
    beq  x0, x0, fail
timer_ok:

    # Success
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 8: Comprehensive Full System Regression Suite
# -----------------------------------------------------------------------------
ASM_FULL_SUITE = """
# Test 8: Comprehensive Military Tactical RV32I Regression Suite
_start:
    # 1. Arithmetic Test
    addi x1, x0, 100
    addi x2, x0, 200
    add  x3, x1, x2      # 300
    addi x4, x0, 300
    bne  x3, x4, fail

    # 2. Forwarding Test
    addi x5, x3, 50      # 350
    addi x6, x5, 50      # 400
    addi x7, x0, 400
    bne  x6, x7, fail

    # 3. Memory & Load-Use Test
    lui  s0, 0x00001
    sw   x6, 0(s0)
    lw   x8, 0(s0)
    addi x9, x8, 10      # 410 (Load-Use stall)
    addi x10, x0, 410
    bne  x9, x10, fail

    # 4. Function Call with JAL/JALR
    jal  ra, test_func
    addi x11, x0, 999
    bne  a0, x11, fail

    # 5. Print "[VALKYRIE] MISSION SUCCESS\\n" via UART
    lui  s1, 0x10000
    addi t0, x0, 91     # '['
    sw   t0, 0(s1)
    addi t0, x0, 86     # 'V'
    sw   t0, 0(s1)
    addi t0, x0, 65     # 'A'
    sw   t0, 0(s1)
    addi t0, x0, 76     # 'L'
    sw   t0, 0(s1)
    addi t0, x0, 75     # 'K'
    sw   t0, 0(s1)
    addi t0, x0, 89     # 'Y'
    sw   t0, 0(s1)
    addi t0, x0, 82     # 'R'
    sw   t0, 0(s1)
    addi t0, x0, 73     # 'I'
    sw   t0, 0(s1)
    addi t0, x0, 69     # 'E'
    sw   t0, 0(s1)
    addi t0, x0, 93     # ']'
    sw   t0, 0(s1)
    addi t0, x0, 32     # ' '
    sw   t0, 0(s1)
    addi t0, x0, 79     # 'O'
    sw   t0, 0(s1)
    addi t0, x0, 75     # 'K'
    sw   t0, 0(s1)
    addi t0, x0, 10     # '\\n'
    sw   t0, 0(s1)

    # 6. Signal Simulation Success
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

test_func:
    addi a0, x0, 999
    jalr x0, ra, 0

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

ALL_TESTS = {
    "test_arithmetic": ASM_ARITHMETIC,
    "test_branch":     ASM_BRANCH,
    "test_jump":       ASM_JUMP,
    "test_load_store": ASM_LOAD_STORE,
    "test_forwarding": ASM_FORWARDING,
    "test_load_use":   ASM_LOAD_USE,
    "test_uart_timer": ASM_UART_TIMER,
    "test_full_suite": ASM_FULL_SUITE
}

def main():
    for name, asm_code in ALL_TESTS.items():
        s_path = os.path.join(TESTS_DIR, f"{name}.s")
        hex_path = os.path.join(TESTS_DIR, f"{name}.hex")

        # Save assembly source
        with open(s_path, "w") as f:
            f.write(asm_code.strip() + "\n")

        # Assemble into hex
        code = assemble(asm_code)
        with open(hex_path, "w") as f:
            for w in code:
                f.write(f"{w:08x}\n")

        print(f"[OK] Generated {name}.s and {name}.hex ({len(code)} instructions)")

if __name__ == "__main__":
    main()
