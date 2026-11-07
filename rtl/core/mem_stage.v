`timescale 1ns / 1ps
// ============================================================================
// File: mem_stage.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Data Memory Stage providing load/store byte-alignment, 
//              sign/zero extension (LB, LH, LW, LBU, LHU, SB, SH, SW), and 
//              bus request framing.
// ============================================================================

module mem_stage (
    input  wire [31:0] alu_result_in,
    input  wire [31:0] mem_wdata_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        reg_write_in,
    input  wire [1:0]  wb_src_in,

    // Memory bus physical signals
    input  wire [31:0] dmem_rdata,
    output wire [31:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    output wire        dmem_wen,
    output reg  [3:0]  dmem_wmask,
    output wire        dmem_req,

    // Outputs to MEM/WB pipeline register
    output wire [31:0] ex_result_out,
    output reg  [31:0] mem_rdata_out,
    output wire [4:0]  rd_out,
    output wire        reg_write_out,
    output wire [1:0]  wb_src_out
);

    wire [1:0] byte_offset = alu_result_in[1:0];

    assign dmem_addr     = alu_result_in;
    assign dmem_wen      = mem_write_in;
    assign dmem_req      = mem_read_in | mem_write_in;
    assign ex_result_out = alu_result_in;
    assign rd_out        = rd_in;
    assign reg_write_out = reg_write_in;
    assign wb_src_out    = wb_src_in;

    // Store Data Alignment & Byte Mask Generator
    always @(*) begin
        case (funct3_in)
            3'b000: begin // SB - Store Byte
                case (byte_offset)
                    2'b00: begin
                        dmem_wmask = 4'b0001;
                        dmem_wdata = {24'd0, mem_wdata_in[7:0]};
                    end
                    2'b01: begin
                        dmem_wmask = 4'b0010;
                        dmem_wdata = {16'd0, mem_wdata_in[7:0], 8'd0};
                    end
                    2'b10: begin
                        dmem_wmask = 4'b0100;
                        dmem_wdata = {8'd0, mem_wdata_in[7:0], 16'd0};
                    end
                    2'b11: begin
                        dmem_wmask = 4'b1000;
                        dmem_wdata = {mem_wdata_in[7:0], 24'd0};
                    end
                endcase
            end

            3'b001: begin // SH - Store Halfword
                if (byte_offset[1]) begin
                    dmem_wmask = 4'b1100;
                    dmem_wdata = {mem_wdata_in[15:0], 16'd0};
                end else begin
                    dmem_wmask = 4'b0011;
                    dmem_wdata = {16'd0, mem_wdata_in[15:0]};
                end
            end

            3'b010: begin // SW - Store Word
                dmem_wmask = 4'b1111;
                dmem_wdata = mem_wdata_in;
            end

            default: begin
                dmem_wmask = 4'b0000;
                dmem_wdata = mem_wdata_in;
            end
        endcase
    end

    // Load Data Alignment & Extension Generator
    always @(*) begin
        case (funct3_in)
            3'b000: begin // LB - Load Byte (Sign-extended)
                case (byte_offset)
                    2'b00: mem_rdata_out = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: mem_rdata_out = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: mem_rdata_out = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: mem_rdata_out = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end

            3'b001: begin // LH - Load Halfword (Sign-extended)
                if (byte_offset[1])
                    mem_rdata_out = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                else
                    mem_rdata_out = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
            end

            3'b010: begin // LW - Load Word
                mem_rdata_out = dmem_rdata;
            end

            3'b100: begin // LBU - Load Byte Unsigned (Zero-extended)
                case (byte_offset)
                    2'b00: mem_rdata_out = {24'd0, dmem_rdata[7:0]};
                    2'b01: mem_rdata_out = {24'd0, dmem_rdata[15:8]};
                    2'b10: mem_rdata_out = {24'd0, dmem_rdata[23:16]};
                    2'b11: mem_rdata_out = {24'd0, dmem_rdata[31:24]};
                endcase
            end

            3'b101: begin // LHU - Load Halfword Unsigned (Zero-extended)
                if (byte_offset[1])
                    mem_rdata_out = {16'd0, dmem_rdata[31:16]};
                else
                    mem_rdata_out = {16'd0, dmem_rdata[15:0]};
            end

            default: begin
                mem_rdata_out = dmem_rdata;
            end
        endcase
    end

endmodule
