library ieee;
use ieee.std_logic_1164.all;

use work.recop_types.all;
use work.opcodes.all;
use work.various_constants.all;

entity control_unit is
    port (
        clk           : in  bit_1;
        reset         : in  bit_1;

        -- decoded instruction fields from datapath
        am            : in  bit_2;
        opcode        : in  bit_6;

        -- control outputs to datapath
        ir_load       : out bit_1;
        pc_inc        : out bit_1;
        pc_load       : out bit_1;
        pc_from_rx    : out bit_1;

        reg_write     : out bit_1;
        rf_input_sel  : out bit_3;

        alu_operation : out bit_3;
        alu_op1_sel   : out bit_2;
        alu_op2_sel   : out bit_1;

        clr_z_flag    : out bit_1
    );
end entity;

architecture rtl of control_unit is
    type state_t is (ST_RESET, ST_FETCH, ST_EXEC);
    signal state, next_state : state_t;
begin

    -- state register
    process(clk, reset)
    begin
        if reset = '1' then
            state <= ST_RESET;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    -- next state logic
    process(state)
    begin
        case state is
            when ST_RESET =>
                next_state <= ST_FETCH;
            when ST_FETCH =>
                next_state <= ST_EXEC;
            when ST_EXEC  =>
                next_state <= ST_FETCH;
            when others   =>
                next_state <= ST_FETCH;
        end case;
    end process;

    -- output logic
    process(state, am, opcode)
    begin
        -- defaults
        ir_load       <= '0';
        pc_inc        <= '0';
        pc_load       <= '0';
        pc_from_rx    <= '0';

        reg_write     <= '0';
        rf_input_sel  <= "000";     -- regfile input mux

        alu_operation <= alu_idle;
        alu_op1_sel   <= "00";
        alu_op2_sel   <= '1';

        clr_z_flag    <= '0';

        case state is
            when ST_RESET =>
                null;

            when ST_FETCH =>
                -- load IR from ROM at current PC
                ir_load <= '1';

            when ST_EXEC =>
                case opcode is

                    -- NOOP
                    when noop =>
                        pc_inc <= '1';

                    -- LDR Rz #imm
                    when ldr =>
                        if am = am_immediate then
                            reg_write    <= '1';
                            rf_input_sel <= "000";  -- write immediate to Rz
                        end if;
                        pc_inc <= '1';

                    -- ADD
                    when addr =>
                        reg_write     <= '1';
                        rf_input_sel  <= "011";     -- write ALU output to Rz
                        alu_operation <= alu_add;

                        if am = am_immediate then
                            -- Rz <- Rx + immediate
                            alu_op1_sel <= "01";    -- operand_1 = imm
                            alu_op2_sel <= '0';     -- operand_2 = Rx
                        elsif am = am_register then
                            -- Rz <- Rz + Rx
                            alu_op1_sel <= "00";    -- operand_1 = Rx
                            alu_op2_sel <= '1';     -- operand_2 = Rz
                        end if;

                        pc_inc <= '1';

                    -- JMP
                    when jmp =>
                        pc_load <= '1';

                        if am = am_register then
                            -- JMP Rx
                            pc_from_rx <= '1';
                        else
                            -- JMP #addr
                            pc_from_rx <= '0';
                        end if;

                    when others =>
                        -- unsupported instructions just step to next instruction
                        pc_inc <= '1';
                end case;

            when others =>
                null;
        end case;
    end process;

end architecture;