LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

USE WORK.RECOP_TYPES.ALL;
USE WORK.OPCODES.ALL;
USE WORK.VARIOUS_CONSTANTS.ALL;

ENTITY tb_control_unit IS
END ENTITY tb_control_unit;

ARCHITECTURE sim OF tb_control_unit IS

    SIGNAL clk : bit_1 := '0';
    SIGNAL reset : bit_1 := '1';

    SIGNAL am : bit_2 := am_inherent;
    SIGNAL opcode : bit_6 := noop;
    SIGNAL z_flag : bit_1 := '0';

    SIGNAL ir_load : bit_1;
    SIGNAL op_load : bit_1;
    SIGNAL pm_addr_sel : bit_1;

    SIGNAL pc_inc : bit_1;
    SIGNAL pc_step_sel : bit_1;
    SIGNAL pc_load : bit_1;
    SIGNAL pc_from_rx : bit_1;

    SIGNAL reg_write : bit_1;
    SIGNAL rf_input_sel : bit_3;

    SIGNAL alu_operation : bit_3;
    SIGNAL alu_op1_sel : bit_2;
    SIGNAL alu_op2_sel : bit_1;

    SIGNAL clr_z_flag : bit_1;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    DUT : ENTITY work.control_unit
        PORT MAP (
            clk => clk,
            reset => reset,
            am => am,
            opcode => opcode,
            z_flag => z_flag,

            ir_load => ir_load,
            op_load => op_load,
            pm_addr_sel => pm_addr_sel,

            pc_inc => pc_inc,
            pc_step_sel => pc_step_sel,
            pc_load => pc_load,
            pc_from_rx => pc_from_rx,

            reg_write => reg_write,
            rf_input_sel => rf_input_sel,

            alu_operation => alu_operation,
            alu_op1_sel => alu_op1_sel,
            alu_op2_sel => alu_op2_sel,

            clr_z_flag => clr_z_flag
        );

    --------------------------------------------------------------------
    -- CLOCK
    --------------------------------------------------------------------
    CLK_PROCESS : PROCESS
    BEGIN
        WHILE TRUE LOOP
            clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            clk <= '1';
            WAIT FOR CLK_PERIOD / 2;
        END LOOP;
    END PROCESS;

    --------------------------------------------------------------------
    -- STIMULUS / CHECKS
    --------------------------------------------------------------------
    STIM_PROC : PROCESS
    BEGIN
        REPORT "Starting control unit testbench";

        ----------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------
        reset <= '1';
        am <= am_inherent;
        opcode <= noop;
        z_flag <= '0';

        WAIT FOR 12 ns;   -- not on a rising edge
        reset <= '0';
        WAIT FOR 1 ns;

        ----------------------------------------------------------------
        -- First active cycle should go to ST_FETCH
        ----------------------------------------------------------------
        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: FETCH after reset";

        ASSERT ir_load = '1' REPORT "FETCH: ir_load should be 1" SEVERITY ERROR;
        ASSERT op_load = '0' REPORT "FETCH: op_load should be 0" SEVERITY ERROR;
        ASSERT pm_addr_sel = '0' REPORT "FETCH: pm_addr_sel should be 0" SEVERITY ERROR;
        ASSERT pc_inc = '0' REPORT "FETCH: pc_inc should be 0" SEVERITY ERROR;
        ASSERT pc_load = '0' REPORT "FETCH: pc_load should be 0" SEVERITY ERROR;
        ASSERT reg_write = '0' REPORT "FETCH: reg_write should be 0" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- NOOP
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_inherent;
        opcode <= noop;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: NOOP decode";
        ASSERT op_load = '0' REPORT "NOOP decode: op_load should be 0" SEVERITY ERROR;
        ASSERT ir_load = '0' REPORT "NOOP decode: ir_load should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: NOOP exec";
        ASSERT pc_inc = '1' REPORT "NOOP exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '0' REPORT "NOOP exec: pc_step_sel should be 0" SEVERITY ERROR;
        ASSERT pc_load = '0' REPORT "NOOP exec: pc_load should be 0" SEVERITY ERROR;
        ASSERT reg_write = '0' REPORT "NOOP exec: reg_write should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: back to FETCH";
        ASSERT ir_load = '1' REPORT "Return FETCH: ir_load should be 1" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- LDR immediate
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_immediate;
        opcode <= ldr;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR immediate decode";
        ASSERT op_load = '1' REPORT "LDR imm decode: op_load should be 1" SEVERITY ERROR;
        ASSERT pm_addr_sel = '1' REPORT "LDR imm decode: pm_addr_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR immediate exec";
        ASSERT reg_write = '1' REPORT "LDR imm exec: reg_write should be 1" SEVERITY ERROR;
        ASSERT rf_input_sel = rf_from_operand REPORT "LDR imm exec: rf_input_sel should be rf_from_operand" SEVERITY ERROR;
        ASSERT pc_inc = '1' REPORT "LDR imm exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '1' REPORT "LDR imm exec: pc_step_sel should be 1" SEVERITY ERROR;
        ASSERT pc_load = '0' REPORT "LDR imm exec: pc_load should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After LDR imm: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- LDR register
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_register;
        opcode <= ldr;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR register decode";
        ASSERT op_load = '0' REPORT "LDR reg decode: op_load should be 0" SEVERITY ERROR;
        ASSERT pm_addr_sel = '0' REPORT "LDR reg decode: pm_addr_sel should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR register exec";
        ASSERT reg_write = '1' REPORT "LDR reg exec: reg_write should be 1" SEVERITY ERROR;
        ASSERT rf_input_sel = rf_from_dm REPORT "LDR reg exec: rf_input_sel should be rf_from_dm" SEVERITY ERROR;
        ASSERT pc_inc = '1' REPORT "LDR reg exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '0' REPORT "LDR reg exec: pc_step_sel should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After LDR reg: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- LDR direct
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_direct;
        opcode <= ldr;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR direct decode";
        ASSERT op_load = '1' REPORT "LDR dir decode: op_load should be 1" SEVERITY ERROR;
        ASSERT pm_addr_sel = '1' REPORT "LDR dir decode: pm_addr_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: LDR direct exec";
        ASSERT reg_write = '1' REPORT "LDR dir exec: reg_write should be 1" SEVERITY ERROR;
        ASSERT rf_input_sel = rf_from_dm REPORT "LDR dir exec: rf_input_sel should be rf_from_dm" SEVERITY ERROR;
        ASSERT pc_inc = '1' REPORT "LDR dir exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '1' REPORT "LDR dir exec: pc_step_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After LDR dir: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- ADD immediate
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_immediate;
        opcode <= addr;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: ADD immediate decode";
        ASSERT op_load = '1' REPORT "ADD imm decode: op_load should be 1" SEVERITY ERROR;
        ASSERT pm_addr_sel = '1' REPORT "ADD imm decode: pm_addr_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: ADD immediate exec";
        ASSERT alu_operation = alu_add REPORT "ADD imm exec: alu_operation should be alu_add" SEVERITY ERROR;
        ASSERT alu_op1_sel = "01" REPORT "ADD imm exec: alu_op1_sel should be operand" SEVERITY ERROR;
        ASSERT alu_op2_sel = '0' REPORT "ADD imm exec: alu_op2_sel should be Rx" SEVERITY ERROR;
        ASSERT reg_write = '1' REPORT "ADD imm exec: reg_write should be 1" SEVERITY ERROR;
        ASSERT rf_input_sel = rf_from_alu REPORT "ADD imm exec: rf_input_sel should be rf_from_alu" SEVERITY ERROR;
        ASSERT pc_inc = '1' REPORT "ADD imm exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '1' REPORT "ADD imm exec: pc_step_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After ADD imm: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- ADD register
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_register;
        opcode <= addr;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: ADD register decode";
        ASSERT op_load = '0' REPORT "ADD reg decode: op_load should be 0" SEVERITY ERROR;
        ASSERT pm_addr_sel = '0' REPORT "ADD reg decode: pm_addr_sel should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: ADD register exec";
        ASSERT alu_operation = alu_add REPORT "ADD reg exec: alu_operation should be alu_add" SEVERITY ERROR;
        ASSERT alu_op1_sel = "00" REPORT "ADD reg exec: alu_op1_sel should be Rx" SEVERITY ERROR;
        ASSERT alu_op2_sel = '1' REPORT "ADD reg exec: alu_op2_sel should be Rz" SEVERITY ERROR;
        ASSERT reg_write = '1' REPORT "ADD reg exec: reg_write should be 1" SEVERITY ERROR;
        ASSERT rf_input_sel = rf_from_alu REPORT "ADD reg exec: rf_input_sel should be rf_from_alu" SEVERITY ERROR;
        ASSERT pc_inc = '1' REPORT "ADD reg exec: pc_inc should be 1" SEVERITY ERROR;
        ASSERT pc_step_sel = '0' REPORT "ADD reg exec: pc_step_sel should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After ADD reg: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- JMP immediate
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_immediate;
        opcode <= jmp;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: JMP immediate decode";
        ASSERT op_load = '1' REPORT "JMP imm decode: op_load should be 1" SEVERITY ERROR;
        ASSERT pm_addr_sel = '1' REPORT "JMP imm decode: pm_addr_sel should be 1" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: JMP immediate exec";
        ASSERT pc_load = '1' REPORT "JMP imm exec: pc_load should be 1" SEVERITY ERROR;
        ASSERT pc_from_rx = '0' REPORT "JMP imm exec: pc_from_rx should be 0" SEVERITY ERROR;
        ASSERT pc_inc = '0' REPORT "JMP imm exec: pc_inc should be 0" SEVERITY ERROR;
        ASSERT reg_write = '0' REPORT "JMP imm exec: reg_write should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;
        ASSERT ir_load = '1' REPORT "After JMP imm: should return to FETCH" SEVERITY ERROR;

        ----------------------------------------------------------------
        -- JMP register
        ----------------------------------------------------------------
        WAIT UNTIL FALLING_EDGE(clk);
        am <= am_register;
        opcode <= jmp;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: JMP register decode";
        ASSERT op_load = '0' REPORT "JMP reg decode: op_load should be 0" SEVERITY ERROR;
        ASSERT pm_addr_sel = '0' REPORT "JMP reg decode: pm_addr_sel should be 0" SEVERITY ERROR;

        WAIT UNTIL RISING_EDGE(clk);
        WAIT FOR 1 ns;

        REPORT "CHECK: JMP register exec";
        ASSERT pc_load = '1' REPORT "JMP reg exec: pc_load should be 1" SEVERITY ERROR;
        ASSERT pc_from_rx = '1' REPORT "JMP reg exec: pc_from_rx should be 1" SEVERITY ERROR;
        ASSERT pc_inc = '0' REPORT "JMP reg exec: pc_inc should be 0" SEVERITY ERROR;
        ASSERT reg_write = '0' REPORT "JMP reg exec: reg_write should be 0" SEVERITY ERROR;

        REPORT "All CU checks passed" SEVERITY NOTE;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;