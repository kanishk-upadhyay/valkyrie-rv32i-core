`timescale 1ns / 1ps
// ============================================================================
// File: ex_stage.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Execution Stage featuring 32-bit ALU, Branch Comparator Unit,
//              operand forwarding multiplexers, and branch target calculator.
// ============================================================================

module ex_stage (
    input  wire [31:0] pc_ex,
    input  wire [31:0] pc_plus4_ex,
    input  wire [31:0] reg_rdata1_ex,
    input  wire [31:0] reg_rdata2_ex,
    input  wire [31:0] imm_ex,
    input  wire [4:0]  rd_ex,
    input  wire [2:0]  funct3_ex,

    // Control signals from ID/EX
    input  wire [3:0]  alu_op_ex,
    input  wire        alu_src_a_ex,
    input  wire        alu_src_b_ex,
    input  wire        mem_read_ex,
    input  wire        mem_write_ex,
    input  wire        reg_write_ex,
    input  wire [1:0]  wb_src_ex,
    input  wire        is_branch_ex,
    input  wire        is_jal_ex,
    input  wire        is_jalr_ex,

    // Forwarding inputs
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,
    input  wire [31:0] ex_result_mem,
    input  wire [31:0] wb_data,

    // Outputs to EX/MEM pipeline register
    output wire [31:0] ex_result,
    output wire [31:0] mem_wdata_ex,
    output wire [4:0]  rd_out,
    output wire [2:0]  funct3_out,
    output wire        mem_read_out,
    output wire        mem_write_out,
    output wire        reg_write_out,
    output wire [1:0]  wb_src_out,

    // Branch feedback to IF stage & Hazard Unit
    output wire        branch_taken,
    output wire [31:0] branch_target
);

    reg [31:0] forwarded_a;
    reg [31:0] forwarded_b;

    // Operand A Forwarding Mux
    always @(*) begin
        case (forward_a)
            2'b10:   forwarded_a = ex_result_mem; // From EX/MEM
            2'b01:   forwarded_a = wb_data;       // From MEM/WB
            default: forwarded_a = reg_rdata1_ex; // From ID/EX
        endcase
    end

    // Operand B Forwarding Mux
    always @(*) begin
        case (forward_b)
            2'b10:   forwarded_b = ex_result_mem; // From EX/MEM
            2'b01:   forwarded_b = wb_data;       // From MEM/WB
            default: forwarded_b = reg_rdata2_ex; // From ID/EX
        endcase
    end

    // ALU Input Selectors
    wire [31:0] alu_in_a = alu_src_a_ex ? pc_ex : forwarded_a;
    wire [31:0] alu_in_b = alu_src_b_ex ? imm_ex : forwarded_b;
    wire [31:0] alu_out;
    wire        alu_zero;

    // Instantiate 32-bit ALU
    alu u_alu (
        .alu_op  (alu_op_ex),
        .op_a    (alu_in_a),
        .op_b    (alu_in_b),
        .alu_out (alu_out),
        .zero    (alu_zero)
    );

    // Instantiate Branch Unit
    branch_unit u_branch_unit (
        .branch_op    (funct3_ex),
        .is_branch    (is_branch_ex),
        .is_jal       (is_jal_ex),
        .is_jalr      (is_jalr_ex),
        .op_a         (forwarded_a),
        .op_b         (forwarded_b),
        .branch_taken (branch_taken)
    );

    // Branch / Jump Target Address Computation
    // JALR: (rs1 + imm) & ~1
    // JAL / Branch: pc + imm
    assign branch_target = is_jalr_ex ? ((forwarded_a + imm_ex) & ~32'h0000_0001) :
                                        (pc_ex + imm_ex);

    // Write-back result selection for EX stage:
    // For JAL/JALR, return address PC+4 is saved; otherwise ALU result
    assign ex_result     = (wb_src_ex == 2'b10) ? pc_plus4_ex : alu_out;
    assign mem_wdata_ex  = forwarded_b;
    assign rd_out        = rd_ex;
    assign funct3_out    = funct3_ex;
    assign mem_read_out  = mem_read_ex;
    assign mem_write_out = mem_write_ex;
    assign reg_write_out = reg_write_ex;
    assign wb_src_out    = wb_src_ex;

endmodule
