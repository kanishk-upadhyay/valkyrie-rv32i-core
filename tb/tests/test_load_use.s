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
