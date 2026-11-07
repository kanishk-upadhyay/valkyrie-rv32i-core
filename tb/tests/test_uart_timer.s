# Test 7: Tactical MMIO Peripherals (UART & Timer)
_start:
    lui  s0, 0x10000     # UART Base: 0x10000000
    lui  s1, 0x20000     # Timer Base: 0x20000000

    # Print 'V' (0x56)
    addi t0, x0, 86
    sw   t0, 0(s0)
    # Print 'A' (0x41)
    addi t0, x0, 65
    sw   t0, 0(s0)
    # Print 'L' (0x4C)
    addi t0, x0, 76
    sw   t0, 0(s0)
    # Print 'K' (0x4B)
    addi t0, x0, 75
    sw   t0, 0(s0)
    # Print '\n' (0x0A)
    addi t0, x0, 10
    sw   t0, 0(s0)

    # Read initial mtime counter
    lw   t1, 0(s1)

    # Spin loop to let timer advance
    addi t2, x0, 50
delay_loop:
    addi t2, t2, -1
    bne  t2, x0, delay_loop

    # Read second mtime counter
    lw   t3, 0(s1)

    # Verify t3 > t1 (timer advanced!)
    bltu t1, t3, timer_ok
    beq  x0, x0, fail
timer_ok:

    # Success
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
