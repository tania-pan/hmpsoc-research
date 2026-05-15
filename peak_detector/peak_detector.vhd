library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity peak_detector is
	port (
		clk 					: in std_logic;
		reset 				: in std_logic;
		
		current_corr 		: in unsigned(31 downto 0);
		data_ready 			: in std_logic;
		
		avalon_read			: in std_logic;
		avalon_readdata 	: out std_logic_vector(31 downto 0);
		
		peak_detected 		: out std_logic
	);
end entity;

architecture rtl of peak_detector is

	signal last_corr 			: unsigned(31 downto 0) := (others => '0');
	signal counter				: unsigned(31 downto 0) := (others => '0');
	signal result_reg 		: unsigned(31 downto 0) := (others => '0');
   signal irq_reg    		: std_logic := '0';
   signal positive_slope  	: std_logic := '0';
	
	begin
	
		process(clk, reset)
		begin
		
			if reset = '0' then
			
				last_corr      <= (others => '0');
            counter        <= (others => '0');
            result_reg     <= (others => '0');
            irq_reg        <= '0';
            positive_slope <= '0'; 
			
			elsif rising_edge(clk) then
            
				if data_ready = '1' then
					if current_corr > last_corr then
						positive_slope <= '1';
						counter <= counter + 1;
					elsif current_corr < last_corr and positive_slope = '1' then
						
						result_reg     <= counter;
                  irq_reg        <= '1';     
                  counter        <= (others => '0');
                  positive_slope <= '0';     
					else
                  counter <= counter + 1;
					end if;
					last_corr <= current_corr;
				end if;

				-- reset on read
            if avalon_read = '1' then
                irq_reg <= '0';
            end if;

		end if;
	end process;

   peak_detected <= irq_reg;
   avalon_readdata <= std_logic_vector(result_reg);

end architecture;
	