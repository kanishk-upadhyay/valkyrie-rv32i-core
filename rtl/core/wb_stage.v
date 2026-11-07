`timescale 1ns / 1ps
// ============================================================================
// File: wb_stage.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Write-Back Stage multiplexing between ALU/EX result and memory
//              read data for register file commit.
// ============================================================================

module wb_stage (
    input  wire [31:0] ex_result_in,
    input  wire [31:0] mem_rdata_in,
    input  wire [4:0]  rd_in,
    input  wire        reg_write_in,
    input  wire [1:0]  wb_src_in,

    // Feedback to Register File (in ID stage) and Forwarding Unit
    output wire        wb_reg_write,
    output wire [4:0]  wb_rd,
    output wire [31:0] wb_data
);

    // wb_src: 2'b01 -> Memory data, otherwise -> ALU/EX result (including PC+4 for JAL/JALR)
    assign wb_data      = (wb_src_in == 2'b01) ? mem_rdata_in : ex_result_in;
    assign wb_reg_write = reg_write_in;
    assign wb_rd        = rd_in;

endmodule
