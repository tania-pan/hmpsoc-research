library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asp_signal_tb is
end entity;

architecture sim of asp_signal_tb is

    component asp_signal is
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            tick_16khz   : in  std_logic;
            noc_recv     : in  std_logic_vector(39 downto 0);
            noc_send     : out std_logic_vector(39 downto 0);
            noc_ready    : in  std_logic
        );
    end component;

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal tick_16khz   : std_logic := '0';
    signal noc_recv     : std_logic_vector(39 downto 0) := (others => '0');
    signal noc_send     : std_logic_vector(39 downto 0);
    signal noc_ready    : std_logic := '1';

    constant clk_period : time := 20 ns; -- 50MHz clock

begin

    uut: asp_signal
        port map (
            clk          => clk,
            reset        => reset,
            tick_16khz   => tick_16khz,
            noc_recv     => noc_recv,
            noc_send     => noc_send,
            noc_ready    => noc_ready
        );

    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    sim_process : process
    begin
		
		  -- system starts in reset
        reset <= '0';
        noc_recv <= (others => '0');
        wait for 100 ns;
        
		  -- release reset
        reset <= '1';
        wait for clk_period * 5;

		  -- bit 39 = valid, bits 31:28 = "1111" (config), destination =02, mode = 0
		  noc_recv <= x"80F0020000";        
		  wait for clk_period; -- hold for 1 clk cycle
        
        noc_recv <= (others => '0'); -- clear bus
        wait for clk_period * 5;

        for i in 1 to 2000 loop
            tick_16khz <= '1';
            wait for clk_period;
            tick_16khz <= '0';
				wait for 62.5us - clk_period;
        end loop;

        wait;
    end process;

end architecture;