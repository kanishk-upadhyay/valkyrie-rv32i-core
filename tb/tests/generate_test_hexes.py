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

# -----------------------------------------------------------------------------
# Test 9: Autonomous Drone Quadcopter Flight Control (PID Loop)
# -----------------------------------------------------------------------------
ASM_DRONE_PID = """
# Test 9: Autonomous Drone Quadcopter Flight Control (PID Loop)
_start:
    lui  s0, 0x00001     # Base buffer at 0x1000
    addi t0, x0, 1000    # Target setpoint: 1000 (10.00 deg)
    addi t1, x0, 850     # Measured IMU gyro: 850 (8.50 deg)
    addi t2, x0, 50      # Prev integral error sum: 50
    addi t3, x0, 100     # Prev error: 100

    # Error: e = setpoint - sensor = 150
    sub  t4, t0, t1

    # P_term = Kp * e (Kp = 4)
    slli s1, t4, 2       # 150 << 2 = 600

    # I_term = (prev_integral + e) * Ki (Ki = 1)
    add  s2, t2, t4      # 50 + 150 = 200

    # D_term = (e - prev_error) * Kd (Kd = 2)
    sub  s3, t4, t3      # 150 - 100 = 50
    slli s3, s3, 1       # 50 << 1 = 100

    # Total motor thrust correction = P + I + D
    add  s4, s1, s2      # 600 + 200 = 800
    add  s4, s4, s3      # 800 + 100 = 900

    # Store motor command to memory
    sw   s4, 0(s0)
    lw   s5, 0(s0)

    # Verify motor command == 900
    addi s6, x0, 900
    bne  s5, s6, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 10: Military Tactical Radio Packet Checksum (SDR Link Layer)
# -----------------------------------------------------------------------------
ASM_CRC32_RADIO = """
# Test 10: Military Tactical Radio Packet Checksum (SDR Link Layer)
_start:
    lui  s0, 0x00001     # Packet buffer at 0x1000
    
    # Packet header & payload words
    addi t0, x0, 0x12
    slli t0, t0, 8
    ori  t0, t0, 0x34    # 0x1234
    
    addi t1, x0, 0x56
    slli t1, t1, 8
    ori  t1, t1, 0x78    # 0x5678

    # Store packet words
    sw   t0, 0(s0)
    sw   t1, 4(s0)

    # Compute CRC/checksum accumulator
    lw   a0, 0(s0)
    lw   a1, 4(s0)

    # XOR reduction & rotate
    xor  s1, a0, a1      # 0x1234 ^ 0x5678 = 0x444C
    slli s2, s1, 3       # Rotate left by 3
    srli s3, s1, 29
    or   s2, s2, s3

    # Add polynomial mask 0x99
    addi s4, x0, 0x99
    xor  s5, s2, s4

    # Store computed checksum
    sw   s5, 8(s0)
    lw   s6, 8(s0)
    bne  s5, s6, fail

    # Verify s5 != 0
    beq  s5, x0, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 11: Avionics 3D Coordinate Transformation
# -----------------------------------------------------------------------------
ASM_MATRIX_ROTATION = """
# Test 11: Avionics 3D Coordinate Transformation
_start:
    # Vector: X=10, Y=20, Z=30
    addi t0, x0, 10
    addi t1, x0, 20
    addi t2, x0, 30

    # Transformation:
    # X' = 2*X - Y       = 2*10 - 20 = 0
    # Y' = X + 2*Y - Z   = 10 + 40 - 30 = 20
    # Z' = Y + 2*Z       = 20 + 60 = 80

    # Compute X'
    slli a0, t0, 1       # 20
    sub  a0, a0, t1      # 20 - 20 = 0

    # Compute Y'
    slli a1, t1, 1       # 40
    add  a1, a1, t0      # 50
    sub  a1, a1, t2      # 50 - 30 = 20

    # Compute Z'
    slli a2, t2, 1       # 60
    add  a2, a2, t1      # 80

    # Store results in memory
    lui  s0, 0x00001
    sw   a0, 0(s0)
    sw   a1, 4(s0)
    sw   a2, 8(s0)

    # Verify X' == 0
    lw   s1, 0(s0)
    bne  s1, x0, fail

    # Verify Y' == 20
    lw   s2, 4(s0)
    addi s4, x0, 20
    bne  s2, s4, fail

    # Verify Z' == 80
    lw   s3, 8(s0)
    addi s5, x0, 80
    bne  s3, s5, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 12: RF Spectrum Signal Sorting & Jamming Peak Detection
# -----------------------------------------------------------------------------
ASM_TACTICAL_TELEMETRY = """
# Test 12: RF Spectrum Signal Sorting & Electronic Warfare Peak Detection
_start:
    lui  s0, 0x00001     # Base address 0x1000

    # Array of 4 signal channel power levels (dBm): 45, 12, 89, 34
    addi t0, x0, 45
    addi t1, x0, 12
    addi t2, x0, 89
    addi t3, x0, 34

    sw   t0, 0(s0)
    sw   t1, 4(s0)
    sw   t2, 8(s0)
    sw   t3, 12(s0)

    # Bubble sort pass 1: compare 0 and 1
    lw   a0, 0(s0)
    lw   a1, 4(s0)
    blt  a0, a1, skip1
    sw   a1, 0(s0)
    sw   a0, 4(s0)
skip1:

    # Compare 1 and 2
    lw   a0, 4(s0)
    lw   a1, 8(s0)
    blt  a0, a1, skip2
    sw   a1, 4(s0)
    sw   a0, 8(s0)
skip2:

    # Compare 2 and 3
    lw   a0, 8(s0)
    lw   a1, 12(s0)
    blt  a0, a1, skip3
    sw   a1, 8(s0)
    sw   a0, 12(s0)
skip3:

    # After pass 1, the maximum power (89 dBm) must have bubbled to word 3
    lw   s1, 12(s0)
    addi s2, x0, 89
    bne  s1, s2, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 13: Machine-Mode CSR, Interrupt Preemption & Trap Handler
# -----------------------------------------------------------------------------
ASM_INTERRUPT_TRAP = """
# Test 13: Machine-Mode CSR, Asynchronous External Interrupt & Trap Return
_start:
    # 1. Initialize State Registers
    addi s1, x0, 0          # s1: Background work iteration counter
    addi s2, x0, 0          # s2: ISR execution marker
    addi s3, x0, 0          # s3: mcause saved in ISR
    addi s4, x0, 0          # s4: mepc saved in ISR

    # 2. Configure mtvec to point to trap_handler
    addi t0, x0, trap_handler
    csrw mtvec, t0

    # 3. Enable Machine External Interrupt in mie (MEIE = bit 11 = 0x800)
    addi t1, x0, 1
    slli t1, t1, 11
    csrw mie, t1

    # 4. Enable Global Interrupts in mstatus (MIE = bit 3 = 0x8)
    addi t2, x0, 8
    csrs mstatus, t2

    # 5. Assert External Interrupt via Memory-Mapped Peripheral
    # Write 1 to 0x10000008 (irq_inject_reg)
    lui  a0, 0x10000
    addi a1, x0, 1
    sw   a1, 8(a0)

    # 6. Background Task Loop (Preempted by Hardware Interrupt)
bg_loop:
    addi s1, s1, 1
    bne  s2, x0, check_results
    beq  x0, x0, bg_loop

# -----------------------------------------------------------------------------
# Interrupt Service Routine (ISR) / Trap Handler
# -----------------------------------------------------------------------------
trap_handler:
    # Save trap context
    csrr s3, mcause
    csrr s4, mepc

    # Clear external interrupt source at 0x10000008
    lui  a0, 0x10000
    sw   x0, 8(a0)

    # Set ISR execution marker
    addi s2, s2, 1

    # Return from interrupt trap
    mret

# -----------------------------------------------------------------------------
# Post-Interrupt Verification
# -----------------------------------------------------------------------------
check_results:
    # Verify ISR ran (s2 == 1)
    addi t5, x0, 1
    bne  s2, t5, fail

    # Verify mcause: External IRQ = 0x8000000B
    lui  t6, 0x80000
    addi t6, t6, 11
    bne  s3, t6, fail

    # Verify mepc within background loop range [bg_loop, trap_handler)
    addi t0, x0, bg_loop
    blt  s4, t0, fail
    addi t1, x0, trap_handler
    bge  s4, t1, fail

    # Verify background task ran
    blt  s1, t5, fail

    # Verify mstatus MIE restored to 1 (bit 3 == 8)
    csrr t2, mstatus
    andi t2, t2, 8
    addi t3, x0, 8
    bne  t2, t3, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 14: Sub-Word Memory Access & Alignment (LB, LBU, LH, LHU, SB, SH)
# -----------------------------------------------------------------------------
ASM_SUBWORD_MEMORY = """
# Test 14: Sub-Word Memory Access & Alignment
_start:
    lui  s0, 0x00001
    addi s0, s0, 0x000

    # 1. Store Word, read individual bytes (Little Endian)
    lui  t0, 0x12345
    ori  t0, t0, 0x678
    sw   t0, 0(s0)

    lbu  t1, 0(s0)
    addi t2, x0, 0x78
    bne  t1, t2, fail

    lbu  t1, 1(s0)
    addi t2, x0, 0x56
    bne  t1, t2, fail

    lbu  t1, 2(s0)
    addi t2, x0, 0x34
    bne  t1, t2, fail

    lbu  t1, 3(s0)
    addi t2, x0, 0x12
    bne  t1, t2, fail

    # 2. Signed vs Unsigned Byte Extension (negative byte 0x85)
    addi t0, x0, 0x85
    sb   t0, 4(s0)

    lbu  t1, 4(s0)
    addi t2, x0, 0x85
    bne  t1, t2, fail

    lb   t1, 4(s0)
    addi t2, x0, -123
    bne  t1, t2, fail

    # 3. Store Halfword and read Halfwords (LH vs LHU)
    lui  t0, 0x00008
    ori  t0, t0, 0x765
    sh   t0, 8(s0)

    lhu  t1, 8(s0)
    bne  t1, t0, fail

    lh   t1, 8(s0)
    lui  t2, 0xFFFF8
    ori  t2, t2, 0x765
    bne  t1, t2, fail

    lui  t0, 0x00004
    ori  t0, t0, 0x321
    sh   t0, 10(s0)

    lw   t1, 8(s0)
    lui  t2, 0x43218
    ori  t2, t2, 0x765
    bne  t1, t2, fail

    # 4. Partial Byte Overwrite inside Word
    addi t0, x0, 0xAA
    sb   t0, 9(s0)

    lw   t1, 8(s0)
    lui  t2, 0x4321B
    addi t2, t2, -1435
    bne  t1, t2, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 15: Pipeline Hazard Stress (Chained RAW, Load-to-Store, Dual-Stage)
# -----------------------------------------------------------------------------
ASM_HAZARD_STRESS = """
# Test 15: Pipeline Hazard Stress & Forwarding Paths
_start:
    lui  sp, 0x00001
    addi sp, sp, 0x000

    # 1. Back-to-back Load-to-Store Forwarding
    addi s1, x0, 0x42
    sw   s1, 0(sp)
    lw   s2, 0(sp)
    sw   s2, 4(sp)
    lw   s3, 4(sp)
    bne  s3, s1, fail

    # 2. Load followed immediately by dependent conditional branch
    addi t0, x0, 100
    sw   t0, 8(sp)
    lw   t1, 8(sp)
    beq  t1, t0, b_ok
    beq  x0, x0, fail
b_ok:

    # 3. Simultaneous Dual-Stage Forwarding (EX/MEM and MEM/WB)
    addi t2, x0, 10
    addi t3, x0, 20
    addi t4, x0, 30
    add  t2, t2, t3     # t2 = 30
    add  t3, t3, t4     # t3 = 50
    add  t5, t2, t3     # t5 = 30 + 50 = 80
    addi t6, x0, 80
    bne  t5, t6, fail

    # Reverse operand ordering
    add  t5, t3, t2     # t5 = 50 + 30 = 80
    bne  t5, t6, fail

    # 4. Priority Forwarding (EX/MEM over MEM/WB when both target same rd)
    addi t1, x0, 5
    addi t1, x0, 15
    add  t2, t1, x0     # Should forward 15
    addi t3, x0, 15
    bne  t2, t3, fail

    # 5. Consecutive Branch Flushes & Not-Taken Flow
    addi t1, x0, 1
    addi t2, x0, 2
    beq  t1, t2, fail   # not taken
    bne  t1, t2, b1     # taken
    beq  x0, x0, fail
b1:
    blt  t1, t2, b2     # taken
    beq  x0, x0, fail
b2:
    bge  t1, t2, fail   # not taken

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 16: Upper Immediates & AUIPC PC-Relative Boundary Test
# -----------------------------------------------------------------------------
ASM_UPPER_IMM = """
# Test 16: Upper Immediates (LUI & AUIPC)
_start:
    # 1. LUI edge values
    lui  t0, 0x00000
    bne  t0, x0, fail

    lui  t1, 0xFFFFF
    addi t2, x0, -1
    slli t2, t2, 12
    bne  t1, t2, fail

    lui  t3, 0x80000
    srai t4, t3, 31
    addi t5, x0, -1
    bne  t4, t5, fail

    # 2. AUIPC PC-Relative Computation
    auipc s0, 0
    auipc s1, 0
    sub   s2, s1, s0
    addi  s3, x0, 4
    bne   s2, s3, fail

    # Jump relative to AUIPC
    auipc t0, 0
    addi  t0, t0, 24
    jalr  x0, t0, 0
    beq   x0, x0, fail
    beq   x0, x0, fail
    beq   x0, x0, fail

target:
    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 17: Call Stack & Recursion (Standard ABI Linkage & Stack Frames)
# -----------------------------------------------------------------------------
ASM_CALL_STACK_RECURSION = """
# Test 17: Call Stack & Recursive Fibonacci
_start:
    lui  sp, 0x00002
    addi sp, sp, 0x000
    addi a0, x0, 7          # fib(7)
    jal  ra, fib
    addi t0, x0, 13         # Expected fib(7) = 13
    bne  a0, t0, fail

    addi a0, x0, 6          # fib(6)
    jal  ra, fib
    addi t0, x0, 8          # Expected fib(6) = 8
    bne  a0, t0, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop

fib:
    addi t0, x0, 1
    bge  t0, a0, fib_base

    # Prologue: allocate 16-byte stack frame
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    add  s0, a0, x0

    # Call fib(n-1)
    addi a0, s0, -1
    jal  ra, fib
    add  s1, a0, x0

    # Call fib(n-2)
    addi a0, s0, -2
    jal  ra, fib

    # Result = fib(n-1) + fib(n-2)
    add  a0, s1, a0

    # Epilogue: restore stack frame
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    jalr x0, ra, 0

fib_base:
    jalr x0, ra, 0
"""

# -----------------------------------------------------------------------------
# Test 18: Real-Time Timer Interrupt Preemption (mtimecmp & CSRs)
# -----------------------------------------------------------------------------
ASM_TIMER_IRQ = """
# Test 18: Real-Time Hardware Timer Interrupt Preemption
_start:
    lui  t0, 0x00000
    ori  t0, t0, timer_isr
    csrw mtvec, t0

    addi s0, x0, 0
    addi s1, x0, 0

    # Read current mtime
    lui  t1, 0x20000
    lw   t2, 0(t1)

    # Set mtimecmp = mtime + 30
    addi t2, t2, 30
    sw   t2, 8(t1)

    # Enable MTIE (bit 7 = 0x80)
    addi t3, x0, 128
    csrw mie, t3

    # Enable global interrupts: set MIE (bit 3 = 0x08)
    addi t3, x0, 8
    csrs mstatus, t3

work_loop:
    addi s0, s0, 1
    bne  s1, x0, test_done
    addi t4, x0, 500
    blt  s0, t4, work_loop

    # Timed out waiting for ISR
    beq  x0, x0, fail

timer_isr:
    addi s1, x0, 1

    # Disable timer condition: mtimecmp = 0xFFFFFFFF
    lui  t1, 0x20000
    lui  t2, 0xFFFFF
    ori  t2, t2, 0xFFF
    sw   t2, 8(t1)

    # Disable MTIE
    csrw mie, x0

    mret

test_done:
    addi t5, x0, 5
    blt  s0, t5, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 19: Tactical Cryptography: ChaCha20 Quarter-Round Stream Cipher
# -----------------------------------------------------------------------------
ASM_CRYPTO_PRIMITIVES = """
# Test 19: ChaCha20 ARX Cryptographic Quarter-Round
_start:
    lui  s0, 0x11111
    ori  s0, s0, 0x111

    lui  s1, 0x01020
    ori  s1, s1, 0x304

    lui  s2, 0x9B8D7
    addi s2, s2, -189

    lui  s3, 0x01234
    ori  s3, s3, 0x567

    # Round 1
    add  s0, s0, s1
    xor  s3, s3, s0
    slli t0, s3, 16
    srli t1, s3, 16
    or   s3, t0, t1

    # Round 2
    add  s2, s2, s3
    xor  s1, s1, s2
    slli t0, s1, 12
    srli t1, s1, 20
    or   s1, t0, t1

    # Round 3
    add  s0, s0, s1
    xor  s3, s3, s0
    slli t0, s3, 8
    srli t1, s3, 24
    or   s3, t0, t1

    # Round 4
    add  s2, s2, s3
    xor  s1, s1, s2
    slli t0, s1, 7
    srli t1, s1, 25
    or   s1, t0, t1

    # Verify a = 0xea2a92f4
    lui  t2, 0xEA2A9
    ori  t2, t2, 0x2F4
    bne  s0, t2, fail

    # Verify b = 0xcb1cf8ce
    lui  t2, 0xCB1D0
    addi t2, t2, -1842
    bne  s1, t2, fail

    # Verify c = 0x4581472e
    lui  t2, 0x45814
    ori  t2, t2, 0x72E
    bne  s2, t2, fail

    # Verify d = 0x5881c4bb
    lui  t2, 0x5881C
    ori  t2, t2, 0x4BB
    bne  s3, t2, fail

    # Pass
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    addi x31, x0, 0
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
"""

# -----------------------------------------------------------------------------
# Test 20: Machine-Mode Synchronous Trap (ECALL System Call)
# -----------------------------------------------------------------------------
ASM_ECALL_EBREAK = """
# Test 20: Machine-Mode Synchronous Trap (ECALL)
_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    ecall
    beq  x0, x0, _start
"""

ALL_TESTS = {
    "test_arithmetic":         ASM_ARITHMETIC,
    "test_branch":             ASM_BRANCH,
    "test_jump":               ASM_JUMP,
    "test_load_store":         ASM_LOAD_STORE,
    "test_forwarding":         ASM_FORWARDING,
    "test_load_use":           ASM_LOAD_USE,
    "test_uart_timer":         ASM_UART_TIMER,
    "test_full_suite":         ASM_FULL_SUITE,
    "test_drone_flight_pid":   ASM_DRONE_PID,
    "test_crc32_radio":        ASM_CRC32_RADIO,
    "test_matrix_rotation":    ASM_MATRIX_ROTATION,
    "test_tactical_telemetry": ASM_TACTICAL_TELEMETRY,
    "test_interrupt_trap":     ASM_INTERRUPT_TRAP,
    "test_subword_memory":     ASM_SUBWORD_MEMORY,
    "test_hazard_stress":      ASM_HAZARD_STRESS,
    "test_upper_imm":          ASM_UPPER_IMM,
    "test_call_stack_recursion": ASM_CALL_STACK_RECURSION,
    "test_timer_irq":          ASM_TIMER_IRQ,
    "test_crypto_primitives":  ASM_CRYPTO_PRIMITIVES,
    "test_ecall_ebreak":       ASM_ECALL_EBREAK
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
