-- Safe Testbench for Power Signal Data (tb_moving_average_asp.vhd)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_moving_average_asp is
end entity tb_moving_average_asp;

architecture sim of tb_moving_average_asp is
    constant CLK_PERIOD : time := 20 ns;
    
    signal clk_tb          : std_logic := '0';
    signal recv_slot_addr  : std_logic_vector(7 downto 0) := (others => '0');
    signal recv_slot_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal send_slot_addr  : std_logic_vector(7 downto 0);
    signal send_slot_data  : std_logic_vector(31 downto 0);
begin

    -- Instantiates the design from your other file cleanly
    UUT: entity work.moving_average_asp
        generic map (
            TARGET_PORT => x"02"
        )
        port map (
            clock          => clk_tb,
            recv_slot_addr => recv_slot_addr,
            recv_slot_data => recv_slot_data,
            send_slot_addr => send_slot_addr,
            send_slot_data => send_slot_data
        );

    -- Loop-free clock generation process
    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD / 2;
        clk_tb <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_process;

    -- Stimulus Generation
    stim_proc: process
        procedure send_power_sample(
            constant payload : in integer
        ) is
            variable v_data : std_logic_vector(31 downto 0) := (others => '0');
        begin
            wait until falling_edge(clk_tb);
            v_data(31 downto 28) := "1000"; 
            v_data(11 downto 0)  := std_logic_vector(to_unsigned(payload, 12));
            
            recv_slot_data <= v_data;
            recv_slot_addr <= x"01"; 
            
            wait until rising_edge(clk_tb);
            wait for 2 ns;
            recv_slot_data <= (others => '0');
            recv_slot_addr <= (others => '0');
        end procedure;
    begin
        wait for 40 ns;
        
        -- Step Test (Unsigned values): sudden step change to 1000
        send_power_sample(1000); wait for CLK_PERIOD * 2;
        send_power_sample(1000); wait for CLK_PERIOD * 2;
        send_power_sample(1000); wait for CLK_PERIOD * 2;
        send_power_sample(1000); wait for CLK_PERIOD * 5;
        
        -- Sine Wave Sequence Test
        send_power_sample(2048); wait for CLK_PERIOD * 2; 
        send_power_sample(2500); wait for CLK_PERIOD * 2; 
        send_power_sample(3100); wait for CLK_PERIOD * 2; 
        send_power_sample(3500); wait for CLK_PERIOD * 2; 
        send_power_sample(3100); wait for CLK_PERIOD * 2; 
        send_power_sample(2500); wait for CLK_PERIOD * 2;
        send_power_sample(2048); wait for CLK_PERIOD * 5;
        
        wait;
    end process stim_proc;
end architecture sim;