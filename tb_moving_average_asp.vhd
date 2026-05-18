library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_MovingAverageAsp is
end entity tb_MovingAverageAsp;

architecture sim of tb_MovingAverageAsp is
    constant CLK_PERIOD : time := 20 ns;
    
    signal clk_tb          : std_logic := '0';
    signal recv_slot_addr  : std_logic_vector(7 downto 0) := (others => '0');
    signal recv_slot_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal send_slot_addr  : std_logic_vector(7 downto 0);
    signal send_slot_data  : std_logic_vector(31 downto 0);
begin

    UUT: entity work.MovingAverageAsp
        generic map (
            TARGET_PORT => x"02",
            MAX_CLIP    => to_signed(4096, 16),
            MIN_CLIP    => to_signed(-4096, 16)
        )
        port map (
            clock          => clk_tb,
            recv_slot_addr => recv_slot_addr,
            recv_slot_data => recv_slot_data,
            send_slot_addr => send_slot_addr,
            send_slot_data => send_slot_data
        );

    clk_process : process
    begin
        while true loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process clk_process;

    stim_proc: process
        procedure send_packet(
            constant header  : in std_logic_vector(3 downto 2);
            constant channel : in std_logic;
            constant payload : in integer
        ) is
            variable v_data : std_logic_vector(31 downto 0) := (others => '0');
        begin
            wait until falling_edge(clk_tb);
            v_data(31 downto 28) := header & "00"; 
            v_data(16)           := channel;
            v_data(15 downto 0)  := std_logic_vector(to_signed(payload, 16));
            
            recv_slot_data <= v_data;
            recv_slot_addr <= x"01";
            
            wait until rising_edge(clk_tb);
            wait for 2 ns;
            recv_slot_data <= (others => '0');
            recv_slot_addr <= (others => '0');
        end procedure;
    begin
        wait for 40 ns;
        
        -- Test sequence
        send_packet("10", '0', 100); wait for CLK_PERIOD * 2;
        send_packet("10", '0', 100); wait for CLK_PERIOD * 2;
        send_packet("10", '0', 100); wait for CLK_PERIOD * 2;
        send_packet("10", '0', 100); wait for CLK_PERIOD * 5;
        
        send_packet("10", '1', 800); wait for CLK_PERIOD * 2;
        send_packet("10", '0', 200); wait for CLK_PERIOD * 2;
        send_packet("10", '1', 800); wait for CLK_PERIOD * 5;

        send_packet("10", '0', 20000); wait for CLK_PERIOD * 2;
        send_packet("10", '0', 20000); wait for CLK_PERIOD * 5;
        
        wait;
    end process stim_proc;
end architecture sim;