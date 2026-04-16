LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

USE WORK.RECOP_TYPES.ALL;
USE WORK.OPCODES.ALL;
USE WORK.VARIOUS_CONSTANTS.ALL;

ENTITY control_unit IS
    PORT (
        clk : IN bit_1;
        reset : IN bit_1;

        -- decoded instruction fields from datapath
        am : IN bit_2;
        opcode : IN bit_6;
        z_flag : IN bit_1;
        rz_zero : IN bit_1;

        -- control outputs to datapath
        ir_load : OUT bit_1;
        op_load : OUT bit_1;
        pm_addr_sel : OUT bit_1; -- '0' = PC, '1' = PC+1

        pc_inc : OUT bit_1;
        pc_step_sel : OUT bit_1; -- '0' = +1, '1' = +2
        pc_load : OUT bit_1;
        pc_from_rx : OUT bit_1;

        reg_write : OUT bit_1;
        rf_input_sel : OUT bit_3;

        alu_operation : OUT bit_3;
        alu_op1_sel : OUT bit_2;
        alu_op2_sel : OUT bit_1;
        clr_z_flag : OUT bit_1;

        -- data memory control
        dm_wr : OUT bit_1;
        dm_addr_sel : OUT bit_2;
        dm_data_sel : OUT bit_2;

        -- special-register control
        dpcr_wr : OUT bit_1;
        dpcr_lsb_sel : OUT bit_1;
        sop_wr : OUT bit_1
    );
END ENTITY control_unit;

ARCHITECTURE state OF control_unit IS
    TYPE state_t IS (
        ST_RESET,
        ST_FETCH1_ADDR,
        ST_FETCH1_LOAD,
        ST_DECODE,
        ST_FETCH2_ADDR,
        ST_FETCH2_LOAD,
        ST_EXEC
    );
    SIGNAL state, next_state : state_t;
BEGIN

    --------------------------------------------------------------------
    -- STATE TRANSITION PROCESS
    --------------------------------------------------------------------
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state <= ST_RESET;
        ELSIF RISING_EDGE(clk) THEN
            state <= next_state;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------
    -- NEXT STATE + OUTPUT LOGIC
    --------------------------------------------------------------------
    PROCESS (state, opcode, am, z_flag, rz_zero)
    BEGIN
        -- defaults
        next_state <= state;

        ir_load <= '0';
        op_load <= '0';
        pm_addr_sel <= '0';

        pc_inc <= '0';
        pc_step_sel <= '0';
        pc_load <= '0';
        pc_from_rx <= '0';

        reg_write <= '0';
        rf_input_sel <= (OTHERS => '0');

        alu_operation <= alu_idle;
        alu_op1_sel <= (OTHERS => '0');
        alu_op2_sel <= '0';

        clr_z_flag <= '0';

        dm_wr <= '0';
        dm_addr_sel <= (OTHERS => '0');
        dm_data_sel <= (OTHERS => '0');

        dpcr_wr <= '0';
        dpcr_lsb_sel <= '0';
        sop_wr <= '0';

        CASE state IS

            ----------------------------------------------------------------
            -- RESET
            ----------------------------------------------------------------
            WHEN ST_RESET =>
                next_state <= ST_FETCH1_ADDR;

            ----------------------------------------------------------------
            -- FETCH FIRST WORD: PRESENT ADDRESS
            ----------------------------------------------------------------
            WHEN ST_FETCH1_ADDR =>
                pm_addr_sel <= '0';   -- PC
                next_state <= ST_FETCH1_LOAD;

            ----------------------------------------------------------------
            -- FETCH FIRST WORD: LATCH DATA
            ----------------------------------------------------------------
            WHEN ST_FETCH1_LOAD =>
                pm_addr_sel <= '0';   -- still PC
                ir_load <= '1';       -- latch first 16-bit word
                next_state <= ST_DECODE;

            ----------------------------------------------------------------
            -- DECODE
            ----------------------------------------------------------------
            WHEN ST_DECODE =>
                IF am = am_immediate OR am = am_direct THEN
                    next_state <= ST_FETCH2_ADDR;
                ELSE
                    next_state <= ST_EXEC;
                END IF;

            ----------------------------------------------------------------
            -- FETCH SECOND WORD: PRESENT ADDRESS
            ----------------------------------------------------------------
            WHEN ST_FETCH2_ADDR =>
                pm_addr_sel <= '1';   -- PC + 1
                next_state <= ST_FETCH2_LOAD;

            ----------------------------------------------------------------
            -- FETCH SECOND WORD: LATCH DATA
            ----------------------------------------------------------------
            WHEN ST_FETCH2_LOAD =>
                pm_addr_sel <= '1';   -- still PC + 1
                op_load <= '1';       -- latch operand word
                next_state <= ST_EXEC;

            ----------------------------------------------------------------
            -- EXECUTE
            ----------------------------------------------------------------
            WHEN ST_EXEC =>
                next_state <= ST_FETCH1_ADDR;

                CASE opcode IS

                    --------------------------------------------------------
                    -- NOOP
                    --------------------------------------------------------
                    WHEN noop =>
                        pc_inc <= '1';
                        pc_step_sel <= '0';

                    --------------------------------------------------------
                    -- JMP
                    --------------------------------------------------------
                    WHEN jmp =>
                        CASE am IS
                            WHEN am_immediate =>
                                pc_load <= '1';
                                pc_from_rx <= '0';

                            WHEN am_register =>
                                pc_load <= '1';
                                pc_from_rx <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    --------------------------------------------------------
                    -- LDR
                    --------------------------------------------------------
                    WHEN ldr =>
                        CASE am IS
                            WHEN am_immediate =>
                                reg_write <= '1';
                                rf_input_sel <= rf_from_operand;
                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;
                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN am_direct =>
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;
                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    --------------------------------------------------------
                    -- ADD
                    --------------------------------------------------------
                    WHEN addr =>
                        CASE am IS
                            WHEN am_immediate =>
                                alu_operation <= alu_add;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                alu_operation <= alu_add;
                                alu_op1_sel <= "00"; -- rx
                                alu_op2_sel <= '1';  -- rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    --------------------------------------------------------
                    -- AND
                    --------------------------------------------------------
                    WHEN andr =>
                        CASE am IS
                            WHEN am_immediate =>
                                alu_operation <= alu_and;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                alu_operation <= alu_and;
                                alu_op1_sel <= "00"; -- rx
                                alu_op2_sel <= '1';  -- rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    --------------------------------------------------------
                    -- OR
                    --------------------------------------------------------
                    WHEN orr =>
                        CASE am IS
                            WHEN am_immediate =>
                                alu_operation <= alu_or;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                alu_operation <= alu_or;
                                alu_op1_sel <= "00"; -- rx
                                alu_op2_sel <= '1';  -- rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    --------------------------------------------------------
                    -- CLFZ
                    --------------------------------------------------------
                    WHEN clfz =>
                        clr_z_flag <= '1';
                        pc_inc <= '1';
                        pc_step_sel <= '0';

                    --------------------------------------------------------
                    -- unimplemented instructions for now
                    --------------------------------------------------------
                    WHEN OTHERS =>
                        NULL;
                END CASE;

        END CASE;
    END PROCESS;

END ARCHITECTURE state;