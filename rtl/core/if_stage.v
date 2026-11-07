`timescale 1ns / 1ps
// ============================================================================
// File: if_stage.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Instruction Fetch Stage featuring Program Counter (PC), PC+4 
//              generator, and branch/jump target multiplexer.
// ============================================================================

module if_stage #(
    parameter RESET_VECTOR = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall_pc,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    output wire [31:0] pc_out,
    output wire [31:0] pc_plus4_out
);

    reg [31:0] pc_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= RESET_VECTOR;
        end else if (branch_taken) begin
            pc_reg <= branch_target;
        end else if (!stall_pc) begin
            pc_reg <= pc_reg + 32'd4;
        end
    end

    assign pc_out       = pc_reg;
    assign pc_plus4_out = pc_reg + 32'd4;

endmodule
