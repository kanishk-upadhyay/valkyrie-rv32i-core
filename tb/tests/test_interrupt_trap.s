# Test 13: Machine-Mode CSR, Asynchronous External Interrupt & Trap Return
_start:
    # 1. Initialize State Registers
    addi s1, x0, 0          # s1: Background work iteration counter
    addi s2, x0, 0          # s2: ISR execution marker
    addi s3, x0, 0          # s3: mcause saved in ISR
    addi s4, x0, 0          # s4: mepc saved in ISR

    # 2. Configure mtvec to point to trap_handler
    addi t0, x0, trap_handler
    csrw mtvec, t0

    # 3. Enable Machine External Interrupt in mie (MEIE = bit 11 = 0x800)
    addi t1, x0, 1
    slli t1, t1, 11
    csrw mie, t1

    # 4. Enable Global Interrupts in mstatus (MIE = bit 3 = 0x8)
    addi t2, x0, 8
    csrs mstatus, t2

    # 5. Assert External Interrupt via Memory-Mapped Peripheral
    # Write 1 to 0x10000008 (irq_inject_reg)
    lui  a0, 0x10000
    addi a1, x0, 1
    sw   a1, 8(a0)

    # 6. Background Task Loop (Preempted by Hardware Interrupt)
bg_loop:
    addi s1, s1, 1
    bne  s2, x0, check_results
    beq  x0, x0, bg_loop

# -----------------------------------------------------------------------------
# Interrupt Service Routine (ISR) / Trap Handler
# -----------------------------------------------------------------------------
trap_handler:
    # Save trap context
    csrr s3, mcause
    csrr s4, mepc

    # Clear external interrupt source at 0x10000008
    lui  a0, 0x10000
    sw   x0, 8(a0)

    # Set ISR execution marker
    addi s2, s2, 1

    # Return from interrupt trap
    mret

# -----------------------------------------------------------------------------
# Post-Interrupt Verification
# -----------------------------------------------------------------------------
check_results:
    # Verify ISR ran (s2 == 1)
    addi t5, x0, 1
    bne  s2, t5, fail

    # Verify mcause: External IRQ = 0x8000000B
    lui  t6, 0x80000
    addi t6, t6, 11
    bne  s3, t6, fail

    # Verify mepc within background loop range [bg_loop, trap_handler)
    addi t0, x0, bg_loop
    blt  s4, t0, fail
    addi t1, x0, trap_handler
    bge  s4, t1, fail

    # Verify background task ran
    blt  s1, t5, fail

    # Verify mstatus MIE restored to 1 (bit 3 == 8)
    csrr t2, mstatus
    andi t2, t2, 8
    addi t3, x0, 8
    bne  t2, t3, fail

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
