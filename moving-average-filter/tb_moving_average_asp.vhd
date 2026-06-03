-- Updated Testbench for Programmable Power Signal Data Filtering
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

    -- Instantiates the updated programmable design cleanly
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

    -- Clock generation process
    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD / 2;
        clk_tb <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_process;

    -- Stimulus Generation
    stim_proc: process
        -- Upgraded procedure accepting an additional window mode tracker variable
        -- window_mode: 0 for L=4 ("00"), 1 for L=8 ("01"), 2 for L=16 ("10")
        procedure send_power_sample(
            constant payload     : in integer;
            constant window_mode : in integer
        ) is
            variable v_data : std_logic_vector(31 downto 0) := (others => '0');
        begin
            wait until falling_edge(clk_tb);
            
            -- Pack command prefix "1000" into MSBs
            v_data(31 downto 28) := "1000"; 
            
            -- Pack the dynamic programmable window configurations into bits 21 and 20
            v_data(21 downto 20) := std_logic_vector(to_unsigned(window_mode, 2));
            
            -- Pack the 12-bit unsigned data value into the lower bit fields
            v_data(11 downto 0)  := std_logic_vector(to_unsigned(payload, 12));
            
            recv_slot_data <= v_data;
            recv_slot_addr <= x"01"; 
            
            wait until rising_edge(clk_tb);
            wait for 2 ns; -- Short hold time to mimic physical bus propagation delay
            recv_slot_data <= (others => '0');
            recv_slot_addr <= (others => '0');
        end procedure;
    begin
        -- System settling time
        wait for 40 ns;
        
        -----------------------------------------------------------------------
        -- TEST CASE 1: Verify L = 4 Mode (window_mode = 0)
        -----------------------------------------------------------------------
        -- Step Test to verify settling time over 4 samples
        send_power_sample(1000, 0); wait for CLK_PERIOD * 2;
        send_power_sample(1000, 0); wait for CLK_PERIOD * 2;
        send_power_sample(1000, 0); wait for CLK_PERIOD * 2;
        send_power_sample(1000, 0); wait for CLK_PERIOD * 5; -- Output should read exactly 1000
        
        -- Fluctuating Sine Sample Sequence
        send_power_sample(2048, 0); wait for CLK_PERIOD * 2; 
        send_power_sample(2500, 0); wait for CLK_PERIOD * 2; 
        send_power_sample(3100, 0); wait for CLK_PERIOD * 2; 
        send_power_sample(3500, 0); wait for CLK_PERIOD * 2; 
        send_power_sample(3100, 0); wait for CLK_PERIOD * 2; 
        send_power_sample(2500, 0); wait for CLK_PERIOD * 2;
        send_power_sample(2048, 0); wait for CLK_PERIOD * 5;
        
        -----------------------------------------------------------------------
        -- TEST CASE 2: Dynamic Switch to L = 8 Mode (window_mode = 1)
        -----------------------------------------------------------------------
        -- Verify that history expands up to 8 samples and shifts right by 3
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 2;
        send_power_sample(2000, 1); wait for CLK_PERIOD * 5; -- Output should settle to 2000
        
        -----------------------------------------------------------------------
        -- TEST CASE 3: Dynamic Switch to L = 16 Mode (window_mode = 2)
        -----------------------------------------------------------------------
        -- Verify deep trace accumulation across 16 consecutive cycles
        for i in 1 to 16 loop
            send_power_sample(3000, 2);
            wait for CLK_PERIOD * 2;
        end loop;
        wait for CLK_PERIOD * 5; -- Output should settle to 3000
        
        report "Simulation completed successfully. Verify window configurations via wave diagnostics.";
        wait;
    end process stim_proc;
end architecture sim;