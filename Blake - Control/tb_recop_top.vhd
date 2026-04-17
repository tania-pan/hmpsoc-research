library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.recop_types.all;

entity tb_recop_top is
end entity;

architecture sim of tb_recop_top is

    constant CLK_PERIOD : time := 10 ns;

    signal clk       : bit_1 := '0';
    signal reset     : bit_1 := '0';

    signal sip       : bit_16 := x"0000";
    signal sop       : bit_16;
    signal dpcr      : bit_32;

    signal debug_sel : std_logic_vector(3 downto 0) := "0000";
    signal debug_bus : bit_16;

begin

    dut : entity work.recop_top
        port map (
            clk       => clk,
            reset     => reset,
            sip       => sip,
            sop       => sop,
            dpcr      => dpcr,
            debug_sel => debug_sel,
            debug_bus => debug_bus
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stim : process
    begin
        reset <= '1';
        wait for 25 ns;
        reset <= '0';

        wait for 1 us;
        report "tb_recop_top compile-only simulation reached end";
        wait;
    end process;

end architecture;