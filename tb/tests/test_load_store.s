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
