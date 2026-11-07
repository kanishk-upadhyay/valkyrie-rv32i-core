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
