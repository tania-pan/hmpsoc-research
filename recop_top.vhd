library ieee;
use ieee.std_logic_1164.all;

use work.recop_types.all;

entity recop_top is
    port (
        clk       : in  bit_1;
        reset     : in  bit_1;

        -- external board I/O
        sip       : in  bit_16;
        sop       : out bit_16;
        dpcr      : out bit_32;

        -- choose which internal signal to view
        debug_sel : in  std_logic_vector(3 downto 0);

        -- one muxed debug bus for LEDs / HEX display logic
        debug_bus : out bit_16
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

    signal dm_wr_s         : bit_1;
    signal dm_addr_sel_s   : bit_2;
    signal dm_data_sel_s   : bit_2;

    signal dpcr_wr_s       : bit_1;
    signal dpcr_lsb_sel_s  : bit_1;
    signal sop_wr_s        : bit_1;

    -- internal debug signals from datapath
    signal dbg_pc_s        : bit_16;
    signal dbg_ir_s        : bit_32;
    signal dbg_rx_s        : bit_16;
    signal dbg_rz_s        : bit_16;
    signal dbg_alu_s       : bit_16;

    signal dbg_r1_s        : bit_16;
    signal dbg_r2_s        : bit_16;
    signal dbg_r3_s        : bit_16;
    signal dbg_r5_s        : bit_16;
    signal dbg_r6_s        : bit_16;
    signal dbg_r7_s        : bit_16;
    signal dbg_r8_s        : bit_16;
    signal dbg_r9_s        : bit_16;
    signal dbg_r11_s       : bit_16;
    signal dbg_r13_s       : bit_16;
    signal dbg_r14_s       : bit_16;
    signal dbg_r15_s       : bit_16;

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

            dbg_pc        => dbg_pc_s,
            dbg_ir        => dbg_ir_s,
            dbg_rx        => dbg_rx_s,
            dbg_rz        => dbg_rz_s,
            dbg_alu       => dbg_alu_s,

            dbg_r1        => dbg_r1_s,
            dbg_r2        => dbg_r2_s,
            dbg_r3        => dbg_r3_s,
            dbg_r5        => dbg_r5_s,
            dbg_r6        => dbg_r6_s,
            dbg_r7        => dbg_r7_s,
            dbg_r8        => dbg_r8_s,
            dbg_r9        => dbg_r9_s,
            dbg_r11       => dbg_r11_s,
            dbg_r13       => dbg_r13_s,
            dbg_r14       => dbg_r14_s,
            dbg_r15       => dbg_r15_s
        );

    -- one selected debug bus to show externally
    with debug_sel select
        debug_bus <= dbg_r1_s        when "0000",
                     dbg_r2_s        when "0001",
                     dbg_r3_s        when "0010",
                     dbg_r5_s        when "0011",
                     dbg_r6_s        when "0100",
                     dbg_r7_s        when "0101",
                     dbg_r8_s        when "0110",
                     dbg_r9_s        when "0111",
                     dbg_r11_s       when "1000",
                     dbg_r13_s       when "1001",
                     dbg_r14_s       when "1010",
                     dbg_r15_s       when "1011",
                     dbg_pc_s        when "1100",
                     dbg_alu_s       when "1101",
                     dbg_rx_s        when "1110",
                     dbg_rz_s        when "1111",
                     X"0000"         when others;

end architecture;