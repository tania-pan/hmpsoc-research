library ieee;
use ieee.std_logic_1164.all;

use work.recop_types.all;

entity recop_top is
    port (
        clk         : in  bit_1;
        reset       : in  bit_1;

        -- Updated debug outputs
        dbg_pc      : out bit_16;
        dbg_ir_word : out bit_16;
        dbg_op      : out bit_16;
        dbg_ir      : out bit_32;
        dbg_rx      : out bit_16;
        dbg_rz      : out bit_16;
        dbg_alu     : out bit_16
    );
end entity;

architecture rtl of recop_top is

    -- ==========================================
    -- Interconnect Signals (Control <-> Datapath)
    -- ==========================================
    signal am_s            : bit_2;
    signal opcode_s        : bit_6;
    signal z_flag_s        : bit_1;

    signal ir_load_s       : bit_1;
    signal op_load_s       : bit_1;
    signal pm_addr_sel_s   : bit_1;
    signal pc_inc_s        : bit_1;
    signal pc_step_sel_s   : bit_1;
    signal pc_load_s       : bit_1;
    signal pc_from_rx_s    : bit_1;

    signal reg_write_s     : bit_1;
    signal rf_input_sel_s  : bit_3;

    signal alu_operation_s : bit_3;
    signal alu_op1_sel_s   : bit_2;
    signal alu_op2_sel_s   : bit_1;
    signal clr_z_flag_s    : bit_1;

    -- ==========================================
    -- Memory Signals (Datapath <-> Memory)
    -- ==========================================
    signal pm_addr_s       : bit_16;
    signal pm_q_s          : bit_16;
    
begin

    --------------------------------------------------------------------
    -- 1. Control Unit
    --------------------------------------------------------------------
    u_control : entity work.control_unit
        port map (
            clk           => clk,
            reset         => reset,
            
            am            => am_s,
            opcode        => opcode_s,
            z_flag        => z_flag_s,

            ir_load       => ir_load_s,
            op_load       => op_load_s,
            pm_addr_sel   => pm_addr_sel_s,
            pc_inc        => pc_inc_s,
            pc_step_sel   => pc_step_sel_s,
            pc_load       => pc_load_s,
            pc_from_rx    => pc_from_rx_s,
            reg_write     => reg_write_s,
            rf_input_sel  => rf_input_sel_s,
            alu_operation => alu_operation_s,
            alu_op1_sel   => alu_op1_sel_s,
            alu_op2_sel   => alu_op2_sel_s,
            clr_z_flag    => clr_z_flag_s
        );

    --------------------------------------------------------------------
    -- 2. Datapath
    --------------------------------------------------------------------
    u_datapath : entity work.datapath
        port map (
            clk           => clk,
            reset         => reset,

            pm_q          => pm_q_s,

            ir_load       => ir_load_s,
            op_load       => op_load_s,
            pm_addr_sel   => pm_addr_sel_s,
            pc_inc        => pc_inc_s,
            pc_step_sel   => pc_step_sel_s,
            pc_load       => pc_load_s,
            pc_from_rx    => pc_from_rx_s,
            reg_write     => reg_write_s,
            rf_input_sel  => rf_input_sel_s,
            alu_operation => alu_operation_s,
            alu_op1_sel   => alu_op1_sel_s,
            alu_op2_sel   => alu_op2_sel_s,
            clr_z_flag    => clr_z_flag_s,

            pm_addr       => pm_addr_s,
            am            => am_s,
            opcode        => opcode_s,
            z_flag        => z_flag_s,
            pc_out        => open, -- Not used at top level currently

            dbg_ir_word   => dbg_ir_word,
            dbg_op        => dbg_op,
            dbg_ir        => dbg_ir,
            dbg_rx        => dbg_rx,
            dbg_rz        => dbg_rz,
            dbg_alu       => dbg_alu
        );

    --------------------------------------------------------------------
    -- 3. Simulation Memory 
    --------------------------------------------------------------------
    u_memory : entity work.memory
        port map (
            clk        => clk,
            
            -- Instruction Fetch Connections
            pm_address => pm_addr_s,
            pm_outdata => pm_q_s,
            
            -- Data Memory Connections (Tied off until Load/Store logic is added)
            dm_address => X"0000",
            dm_outdata => open,
            dm_wr      => '0',
            dm_indata  => X"0000"
        );

end architecture;