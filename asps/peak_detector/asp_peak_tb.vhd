library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asp_peak_tb is
end entity;

architecture sim of asp_peak_tb is

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    
    signal noc_recv     : std_logic_vector(39 downto 0) := (others => '0');
    signal noc_send     : std_logic_vector(39 downto 0);
    signal noc_ready    : std_logic := '1';

    constant clk_period : time := 20 ns; -- 50MHz

begin

    uut: entity work.asp_peak
        port map (
            clk       => clk,
            reset     => reset,
            noc_recv  => noc_recv,
            noc_send  => noc_send,
            noc_ready => noc_ready
        );

    clk_process : process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    sim_process: process
    begin
        -- starts in reset
        reset <= '0';
        noc_recv <= (others => '0');
        wait for 100 ns;
        
        -- release reset
        reset <= '1';
        wait for clk_period * 5;

        -- send config packet
        noc_recv <= x"80F0020000"; 
        wait for clk_period;
        noc_recv <= (others => '0');
        wait for clk_period * 5;

        -- creating a wave: 100 -> 500 -> 1023 -> 800
        
        -- sample 1: amplitude 100 (hex: x"0064")
        noc_recv <= x"8000000064"; wait for clk_period;
        noc_recv <= (others => '0'); wait for clk_period * 5;

        -- sample 2: smplitude 500 (hex: x"01F4")
        noc_recv <= x"80000001F4"; wait for clk_period;
        noc_recv <= (others => '0'); wait for clk_period * 5;

        -- sample 3: amplitude 1023 (hex: x"03FF")
        noc_recv <= x"80000003FF"; wait for clk_period;
        noc_recv <= (others => '0'); wait for clk_period * 5;

        -- sample 4: amplitude 800 (hex: x"0320")
        noc_recv <= x"8000000320"; wait for clk_period;
        noc_recv <= (others => '0'); wait for clk_period * 15;

        wait;
    end process;

end architecture;