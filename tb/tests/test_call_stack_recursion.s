# Test 17: Call Stack & Recursive Fibonacci
_start:
    lui  sp, 0x00002
    addi sp, sp, 0x000
    addi a0, x0, 7          # fib(7)
    jal  ra, fib
    addi t0, x0, 13         # Expected fib(7) = 13
    bne  a0, t0, fail

    addi a0, x0, 6          # fib(6)
    jal  ra, fib
    addi t0, x0, 8          # Expected fib(6) = 8
    bne  a0, t0, fail

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

fib:
    addi t0, x0, 1
    bge  t0, a0, fib_base

    # Prologue: allocate 16-byte stack frame
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    add  s0, a0, x0

    # Call fib(n-1)
    addi a0, s0, -1
    jal  ra, fib
    add  s1, a0, x0

    # Call fib(n-2)
    addi a0, s0, -2
    jal  ra, fib

    # Result = fib(n-1) + fib(n-2)
    add  a0, s1, a0

    # Epilogue: restore stack frame
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    jalr x0, ra, 0

fib_base:
    jalr x0, ra, 0
