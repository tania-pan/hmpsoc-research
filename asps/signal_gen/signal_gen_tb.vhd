library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_gen_tb is
end entity;

architecture sim of signal_gen_tb is
    signal clk          : std_logic := '0';
    signal reset_n      : std_logic := '0';
    signal tick_16khz   : std_logic := '0';
    signal signal_out   : std_logic_vector(9 downto 0);
    signal data_ready   : std_logic;

    constant clk_period : time := 20 ns; -- 50MHz clock
begin

    uut: entity work.signal_gen
        port map (
            clk        => clk,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            signal_out => signal_out,
            data_ready => data_ready
        );

    clk_process : process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    sim_process : process
    begin
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for clk_period * 5;

        for i in 1 to 2000 loop
            tick_16khz <= '1';
            wait for clk_period;
            tick_16khz <= '0';
            
            wait for clk_period * 3; 
        end loop;

        report "Simulation finished successfully.";
        wait;
    end process;

end architecture;