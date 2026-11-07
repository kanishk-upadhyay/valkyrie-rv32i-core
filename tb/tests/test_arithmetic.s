# Test 1: Full RV32I Arithmetic & Logic
_start:
    # ADDI, ADD, SUB
    addi x1, x0, 15
    addi x2, x0, 25
    add  x3, x1, x2      # x3 = 40
    sub  x4, x2, x1      # x4 = 10
    
    # Check x3 == 40
    addi x5, x0, 40
    bne  x3, x5, fail
    # Check x4 == 10
    addi x5, x0, 10
    bne  x4, x5, fail

    # Shift operations
    slli x6, x1, 2       # 15 << 2 = 60
    addi x5, x0, 60
    bne  x6, x5, fail

    srli x7, x6, 1       # 60 >> 1 = 30
    addi x5, x0, 30
    bne  x7, x5, fail

    addi x8, x0, -16     # 0xFFFFFFF0
    srai x9, x8, 2       # -4 (0xFFFFFFFC)
    addi x5, x0, -4
    bne  x9, x5, fail

    # Bitwise: AND, OR, XOR
    andi x10, x1, 7      # 15 & 7 = 7
    addi x5, x0, 7
    bne  x10, x5, fail

    ori  x11, x1, 16     # 15 | 16 = 31
    addi x5, x0, 31
    bne  x11, x5, fail

    xori x12, x1, 15     # 15 ^ 15 = 0
    bne  x12, x0, fail

    # Set Less Than: SLT, SLTU, SLTI, SLTIU
    slti x13, x8, 0      # -16 < 0 -> 1
    addi x5, x0, 1
    bne  x13, x5, fail

    sltiu x14, x8, 10    # unsigned(-16) < 10 -> 0
    bne  x14, x0, fail

    slt  x15, x8, x1     # -16 < 15 -> 1
    addi x5, x0, 1
    bne  x15, x5, fail

    sltu x16, x8, x1     # unsigned(-16) < 15 -> 0
    bne  x16, x0, fail

    # Upper immediates: LUI, AUIPC
    lui  x17, 0x12345    # 0x12345000
    # auipc test
    auipc x18, 0x0       # current PC

    # Pass
    lui  x30, 0x30000    # Sim status address 0x30000000
    addi x31, x0, 1      # Status 1 = PASS
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

fail:
    lui  x30, 0x30000
    lui  x31, 0xDEADB    # Status 0xDEADBEEF
    ori  x31, x31, 0xEEF
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
