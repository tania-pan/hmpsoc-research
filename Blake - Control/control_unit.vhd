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

        -- control outputs to datapath
        ir_load : OUT bit_1;
        op_load : OUT bit_1;
        pm_addr_sel : OUT bit_1;

        pc_inc : OUT bit_1;
        pc_load : OUT bit_1;
        pc_from_rx : OUT bit_1;

        reg_write : OUT bit_1;
        rf_input_sel : OUT bit_3;

        alu_operation : OUT bit_3;
        alu_op1_sel : OUT bit_2;
        alu_op2_sel : OUT bit_1;

        clr_z_flag : OUT bit_1
    );
END ENTITY control_unit;

ARCHITECTURE state OF control_unit IS
    TYPE state_t IS (ST_RESET, ST_FETCH, ST_DECODE, ST_EXEC);
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
    PROCESS (state, opcode, am)
    BEGIN
        -- DEFAULT
        next_state <= state;

        ir_load <= '0';
        op_load <= '0';
        pm_addr_sel <= '0';

        pc_inc <= '0';
        pc_load <= '0';
        pc_from_rx <= '0';
        reg_write <= '0';
        rf_input_sel <= (OTHERS => '0');
        alu_operation <= (OTHERS => '0');
        alu_op1_sel <= (OTHERS => '0');
        alu_op2_sel <= '0';
        clr_z_flag <= '0';

        CASE state IS
            WHEN ST_RESET =>
                next_state <= ST_FETCH;

            WHEN ST_FETCH =>
                -- fetch first 16-bit instruction word from PM[PC]
                pm_addr_sel <= '0';
                ir_load <= '1';
                next_state <= ST_DECODE;

            WHEN ST_DECODE =>
                -- decide whether this instruction needs a second 16-bit operand word
                IF am = am_immediate OR am = am_direct THEN
                    -- fetch Operand word from PM[PC+1]
                    pm_addr_sel <= '1';
                    op_load <= '1';
                    next_state <= ST_EXEC;
                ELSE
                    -- inherent / register instructions do not need operand fetch
                    next_state <= ST_EXEC;
                END IF;

            WHEN ST_EXEC =>
                next_state <= ST_FETCH;

                -- determine instruction based on opcode
                -- rf_input_sel meanings:
                -- "000" = operand / ir_operand
                -- "001" = DPRR result bit
                -- "011" = ALU output
                -- "100" = MAX output
                -- "101" = SIP hold
                -- "110" = ER
                -- "111" = data memory output
                
                CASE opcode IS
                    WHEN ldr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- LDR Rz #Operand: write fetched operand into Rz
                                reg_write <= '1';
                                rf_input_sel <= "000"; -- "000" = ir_operand

                            WHEN am_register =>
                                -- LDR Rz Rx: write data memory output into Rz
                                reg_write <= '1';
                                rf_input_sel <= "111"; -- dm_out

                            WHEN am_direct =>
                                -- LDR Rz $Operand : write data memory output into Rz
                                reg_write <= '1';
                                rf_input_sel <= "111"; -- dm_out

                            WHEN am_inherent =>
                                NULL;

                            WHEN OTHERS =>
                                NULL;

                        END CASE;

                    WHEN OTHERS =>
                        NULL;
                END CASE;

        END CASE;
    END PROCESS;

END ARCHITECTURE state;