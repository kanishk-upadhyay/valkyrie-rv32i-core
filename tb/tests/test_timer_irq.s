# Test 18: Real-Time Hardware Timer Interrupt Preemption
_start:
    lui  t0, 0x00000
    ori  t0, t0, timer_isr
    csrw mtvec, t0

    addi s0, x0, 0
    addi s1, x0, 0

    # Read current mtime
    lui  t1, 0x20000
    lw   t2, 0(t1)

    # Set mtimecmp = mtime + 30
    addi t2, t2, 30
    sw   t2, 8(t1)

    # Enable MTIE (bit 7 = 0x80)
    addi t3, x0, 128
    csrw mie, t3

    # Enable global interrupts: set MIE (bit 3 = 0x08)
    addi t3, x0, 8
    csrs mstatus, t3

work_loop:
    addi s0, s0, 1
    bne  s1, x0, test_done
    addi t4, x0, 500
    blt  s0, t4, work_loop

    # Timed out waiting for ISR
    beq  x0, x0, fail

timer_isr:
    addi s1, x0, 1

    # Disable timer condition: mtimecmp = 0xFFFFFFFF
    lui  t1, 0x20000
    lui  t2, 0xFFFFF
    ori  t2, t2, 0xFFF
    sw   t2, 8(t1)

    # Disable MTIE
    csrw mie, x0

    mret

test_done:
    addi t5, x0, 5
    blt  s0, t5, fail

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
