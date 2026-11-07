`timescale 1ns / 1ps
// ============================================================================
// File: tb_core.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Top-level verification testbench with 64KB dual-port RAM model,
//              memory-mapped tactical UART console monitor, real-time cycle counter,
//              and automated regression pass/fail checker.
// ============================================================================

module tb_core;

    // Simulation Parameters
    parameter CLK_PERIOD = 10; // 100 MHz clock
    parameter RAM_WORDS  = 16384; // 64 KB (16K x 32-bit)

    reg clk;
    reg rst_n;

    // Core Wires
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire        imem_req;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_wen;
    wire [3:0]  dmem_wmask;
    wire [31:0] dmem_rdata;
    wire        dmem_req;

    wire [31:0] retired_pc;
    wire        trap_ecall;
    wire        trap_ebreak;

    // Interrupt Lines
    wire        irq_external;
    wire        irq_timer;
    reg         ext_irq_pin;

    // SRAM Bus Wires
    wire [31:0] sram_iaddr;
    wire [31:0] sram_irdata;
    wire [31:0] sram_daddr;
    wire [31:0] sram_dwdata;
    wire        sram_dwen;
    wire [3:0]  sram_dwmask;
    wire [31:0] sram_drdata;

    // Wishbone Bus Wires
    wire [31:0] wb_adr;
    wire [31:0] wb_dat_o;
    wire [31:0] wb_dat_i = 32'd0;
    wire        wb_we;
    wire [3:0]  wb_sel;
    wire        wb_stb;
    wire        wb_cyc;
    wire        wb_ack = wb_cyc & wb_stb; // Single-cycle ACK slave

    // Peripheral Outputs
    wire        uart_tx_valid;
    wire [7:0]  uart_tx_data;
    wire        sim_halt;
    wire [31:0] sim_status;

    // Performance Monitoring Registers
    integer cycle_count;
    integer inst_retired_count;
    integer max_cycles;
    reg [256*8-1:0] hex_file;
    reg [256*8-1:0] vcd_file;

    // ------------------------------------------------------------------------
    // 1. Clock Generation
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ------------------------------------------------------------------------
    // 2. 64KB Unified On-Chip SRAM Model
    // ------------------------------------------------------------------------
    reg [31:0] ram [0:RAM_WORDS-1];
    integer idx;

    // Asynchronous / Combinational Reads
    wire [13:0] iword_idx = sram_iaddr[15:2];
    wire [13:0] dword_idx = sram_daddr[15:2];

    assign sram_irdata = (sram_iaddr < 32'h0001_0000) ? ram[iword_idx] : 32'd0;
    assign sram_drdata = (sram_daddr < 32'h0001_0000) ? ram[dword_idx] : 32'd0;

    // Synchronous Byte-Masked Writes
    always @(posedge clk) begin
        if (sram_dwen && (sram_daddr < 32'h0001_0000)) begin
            if (sram_dwmask[0]) ram[dword_idx][7:0]   <= sram_dwdata[7:0];
            if (sram_dwmask[1]) ram[dword_idx][15:8]  <= sram_dwdata[15:8];
            if (sram_dwmask[2]) ram[dword_idx][23:16] <= sram_dwdata[23:16];
            if (sram_dwmask[3]) ram[dword_idx][31:24] <= sram_dwdata[31:24];
        end
    end

    // ------------------------------------------------------------------------
    // 3. Core & Bus Adapter Instantiation
    // ------------------------------------------------------------------------
    rv32i_core #(
        .RESET_VECTOR (32'h0000_0000)
    ) u_core (
        .clk         (clk),
        .rst_n       (rst_n),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .imem_req    (imem_req),
        .dmem_addr   (dmem_addr),
        .dmem_wdata  (dmem_wdata),
        .dmem_wen    (dmem_wen),
        .dmem_wmask   (dmem_wmask),
        .dmem_rdata   (dmem_rdata),
        .dmem_req     (dmem_req),
        .irq_external (irq_external),
        .irq_timer    (irq_timer),
        .retired_pc   (retired_pc),
        .trap_ecall   (trap_ecall),
        .trap_ebreak  (trap_ebreak)
    );

    memory_bus_adapter u_bus_adapter (
        .clk             (clk),
        .rst_n           (rst_n),
        .core_imem_addr  (imem_addr),
        .core_imem_req   (imem_req),
        .core_imem_rdata (imem_rdata),
        .core_dmem_addr  (dmem_addr),
        .core_dmem_wdata (dmem_wdata),
        .core_dmem_wen   (dmem_wen),
        .core_dmem_wmask (dmem_wmask),
        .core_dmem_req   (dmem_req),
        .core_dmem_rdata (dmem_rdata),
        .sram_iaddr      (sram_iaddr),
        .sram_irdata     (sram_irdata),
        .sram_daddr      (sram_daddr),
        .sram_dwdata     (sram_dwdata),
        .sram_dwen       (sram_dwen),
        .sram_dwmask     (sram_dwmask),
        .sram_drdata     (sram_drdata),
        .wb_adr_o        (wb_adr),
        .wb_dat_o        (wb_dat_o),
        .wb_dat_i        (wb_dat_i),
        .wb_we_o         (wb_we),
        .wb_sel_o        (wb_sel),
        .wb_stb_o        (wb_stb),
        .wb_cyc_o        (wb_cyc),
        .wb_ack_i        (wb_ack),
        .uart_tx_valid   (uart_tx_valid),
        .uart_tx_data    (uart_tx_data),
        .sim_halt        (sim_halt),
        .sim_status      (sim_status),
        .ext_irq_pin     (ext_irq_pin),
        .irq_external    (irq_external),
        .irq_timer       (irq_timer)
    );

    // ------------------------------------------------------------------------
    // 4. Memory-Mapped UART Console Monitor
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && uart_tx_valid) begin
            $write("%c", uart_tx_data);
            $fflush(32'h8000_0001); // Flush stdout
        end
    end

    // ------------------------------------------------------------------------
    // 5. Instruction Retirement Tracker
    // ------------------------------------------------------------------------
    reg [31:0] prev_retired_pc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count        <= 0;
            inst_retired_count <= 0;
            prev_retired_pc    <= 32'hFFFF_FFFF;
        end else begin
            cycle_count <= cycle_count + 1;
            if (retired_pc != 32'd0 && retired_pc != prev_retired_pc) begin
                inst_retired_count <= inst_retired_count + 1;
                prev_retired_pc    <= retired_pc;
            end
        end
    end

    // ------------------------------------------------------------------------
    // 6. Testbench Control & Automated Verification Loop
    // ------------------------------------------------------------------------
    initial begin
        // Default Configuration
        max_cycles  = 100000;
        hex_file    = "";
        vcd_file    = "";
        ext_irq_pin = 0;

        // Parse command line plusargs
        if ($value$plusargs("HEX=%s", hex_file)) begin
            $display("[TB] Loading Memory Image: %0s", hex_file);
        end else begin
            hex_file = "tests/test_arithmetic.hex";
            $display("[TB] Defaulting to Memory Image: %0s", hex_file);
        end

        if ($value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
            $display("[TB] Max Simulation Cycles: %0d", max_cycles);
        end

        // Initialize RAM to zero
        for (idx = 0; idx < RAM_WORDS; idx = idx + 1) begin
            ram[idx] = 32'd0;
        end

        // Load Program Binary Hex
        $readmemh(hex_file, ram);

        // Waveform Dump Setup
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $display("[TB] VCD Waveform dump enabled: %0s", vcd_file);
            $dumpfile(vcd_file);
            $dumpvars(0, tb_core);
        end else if ($test$plusargs("VCD")) begin
            vcd_file = "valkyrie_sim.vcd";
            $display("[TB] VCD Waveform dump enabled: %0s", vcd_file);
            $dumpfile(vcd_file);
            $dumpvars(0, tb_core);
        end

        // Reset Sequence
        rst_n = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;

        // Monitor Simulation Execution
        fork
            // Thread 1: Wait for explicit halt via peripheral control
            begin
                wait (sim_halt == 1'b1);
                #(CLK_PERIOD * 2);
                print_summary(sim_status == 32'h0000_0001 || sim_status == 32'd0);
                $finish;
            end

            // Thread 2: Wait for ECALL or EBREAK trap
            begin
                wait (trap_ecall || trap_ebreak);
                #(CLK_PERIOD * 2);
                $display("\n[TB] Trap Encounted (ECALL/EBREAK) at PC: 0x%08X", retired_pc);
                print_summary(1);
                $finish;
            end

            // Thread 3: Safety Watchdog Timeout
            begin
                wait (cycle_count >= max_cycles);
                $display("\n[TB] ERROR: Simulation timed out after %0d cycles!", max_cycles);
                print_summary(0);
                $finish;
            end
        join
    end

    // ------------------------------------------------------------------------
    // Summary Reporter Task
    // ------------------------------------------------------------------------
    task print_summary;
        input integer passed;
        real cpi;
        real ipc;
        begin
            if (inst_retired_count > 0) begin
                cpi = cycle_count * 1.0 / inst_retired_count;
                ipc = inst_retired_count * 1.0 / cycle_count;
            end else begin
                cpi = 0.0;
                ipc = 0.0;
            end

            $display("\n============================================================");
            $display("   VALKYRIE-RV32I CORE VERIFICATION REPORT");
            $display("   Organization: Indian Army DG Signals / AICTE");
            $display("============================================================");
            if (passed) begin
                $display("   RESULT:             >>> [PASSED] <<<");
                $display("   Status Code:        0x%08X", sim_status);
            end else begin
                $display("   RESULT:             >>> [FAILED] <<<");
                $display("   Status Code:        0x%08X", sim_status);
            end
            $display("   Cycles Elapsed:     %0d", cycle_count);
            $display("   Instructions Ret:   %0d", inst_retired_count);
            $display("   CPI:                %0.2f", cpi);
            $display("   IPC:                %0.2f", ipc);
            $display("============================================================\n");
        end
    endtask

endmodule
