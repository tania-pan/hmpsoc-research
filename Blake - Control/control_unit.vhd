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
        am : IN bit_2; -- adressing mode
        opcode : IN bit_6; -- codes for instructions
        z_flag : IN bit_1; -- SZ, SUB, SUBV, CLFZ
        rz_zero : IN bit_1; -- PRESENT: need to know if Rz = 0

        -- control outputs to datapath
        ir_load : OUT bit_1; -- fetch first instr word
        op_load : OUT bit_1; -- fetch second instr word for immediate/direct AMs
        pm_addr_sel : OUT bit_1; -- select PM address: PC or PC+1 depending on AM

        pc_inc : OUT bit_1; 
        pc_step_sel : OUT bit_1; -- '0' for 1-word instruction, '1' for 2-word instruction
        pc_load : OUT bit_1; 
        pc_from_rx : OUT bit_1; -- JMP uses register jump target

        reg_write : OUT bit_1; -- enable writeback to register file
        rf_input_sel : OUT bit_3; -- select RF input: operand, dprr, alu, max, sip, er, dm

        alu_operation : OUT bit_3; -- select ALU operation: add, and, or, sub, subv
        alu_op1_sel : OUT bit_2; -- select ALU operand 1: Rx or Operand
        alu_op2_sel : OUT bit_1; -- select ALU operand 2: Rx or Rz
        clr_z_flag : OUT bit_1; -- for CLFZ instruction

        -- Still required control outputs:
        -- data memory control
        dm_wr : OUT bit_1;          -- write enable for STR / STRPC memory store operations
        dm_addr_sel : OUT bit_2;    -- selects the address source for memory store operations
        dm_data_sel : OUT bit_2;    -- selects the data source for memory store operations

        -- special-register control
        dpcr_wr : OUT bit_1;        -- write enable for DPCR during DATACALL
        dpcr_lsb_sel : OUT bit_1;   -- selects whether DATACALL writes R7 or Operand into the lower half of DPCR
        sop_wr : OUT bit_1          -- write enable for SOP during SSOP
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
    PROCESS (state, opcode, am, z_flag, rz_zero)
    BEGIN
        -- DEFAULTS
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
            WHEN ST_RESET =>
                next_state <= ST_FETCH;

            WHEN ST_FETCH =>
                -- fetch first 16-bit instruction word from PM[PC]
                pm_addr_sel <= '0';
                ir_load <= '1';
                next_state <= ST_DECODE;

            WHEN ST_DECODE =>
                -- immediate/direct instructions need a second 16-bit operand word
                IF am = am_immediate OR am = am_direct THEN
                    pm_addr_sel <= '1';
                    op_load <= '1';
                    next_state <= ST_EXEC;
                ELSE
                    next_state <= ST_EXEC;
                END IF;

            WHEN ST_EXEC =>
                next_state <= ST_FETCH;

                -- rf_input_sel meanings:
                -- rf_from_operand = "000" = operand / ir_operand
                -- rf_from_dprr    = "001" = DPRR result bit
                -- rf_from_alu     = "011" = ALU output
                -- rf_from_max     = "100" = MAX output
                -- rf_from_sip     = "101" = SIP hold
                -- rf_from_er      = "110" = ER
                -- rf_from_dm      = "111" = data memory output

                -- ALU input select meanings:
                -- alu_op1_sel:
                -- "00" = Rx
                -- "01" = Operand
                --
                -- alu_op2_sel:
                -- '0' = Rx
                -- '1' = Rz

                CASE opcode IS
                    ----------------------------------------------------------------
                    -- NOOP
                    ----------------------------------------------------------------
                    WHEN noop =>
                        pc_inc <= '1';
                        pc_step_sel <= '0';

                    ----------------------------------------------------------------
                    -- JMP
                    ----------------------------------------------------------------
                    WHEN jmp =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- JMP Operand
                                pc_load <= '1';
                                pc_from_rx <= '0';

                            WHEN am_register =>
                                -- JMP Rx
                                pc_load <= '1';
                                pc_from_rx <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- LDR
                    ----------------------------------------------------------------
                    WHEN ldr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- LDR Rz #Operand: write fetched operand into Rz
                                reg_write <= '1';
                                rf_input_sel <= rf_from_operand;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- LDR Rz Rx: write data memory output into Rz
                                -- ASSUMPTION: datapath uses Rx as DM address source for register AM
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN am_direct =>
                                -- LDR Rz $Operand: write data memory output into Rz
                                -- ASSUMPTION: datapath uses operand word as DM address source for direct AM
                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- ADD
                    ----------------------------------------------------------------
                    WHEN addr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- ADD Rz Rx Operand
                                -- Rz = Rx + Operand
                                alu_operation <= alu_add;
                                alu_op1_sel <= "01"; -- Operand
                                alu_op2_sel <= '0';  -- Rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- ADD Rz Rz Rx
                                -- Rz = Rz + Rx
                                alu_operation <= alu_add;
                                alu_op1_sel <= "00"; -- Rx
                                alu_op2_sel <= '1';  -- Rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- AND
                    ----------------------------------------------------------------
                    WHEN andr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- AND Rz Rx Operand
                                -- Rz = Rx AND Operand
                                alu_operation <= alu_and;
                                alu_op1_sel <= "01"; -- Operand
                                alu_op2_sel <= '0';  -- Rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- AND Rz Rz Rx
                                -- Rz = Rz AND Rx
                                alu_operation <= alu_and;
                                alu_op1_sel <= "00"; -- Rx
                                alu_op2_sel <= '1';  -- Rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- OR
                    ----------------------------------------------------------------
                    WHEN orr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- OR Rz Rx Operand
                                -- Rz = Rx OR Operand
                                alu_operation <= alu_or;
                                alu_op1_sel <= "01"; -- Operand
                                alu_op2_sel <= '0';  -- Rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- OR Rz Rz Rx
                                -- Rz = Rz OR Rx
                                alu_operation <= alu_or;
                                alu_op1_sel <= "00"; -- Rx
                                alu_op2_sel <= '1';  -- Rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- CFLZ
                    ----------------------------------------------------------------
                    WHEN clfz =>
                        clr_z_flag <= '1';
                        pc_inc <= '1';
                        pc_step_sel <= '0';

                    ----------------------------------------------------------------
                    -- STR
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- SUBV
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- SUB
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- PRESENT
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- DATACALL
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- SZ
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- LSIP
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- SSOP
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- STRPC
                    ----------------------------------------------------------------

                    ----------------------------------------------------------------
                    -- Completed:
                    -- NOOP, JMP, LDR, ADD, AND, OR, CLFZ
                    --
                    -- Still required:
                    -- STR, SUBV, SUB, PRESENT, DATACALL, SZ, LSIP, SSOP, STRPC, 
                    --
                    -- Red slides (not required):
                    -- CER, CEOT, SEOT, LER, SSVOP, MAX
                    --
                    -- Not in assignment slides:
                    -- SRES
                    --
                    ----------------------------------------------------------------

                    WHEN OTHERS =>
                        NULL;
                END CASE;

        END CASE;
    END PROCESS;

END ARCHITECTURE state;