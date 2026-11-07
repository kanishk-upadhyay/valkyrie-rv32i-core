# Test 12: RF Spectrum Signal Sorting & Electronic Warfare Peak Detection
_start:
    lui  s0, 0x00001     # Base address 0x1000

    # Array of 4 signal channel power levels (dBm): 45, 12, 89, 34
    addi t0, x0, 45
    addi t1, x0, 12
    addi t2, x0, 89
    addi t3, x0, 34

    sw   t0, 0(s0)
    sw   t1, 4(s0)
    sw   t2, 8(s0)
    sw   t3, 12(s0)

    # Bubble sort pass 1: compare 0 and 1
    lw   a0, 0(s0)
    lw   a1, 4(s0)
    blt  a0, a1, skip1
    sw   a1, 0(s0)
    sw   a0, 4(s0)
skip1:

    # Compare 1 and 2
    lw   a0, 4(s0)
    lw   a1, 8(s0)
    blt  a0, a1, skip2
    sw   a1, 4(s0)
    sw   a0, 8(s0)
skip2:

    # Compare 2 and 3
    lw   a0, 8(s0)
    lw   a1, 12(s0)
    blt  a0, a1, skip3
    sw   a1, 8(s0)
    sw   a0, 12(s0)
skip3:

    # After pass 1, the maximum power (89 dBm) must have bubbled to word 3
    lw   s1, 12(s0)
    addi s2, x0, 89
    bne  s1, s2, fail

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
