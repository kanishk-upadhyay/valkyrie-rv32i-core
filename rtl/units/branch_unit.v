`timescale 1ns / 1ps
// ============================================================================
// File: branch_unit.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Branch comparator & control evaluator for RV32I conditional 
//              branches (BEQ, BNE, BLT, BGE, BLTU, BGEU) and unconditional jumps.
// ============================================================================

module branch_unit (
    input  wire [2:0]  branch_op,      // funct3 [14:12]
    input  wire        is_branch,      // Asserted for B-type instructions
    input  wire        is_jal,         // Asserted for JAL instruction
    input  wire        is_jalr,        // Asserted for JALR instruction
    input  wire [31:0] op_a,           // Forwarded RS1 operand
    input  wire [31:0] op_b,           // Forwarded RS2 operand
    output wire        branch_taken
);

    localparam BR_BEQ  = 3'b000;
    localparam BR_BNE  = 3'b001;
    localparam BR_BLT  = 3'b100;
    localparam BR_BGE  = 3'b101;
    localparam BR_BLTU = 3'b110;
    localparam BR_BGEU = 3'b111;

    reg branch_cond_met;

    always @(*) begin
        case (branch_op)
            BR_BEQ:  branch_cond_met = (op_a == op_b);
            BR_BNE:  branch_cond_met = (op_a != op_b);
            BR_BLT:  branch_cond_met = ($signed(op_a) < $signed(op_b));
            BR_BGE:  branch_cond_met = ($signed(op_a) >= $signed(op_b));
            BR_BLTU: branch_cond_met = (op_a < op_b);
            BR_BGEU: branch_cond_met = (op_a >= op_b);
            default: branch_cond_met = 1'b0;
        endcase
    end

    assign branch_taken = is_jal | is_jalr | (is_branch & branch_cond_met);

endmodule
