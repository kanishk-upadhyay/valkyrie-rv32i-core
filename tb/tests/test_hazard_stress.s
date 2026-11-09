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
