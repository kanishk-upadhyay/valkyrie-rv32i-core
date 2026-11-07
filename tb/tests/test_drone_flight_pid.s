# Test 9: Autonomous Drone Quadcopter Flight Control (PID Loop)
_start:
    lui  s0, 0x00001     # Base buffer at 0x1000
    addi t0, x0, 1000    # Target setpoint: 1000 (10.00 deg)
    addi t1, x0, 850     # Measured IMU gyro: 850 (8.50 deg)
    addi t2, x0, 50      # Prev integral error sum: 50
    addi t3, x0, 100     # Prev error: 100

    # Error: e = setpoint - sensor = 150
    sub  t4, t0, t1

    # P_term = Kp * e (Kp = 4)
    slli s1, t4, 2       # 150 << 2 = 600

    # I_term = (prev_integral + e) * Ki (Ki = 1)
    add  s2, t2, t4      # 50 + 150 = 200

    # D_term = (e - prev_error) * Kd (Kd = 2)
    sub  s3, t4, t3      # 150 - 100 = 50
    slli s3, s3, 1       # 50 << 1 = 100

    # Total motor thrust correction = P + I + D
    add  s4, s1, s2      # 600 + 200 = 800
    add  s4, s4, s3      # 800 + 100 = 900

    # Store motor command to memory
    sw   s4, 0(s0)
    lw   s5, 0(s0)

    # Verify motor command == 900
    addi s6, x0, 900
    bne  s5, s6, fail

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
