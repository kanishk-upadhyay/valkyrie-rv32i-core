# Test 20: Machine-Mode Synchronous Trap (ECALL)
_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    ecall
    beq  x0, x0, _start
