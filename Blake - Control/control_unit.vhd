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
        pc_step_sel : OUT bit_1; -- '0' for 1-word instruction, '1' for 2-word instruction
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
        pc_step_sel <= '0';
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
                -- rf_from_operand = "000" = operand / ir_operand
                -- rf_from_dprr = "001" = DPRR result bit
                -- rf_from_alu = "011" = ALU output
                -- rf_from_max = "100" = MAX output
                -- rf_from_sip = "101" = SIP hold
                -- rf_from_er = "110" = ER
                -- rf_from_dm = "111" = data memory output

                -- ALU operation codes:
                -- op1:
                -- "00" = Rx
                -- "01" = Operand
                -- op2:
                -- '0' = Rx
                -- '1' = Rz

                CASE opcode IS
                    WHEN noop =>
                        pc_inc <= '1';
                        pc_step_sel <= '0'; 

                    WHEN jmp =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- JMP #Operand: PC = Operand
                                pc_load <= '1';
                                pc_from_rx <= '0'; -- from operand

                            WHEN am_register =>
                                -- JMP Rx: PC = Rx
                                pc_load <= '1';
                                pc_from_rx <= '1'; -- from register

                            WHEN OTHERS =>
                                NULL;

                        END CASE;

                    WHEN ldr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- LDR Rz #Operand: write fetched operand into Rz
                                reg_write <= '1';
                                rf_input_sel <= rf_from_operand; -- operand from instruction word

                                pc_inc <= '1';
                                pc_step_sel <= '1'; -- 2-word instruction

                            WHEN am_register =>
                                -- LDR Rz Rx: write data memory output into Rz
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm; -- data memory output

                                pc_inc <= '1';
                                pc_step_sel <= '0'; -- 1-word instruction

                            WHEN am_direct =>
                                -- LDR Rz $Operand : write data memory output into Rz
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm; -- data memory output

                                pc_inc <= '1';
                                pc_step_sel <= '1'; -- 2-word instruction

                            WHEN OTHERS =>
                                NULL;

                        END CASE;
                    
                    WHEN addr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- ADD Rz Rx Operand
                                -- Rz = Rx + Operand
                                alu_operation <= alu_add; -- add
                                alu_op1_sel <= "01"; -- Operand
                                alu_op2_sel <= '0'; -- Rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu; -- ALU output

                                pc_inc <= '1';
                                pc_step_sel <= '1'; -- 2-word instruction

                            WHEN am_register =>
                                -- ADD Rz Rz Rx
                                -- Rz = Rz + Rx
                                alu_operation <= alu_add; -- add
                                alu_op1_sel <= "00"; -- Rx
                                alu_op2_sel <= '1'; -- Rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu; -- ALU output

                                pc_inc <= '1';
                                pc_step_sel <= '0'; -- 1-word instruction

                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                                
                    WHEN OTHERS =>
                        NULL;
                END CASE;

        END CASE;
    END PROCESS;

END ARCHITECTURE state;