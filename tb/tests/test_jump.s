# Test 3: Unconditional Jumps & Subroutines
_start:
    addi s1, x0, 0       # Call counter (use s1 so ra/x1 is preserved for link)

    # Call sub1 with JAL
    jal  ra, sub1
    # Check that return was reached and s1 == 1
    addi x5, x0, 1
    bne  s1, x5, fail

    # Call sub2 with JAL
    jal  ra, sub2
    addi x5, x0, 3
    bne  s1, x5, fail

    # Call sub3
    jal  ra, sub3
    addi x5, x0, 7
    bne  s1, x5, fail

    # Success
    lui  x30, 0x30000
    addi x31, x0, 1
    sw   x31, 0(x30)
halt:
    beq  x0, x0, halt

sub1:
    addi s1, s1, 1       # s1 = 1
    jalr x0, ra, 0       # Return to caller

sub2:
    addi s1, s1, 2       # s1 = 3
    jalr x0, ra, 0       # Return to caller

sub3:
    addi s1, s1, 4       # s1 = 7
    jalr x0, ra, 0       # Return to caller

fail:
    lui  x30, 0x30000
    addi x31, x0, 0      # 0 = FAIL
    sw   x31, 0(x30)
fail_loop:
    beq  x0, x0, fail_loop
