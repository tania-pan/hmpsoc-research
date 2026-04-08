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

        -- control signals from control unit
        ir_load       : in  bit_1;
        pc_inc        : in  bit_1;
        pc_load       : in  bit_1;
        pc_from_rx    : in  bit_1;

        reg_write     : in  bit_1;
        rf_input_sel  : in  bit_3;

        alu_operation : in  bit_3;
        alu_op1_sel   : in  bit_2;
        alu_op2_sel   : in  bit_1;
        clr_z_flag    : in  bit_1;

        -- decoded fields out to control unit
        am            : out bit_2;
        opcode        : out bit_6;

        -- debug outputs
        dbg_pc        : out bit_16;
        dbg_ir        : out bit_32;
        dbg_rx        : out bit_16;
        dbg_rz        : out bit_16;
        dbg_alu       : out bit_16
    );
end entity;

architecture rtl of datapath is

    --------------------------------------------------------------------
    -- Tiny built-in 32-bit instruction ROM for bring-up
    -- Replace this later with proper program memory.
    --------------------------------------------------------------------
    type rom_t is array (0 to 15) of bit_32;

    constant program_rom : rom_t := (
        -- 0: LDR R1, #5
        0  => am_immediate & ldr  & X"1" & X"0" & X"0005",

        -- 1: ADD R2, R1, #3   => R2 = 8
        1  => am_immediate & addr & X"2" & X"1" & X"0003",

        -- 2: NOOP
        2  => am_inherent  & noop & X"0" & X"0" & X"0000",

        -- 3: JMP #3   (loop forever)
        3  => am_immediate & jmp  & X"0" & X"0" & X"0003",

        others => X"00000000"
    );

    signal pc_reg       : bit_16 := X"0000";
    signal ir_reg       : bit_32 := X"00000000";

    signal ir_am        : bit_2;
    signal ir_opcode    : bit_6;
    signal ir_rz        : bit_4;
    signal ir_rx        : bit_4;
    signal ir_operand   : bit_16;

    signal sel_z_i      : integer range 0 to 15 := 0;
    signal sel_x_i      : integer range 0 to 15 := 0;

    signal rx_s         : bit_16;
    signal rz_s         : bit_16;
    signal r7_unused    : bit_16;

    signal alu_result_s : bit_16;
    signal z_flag_unused: bit_1;

begin

    --------------------------------------------------------------------
    -- Decode fields from current instruction register
    --------------------------------------------------------------------
    ir_am      <= ir_reg(31 downto 30);
    ir_opcode  <= ir_reg(29 downto 24);
    ir_rz      <= ir_reg(23 downto 20);
    ir_rx      <= ir_reg(19 downto 16);
    ir_operand <= ir_reg(15 downto 0);

    am     <= ir_am;
    opcode <= ir_opcode;

    sel_z_i <= to_integer(unsigned(ir_rz));
    sel_x_i <= to_integer(unsigned(ir_rx));

    --------------------------------------------------------------------
    -- PC and IR registers
    --------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            pc_reg <= X"0000";
            ir_reg <= X"00000000";
        elsif rising_edge(clk) then

            -- fetch current instruction into IR
            if ir_load = '1' then
                ir_reg <= program_rom(to_integer(unsigned(pc_reg(3 downto 0))));
            end if;

            -- update PC
            if pc_load = '1' then
                if pc_from_rx = '1' then
                    pc_reg <= rx_s;         -- JMP Rx
                else
                    pc_reg <= ir_operand;   -- JMP #addr
                end if;
            elsif pc_inc = '1' then
                pc_reg <= std_logic_vector(unsigned(pc_reg) + 1);
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- General-purpose register file
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
            dm_out       => X"0000",       -- not used yet
            aluout       => alu_result_s,
            rz_max       => X"0000",       -- not used yet
            sip_hold     => X"0000",       -- not used yet
            er_temp      => '0',           -- not used yet

            r7           => r7_unused,

            dprr_res     => '0',
            dprr_res_reg => '0',
            dprr_wren    => '0'
        );

    --------------------------------------------------------------------
    -- ALU
    --------------------------------------------------------------------
    u_alu : entity work.alu
        port map (
            clk           => clk,
            z_flag        => z_flag_unused,
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
    -- Debug outputs
    --------------------------------------------------------------------
    dbg_pc  <= pc_reg;
    dbg_ir  <= ir_reg;
    dbg_rx  <= rx_s;
    dbg_rz  <= rz_s;
    dbg_alu <= alu_result_s;

end architecture;