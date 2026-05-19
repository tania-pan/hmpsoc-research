library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity peak_detector_tb is
end entity;

architecture sim of peak_detector_tb is

	signal clk           	: std_logic := '0';
   signal reset       		: std_logic := '0';
   signal current_corr  	: unsigned(31 downto 0) := (others => '0');
   signal data_ready    	: std_logic := '0';
   signal avalon_read   	: std_logic := '0';    signal peak_detected : std_logic;
   signal avalon_readdata	: std_logic_vector(31 downto 0);

   constant clk_period  	: time := 20 ns; -- 50MHz
	 
begin

   uut: entity work.peak_detector
		port map (
			clk             	=> clk,
			reset           	=> reset,
			current_corr		=> current_corr,
			data_ready	      => data_ready,
			avalon_addr     	=> '0',
			avalon_read     	=> avalon_read,
			avalon_readdata 	=> avalon_readdata,
			peak_detected   	=> peak_detected
		);

   clk_process : process
   begin
		clk <= '0'; wait for clk_period/2;
		clk <= '1'; wait for clk_period/2;
	end process;

   sim_process: process
   begin
		reset <= '0';
      wait for 100 ns;
      reset <= '1';
      wait for clk_period * 5;
        
        for i in 1 to 7 loop
            current_corr <= to_unsigned(i * 10, 32);
            data_ready <= '1'; wait for clk_period;
            data_ready <= '0'; wait for clk_period * 2;
        end loop;

        current_corr <= to_unsigned(65, 32); -- dropped from 70
        data_ready <= '1'; wait for clk_period;
        data_ready <= '0'; wait for clk_period * 5;

        -- check if irq is high + sim value being read
        if peak_detected = '1' then
            report "SUCCESS: Peak Detected at counter value " & integer'image(to_integer(unsigned(avalon_readdata)));
            avalon_read <= '1'; wait for clk_period;
            avalon_read <= '0';
        else
            report "FAILURE: No Peak detected." severity error;
        end if;

        wait;
    end process;
end architecture;