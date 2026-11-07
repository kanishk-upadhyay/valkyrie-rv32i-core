`timescale 1ns / 1ps
// ============================================================================
// File: hazard_unit.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Pipeline Hazard Detection Unit resolving Load-Use data hazards 
//              via 1-cycle stall bubbles and branch misprediction flushes.
// ============================================================================

module hazard_unit (
    input  wire [4:0] rs1_id,
    input  wire [4:0] rs2_id,
    input  wire       uses_rs1_id,
    input  wire       uses_rs2_id,
    input  wire [4:0] rd_ex,
    input  wire       mem_read_ex,
    input  wire       branch_taken_ex,
    output wire       stall_pc,
    output wire       stall_if_id,
    output wire       flush_if_id,
    output wire       flush_id_ex
);

    // Load-Use Hazard Condition:
    // If the instruction in EX is a Load (mem_read_ex == 1)
    // and its destination register rd_ex matches rs1 or rs2 of the instruction in ID
    // (provided the instruction in ID actually reads that register and rd_ex != x0),
    // stall the pipeline for 1 clock cycle to allow load data to return.
    wire load_use_hazard;

    assign load_use_hazard = mem_read_ex && (rd_ex != 5'd0) &&
                             ((uses_rs1_id && (rd_ex == rs1_id)) ||
                              (uses_rs2_id && (rd_ex == rs2_id)));

    // Pipeline control assignments:
    // - On load-use stall: freeze PC, freeze IF/ID, and insert bubble into ID/EX
    assign stall_pc    = load_use_hazard;
    assign stall_if_id = load_use_hazard;

    // - On taken branch: flush instructions in IF/ID and ID/EX
    // - On load-use hazard: flush ID/EX (inject bubble)
    assign flush_if_id = branch_taken_ex;
    assign flush_id_ex = branch_taken_ex || load_use_hazard;

endmodule
