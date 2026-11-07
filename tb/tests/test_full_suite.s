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

    # 5. Print "[VALKYRIE] MISSION SUCCESS\n" via UART
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
    addi t0, x0, 10     # '\n'
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
