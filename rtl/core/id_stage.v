`timescale 1ns / 1ps
// ============================================================================
// File: id_stage.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Instruction Decode Stage containing 32x32 Register File,
//              Immediate Generator, and Central Control Unit.
// ============================================================================

module id_stage (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] inst_in,
    input  wire [31:0] pc_in,
    input  wire [31:0] pc_plus4_in,

    // Write-back interface from WB stage
    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd,
    input  wire [31:0] wb_data,

    // Decoded fields & operands
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [4:0]  rd_addr,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [31:0] imm_out,
    output wire [31:0] reg_rdata1,
    output wire [31:0] reg_rdata2,
    output wire [31:0] pc_out,
    output wire [31:0] pc_plus4_out,

    // Control signals for Execute stage
    output reg  [3:0]  alu_op,
    output reg         alu_src_a,      // 0: RS1, 1: PC
    output reg         alu_src_b,      // 0: RS2, 1: Immediate
    output reg         mem_read,
    output reg         mem_write,
    output reg         reg_write,
    output reg  [1:0]  wb_src,         // 00: ALU, 01: MEM, 10: PC+4
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg         uses_rs1,
    output reg         uses_rs2,
    output wire        is_ecall,
    output wire        is_ebreak,
    output reg         is_csr,
    output reg         is_mret,
    output wire [11:0] csr_addr,
    output wire [2:0]  csr_op,
    output wire [4:0]  csr_rs1,
    output wire [4:0]  csr_zimm
);

    // ALU Operation Codes
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

    // RV32I Primary Opcodes
    localparam OPC_R_TYPE   = 7'b0110011;
    localparam OPC_I_ARITH  = 7'b0010011;
    localparam OPC_LOAD     = 7'b0000011;
    localparam OPC_STORE    = 7'b0100011;
    localparam OPC_BRANCH   = 7'b1100011;
    localparam OPC_JAL      = 7'b1101111;
    localparam OPC_JALR     = 7'b1100111;
    localparam OPC_LUI      = 7'b0110111;
    localparam OPC_AUIPC    = 7'b0010111;
    localparam OPC_SYSTEM   = 7'b1110011;
    localparam OPC_FENCE    = 7'b0001111;

    // Extract instruction slices
    wire [6:0] opcode = inst_in[6:0];
    assign rd_addr    = inst_in[11:7];
    assign funct3     = inst_in[14:12];
    assign rs1_addr   = inst_in[19:15];
    assign rs2_addr   = inst_in[24:20];
    assign funct7     = inst_in[31:25];

    assign csr_addr   = inst_in[31:20];
    assign csr_op     = inst_in[14:12];
    assign csr_rs1    = inst_in[19:15];
    assign csr_zimm   = inst_in[19:15];

    assign pc_out       = pc_in;
    assign pc_plus4_out = pc_plus4_in;

    // Immediate generation for all RV32I formats
    wire [31:0] imm_i = {{20{inst_in[31]}}, inst_in[31:20]};
    wire [31:0] imm_s = {{20{inst_in[31]}}, inst_in[31:25], inst_in[11:7]};
    wire [31:0] imm_b = {{19{inst_in[31]}}, inst_in[31], inst_in[7], inst_in[30:25], inst_in[11:8], 1'b0};
    wire [31:0] imm_u = {inst_in[31:12], 12'b0};
    wire [31:0] imm_j = {{11{inst_in[31]}}, inst_in[31], inst_in[19:12], inst_in[20], inst_in[30:21], 1'b0};

    reg [31:0] imm_selected;
    always @(*) begin
        case (opcode)
            OPC_I_ARITH,
            OPC_LOAD,
            OPC_JALR:   imm_selected = imm_i;
            OPC_STORE:  imm_selected = imm_s;
            OPC_BRANCH: imm_selected = imm_b;
            OPC_LUI,
            OPC_AUIPC:  imm_selected = imm_u;
            OPC_JAL:    imm_selected = imm_j;
            OPC_SYSTEM: imm_selected = {27'd0, inst_in[19:15]};
            default:    imm_selected = 32'd0;
        endcase
    end
    assign imm_out = imm_selected;

    // System instruction decoding
    assign is_ecall  = (opcode == OPC_SYSTEM) && (inst_in[31:20] == 12'h000);
    assign is_ebreak = (opcode == OPC_SYSTEM) && (inst_in[31:20] == 12'h001);

    // Control Unit Decoder
    always @(*) begin
        // Safe default assignments
        alu_op    = ALU_ADD;
        alu_src_a = 1'b0;
        alu_src_b = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        wb_src    = 2'b00; // ALU
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;
        uses_rs1  = 1'b0;
        uses_rs2  = 1'b0;
        is_csr    = 1'b0;
        is_mret   = 1'b0;

        case (opcode)
            OPC_R_TYPE: begin
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                alu_src_a = 1'b0; // RS1
                alu_src_b = 1'b0; // RS2
                wb_src    = 2'b00; // ALU
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPC_I_ARITH: begin
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b0;
                alu_src_a = 1'b0; // RS1
                alu_src_b = 1'b1; // Immediate
                wb_src    = 2'b00; // ALU
                case (funct3)
                    3'b000: alu_op = ALU_ADD; // ADDI
                    3'b010: alu_op = ALU_SLT; // SLTI
                    3'b011: alu_op = ALU_SLTU;// SLTIU
                    3'b100: alu_op = ALU_XOR; // XORI
                    3'b110: alu_op = ALU_OR;  // ORI
                    3'b111: alu_op = ALU_AND; // ANDI
                    3'b001: alu_op = ALU_SLL; // SLLI
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI / SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPC_LOAD: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b0;
                alu_src_a = 1'b0; // RS1
                alu_src_b = 1'b1; // Immediate offset
                alu_op    = ALU_ADD;
                wb_src    = 2'b01; // MEM
            end

            OPC_STORE: begin
                mem_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                alu_src_a = 1'b0; // RS1
                alu_src_b = 1'b1; // Immediate offset
                alu_op    = ALU_ADD;
            end

            OPC_BRANCH: begin
                is_branch = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                alu_src_a = 1'b0;
                alu_src_b = 1'b0;
                alu_op    = ALU_SUB;
            end

            OPC_JAL: begin
                is_jal    = 1'b1;
                reg_write = 1'b1;
                wb_src    = 2'b10; // PC+4
            end

            OPC_JALR: begin
                is_jalr   = 1'b1;
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                wb_src    = 2'b10; // PC+4
            end

            OPC_LUI: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1; // Immediate
                alu_op    = ALU_PASS_B;
                wb_src    = 2'b00; // ALU result
            end

            OPC_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = 1'b1; // PC
                alu_src_b = 1'b1; // Immediate
                alu_op    = ALU_ADD;
                wb_src    = 2'b00; // ALU result
            end

            OPC_SYSTEM: begin
                if (funct3 != 3'b000) begin
                    // CSR Instructions: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
                    is_csr    = 1'b1;
                    reg_write = 1'b1;
                    wb_src    = 2'b00; // From EX stage (CSR rdata)
                    uses_rs1  = !funct3[2]; // Register variants use RS1
                    uses_rs2  = 1'b0;
                end else if (inst_in[31:20] == 12'h302) begin
                    // MRET: Return from machine trap
                    is_mret   = 1'b1;
                end
            end

            OPC_FENCE: begin
                // Safe NOP execution in-pipeline
            end

            default: begin
                // Safe default NOP
            end
        endcase
    end

    // Instantiate 32x32 Register File
    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .raddr1 (rs1_addr),
        .rdata1 (reg_rdata1),
        .raddr2 (rs2_addr),
        .rdata2 (reg_rdata2),
        .waddr  (wb_rd),
        .wdata  (wb_data),
        .wen    (wb_reg_write)
    );

endmodule
