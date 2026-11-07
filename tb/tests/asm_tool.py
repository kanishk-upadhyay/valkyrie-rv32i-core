#!/usr/bin/env python3
"""
RV32I Assembler & Test Generator Tool
Project: Valkyrie-RV32I Core
Organization: DG Signals / Indian Army Internship Programme (AICTE)
"""

import sys
import re

REGISTERS = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4, 't0': 5, 't1': 6, 't2': 7,
    's0': 8, 'fp': 8, 's1': 9, 'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13,
    'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20,
    's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REGISTERS[f'x{i}'] = i

def parse_reg(s):
    s = s.strip()
    if s in REGISTERS:
        return REGISTERS[s]
    raise ValueError(f"Unknown register '{s}'")

def parse_imm(s, labels=None, pc=0):
    s = s.strip()
    if labels and s in labels:
        return labels[s]
    return int(s, 0)

def assemble_line(line, labels, pc):
    # Strip comments
    line = re.sub(r'#.*$', '', line).strip()
    if not line:
        return None

    # Handle NOP pseudo
    if line == "nop":
        line = "addi x0, x0, 0"

    parts = re.split(r'[\s,]+', line)
    op = parts[0].lower()
    args = parts[1:]

    # R-type
    r_types = {
        'add':  (0x33, 0x0, 0x00),
        'sub':  (0x33, 0x0, 0x20),
        'sll':  (0x33, 0x1, 0x00),
        'slt':  (0x33, 0x2, 0x00),
        'sltu': (0x33, 0x3, 0x00),
        'xor':  (0x33, 0x4, 0x00),
        'srl':  (0x33, 0x5, 0x00),
        'sra':  (0x33, 0x5, 0x20),
        'or':   (0x33, 0x6, 0x00),
        'and':  (0x33, 0x7, 0x00)
    }
    if op in r_types:
        rd = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        rs2 = parse_reg(args[2])
        opcode, funct3, funct7 = r_types[op]
        return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # I-type arith
    i_types = {
        'addi':  (0x13, 0x0),
        'slti':  (0x13, 0x2),
        'sltiu': (0x13, 0x3),
        'xori':  (0x13, 0x4),
        'ori':   (0x13, 0x6),
        'andi':  (0x13, 0x7)
    }
    if op in i_types:
        rd = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        imm = parse_imm(args[2], labels, pc) & 0xFFF
        opcode, funct3 = i_types[op]
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # Shift immediate
    shift_types = {
        'slli': (0x13, 0x1, 0x00),
        'srli': (0x13, 0x5, 0x00),
        'srai': (0x13, 0x5, 0x20)
    }
    if op in shift_types:
        rd = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        shamt = parse_imm(args[2], labels, pc) & 0x1F
        opcode, funct3, funct7 = shift_types[op]
        imm = (funct7 << 5) | shamt
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # Loads: lw rd, offset(rs1)
    loads = {
        'lb':  (0x03, 0x0),
        'lh':  (0x03, 0x1),
        'lw':  (0x03, 0x2),
        'lbu': (0x03, 0x4),
        'lhu': (0x03, 0x5)
    }
    if op in loads:
        rd = parse_reg(args[0])
        m = re.match(r'([-\w\d]+)\((.+)\)', args[1])
        if not m:
            raise ValueError(f"Invalid load syntax: {args[1]}")
        imm = parse_imm(m.group(1), labels, pc) & 0xFFF
        rs1 = parse_reg(m.group(2))
        opcode, funct3 = loads[op]
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # Stores: sw rs2, offset(rs1)
    stores = {
        'sb': (0x23, 0x0),
        'sh': (0x23, 0x1),
        'sw': (0x23, 0x2)
    }
    if op in stores:
        rs2 = parse_reg(args[0])
        m = re.match(r'([-\w\d]+)\((.+)\)', args[1])
        if not m:
            raise ValueError(f"Invalid store syntax: {args[1]}")
        imm = parse_imm(m.group(1), labels, pc) & 0xFFF
        rs1 = parse_reg(m.group(2))
        opcode, funct3 = stores[op]
        imm_hi = (imm >> 5) & 0x7F
        imm_lo = imm & 0x1F
        return (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lo << 7) | opcode

    # Branches: beq rs1, rs2, label
    branches = {
        'beq':  (0x63, 0x0),
        'bne':  (0x63, 0x1),
        'blt':  (0x63, 0x4),
        'bge':  (0x63, 0x5),
        'bltu': (0x63, 0x6),
        'bgeu': (0x63, 0x7)
    }
    if op in branches:
        rs1 = parse_reg(args[0])
        rs2 = parse_reg(args[1])
        target = parse_imm(args[2], labels, pc)
        offset = (target - pc) if (labels and args[2] in labels) else target
        imm = offset & 0x1FFE
        imm_12   = (imm >> 12) & 0x1
        imm_10_5 = (imm >> 5)  & 0x3F
        imm_4_1  = (imm >> 1)  & 0xF
        imm_11   = (imm >> 11) & 0x1
        opcode, funct3 = branches[op]
        return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode

    # JAL: jal rd, target
    if op == 'jal':
        if len(args) == 1:
            rd = 1 # ra
            target_str = args[0]
        else:
            rd = parse_reg(args[0])
            target_str = args[1]
        target = parse_imm(target_str, labels, pc)
        offset = (target - pc) if (labels and target_str in labels) else target
        imm = offset & 0x1FFFFE
        imm_20    = (imm >> 20) & 0x1
        imm_10_1  = (imm >> 1)  & 0x3FF
        imm_11    = (imm >> 11) & 0x1
        imm_19_12 = (imm >> 12) & 0xFF
        opcode = 0x6F
        return (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | opcode

    # JALR: jalr rd, rs1, offset or jalr rd, offset(rs1)
    if op == 'jalr':
        rd = parse_reg(args[0])
        if len(args) == 2 and '(' in args[1]:
            m = re.match(r'([-\w\d]+)\((.+)\)', args[1])
            imm = parse_imm(m.group(1), labels, pc) & 0xFFF
            rs1 = parse_reg(m.group(2))
        elif len(args) == 3:
            rs1 = parse_reg(args[1])
            imm = parse_imm(args[2], labels, pc) & 0xFFF
        else:
            rs1 = parse_reg(args[1])
            imm = 0
        opcode = 0x67
        funct3 = 0x0
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

    # LUI: lui rd, imm20
    if op == 'lui':
        rd = parse_reg(args[0])
        imm = parse_imm(args[1], labels, pc)
        opcode = 0x37
        return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

    # AUIPC: auipc rd, imm20
    if op == 'auipc':
        rd = parse_reg(args[0])
        imm = parse_imm(args[1], labels, pc)
        opcode = 0x17
        return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

    # System
    if op == 'ecall':
        return 0x00000073
    if op == 'ebreak':
        return 0x00100073

    raise ValueError(f"Unsupported instruction or directive: '{line}'")

def assemble(asm_text):
    lines = asm_text.splitlines()
    labels = {}
    instructions = []
    pc = 0

    # Pass 1: Label resolution
    for line in lines:
        line = re.sub(r'#.*$', '', line).strip()
        if not line:
            continue
        # Check label
        if ':' in line:
            label_part, rest = line.split(':', 1)
            label = label_part.strip()
            labels[label] = pc
            line = rest.strip()
        if line:
            instructions.append((pc, line))
            pc += 4

    # Pass 2: Machine code generation
    machine_code = []
    for pc, line in instructions:
        code = assemble_line(line, labels, pc)
        if code is not None:
            machine_code.append(code)

    return machine_code

if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            code = assemble(f.read())
        out_file = sys.argv[2] if len(sys.argv) > 2 else "out.hex"
        with open(out_file, 'w') as f:
            for w in code:
                f.write(f"{w:08x}\n")
        print(f"Assembled {len(code)} instructions into {out_file}")
