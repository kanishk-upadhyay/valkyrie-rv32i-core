# Test 5: Back-to-Back RAW Data Forwarding
_start:
    # EX-to-EX forwarding (distance 1)
    addi x1, x0, 10
    addi x2, x1, 20      # x1 forwarded from EX: x2 = 30
    addi s2, x0, 30
    bne  x2, s2, fail

    # MEM-to-EX forwarding (distance 2)
    addi x3, x0, 100
    addi x0, x0, 0       # 1 bubble / independent inst
    addi x4, x3, 50      # x3 forwarded from MEM: x4 = 150
    addi s3, x0, 150
    bne  x4, s3, fail

    # Dual forwarding: both operands forwarded in same cycle
    addi x5, x0, 5
    addi x6, x0, 7
    add  x7, x5, x6      # x5 forwarded from MEM, x6 forwarded from EX: x7 = 12
    addi s4, x0, 12
    bne  x7, s4, fail

    # Consecutive accumulator chain (EX-to-EX stress test)
    addi x8, x0, 1
    add  x8, x8, x8      # 2
    add  x8, x8, x8      # 4
    add  x8, x8, x8      # 8
    add  x8, x8, x8      # 16
    add  x8, x8, x8      # 32
    addi s5, x0, 32
    bne  x8, s5, fail

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
