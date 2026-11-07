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
