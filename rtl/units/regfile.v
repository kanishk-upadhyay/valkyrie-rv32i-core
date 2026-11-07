`timescale 1ns / 1ps
// ============================================================================
// File: regfile.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: 32x32-bit dual-read single-write register file with internal
//              bypass write-through logic and x0 hardwired to zero.
// ============================================================================

module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  raddr1,
    output wire [31:0] rdata1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata2,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire        wen
);

    reg [31:0] registers [0:31];
    integer i;

    // Asynchronous read with internal write-through bypass for same-cycle RAW hazard
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 :
                    (wen && (waddr == raddr1)) ? wdata : registers[raddr1];

    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 :
                    (wen && (waddr == raddr2)) ? wdata : registers[raddr2];

    // Synchronous write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else begin
            if (wen && (waddr != 5'd0)) begin
                registers[waddr] <= wdata;
            end
        end
    end

endmodule
