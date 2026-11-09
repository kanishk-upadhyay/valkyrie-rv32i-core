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
