`timescale 1ns / 1ps
// ============================================================================
// File: forwarding_unit.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Data Forwarding Unit resolving RAW (Read-After-Write) data hazards
//              via EX-to-EX and MEM-to-EX forwarding paths.
// ============================================================================

module forwarding_unit (
    input  wire [4:0] rs1_ex,
    input  wire [4:0] rs2_ex,
    input  wire [4:0] rd_mem,
    input  wire       reg_write_mem,
    input  wire [4:0] rd_wb,
    input  wire       reg_write_wb,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    // Forwarding codes:
    // 2'b00: No forwarding (use ID/EX register data)
    // 2'b10: Forward from EX/MEM stage (alu_result_mem)
    // 2'b01: Forward from MEM/WB stage (wb_data)

    always @(*) begin
        // Forwarding logic for RS1 operand
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs1_ex)) begin
            forward_a = 2'b10; // Priority: EX/MEM stage
        end else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs1_ex)) begin
            forward_a = 2'b01; // MEM/WB stage
        end else begin
            forward_a = 2'b00; // No forwarding
        end

        // Forwarding logic for RS2 operand
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs2_ex)) begin
            forward_b = 2'b10; // Priority: EX/MEM stage
        end else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs2_ex)) begin
            forward_b = 2'b01; // MEM/WB stage
        end else begin
            forward_b = 2'b00; // No forwarding
        end
    end

endmodule
