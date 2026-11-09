`timescale 1ns / 1ps
// ============================================================================
// File: rv32i_core.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Top-level 5-stage pipelined RV32I Processor Core. Wires IF, ID,
//              EX, MEM, and WB stages with Hazard Detection and Data Forwarding.
// ============================================================================

module rv32i_core #(
    parameter RESET_VECTOR = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire        imem_req,

    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_wen,
    output wire [3:0]  dmem_wmask,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_req,

    // Hardware Interrupt Lines
    input  wire        irq_external,
    input  wire        irq_timer,

    // Diagnostics / Simulation Tracking
    output wire [31:0] retired_pc,
    output wire        trap_ecall,
    output wire        trap_ebreak
);

    // ========================================================================
    // Pipeline Wires & Hazard Control Signals
    // ========================================================================
    wire        stall_pc;
    wire        stall_if_id;
    wire        flush_if_id;
    wire        flush_id_ex;

    wire        branch_taken_ex;
    wire [31:0] branch_target_ex;

    // Forward declarations of pipeline registers used in trap controller
    reg  [31:0] pc_if_id;
    reg  [31:0] pc_plus4_if_id;
    reg  [31:0] inst_if_id;

    reg  [31:0] pc_id_ex;
    reg         is_ecall_id_ex;
    reg         is_mret_id_ex;

    wire [31:0] pc_if;
    wire [31:0] pc_plus4_if;

    wire        branch_taken_to_if;
    wire [31:0] branch_target_to_if;

    wire [1:0]  forward_a;
    wire [1:0]  forward_b;

    // CSR & Interrupt Controller Wires
    wire        is_csr_id;
    wire        is_mret_id;
    wire [11:0] csr_addr_id;
    wire [2:0]  csr_op_id;
    wire [4:0]  csr_rs1_id;
    wire [4:0]  csr_zimm_id;

    reg         is_csr_id_ex;
    reg  [11:0] csr_addr_id_ex;
    reg  [2:0]  csr_op_id_ex;
    reg  [4:0]  csr_rs1_id_ex;

    wire [11:0] csr_addr_ex_out;
    wire [2:0]  csr_op_ex_out;
    wire [31:0] csr_wdata_ex_out;
    wire        csr_we_ex_out;
    wire [31:0] csr_rdata_from_unit;

    wire [31:0] trap_vector;
    wire [31:0] mepc_out;
    wire        irq_pending;
    wire [31:0] irq_cause;

    // Trap generation logic
    wire        trap_enter_ecall = is_ecall_id_ex;
    wire [31:0] trap_pc_ecall    = pc_id_ex;
    wire [31:0] trap_cause_ecall = {1'b0, 31'd11};

    wire        trap_enter_irq   = irq_pending && !is_ecall_id_ex && !is_mret_id_ex && !branch_taken_ex;
    wire [31:0] trap_pc_irq      = (pc_if_id != 32'd0) ? pc_if_id : pc_if;
    wire [31:0] trap_cause_irq   = irq_cause;

    wire        trap_enter       = trap_enter_ecall | trap_enter_irq;
    wire [31:0] trap_pc_sel      = trap_enter_ecall ? trap_pc_ecall : trap_pc_irq;
    wire [31:0] trap_cause_sel   = trap_enter_ecall ? trap_cause_ecall : trap_cause_irq;
    wire        trap_exit        = is_mret_id_ex;

    assign branch_taken_to_if  = trap_enter | branch_taken_ex;
    assign branch_target_to_if = trap_enter ? trap_vector : branch_target_ex;

    // ========================================================================
    // 1. IF Stage (Instruction Fetch)
    // ========================================================================
    if_stage #(
        .RESET_VECTOR (RESET_VECTOR)
    ) u_if_stage (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall_pc      (stall_pc),
        .branch_taken  (branch_taken_to_if),
        .branch_target (branch_target_to_if),
        .pc_out        (pc_if),
        .pc_plus4_out  (pc_plus4_if)
    );

    assign imem_addr = pc_if;
    assign imem_req  = rst_n;

    // ------------------------------------------------------------------------
    // IF/ID Pipeline Register
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_if_id       <= 32'd0;
            pc_plus4_if_id <= 32'd0;
            inst_if_id     <= 32'h0000_0013; // NOP (addi x0, x0, 0)
        end else if (flush_if_id) begin
            pc_if_id       <= 32'd0;
            pc_plus4_if_id <= 32'd0;
            inst_if_id     <= 32'h0000_0013; // NOP on branch flush
        end else if (!stall_if_id) begin
            pc_if_id       <= pc_if;
            pc_plus4_if_id <= pc_plus4_if;
            inst_if_id     <= imem_rdata;
        end
    end

    // ========================================================================
    // 2. ID Stage (Instruction Decode & Register File)
    // ========================================================================
    wire [4:0]  rs1_id;
    wire [4:0]  rs2_id;
    wire [4:0]  rd_id;
    wire [2:0]  funct3_id;
    wire [6:0]  funct7_id;
    wire [31:0] imm_id;
    wire [31:0] reg_rdata1_id;
    wire [31:0] reg_rdata2_id;
    wire [31:0] pc_id;
    wire [31:0] pc_plus4_id;

    wire [3:0]  alu_op_id;
    wire        alu_src_a_id;
    wire        alu_src_b_id;
    wire        mem_read_id;
    wire        mem_write_id;
    wire        reg_write_id;
    wire [1:0]  wb_src_id;
    wire        is_branch_id;
    wire        is_jal_id;
    wire        is_jalr_id;
    wire        uses_rs1_id;
    wire        uses_rs2_id;
    wire        is_ecall_id;
    wire        is_ebreak_id;

    // Write-back feedback wires
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    id_stage u_id_stage (
        .clk          (clk),
        .rst_n        (rst_n),
        .inst_in      (inst_if_id),
        .pc_in        (pc_if_id),
        .pc_plus4_in  (pc_plus4_if_id),

        .wb_reg_write (wb_reg_write),
        .wb_rd        (wb_rd),
        .wb_data      (wb_data),

        .rs1_addr     (rs1_id),
        .rs2_addr     (rs2_id),
        .rd_addr      (rd_id),
        .funct3       (funct3_id),
        .funct7       (funct7_id),
        .imm_out      (imm_id),
        .reg_rdata1   (reg_rdata1_id),
        .reg_rdata2   (reg_rdata2_id),
        .pc_out       (pc_id),
        .pc_plus4_out (pc_plus4_id),

        .alu_op       (alu_op_id),
        .alu_src_a    (alu_src_a_id),
        .alu_src_b    (alu_src_b_id),
        .mem_read     (mem_read_id),
        .mem_write    (mem_write_id),
        .reg_write    (reg_write_id),
        .wb_src       (wb_src_id),
        .is_branch    (is_branch_id),
        .is_jal       (is_jal_id),
        .is_jalr      (is_jalr_id),
        .uses_rs1     (uses_rs1_id),
        .uses_rs2     (uses_rs2_id),
        .is_ecall     (is_ecall_id),
        .is_ebreak    (is_ebreak_id),
        .is_csr       (is_csr_id),
        .is_mret      (is_mret_id),
        .csr_addr     (csr_addr_id),
        .csr_op       (csr_op_id),
        .csr_rs1      (csr_rs1_id),
        .csr_zimm     (csr_zimm_id)
    );

    // ------------------------------------------------------------------------
    // ID/EX Pipeline Register
    // ------------------------------------------------------------------------
    reg [31:0] pc_plus4_id_ex;
    reg [31:0] reg_rdata1_id_ex;
    reg [31:0] reg_rdata2_id_ex;
    reg [31:0] imm_id_ex;
    reg [4:0]  rs1_id_ex;
    reg [4:0]  rs2_id_ex;
    reg [4:0]  rd_id_ex;
    reg [2:0]  funct3_id_ex;

    reg [3:0]  alu_op_id_ex;
    reg        alu_src_a_id_ex;
    reg        alu_src_b_id_ex;
    reg        mem_read_id_ex;
    reg        mem_write_id_ex;
    reg        reg_write_id_ex;
    reg [1:0]  wb_src_id_ex;
    reg        is_branch_id_ex;
    reg        is_jal_id_ex;
    reg        is_jalr_id_ex;
    reg        is_ebreak_id_ex;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_id_ex         <= 32'd0;
            pc_plus4_id_ex   <= 32'd0;
            reg_rdata1_id_ex <= 32'd0;
            reg_rdata2_id_ex <= 32'd0;
            imm_id_ex        <= 32'd0;
            rs1_id_ex        <= 5'd0;
            rs2_id_ex        <= 5'd0;
            rd_id_ex         <= 5'd0;
            funct3_id_ex     <= 3'd0;

            alu_op_id_ex     <= 4'd0;
            alu_src_a_id_ex  <= 1'b0;
            alu_src_b_id_ex  <= 1'b0;
            mem_read_id_ex   <= 1'b0;
            mem_write_id_ex  <= 1'b0;
            reg_write_id_ex  <= 1'b0;
            wb_src_id_ex     <= 2'b00;
            is_branch_id_ex  <= 1'b0;
            is_jal_id_ex     <= 1'b0;
            is_jalr_id_ex    <= 1'b0;
            is_ecall_id_ex   <= 1'b0;
            is_ebreak_id_ex  <= 1'b0;
            is_csr_id_ex     <= 1'b0;
            is_mret_id_ex    <= 1'b0;
            csr_addr_id_ex   <= 12'd0;
            csr_op_id_ex     <= 3'd0;
            csr_rs1_id_ex    <= 5'd0;
        end else if (flush_id_ex) begin
            pc_id_ex         <= 32'd0;
            pc_plus4_id_ex   <= 32'd0;
            reg_rdata1_id_ex <= 32'd0;
            reg_rdata2_id_ex <= 32'd0;
            imm_id_ex        <= 32'd0;
            rs1_id_ex        <= 5'd0;
            rs2_id_ex        <= 5'd0;
            rd_id_ex         <= 5'd0;
            funct3_id_ex     <= 3'd0;

            alu_op_id_ex     <= 4'd0;
            alu_src_a_id_ex  <= 1'b0;
            alu_src_b_id_ex  <= 1'b0;
            mem_read_id_ex   <= 1'b0;
            mem_write_id_ex  <= 1'b0;
            reg_write_id_ex  <= 1'b0; // NOP bubble: cancel reg write
            wb_src_id_ex     <= 2'b00;
            is_branch_id_ex  <= 1'b0;
            is_jal_id_ex     <= 1'b0;
            is_jalr_id_ex    <= 1'b0;
            is_ecall_id_ex   <= 1'b0;
            is_ebreak_id_ex  <= 1'b0;
            is_csr_id_ex     <= 1'b0;
            is_mret_id_ex    <= 1'b0;
            csr_addr_id_ex   <= 12'd0;
            csr_op_id_ex     <= 3'd0;
            csr_rs1_id_ex    <= 5'd0;
        end else begin
            pc_id_ex         <= pc_id;
            pc_plus4_id_ex   <= pc_plus4_id;
            reg_rdata1_id_ex <= reg_rdata1_id;
            reg_rdata2_id_ex <= reg_rdata2_id;
            imm_id_ex        <= imm_id;
            rs1_id_ex        <= rs1_id;
            rs2_id_ex        <= rs2_id;
            rd_id_ex         <= rd_id;
            funct3_id_ex     <= funct3_id;

            alu_op_id_ex     <= alu_op_id;
            alu_src_a_id_ex  <= alu_src_a_id;
            alu_src_b_id_ex  <= alu_src_b_id;
            mem_read_id_ex   <= mem_read_id;
            mem_write_id_ex  <= mem_write_id;
            reg_write_id_ex  <= reg_write_id;
            wb_src_id_ex     <= wb_src_id;
            is_branch_id_ex  <= is_branch_id;
            is_jal_id_ex     <= is_jal_id;
            is_jalr_id_ex    <= is_jalr_id;
            is_ecall_id_ex   <= is_ecall_id;
            is_ebreak_id_ex  <= is_ebreak_id;
            is_csr_id_ex     <= is_csr_id;
            is_mret_id_ex    <= is_mret_id;
            csr_addr_id_ex   <= csr_addr_id;
            csr_op_id_ex     <= csr_op_id;
            csr_rs1_id_ex    <= csr_rs1_id;
        end
    end

    // ========================================================================
    // 3. EX Stage (Execution, Forwarding MUX, Branch Evaluation)
    // ========================================================================
    wire [31:0] ex_result_ex;
    wire [31:0] mem_wdata_ex;
    wire [4:0]  rd_ex_out;
    wire [2:0]  funct3_ex_out;
    wire        mem_read_ex_out;
    wire        mem_write_ex_out;
    wire        reg_write_ex_out;
    wire [1:0]  wb_src_ex_out;

    // Feedback from EX/MEM for forwarding
    wire [31:0] ex_result_ex_mem_wire;

    ex_stage u_ex_stage (
        .pc_ex         (pc_id_ex),
        .pc_plus4_ex   (pc_plus4_id_ex),
        .reg_rdata1_ex (reg_rdata1_id_ex),
        .reg_rdata2_ex (reg_rdata2_id_ex),
        .imm_ex        (imm_id_ex),
        .rd_ex         (rd_id_ex),
        .funct3_ex     (funct3_id_ex),

        .alu_op_ex     (alu_op_id_ex),
        .alu_src_a_ex  (alu_src_a_id_ex),
        .alu_src_b_ex  (alu_src_b_id_ex),
        .mem_read_ex   (mem_read_id_ex),
        .mem_write_ex  (mem_write_id_ex),
        .reg_write_ex  (reg_write_id_ex),
        .wb_src_ex     (wb_src_id_ex),
        .is_branch_ex  (is_branch_id_ex),
        .is_jal_ex     (is_jal_id_ex),
        .is_jalr_ex    (is_jalr_id_ex),
        .is_csr_ex     (is_csr_id_ex),
        .is_mret_ex    (is_mret_id_ex),
        .csr_addr_ex   (csr_addr_id_ex),
        .csr_op_ex     (csr_op_id_ex),
        .csr_rs1_ex    (csr_rs1_id_ex),
        .csr_rdata_in  (csr_rdata_from_unit),
        .mepc_in       (mepc_out),

        .forward_a     (forward_a),
        .forward_b     (forward_b),
        .ex_result_mem (ex_result_ex_mem_wire),
        .wb_data       (wb_data),

        .ex_result     (ex_result_ex),
        .mem_wdata_ex  (mem_wdata_ex),
        .rd_out        (rd_ex_out),
        .funct3_out    (funct3_ex_out),
        .mem_read_out  (mem_read_ex_out),
        .mem_write_out (mem_write_ex_out),
        .reg_write_out (reg_write_ex_out),
        .wb_src_out    (wb_src_ex_out),

        .csr_addr_out  (csr_addr_ex_out),
        .csr_op_out    (csr_op_ex_out),
        .csr_wdata_out (csr_wdata_ex_out),
        .csr_we_out    (csr_we_ex_out),

        .branch_taken  (branch_taken_ex),
        .branch_target (branch_target_ex)
    );

    // ========================================================================
    // Machine-Mode CSR Unit & Interrupt Controller
    // ========================================================================
    csr_unit u_csr_unit (
        .clk          (clk),
        .rst_n        (rst_n),
        .csr_addr     (csr_addr_ex_out),
        .csr_op       (csr_op_ex_out),
        .csr_wdata    (csr_wdata_ex_out),
        .csr_we       (csr_we_ex_out),
        .csr_rdata    (csr_rdata_from_unit),
        .trap_enter   (trap_enter),
        .trap_pc      (trap_pc_sel),
        .trap_cause   (trap_cause_sel),
        .trap_exit    (trap_exit),
        .trap_vector  (trap_vector),
        .mepc_out     (mepc_out),
        .irq_external (irq_external),
        .irq_timer    (irq_timer),
        .irq_pending  (irq_pending),
        .irq_cause    (irq_cause)
    );

    // ------------------------------------------------------------------------
    // EX/MEM Pipeline Register
    // ------------------------------------------------------------------------
    reg [31:0] pc_ex_mem;
    reg [31:0] ex_result_ex_mem;
    reg [31:0] mem_wdata_ex_mem;
    reg [4:0]  rd_ex_mem;
    reg [2:0]  funct3_ex_mem;
    reg        mem_read_ex_mem;
    reg        mem_write_ex_mem;
    reg        reg_write_ex_mem;
    reg [1:0]  wb_src_ex_mem;
    reg        is_ecall_ex_mem;
    reg        is_ebreak_ex_mem;

    assign ex_result_ex_mem_wire = ex_result_ex_mem;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_ex_mem        <= 32'd0;
            ex_result_ex_mem <= 32'd0;
            mem_wdata_ex_mem <= 32'd0;
            rd_ex_mem        <= 5'd0;
            funct3_ex_mem    <= 3'd0;
            mem_read_ex_mem  <= 1'b0;
            mem_write_ex_mem <= 1'b0;
            reg_write_ex_mem <= 1'b0;
            wb_src_ex_mem    <= 2'b00;
            is_ecall_ex_mem  <= 1'b0;
            is_ebreak_ex_mem <= 1'b0;
        end else begin
            pc_ex_mem        <= pc_id_ex;
            ex_result_ex_mem <= ex_result_ex;
            mem_wdata_ex_mem <= mem_wdata_ex;
            rd_ex_mem        <= rd_ex_out;
            funct3_ex_mem    <= funct3_ex_out;
            mem_read_ex_mem  <= mem_read_ex_out;
            mem_write_ex_mem <= mem_write_ex_out;
            reg_write_ex_mem <= reg_write_ex_out;
            wb_src_ex_mem    <= wb_src_ex_out;
            is_ecall_ex_mem  <= is_ecall_id_ex;
            is_ebreak_ex_mem <= is_ebreak_id_ex;
        end
    end

    // ========================================================================
    // 4. MEM Stage (Data Memory & Alignment Logic)
    // ========================================================================
    wire [31:0] ex_result_mem_out;
    wire [31:0] mem_rdata_mem_out;
    wire [4:0]  rd_mem_out;
    wire        reg_write_mem_out;
    wire [1:0]  wb_src_mem_out;

    mem_stage u_mem_stage (
        .alu_result_in (ex_result_ex_mem),
        .mem_wdata_in  (mem_wdata_ex_mem),
        .rd_in         (rd_ex_mem),
        .funct3_in     (funct3_ex_mem),
        .mem_read_in   (mem_read_ex_mem),
        .mem_write_in  (mem_write_ex_mem),
        .reg_write_in  (reg_write_ex_mem),
        .wb_src_in     (wb_src_ex_mem),

        .dmem_rdata    (dmem_rdata),
        .dmem_addr     (dmem_addr),
        .dmem_wdata    (dmem_wdata),
        .dmem_wen      (dmem_wen),
        .dmem_wmask    (dmem_wmask),
        .dmem_req      (dmem_req),

        .ex_result_out (ex_result_mem_out),
        .mem_rdata_out (mem_rdata_mem_out),
        .rd_out        (rd_mem_out),
        .reg_write_out (reg_write_mem_out),
        .wb_src_out    (wb_src_mem_out)
    );

    // ------------------------------------------------------------------------
    // MEM/WB Pipeline Register
    // ------------------------------------------------------------------------
    reg [31:0] pc_mem_wb;
    reg [31:0] ex_result_mem_wb;
    reg [31:0] mem_rdata_mem_wb;
    reg [4:0]  rd_mem_wb;
    reg        reg_write_mem_wb;
    reg [1:0]  wb_src_mem_wb;
    reg        is_ecall_mem_wb;
    reg        is_ebreak_mem_wb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_mem_wb        <= 32'd0;
            ex_result_mem_wb <= 32'd0;
            mem_rdata_mem_wb <= 32'd0;
            rd_mem_wb        <= 5'd0;
            reg_write_mem_wb <= 1'b0;
            wb_src_mem_wb    <= 2'b00;
            is_ecall_mem_wb  <= 1'b0;
            is_ebreak_mem_wb <= 1'b0;
        end else begin
            pc_mem_wb        <= pc_ex_mem;
            ex_result_mem_wb <= ex_result_mem_out;
            mem_rdata_mem_wb <= mem_rdata_mem_out;
            rd_mem_wb        <= rd_mem_out;
            reg_write_mem_wb <= reg_write_mem_out;
            wb_src_mem_wb    <= wb_src_mem_out;
            is_ecall_mem_wb  <= is_ecall_ex_mem;
            is_ebreak_mem_wb <= is_ebreak_ex_mem;
        end
    end

    // ========================================================================
    // 5. WB Stage (Write-Back Stage)
    // ========================================================================
    wb_stage u_wb_stage (
        .ex_result_in  (ex_result_mem_wb),
        .mem_rdata_in  (mem_rdata_mem_wb),
        .rd_in         (rd_mem_wb),
        .reg_write_in  (reg_write_mem_wb),
        .wb_src_in     (wb_src_mem_wb),

        .wb_reg_write  (wb_reg_write),
        .wb_rd         (wb_rd),
        .wb_data       (wb_data)
    );

    // ========================================================================
    // 6. Hazard Detection & Forwarding Units
    // ========================================================================
    hazard_unit u_hazard_unit (
        .rs1_id          (rs1_id),
        .rs2_id          (rs2_id),
        .uses_rs1_id     (uses_rs1_id),
        .uses_rs2_id     (uses_rs2_id),
        .rd_ex           (rd_id_ex),
        .mem_read_ex     (mem_read_id_ex),
        .branch_taken_ex (branch_taken_to_if),
        .stall_pc        (stall_pc),
        .stall_if_id     (stall_if_id),
        .flush_if_id     (flush_if_id),
        .flush_id_ex     (flush_id_ex)
    );

    forwarding_unit u_forwarding_unit (
        .rs1_ex        (rs1_id_ex),
        .rs2_ex        (rs2_id_ex),
        .rd_mem        (rd_ex_mem),
        .reg_write_mem (reg_write_ex_mem),
        .rd_wb         (wb_rd),
        .reg_write_wb  (wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );

    // Status and debug signals
    assign retired_pc  = pc_mem_wb;
    assign trap_ecall  = is_ecall_mem_wb;
    assign trap_ebreak = is_ebreak_mem_wb;

endmodule
