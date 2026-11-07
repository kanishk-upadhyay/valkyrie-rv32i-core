`timescale 1ns / 1ps
// ============================================================================
// File: alu.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: 32-bit Arithmetic Logic Unit supporting all RV32I ALU operations.
// ============================================================================

module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] op_a,
    input  wire [31:0] op_b,
    output reg  [31:0] alu_out,
    output wire        zero
);

    localparam ALU_ADD    = 4'd0;
    localparam ALU_SUB    = 4'd1;
    localparam ALU_SLL    = 4'd2;
    localparam ALU_SLT    = 4'd3;
    localparam ALU_SLTU   = 4'd4;
    localparam ALU_XOR    = 4'd5;
    localparam ALU_SRL    = 4'd6;
    localparam ALU_SRA    = 4'd7;
    localparam ALU_OR     = 4'd8;
    localparam ALU_AND    = 4'd9;
    localparam ALU_PASS_B = 4'd10;

    always @(*) begin
        case (alu_op)
            ALU_ADD:    alu_out = op_a + op_b;
            ALU_SUB:    alu_out = op_a - op_b;
            ALU_SLL:    alu_out = op_a << op_b[4:0];
            ALU_SLT:    alu_out = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   alu_out = (op_a < op_b) ? 32'd1 : 32'd0;
            ALU_XOR:    alu_out = op_a ^ op_b;
            ALU_SRL:    alu_out = op_a >> op_b[4:0];
            ALU_SRA:    alu_out = $signed(op_a) >>> op_b[4:0];
            ALU_OR:     alu_out = op_a | op_b;
            ALU_AND:    alu_out = op_a & op_b;
            ALU_PASS_B: alu_out = op_b;
            default:    alu_out = 32'd0;
        endcase
    end

    assign zero = (alu_out == 32'd0);

endmodule
