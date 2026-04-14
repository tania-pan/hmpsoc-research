library ieee;
use ieee.std_logic_1164.all;

use work.recop_types.all;
use work.opcodes.all;
use work.various_constants.all;

entity control_unit is
    port (
        -- Clock and Reset
        clk           : in  bit_1;
        reset         : in  bit_1;

        -- Inputs from Datapath
        am            : in  bit_2;
        opcode        : in  bit_6;
        z_flag        : in  bit_1;

        -- Outputs to Datapath
        ir_load       : out bit_1;
        op_load       : out bit_1;
        pm_addr_sel   : out bit_1;
        pc_inc        : out bit_1;
        pc_step_sel   : out bit_1;
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

architecture stub of control_unit is
begin
    -- =========================================================
    -- DUMMY ARCHITECTURE: Ties everything to 0 to pass compile
    -- Person 2 will replace this block with their State Machine
    -- =========================================================
    ir_load       <= '0';
    op_load       <= '0';
    pm_addr_sel   <= '0';
    pc_inc        <= '0';
    pc_step_sel   <= '0';
    pc_load       <= '0';
    pc_from_rx    <= '0';
    reg_write     <= '0';
    rf_input_sel  <= "000";
    alu_operation <= "000";
    alu_op1_sel   <= "00";
    alu_op2_sel   <= '0';
    clr_z_flag    <= '0';

end architecture;