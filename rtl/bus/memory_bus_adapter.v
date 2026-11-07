`timescale 1ns / 1ps
// ============================================================================
// File: memory_bus_adapter.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Unified Memory Bus Adapter with Wishbone Master interface and
//              memory-mapped tactical peripherals:
//              - 0x0000_0000 - 0x0FFF_FFFF: On-Chip SRAM (Instruction & Data)
//              - 0x1000_0000: Memory-Mapped Tactical UART (TX Data & Status)
//              - 0x2000_0000: 64-bit Hardware Real-Time Timer (mtime/mtimeh)
//              - 0x3000_0000: Mission Execution Status / Sim Halt Control
//              - 0x4000_0000+: Wishbone External Peripheral Bus
// ============================================================================

module memory_bus_adapter (
    input  wire        clk,
    input  wire        rst_n,

    // Core Instruction Memory Bus
    input  wire [31:0] core_imem_addr,
    input  wire        core_imem_req,
    output wire [31:0] core_imem_rdata,

    // Core Data Memory Bus
    input  wire [31:0] core_dmem_addr,
    input  wire [31:0] core_dmem_wdata,
    input  wire        core_dmem_wen,
    input  wire [3:0]  core_dmem_wmask,
    input  wire        core_dmem_req,
    output reg  [31:0] core_dmem_rdata,

    // On-Chip SRAM Interface
    output wire [31:0] sram_iaddr,
    input  wire [31:0] sram_irdata,
    output wire [31:0] sram_daddr,
    output wire [31:0] sram_dwdata,
    output wire        sram_dwen,
    output wire [3:0]  sram_dwmask,
    input  wire [31:0] sram_drdata,

    // Wishbone Master Interface (for off-chip expansion / IP blocks)
    output reg  [31:0] wb_adr_o,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    output reg         wb_we_o,
    output reg  [3:0]  wb_sel_o,
    output reg         wb_stb_o,
    output reg         wb_cyc_o,
    input  wire        wb_ack_i,

    // Peripheral Hardware Outputs
    output reg         uart_tx_valid,
    output reg  [7:0]  uart_tx_data,
    output reg         sim_halt,
    output reg  [31:0] sim_status
);

    // Hardware Signature: "VALK" (0x56414C4B)
    localparam CORE_SIGNATURE = 32'h5641_4C4B;

    // Address Decoding Ranges
    wire is_sram_access = (core_dmem_addr < 32'h1000_0000);
    wire is_uart_data   = (core_dmem_addr == 32'h1000_0000);
    wire is_uart_status = (core_dmem_addr == 32'h1000_0004);
    wire is_mtime_low   = (core_dmem_addr == 32'h2000_0000);
    wire is_mtime_high  = (core_dmem_addr == 32'h2000_0004);
    wire is_sim_ctrl    = (core_dmem_addr == 32'h3000_0000);
    wire is_wb_access   = (core_dmem_addr >= 32'h4000_0000);

    // ------------------------------------------------------------------------
    // 1. Instruction Memory SRAM Connection
    // ------------------------------------------------------------------------
    assign sram_iaddr       = core_imem_addr;
    assign core_imem_rdata  = sram_irdata;

    // ------------------------------------------------------------------------
    // 2. Data Memory SRAM Routing
    // ------------------------------------------------------------------------
    assign sram_daddr  = core_dmem_addr;
    assign sram_dwdata = core_dmem_wdata;
    assign sram_dwen   = core_dmem_wen && is_sram_access;
    assign sram_dwmask = core_dmem_wmask;

    // ------------------------------------------------------------------------
    // 3. 64-bit Hardware Real-Time Tactical Timer
    // ------------------------------------------------------------------------
    reg [63:0] mtime_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime_counter <= 64'd0;
        end else begin
            mtime_counter <= mtime_counter + 64'd1;
        end
    end

    // ------------------------------------------------------------------------
    // 4. Peripheral Control & Register Writes
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_valid <= 1'b0;
            uart_tx_data  <= 8'd0;
            sim_halt      <= 1'b0;
            sim_status    <= 32'd0;
        end else begin
            uart_tx_valid <= 1'b0; // Single-cycle strobe

            if (core_dmem_wen && core_dmem_req) begin
                if (is_uart_data) begin
                    uart_tx_valid <= 1'b1;
                    uart_tx_data  <= core_dmem_wdata[7:0];
                end else if (is_sim_ctrl) begin
                    sim_halt   <= 1'b1;
                    sim_status <= core_dmem_wdata;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // 5. Data Read Multiplexer
    // ------------------------------------------------------------------------
    always @(*) begin
        if (is_sram_access) begin
            core_dmem_rdata = sram_drdata;
        end else if (is_uart_data) begin
            core_dmem_rdata = 32'd0;
        end else if (is_uart_status) begin
            core_dmem_rdata = 32'h0000_0001; // Bit 0: TX Ready
        end else if (is_mtime_low) begin
            core_dmem_rdata = mtime_counter[31:0];
        end else if (is_mtime_high) begin
            core_dmem_rdata = mtime_counter[63:32];
        end else if (is_sim_ctrl) begin
            core_dmem_rdata = CORE_SIGNATURE;
        end else if (is_wb_access) begin
            core_dmem_rdata = wb_dat_i;
        end else begin
            core_dmem_rdata = 32'd0;
        end
    end

    // ------------------------------------------------------------------------
    // 6. Wishbone Bus Interface
    // ------------------------------------------------------------------------
    always @(*) begin
        if (is_wb_access && core_dmem_req) begin
            wb_adr_o = core_dmem_addr;
            wb_dat_o = core_dmem_wdata;
            wb_we_o  = core_dmem_wen;
            wb_sel_o = core_dmem_wmask;
            wb_stb_o = 1'b1;
            wb_cyc_o = 1'b1;
        end else begin
            wb_adr_o = 32'd0;
            wb_dat_o = 32'd0;
            wb_we_o  = 1'b0;
            wb_sel_o = 4'b0000;
            wb_stb_o = 1'b0;
            wb_cyc_o = 1'b0;
        end
    end

endmodule
