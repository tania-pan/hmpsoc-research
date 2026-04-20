import sys

OPCODES = {
    'LDR':          0b000000,
    'STR':          0b000010,
    'JMP':          0b011000,
    'PRESENT':      0b011100,
    'AND':          0b001000,
    'OR':           0b001100,
    'ADD':          0b111000,
    'SUB':          0b000100,
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

AM = {
    'INHERENT':  0b00,
    'IMMEDIATE': 0b01,
    'DIRECT':    0b10,
    'REGISTER':  0b11,
}


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


def parse_register(token):
    return int(token[1:])


def parse_immediate(token):
    if token.startswith('#') or token.startswith('$'):
        value = token[1:]
    else:
        value = token
    return int(value, 0)


def resolve_operand(token, labels):
    t = token.strip()
    if t.startswith('#') or t.startswith('$'):
        t = t[1:]

    key = t.upper()
    if key in labels:
        return labels[key]

    return int(t, 0)


def first_pass(lines):
    labels = {}
    address = 0

    for line in lines:
        if line.endswith(':'):
            labels[line[:-1].strip().upper()] = address
            continue

        tokens = line.replace(',', ' ').split()
        opcode_str = tokens[0].upper()

        if len(tokens) == 1:
            address += 1

        elif len(tokens) == 2:
            op1 = tokens[1]

            if opcode_str == 'JMP' and op1.startswith('R'):
                address += 1
            elif opcode_str in ('DATACALL', 'SSOP', 'SSVOP', 'LSIP', 'LER', 'SRES') and op1.startswith('R'):
                address += 1
            elif opcode_str == 'STRPC':
                address += 2
            else:
                address += 2

        elif len(tokens) == 3:
            op2 = tokens[2]

            if op2.startswith('R'):
                address += 1
            else:
                address += 2

        elif len(tokens) == 4:
            op3 = tokens[3]

            if op3.startswith('R'):
                address += 1
            else:
                address += 2

        else:
            raise ValueError(f"Unsupported syntax in first pass: {line}")

    return labels


def second_pass(lines, labels):
    machine_code = []

    for line in lines:
        if line.endswith(':'):
            continue

        tokens = line.replace(',', ' ').split()
        opcode_str = tokens[0].upper()
        opcode = OPCODES.get(opcode_str)

        if opcode is None:
            raise ValueError(f"Unknown opcode: {opcode_str}")

        am = AM['INHERENT']
        rz_val = 0
        rx_val = 0
        operand = 0

        # ------------------------------------------------------------
        # 1-token instructions
        # ------------------------------------------------------------
        if len(tokens) == 1:
            am = AM['INHERENT']

        # ------------------------------------------------------------
        # 2-token instructions
        # ------------------------------------------------------------
        elif len(tokens) == 2:
            op1 = tokens[1]

            if opcode_str == 'JMP':
                if op1.startswith('R'):
                    am = AM['REGISTER']
                    rx_val = parse_register(op1)
                else:
                    am = AM['IMMEDIATE']
                    operand = resolve_operand(op1, labels)

            elif opcode_str == 'SZ':
                am = AM['IMMEDIATE']
                operand = resolve_operand(op1, labels)

            elif opcode_str == 'STRPC':
                # STRPC $Operand
                am = AM['DIRECT']
                operand = resolve_operand(op1, labels)

            elif opcode_str in ('DATACALL', 'SSOP', 'SSVOP'):
                am = AM['REGISTER']
                rx_val = parse_register(op1)

            elif opcode_str in ('LSIP', 'LER', 'SRES'):
                am = AM['REGISTER']
                rz_val = parse_register(op1)

            else:
                raise ValueError(f"Unsupported 2-token form: {line}")

        # ------------------------------------------------------------
        # 3-token instructions
        # ------------------------------------------------------------
        elif len(tokens) == 3:
            op1 = tokens[1]
            op2 = tokens[2]

            if opcode_str == 'DATACALL':
                # DATACALL Rx #Operand
                rx_val = parse_register(op1)

                if op2.startswith('#'):
                    am = AM['IMMEDIATE']
                    operand = parse_immediate(op2)
                elif op2.startswith('$'):
                    am = AM['DIRECT']
                    operand = parse_immediate(op2)
                else:
                    am = AM['DIRECT']
                    operand = resolve_operand(op2, labels)

            elif opcode_str == 'STR':
                if op2.startswith('#'):
                    # STR Rz #Operand
                    rz_val = parse_register(op1)
                    am = AM['IMMEDIATE']
                    operand = parse_immediate(op2)

                elif op2.startswith('R'):
                    # STR Rz Rx
                    rz_val = parse_register(op1)
                    rx_val = parse_register(op2)
                    am = AM['REGISTER']

                elif op2.startswith('$'):
                    # STR Rx $Operand
                    rx_val = parse_register(op1)
                    am = AM['DIRECT']
                    operand = parse_immediate(op2)

                else:
                    # STR Rx LABEL
                    rx_val = parse_register(op1)
                    am = AM['DIRECT']
                    operand = resolve_operand(op2, labels)

            elif opcode_str == 'PRESENT':
                # PRESENT Rz #Operand / LABEL
                rz_val = parse_register(op1)
                am = AM['IMMEDIATE']
                operand = resolve_operand(op2, labels)

            else:
                # default form: OP Rz operand
                rz_val = parse_register(op1)

                if op2.startswith('#'):
                    am = AM['IMMEDIATE']
                    operand = parse_immediate(op2)

                elif op2.startswith('$'):
                    am = AM['DIRECT']
                    operand = parse_immediate(op2)

                elif op2.startswith('R'):
                    am = AM['REGISTER']
                    rx_val = parse_register(op2)

                else:
                    am = AM['DIRECT']
                    operand = resolve_operand(op2, labels)

        # ------------------------------------------------------------
        # 4-token instructions
        # ------------------------------------------------------------
        elif len(tokens) == 4:
            rz_val = parse_register(tokens[1])
            rx_val = parse_register(tokens[2])
            op3 = tokens[3]

            if op3.startswith('#'):
                am = AM['IMMEDIATE']
                operand = parse_immediate(op3)

            elif op3.startswith('$'):
                am = AM['DIRECT']
                operand = parse_immediate(op3)

            elif op3.startswith('R'):
                am = AM['REGISTER']

            else:
                am = AM['DIRECT']
                operand = resolve_operand(op3, labels)

        else:
            raise ValueError(f"Unsupported syntax in second pass: {line}")

        word1 = (
            (am << 14) |
            (opcode << 8) |
            (rz_val << 4) |
            (rx_val & 0xF)
        )
        machine_code.append(word1)

        if am == AM['IMMEDIATE'] or am == AM['DIRECT']:
            machine_code.append(operand & 0xFFFF)

    return machine_code


def write_mif(instructions, filename, depth=512):
    with open(filename, 'w') as f:
        f.write('WIDTH=16;\n')
        f.write(f'DEPTH={depth};\n\n')
        f.write('ADDRESS_RADIX=HEX;\n')
        f.write('DATA_RADIX=HEX;\n\n')
        f.write('CONTENT BEGIN\n')

        for i, instr in enumerate(instructions):
            f.write(f'    {i:X} : {instr:04X};\n')

        for i in range(len(instructions), depth):
            f.write(f'    {i:X} : 0000;\n')

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
    write_mif(instructions, 'instructions.mif', depth=32768)

    print(f"Assembled {len(instructions)} words into {output_file}")


if __name__ == "__main__":
    main()