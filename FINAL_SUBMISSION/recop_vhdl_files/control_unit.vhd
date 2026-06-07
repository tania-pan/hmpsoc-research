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
        am : IN bit_2;          -- addressing mode
        opcode : IN bit_6;      -- instruction opcode
        z_flag : IN bit_1;      -- used by CLFZ / SUB / SUBV / SZ
        rz_zero : IN bit_1;     -- used by PRESENT

        -- control outputs to datapath
        ir_load : OUT bit_1;    -- load first 16-bit instruction word into IR upper half
        op_load : OUT bit_1;    -- load second 16-bit operand word into IR lower half
        pm_addr_sel : OUT bit_1; -- '0' = use PC, '1' = use PC+1 for PM address

        pc_inc : OUT bit_1; 
        pc_step_sel : OUT bit_1; -- '0' = increment PC by 1, '1' = increment PC by 2
        pc_load : OUT bit_1; 
        pc_from_rx : OUT bit_1; -- '0' = load PC from operand, '1' = load PC from Rx

        reg_write : OUT bit_1;  -- write enable for register file
        rf_input_sel : OUT bit_3; -- select data written into Rz

        alu_operation : OUT bit_3; -- ALU operation select
        alu_op1_sel : OUT bit_2;   -- ALU operand 1 select
        alu_op2_sel : OUT bit_1;   -- ALU operand 2 select
        clr_z_flag : OUT bit_1;    -- clear z flag for CLFZ

        -- data memory control
        dm_wr : OUT bit_1;       -- write enable for STR / STRPC
        dm_addr_sel : OUT bit_2; -- select data-memory address source
        dm_data_sel : OUT bit_2; -- select data-memory write-data source

        -- special-register control
        dpcr_wr : OUT bit_1;       -- write enable for DPCR during DATACALL
        dpcr_lsb_sel : OUT bit_1;  -- '0' = use R7 in DPCR lower half, '1' = use operand
        sop_wr : OUT bit_1;         -- write enable for SOP during SSOP
		  
		  instr_done : out bit_1 -- for debug button 
    );
END ENTITY control_unit;

ARCHITECTURE state OF control_unit IS
    TYPE state_t IS (
        ST_RESET,
        ST_FETCH1_ADDR,  -- present PC on program memory
        ST_FETCH1_LOAD,  -- latch first 16-bit word from program memory
        ST_DECODE,       -- inspect am/opcode from first word
        ST_FETCH2_ADDR,  -- present PC+1 on program memory for operand word
        ST_FETCH2_LOAD,  -- latch second 16-bit operand word
        ST_EXEC,         -- execute instruction
        ST_DM_READ_ADDR, -- present address to synchronous data memory
        ST_DM_READ_LOAD  -- load synchronous data memory read result into regfile
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
		  instr_done <= '0';

        CASE state IS

            ----------------------------------------------------------------
            -- RESET
            ----------------------------------------------------------------
            WHEN ST_RESET =>
                next_state <= ST_FETCH1_ADDR;

            ----------------------------------------------------------------
            -- FETCH FIRST WORD: PRESENT ADDRESS
            -- real program memory is synchronous, so first present address,
            -- then latch returned data in the next state
            ----------------------------------------------------------------
            WHEN ST_FETCH1_ADDR =>
					 instr_done <= '0';
                pm_addr_sel <= '0';   -- use PC
                next_state <= ST_FETCH1_LOAD;

            ----------------------------------------------------------------
            -- FETCH FIRST WORD: LATCH DATA
            ----------------------------------------------------------------
            WHEN ST_FETCH1_LOAD =>
                pm_addr_sel <= '0';   -- still using PC
                ir_load <= '1';       -- load first 16-bit word into IR upper half
                next_state <= ST_DECODE;

            ----------------------------------------------------------------
            -- DECODE
            -- if instruction is immediate or direct, fetch second word
            -- otherwise go straight to execution
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
                pm_addr_sel <= '1';   -- use PC+1
                next_state <= ST_FETCH2_LOAD;

            ----------------------------------------------------------------
            -- FETCH SECOND WORD: LATCH DATA
            ----------------------------------------------------------------
            WHEN ST_FETCH2_LOAD =>
                pm_addr_sel <= '1';   -- still using PC+1
                op_load <= '1';       -- load second 16-bit word into IR lower half
                next_state <= ST_EXEC;

            ----------------------------------------------------------------
            -- EXECUTE
            ----------------------------------------------------------------
            WHEN ST_EXEC =>
                next_state <= ST_FETCH1_ADDR;
					 instr_done <= '1';

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

                -- data memory select assumptions used below:
                --
                -- dm_addr_sel:
                -- "00" = address from Rz
                -- "01" = address from Rx
                -- "10" = address from Operand
                --
                -- dm_data_sel:
                -- "00" = data from Operand
                -- "01" = data from Rx
                -- "10" = data from PC

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
                                -- JMP #Operand
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
                                -- LDR Rz #Operand
                                reg_write <= '1';
                                rf_input_sel <= rf_from_operand;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- LDR Rz Rx
                                -- Rz <- M[Rx]
                                -- synchronous DM read: set address first,
                                -- then load result in ST_DM_READ_LOAD
                                next_state <= ST_DM_READ_ADDR;
										  instr_done <= '0';

                            WHEN am_direct =>
                                -- LDR Rz $Operand
                                -- Rz <- M[Operand]
                                -- synchronous DM read: set address first,
                                -- then load result in ST_DM_READ_LOAD
                                next_state <= ST_DM_READ_ADDR;
										  instr_done <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- STR
                    ----------------------------------------------------------------
                    WHEN str =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- STR Rz #Operand
                                -- M[Rz] <- Operand
                                dm_wr <= '1';
                                dm_addr_sel <= "00"; -- address = Rz
                                dm_data_sel <= "00"; -- data = Operand

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- STR Rz Rx
                                -- M[Rz] <- Rx
                                dm_wr <= '1';
                                dm_addr_sel <= "00"; -- address = Rz
                                dm_data_sel <= "01"; -- data = Rx

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN am_direct =>
                                -- STR Rx $Operand
                                -- M[Operand] <- Rx
                                dm_wr <= '1';
                                dm_addr_sel <= "10"; -- address = Operand
                                dm_data_sel <= "01"; -- data = Rx

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
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- ADD Rz Rz Rx
                                -- Rz = Rz + Rx
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

                    ----------------------------------------------------------------
                    -- AND
                    ----------------------------------------------------------------
                    WHEN andr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- AND Rz Rx Operand
                                -- Rz = Rx AND Operand
                                alu_operation <= alu_and;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- AND Rz Rz Rx
                                -- Rz = Rz AND Rx
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

                    ----------------------------------------------------------------
                    -- OR
                    ----------------------------------------------------------------
                    WHEN orr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- OR Rz Rx Operand
                                -- Rz = Rx OR Operand
                                alu_operation <= alu_or;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- OR Rz Rz Rx
                                -- Rz = Rz OR Rx
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

                    ----------------------------------------------------------------
                    -- SUB
                    ----------------------------------------------------------------
                    WHEN subr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- SUB Rz #Operand
                                -- evaluate Rz - Operand, result not stored
                                alu_operation <= alu_sub;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '1';  -- rz

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- SUBV
                    ----------------------------------------------------------------
                    WHEN subvr =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- SUBV Rz Rx #Operand
                                -- Rz <- Rx - Operand
                                alu_operation <= alu_sub;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '0';  -- rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- PRESENT
                    ----------------------------------------------------------------
                    WHEN present =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- if Rz = 0 then PC <- Operand else NEXT
                                IF rz_zero = '1' THEN
                                    pc_load <= '1';
                                    pc_from_rx <= '0';
                                ELSE
                                    pc_inc <= '1';
                                    pc_step_sel <= '1';
                                END IF;

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- DATACALL
                    ----------------------------------------------------------------
                    WHEN datacall =>
                        CASE am IS
                            WHEN am_register =>
                                -- DATACALL Rx
                                -- DPCR <- Rx & R7
                                dpcr_wr <= '1';
                                dpcr_lsb_sel <= '0';

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN am_immediate =>
                                -- DATACALL Rx #Operand
                                -- DPCR <- Rx & Operand
                                dpcr_wr <= '1';
                                dpcr_lsb_sel <= '1';

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- DATACALL2
                    ----------------------------------------------------------------
                    WHEN datacall2 =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- treated same as DATACALL immediate
                                dpcr_wr <= '1';
                                dpcr_lsb_sel <= '1';

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- SZ
                    ----------------------------------------------------------------
                    WHEN sz =>
                        CASE am IS
                            WHEN am_immediate =>
                                -- if Z = 1 then PC <- Operand else NEXT
                                IF z_flag = '1' THEN
                                    pc_load <= '1';
                                    pc_from_rx <= '0';
                                ELSE
                                    pc_inc <= '1';
                                    pc_step_sel <= '1';
                                END IF;

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- LSIP
                    ----------------------------------------------------------------
                    WHEN lsip =>
                        CASE am IS
                            WHEN am_register =>
                                -- LSIP Rz
                                -- Rz <- SIP
                                reg_write <= '1';
                                rf_input_sel <= rf_from_sip;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- SSOP
                    ----------------------------------------------------------------
                    WHEN ssop =>
                        CASE am IS
                            WHEN am_register =>
                                -- SSOP Rx
                                -- SOP <- Rx
                                sop_wr <= '1';

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- STRPC
                    ----------------------------------------------------------------
                    WHEN strpc =>
                        CASE am IS
                            WHEN am_direct =>
                                -- STRPC $Operand
                                -- M[Operand] <- PC
                                dm_wr <= '1';
                                dm_addr_sel <= "10"; -- address = Operand
                                dm_data_sel <= "10"; -- data = PC

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                    ----------------------------------------------------------------
                    -- CLFZ
                    ----------------------------------------------------------------
                    WHEN clfz =>
                        clr_z_flag <= '1';
                        pc_inc <= '1';
                        pc_step_sel <= '0';

                    ----------------------------------------------------------------
                    -- Completed:
                    -- NOOP, JMP, LDR, STR, ADD, AND, OR, SUB, SUBV,
                    -- PRESENT, DATACALL, SZ, CLFZ, LSIP, SSOP, STRPC, MAX
                    --
                    -- Red slides (not required):
                    -- CER, CEOT, SEOT, LER, SSVOP
                    --
                    -- Not in assignment slides:
                    -- SRES
                    ----------------------------------------------------------------
						  
						  ----------------------------------------------------------------
                    -- MAX
                    ----------------------------------------------------------------
                    WHEN max =>
                        CASE am IS

                            WHEN am_immediate =>
                                -- MAX Rz #Operand
                                -- Rz = max(Rz, Operand)
                                alu_operation <= alu_max;
                                alu_op1_sel <= "01"; -- operand
                                alu_op2_sel <= '1';  -- rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '1';

                            WHEN am_register =>
                                -- MAX Rz Rx
                                -- Rz = max(Rz, Rx)
                                alu_operation <= alu_max;
                                alu_op1_sel <= "00"; -- rx
                                alu_op2_sel <= '1';  -- rz

                                reg_write <= '1';
                                rf_input_sel <= rf_from_alu;

                                pc_inc <= '1';
                                pc_step_sel <= '0';

                            WHEN OTHERS =>
                                NULL;

                        END CASE;

                    WHEN OTHERS =>
                        NULL;
                END CASE;

            ----------------------------------------------------------------
            -- DATA MEMORY READ: PRESENT ADDRESS
            -- needed because data_mem is synchronous, so loads from DM
            -- cannot present address and consume data in the same cycle
            ----------------------------------------------------------------
            WHEN ST_DM_READ_ADDR =>
                CASE opcode IS
                    WHEN ldr =>
                        CASE am IS
                            WHEN am_register =>
                                -- LDR Rz Rx
                                dm_addr_sel <= "01"; -- address = Rx
                                next_state <= ST_DM_READ_LOAD;

                            WHEN am_direct =>
                                -- LDR Rz $Operand
                                dm_addr_sel <= "10"; -- address = Operand
                                next_state <= ST_DM_READ_LOAD;

                            WHEN OTHERS =>
                                next_state <= ST_FETCH1_ADDR;
                        END CASE;

                    WHEN OTHERS =>
                        next_state <= ST_FETCH1_ADDR;
                END CASE;

            ----------------------------------------------------------------
            -- DATA MEMORY READ: LOAD RETURNED DATA
            ----------------------------------------------------------------
            WHEN ST_DM_READ_LOAD =>
                CASE opcode IS
                    WHEN ldr =>
                        CASE am IS
                            WHEN am_register =>
                                -- LDR Rz Rx
                                dm_addr_sel <= "01"; -- address = Rx

                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;

                                pc_inc <= '1';
                                pc_step_sel <= '0';
										  instr_done <= '1';
                                next_state <= ST_FETCH1_ADDR;

                            WHEN am_direct =>
                                -- LDR Rz $Operand
                                dm_addr_sel <= "10"; -- address = Operand

                                reg_write <= '1';
                                rf_input_sel <= rf_from_dm;

                                pc_inc <= '1';
                                pc_step_sel <= '1';
										  instr_done <= '1';
                                next_state <= ST_FETCH1_ADDR;

                            WHEN OTHERS =>
                                next_state <= ST_FETCH1_ADDR;
                        END CASE;
								

                    WHEN OTHERS =>
                        next_state <= ST_FETCH1_ADDR;
                END CASE;
					 


        END CASE;
    END PROCESS;

END ARCHITECTURE state;