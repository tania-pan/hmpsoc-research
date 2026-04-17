library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.opcodes.all;
use work.various_constants.all;

entity datapath is
    port (
        clk           : in  bit_1;
        reset         : in  bit_1;

        ir_load       : in  bit_1;
        op_load       : in  bit_1;
        pm_addr_sel   : in  bit_1;

        pc_inc        : in  bit_1;
        pc_step_sel   : in  bit_1;
        pc_load       : in  bit_1;
        pc_from_rx    : in  bit_1;

        reg_write     : in  bit_1;
        rf_input_sel  : in  bit_3;

        alu_operation : in  bit_3;
        alu_op1_sel   : in  bit_2;
        alu_op2_sel   : in  bit_1;
        clr_z_flag    : in  bit_1;

        dm_wr         : in  bit_1;
        dm_addr_sel   : in  bit_2;
        dm_data_sel   : in  bit_2;

        dpcr_lsb_sel  : in  bit_1;
        dpcr_wr       : in  bit_1;
        sop_wr        : in  bit_1;

        sip           : in  bit_16;
        sop           : out bit_16;
        dpcr          : out bit_32;

        am            : out bit_2;
        opcode        : out bit_6;
        z_flag        : out bit_1;
        rz_zero       : out bit_1;

        dbg_pc        : out bit_16;
        dbg_ir        : out bit_32;
        dbg_rx        : out bit_16;
        dbg_rz        : out bit_16;
        dbg_alu       : out bit_16;

        dbg_r1        : out bit_16;
        dbg_r2        : out bit_16;
        dbg_r3        : out bit_16;
        dbg_r5        : out bit_16;
        dbg_r6        : out bit_16;
        dbg_r7        : out bit_16;
        dbg_r8        : out bit_16;
        dbg_r9        : out bit_16;
        dbg_r11       : out bit_16;
        dbg_r13       : out bit_16;
        dbg_r14       : out bit_16;
        dbg_r15       : out bit_16
    );
end entity;

architecture rtl of datapath is

    signal pc_reg         : bit_16 := X"0000";
    signal ir_reg         : bit_32 := X"00000000";

    signal ir_am          : bit_2;
    signal ir_opcode      : bit_6;
    signal ir_rz          : bit_4;
    signal ir_rx          : bit_4;
    signal ir_operand     : bit_16;

    signal sel_z_i        : integer range 0 to 15 := 0;
    signal sel_x_i        : integer range 0 to 15 := 0;

    signal rx_s           : bit_16;
    signal rz_s           : bit_16;

    signal alu_result_s   : bit_16;
    signal z_flag_s       : bit_1;

    -- DATA MEMORY SIGNALS
    signal dm_addr_s      : std_logic_vector(11 downto 0);
    signal dm_data_s      : std_logic_vector(15 downto 0);
    signal dm_q_s         : std_logic_vector(15 downto 0);
    signal dm_out_s       : bit_16;

    signal r7_s           : bit_16;
    signal er_dummy_s     : bit_1;
    signal eot_dummy_s    : bit_1;
    signal svop_dummy_s   : bit_16;
    signal sip_r_s        : bit_16;
    signal dprr_dummy_s   : bit_2 := (others => '0');

    signal rz_max_s       : bit_16 := X"0000";

    signal pm_addr_s      : std_logic_vector(14 downto 0);
    signal pm_q_s         : std_logic_vector(15 downto 0);

    -- fixed register debug signals
    signal dbg_r1_s       : bit_16;
    signal dbg_r2_s       : bit_16;
    signal dbg_r3_s       : bit_16;
    signal dbg_r5_s       : bit_16;
    signal dbg_r6_s       : bit_16;
    signal dbg_r7_s       : bit_16;
    signal dbg_r8_s       : bit_16;
    signal dbg_r9_s       : bit_16;
    signal dbg_r11_s      : bit_16;
    signal dbg_r13_s      : bit_16;
    signal dbg_r14_s      : bit_16;
    signal dbg_r15_s      : bit_16;

begin
	
    --------------------------------------------------------------------
    -- PROGRAM MEMORY
    --------------------------------------------------------------------
    u_prog_mem : entity work.prog_mem
        port map (
            address => pm_addr_s,
            clock   => clk,
            q       => pm_q_s
        );

    pm_addr_s <= std_logic_vector(unsigned(pc_reg(14 downto 0)) + 1)
                 when pm_addr_sel = '1'
                 else std_logic_vector(pc_reg(14 downto 0));

    --------------------------------------------------------------------
    -- DATA MEMORY
    --------------------------------------------------------------------
    u_data_mem : entity work.data_mem
        port map (
            address => dm_addr_s,
            clock   => clk,
            data    => dm_data_s,
            wren    => dm_wr,
            q       => dm_q_s
        );

    dm_out_s <= bit_16(dm_q_s);

    -- address mux
    with dm_addr_sel select
        dm_addr_s <= std_logic_vector(rz_s(11 downto 0))        when "00",
                     std_logic_vector(rx_s(11 downto 0))        when "01",
                     std_logic_vector(ir_operand(11 downto 0))  when "10",
                     (others => '0')                           when others;
							
    -- data mux (write data)
    with dm_data_sel select
        dm_data_s <= std_logic_vector(ir_operand) when "00",
                     std_logic_vector(rx_s)       when "01",
                     std_logic_vector(pc_reg)     when "10",
                     (others => '0')              when others;
	

	--------------------------------------------------------------------
    -- ALU
    --------------------------------------------------------------------
    u_alu : entity work.alu
        port map (
            clk           => clk,
            z_flag        => z_flag_s,
            alu_operation => alu_operation,
            alu_op1_sel   => alu_op1_sel,
            alu_op2_sel   => alu_op2_sel,
            alu_carry     => '0',
            alu_result    => alu_result_s,

            rx            => rx_s,
            rz            => rz_s,
            ir_operand    => ir_operand,

            clr_z_flag    => clr_z_flag,
            reset         => reset
        );


    --------------------------------------------------------------------
    -- IR DECODE
    --------------------------------------------------------------------
    ir_am      <= ir_reg(31 downto 30);
    ir_opcode  <= ir_reg(29 downto 24);
    ir_rz      <= ir_reg(23 downto 20);
    ir_rx      <= ir_reg(19 downto 16);
    ir_operand <= ir_reg(15 downto 0);

    am      <= ir_am;
    opcode  <= ir_opcode;
    z_flag  <= z_flag_s;
    rz_zero <= '1' when rz_s = X"0000" else '0';

    sel_z_i <= to_integer(unsigned(ir_rz));
    sel_x_i <= to_integer(unsigned(ir_rx));

    --------------------------------------------------------------------
    -- PC / IR REGISTERS
    --------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            pc_reg <= X"0000";
            ir_reg <= X"00000000";

        elsif rising_edge(clk) then

            if ir_load = '1' then
                ir_reg(31 downto 16) <= pm_q_s;
                ir_reg(15 downto 0)  <= X"0000";
            end if;

            if op_load = '1' then
                ir_reg(15 downto 0) <= pm_q_s;
            end if;

            if pc_load = '1' then
                if pc_from_rx = '1' then
                    pc_reg <= rx_s;
                else
                    pc_reg <= ir_operand;
                end if;

            elsif pc_inc = '1' then
                if pc_step_sel = '1' then
                    pc_reg <= std_logic_vector(unsigned(pc_reg) + 2);
                else
                    pc_reg <= std_logic_vector(unsigned(pc_reg) + 1);
                end if;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- REGFILE
    --------------------------------------------------------------------
    u_regfile : entity work.regfile
        port map (
            clk          => clk,
            init         => reset,
            ld_r         => reg_write,
            sel_z        => sel_z_i,
            sel_x        => sel_x_i,
            rx           => rx_s,
            rz           => rz_s,
            rf_input_sel => rf_input_sel,
            ir_operand   => ir_operand,
            dm_out       => dm_out_s,
            aluout       => alu_result_s,
            rz_max       => rz_max_s,
            sip_hold     => sip_r_s,
            er_temp      => er_dummy_s,
            r7           => r7_s,
            dprr_res     => dprr_dummy_s(0),
            dprr_res_reg => dprr_dummy_s(0),
            dprr_wren    => '0',
				r1_dbg  => dbg_r1_s,
				r2_dbg  => dbg_r2_s,
				r3_dbg  => dbg_r3_s,
				r5_dbg  => dbg_r5_s,
				r6_dbg  => dbg_r6_s,
				r7_dbg  => dbg_r7_s,
				r8_dbg  => dbg_r8_s,
				r9_dbg  => dbg_r9_s,
				r11_dbg => dbg_r11_s,
				r13_dbg => dbg_r13_s,
				r14_dbg => dbg_r14_s,
				r15_dbg => dbg_r15_s
        );


    --------------------------------------------------------------------
    -- SPECIAL REGISTERS
    --------------------------------------------------------------------
    u_registers : entity work.registers
        port map (
            clk          => clk,
            reset        => reset,

            dpcr         => dpcr,
            r7           => r7_s,
            rx           => rx_s,
            ir_operand   => ir_operand,
            dpcr_lsb_sel => dpcr_lsb_sel,
            dpcr_wr      => dpcr_wr,

            er           => er_dummy_s,
            er_wr        => '0',
            er_clr       => '0',

            eot          => eot_dummy_s,
            eot_wr       => '0',
            eot_clr      => '0',

            svop         => svop_dummy_s,
            svop_wr      => '0',

            sip_r        => sip_r_s,
            sip          => sip,

            sop          => sop,
            sop_wr       => sop_wr,

            dprr         => dprr_dummy_s,
            irq_wr       => '0',
            irq_clr      => '0',
            result_wen   => '0',
            result       => z_flag_s
        );

    --------------------------------------------------------------------
    -- DEBUG
    --------------------------------------------------------------------
    dbg_pc  <= pc_reg;
    dbg_ir  <= ir_reg;
    dbg_rx  <= rx_s;
    dbg_rz  <= rz_s;
    dbg_alu <= alu_result_s;
	 
	 
	 dbg_r1  <= dbg_r1_s;
	dbg_r2  <= dbg_r2_s;
	dbg_r3  <= dbg_r3_s;
	dbg_r5  <= dbg_r5_s;
	dbg_r6  <= dbg_r6_s;
	dbg_r7  <= dbg_r7_s;
	dbg_r8  <= dbg_r8_s;
	dbg_r9  <= dbg_r9_s;
	dbg_r11 <= dbg_r11_s;
	dbg_r13 <= dbg_r13_s;
	dbg_r14 <= dbg_r14_s;
	dbg_r15 <= dbg_r15_s;

end architecture;

