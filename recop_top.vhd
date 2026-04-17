library ieee;
use ieee.std_logic_1164.all;

use work.recop_types.all;

entity recop_top is
    port (
        clk      : in  bit_1;
        reset    : in  bit_1;

        -- debug outputs
        dbg_pc   : out bit_16;
        dbg_ir   : out bit_32;
        dbg_rx   : out bit_16;
        dbg_rz   : out bit_16;
        dbg_alu  : out bit_16;
          
        -- External I/O for the FPGA Board
        sip      : in  bit_16;
        sop      : out bit_16;
        dpcr     : out bit_32
    );
end entity;

architecture rtl of recop_top is

    signal am_s            : bit_2;
    signal opcode_s        : bit_6;
    signal z_flag_s        : bit_1;
    signal rz_zero_s       : bit_1;

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

    -- data memory control (currently unused inside datapath)
    signal dm_wr_s         : bit_1;
    signal dm_addr_sel_s   : bit_2;
    signal dm_data_sel_s   : bit_2;

    -- special register control
    signal dpcr_wr_s       : bit_1;
    signal dpcr_lsb_sel_s  : bit_1;
    signal sop_wr_s        : bit_1;

begin

    u_control : entity work.control_unit
        port map (
            clk           => clk,
            reset         => reset,

            am            => am_s,
            opcode        => opcode_s,
            z_flag        => z_flag_s,
            rz_zero       => rz_zero_s,

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

            dm_wr         => dm_wr_s,
            dm_addr_sel   => dm_addr_sel_s,
            dm_data_sel   => dm_data_sel_s,

            dpcr_wr       => dpcr_wr_s,
            dpcr_lsb_sel  => dpcr_lsb_sel_s,
            sop_wr        => sop_wr_s
        );

    u_datapath : entity work.datapath
        port map (
            clk           => clk,
            reset         => reset,

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

            dm_wr         => dm_wr_s,
            dm_addr_sel   => dm_addr_sel_s,
            dm_data_sel   => dm_data_sel_s,

            dpcr_wr       => dpcr_wr_s,
            dpcr_lsb_sel  => dpcr_lsb_sel_s,
            sop_wr        => sop_wr_s,

            sip           => sip,
            sop           => sop,
            dpcr          => dpcr,

            am            => am_s,
            opcode        => opcode_s,
            z_flag        => z_flag_s,
            rz_zero       => rz_zero_s,

            dbg_pc        => dbg_pc,
            dbg_ir        => dbg_ir,
            dbg_rx        => dbg_rx,
            dbg_rz        => dbg_rz,
            dbg_alu       => dbg_alu
        );

end architecture;