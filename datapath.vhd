library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;
use work.opcodes.all;
use work.various_constants.all;

entity datapath is
    port (
        -- Clock and Reset
        clk           : in  bit_1;
        reset         : in  bit_1;
        
        -- Memory Data Input
        pm_q          : in  bit_16;
        
        -- Control Signals from Control Unit
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

        -- Outputs to Memory and Control Unit
        pm_addr       : out bit_16;
        am            : out bit_2;
        opcode        : out bit_6;
        z_flag        : out bit_1;
        pc_out        : out bit_16;

        -- Debug outputs
        dbg_ir_word   : out bit_16;
        dbg_op        : out bit_16;
        dbg_ir        : out bit_32;
        dbg_rx        : out bit_16;
        dbg_rz        : out bit_16;
        dbg_alu       : out bit_16
    );
end entity;

architecture rtl of datapath is

    -- Internal Registers
    signal pc_reg       : bit_16 := X"0000";
    signal ir_word      : bit_16 := X"0000"; -- Holds AM, Opcode, Rz, Rx
    signal op_word      : bit_16 := X"0000"; -- Holds 16-bit Immediate/Address

    -- Instruction Decoding Signals
    signal ir_am        : bit_2;
    signal ir_opcode    : bit_6;
    signal ir_rz        : bit_4;
    signal ir_rx        : bit_4;

    -- Component connection signals
    signal sel_z_i      : integer range 0 to 15 := 0;
    signal sel_x_i      : integer range 0 to 15 := 0;
    signal rx_s         : bit_16;
    signal rz_s         : bit_16;
    signal alu_result_s : bit_16;
    signal z_flag_s     : bit_1;

    -- Unused component ports tied off
    signal r7_unused    : bit_16;

begin

    --------------------------------------------------------------------
    -- Program Memory Address Multiplexer
    --------------------------------------------------------------------
    -- '0' = point to current PC (to fetch ir_word)
    -- '1' = point to PC + 1 (to fetch op_word)
    pm_addr <= pc_reg when (pm_addr_sel = '0') else 
               std_logic_vector(unsigned(pc_reg) + 1);

    --------------------------------------------------------------------
    -- Instruction Decoding (from 16-bit ir_word)
    --------------------------------------------------------------------
    -- Upper 16 bits of the ReCOP 32-bit instruction
    ir_am      <= ir_word(15 downto 14);
    ir_opcode  <= ir_word(13 downto 8);
    ir_rz      <= ir_word(7 downto 4);
    ir_rx      <= ir_word(3 downto 0);

    am         <= ir_am;
    opcode     <= ir_opcode;

    sel_z_i    <= to_integer(unsigned(ir_rz));
    sel_x_i    <= to_integer(unsigned(ir_rx));

    --------------------------------------------------------------------
    -- Datapath Registers (PC, IR, OP)
    --------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            pc_reg  <= X"0000";
            ir_word <= X"0000";
            op_word <= X"0000";
        elsif rising_edge(clk) then

            -- Fetch instruction word
            if ir_load = '1' then
                ir_word <= pm_q;
            end if;

            -- Fetch operand word
            if op_load = '1' then
                op_word <= pm_q;
            end if;

            -- Program Counter Update Logic
            if pc_load = '1' then
                if pc_from_rx = '1' then
                    pc_reg <= rx_s;         -- Branch/Jump to Rx
                else
                    pc_reg <= op_word;      -- Branch/Jump to Immediate Address
                end if;
            elsif pc_inc = '1' then
                if pc_step_sel = '0' then
                    pc_reg <= std_logic_vector(unsigned(pc_reg) + 1); -- Step 1
                else
                    pc_reg <= std_logic_vector(unsigned(pc_reg) + 2); -- Step 2
                end if;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Instantiate Register File
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

            ir_operand   => op_word,       -- Operand word feeds into RF
            dm_out       => X"0000",       -- Data memory input (tie off until added)
            aluout       => alu_result_s,
            rz_max       => X"0000",
            sip_hold     => X"0000",
            er_temp      => '0',

            r7           => r7_unused,

            dprr_res     => '0',
            dprr_res_reg => '0',
            dprr_wren    => '0'
        );

    --------------------------------------------------------------------
    -- Instantiate ALU
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
            ir_operand    => op_word,      -- Operand word feeds into ALU

            clr_z_flag    => clr_z_flag,
            reset         => reset
        );

    --------------------------------------------------------------------
    -- Output Assignments
    --------------------------------------------------------------------
    z_flag      <= z_flag_s;
    pc_out      <= pc_reg;
    
    -- Debugging
    dbg_ir_word <= ir_word;
    dbg_op      <= op_word;
    dbg_ir      <= ir_word & op_word; -- Combine back into 32-bit for easy viewing
    dbg_rx      <= rx_s;
    dbg_rz      <= rz_s;
    dbg_alu     <= alu_result_s;

end architecture;