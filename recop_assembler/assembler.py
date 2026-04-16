import sys
import token

#operations
OPCODES = {
    
    'LDR':          0b000000, 
    'STR':          0b000001, 
    'JMP':          0b011000,
    'PRESENT':      0b011100,
    'AND':          0b001000,
    'OR':           0b001100,
    'ADD':          0b000100,
    'SUB':          0b001000,
    'SUBV':         0b000011,
    'CLFZ':         0b010000,
    'CER':          0b111100,
    'CEOT':         0b111110,
    'SEOT':         0b111111,
    'NOOP':         0b110100,
    'SZ':           0b010100,
    'LER':          0b110110,
    'SSVOP':        0b111011,
    'SSOP':         0b111010,   
    'LSIP':         0b110111,
    'DATACALL':     0b101000,
    'DATACALL2':    0b101001,
    'MAX':          0b011110,
    'STRPC':        0b011101,
    'SRES':         0b101010,
}

# addressing modes
AM = {
    'INHERENT': 0b00,
    'IMMEDIATE': 0b01,
    'DIRECT':    0b10,
    'REGISTER':  0b11,
}

# reads assembly file, removes comments and empty lines
def read_file(filename):
    lines = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if ';' in line:
                line = line[:line.index(';')].strip()
            if line:
                lines.append(line)
    return lines

# first pass to collect labels and their addresses
def first_pass(lines):
    labels = {}
    address = 0
    for line in lines:
        if line.endswith(':'):
            label_name = line[:-1]
            labels[label_name] = address
        else:
            address += 1
    return labels

# second pass to generate machine code
def second_pass(lines, labels):
    machine_code = []
    for line in lines:
        if line.endswith(':'):
            continue  # skip label definitions

        tokens = line.replace(',', ' ').split() # supports both "ADD R1, R2, #10" and "ADD R1 R2 #10" formats
        opcode_str = tokens[0].upper()          
        opcode = OPCODES.get(opcode_str)
        if opcode is None:
            raise ValueError(f"Unknown opcode: {opcode_str}")
        
        # initialize values to 0
        am = AM['INHERENT']
        rz_val = 0
        rx_val = 0
        operand = 0

        # determine addressing mode and operands
        if len(tokens) == 2:
            # format: JMP TARGET
            target = tokens[1]
            am = AM['DIRECT']
            if target in labels:
                operand = labels[target]
            else:
                operand = parse_immediate(target)
                
        elif len(tokens) == 3:
            # format: LDR R1, #10
            rz_val = parse_register(tokens[1])
            operand_token = tokens[2]
            
            if operand_token.startswith('#'):
                am = AM['IMMEDIATE']
                operand = parse_immediate(operand_token)
            elif operand_token.startswith('R'):
                am = AM['REGISTER']
                operand = parse_register(operand_token)
            else:
                am = AM['DIRECT']
                operand = labels.get(operand_token, 0)

        elif len(tokens) == 4:
            # format: ADD R3, R1, #20
            rz_val = parse_register(tokens[1])
            rx_val = parse_register(tokens[2])
            operand_token = tokens[3]
            
            if operand_token.startswith('#'):
                am = AM['IMMEDIATE']
                operand = parse_immediate(operand_token)
            elif operand_token.startswith('R'):
                am = AM['REGISTER']
                operand = parse_register(operand_token)
            else:
                am = AM['DIRECT']
                operand = labels.get(operand_token, 0)
        
        # encode instruction: [am(2)][opcode(6)][rz(4)][rx(4)][operand(16)]
        instruction = (
                            (am << 30) | 
                            (opcode << 24) | 
                            (rz_val << 20) | 
                            (rx_val << 16) | 
                            (operand & 0xFFFF)
)
        machine_code.append(instruction)
    return machine_code

def parse_register(token):
    # token like 'R3' or 'R15'
    return int(token[1:])

def parse_immediate(token):
    # token like '#20' or '#0xFF'
    value = token[1:]
    return int(value, 0)  # int with base 0 handles decimal, hex 0x, binary 0b

def write_mif(instructions, filename, depth=256):
    with open(filename, 'w') as f:
        f.write(f'WIDTH=32;\n')
        f.write(f'DEPTH={depth};\n\n')
        f.write('ADDRESS_RADIX=HEX;\n')
        f.write('DATA_RADIX=HEX;\n\n')
        f.write('CONTENT BEGIN\n')
        for i, instr in enumerate(instructions):
            f.write(f'    {i:X} : {instr:08X};\n')
        # Fill unused locations with 0
        for i in range(len(instructions), depth):
            f.write(f'    {i:X} : 00000000;\n')
        f.write('END;\n')

def main():
    if len(sys.argv) != 3:
        print("Usage: python assembler.py input.asm output.mif")
        return
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    lines = read_file(input_file)
    labels = first_pass(lines)
    instructions = second_pass(lines, labels)
    write_mif(instructions, output_file)
    print(f"Assembled {len(instructions)} instructions into {output_file}")

main()