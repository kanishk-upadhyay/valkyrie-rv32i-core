`timescale 1ns / 1ps
// ============================================================================
// File: csr_unit.v
// Project: Valkyrie-RV32I Core
// Organization: DG Signals / Indian Army Internship Programme (AICTE)
// Description: Machine-Mode Control and Status Register (CSR) Unit & 
//              Asynchronous Interrupt Controller supporting mstatus, mie, mip,
//              mtvec, mepc, mcause, and mscratch according to RISC-V Privileged
//              Architecture v1.12.
// ============================================================================

module csr_unit (
    input  wire        clk,
    input  wire        rst_n,

    // CSR Access Interface (from EX stage)
    input  wire [11:0] csr_addr,
    input  wire [2:0]  csr_op,         // funct3 (CSRRW, CSRRS, CSRRC, etc.)
    input  wire [31:0] csr_wdata,
    input  wire        csr_we,
    output reg  [31:0] csr_rdata,

    // Trap / Exception Interface
    input  wire        trap_enter,     // Asserted when taking an interrupt or exception
    input  wire [31:0] trap_pc,        // PC to save into mepc
    input  wire [31:0] trap_cause,     // Cause value to save into mcause
    input  wire        trap_exit,      // Asserted on MRET instruction
    output wire [31:0] trap_vector,    // Base trap vector (mtvec)
    output wire [31:0] mepc_out,       // Return PC (mepc)

    // Hardware Interrupt Lines
    input  wire        irq_external,   // External asynchronous interrupt pin
    input  wire        irq_timer,      // Real-time hardware timer interrupt
    output wire        irq_pending,    // Active interrupt ready to preempt core
    output wire [31:0] irq_cause       // Cause code for the pending interrupt
);

    // Standard RISC-V Machine-Mode CSR Addresses
    localparam CSR_MSTATUS   = 12'h300;
    localparam CSR_MIE       = 12'h304;
    localparam CSR_MTVEC     = 12'h305;
    localparam CSR_MSCRATCH  = 12'h340;
    localparam CSR_MEPC      = 12'h341;
    localparam CSR_MCAUSE    = 12'h342;
    localparam CSR_MIP       = 12'h344;

    // Internal Machine-Mode Registers
    // mstatus: [12:11]=MPP (always 2'b11 for M-mode), [7]=MPIE, [3]=MIE
    reg [31:0] mstatus_reg;
    reg [31:0] mie_reg;
    reg [31:0] mtvec_reg;
    reg [31:0] mscratch_reg;
    reg [31:0] mepc_reg;
    reg [31:0] mcause_reg;

    // mip: bit 7 = MTIP (timer), bit 11 = MEIP (external)
    wire [31:0] mip_wire;
    assign mip_wire = {20'd0, irq_external, 3'd0, irq_timer, 7'd0};

    // Combinational CSR Read Multiplexer
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata = mstatus_reg;
            CSR_MIE:      csr_rdata = mie_reg;
            CSR_MTVEC:    csr_rdata = mtvec_reg;
            CSR_MSCRATCH: csr_rdata = mscratch_reg;
            CSR_MEPC:     csr_rdata = mepc_reg;
            CSR_MCAUSE:   csr_rdata = mcause_reg;
            CSR_MIP:      csr_rdata = mip_wire;
            default:      csr_rdata = 32'd0;
        endcase
    end

    // Compute updated CSR value based on atomic CSR operation
    reg [31:0] csr_updated_val;
    always @(*) begin
        case (csr_op)
            3'b001, 3'b101: csr_updated_val = csr_wdata;                  // CSRRW / CSRRWI (Write)
            3'b010, 3'b110: csr_updated_val = csr_rdata | csr_wdata;       // CSRRS / CSRRSI (Set bits)
            3'b011, 3'b111: csr_updated_val = csr_rdata & ~csr_wdata;      // CSRRC / CSRRCI (Clear bits)
            default:        csr_updated_val = csr_wdata;
        endcase
    end

    // Synchronous CSR State Transitions & Trap Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_reg  <= 32'h0000_1800; // MPP=2'b11, MIE=0, MPIE=0
            mie_reg      <= 32'd0;
            mtvec_reg    <= 32'd0;
            mscratch_reg <= 32'd0;
            mepc_reg     <= 32'd0;
            mcause_reg   <= 32'd0;
        end else if (trap_enter) begin
            // Enter trap: save PC and Cause, backup MIE into MPIE, disable MIE
            mepc_reg        <= trap_pc;
            mcause_reg      <= trap_cause;
            mstatus_reg[7]  <= mstatus_reg[3]; // MPIE <= MIE
            mstatus_reg[3]  <= 1'b0;           // MIE <= 0
        end else if (trap_exit) begin
            // Exit trap (MRET): restore MIE from MPIE, set MPIE <= 1
            mstatus_reg[3]  <= mstatus_reg[7]; // MIE <= MPIE
            mstatus_reg[7]  <= 1'b1;           // MPIE <= 1
        end else if (csr_we) begin
            // Standard CSR Write
            case (csr_addr)
                CSR_MSTATUS: begin
                    // Only writable bits: MIE (bit 3), MPIE (bit 7)
                    mstatus_reg[3] <= csr_updated_val[3];
                    mstatus_reg[7] <= csr_updated_val[7];
                end
                CSR_MIE: begin
                    // Enable bits: MTIE (bit 7), MEIE (bit 11)
                    mie_reg[7]  <= csr_updated_val[7];
                    mie_reg[11] <= csr_updated_val[11];
                end
                CSR_MTVEC: begin
                    mtvec_reg <= {csr_updated_val[31:2], 2'b00}; // Force 4-byte aligned
                end
                CSR_MSCRATCH: begin
                    mscratch_reg <= csr_updated_val;
                end
                CSR_MEPC: begin
                    mepc_reg <= {csr_updated_val[31:2], 2'b00};
                end
                CSR_MCAUSE: begin
                    mcause_reg <= csr_updated_val;
                end
                default: begin
                    // Read-only or unsupported CSRs ignore writes
                end
            endcase
        end
    end

    // Outputs for Trap Redirection & MRET
    assign trap_vector = mtvec_reg;
    assign mepc_out    = mepc_reg;

    // Asynchronous Interrupt Detection Logic:
    // Interrupts enabled globally when mstatus.MIE (bit 3) is 1.
    // Check external interrupt (MEIE & MEIP) and timer interrupt (MTIE & MTIP).
    wire mti_active = mie_reg[7]  && irq_timer;
    wire mei_active = mie_reg[11] && irq_external;

    assign irq_pending = mstatus_reg[3] && (mei_active || mti_active);

    // Interrupt Priority: External Interrupt (MEI = 11) > Timer Interrupt (MTI = 7)
    assign irq_cause = mei_active ? {1'b1, 31'd11} : {1'b1, 31'd7};

endmodule
