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
