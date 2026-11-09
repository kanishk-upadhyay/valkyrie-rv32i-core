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
