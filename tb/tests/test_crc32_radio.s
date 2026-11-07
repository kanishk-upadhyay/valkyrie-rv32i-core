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
