--Moving Average Filter ASP
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity moving_average_asp is
    generic (
        TARGET_PORT : std_logic_vector(7 downto 0) := x"02"
    );
    port (
        clock          : in  std_logic;
        recv_slot_addr : in  std_logic_vector(7 downto 0);
        recv_slot_data : in  std_logic_vector(31 downto 0);
        send_slot_addr : out std_logic_vector(7 downto 0);
        send_slot_data : out std_logic_vector(31 downto 0)
    );
end entity moving_average_asp;

architecture rtl of moving_average_asp is
    -- Use unsigned types matching your ADC bit width selection (e.g., 12 bits)
    type sample_reg is array (0 to 2) of unsigned(11 downto 0);
    signal regs : sample_reg := (others => (others => '0')); 
begin
    process(clock)
        -- Sized to cleanly hold the sum of 4 cumulative unsigned samples without overflow
        variable v_sum  : unsigned(13 downto 0);
        variable v_avg  : unsigned(11 downto 0);
    begin
        if rising_edge(clock) then
            send_slot_addr <= (others => '0');
            send_slot_data <= (others => '0');

            -- Ensure this matches your DP-ASP command packet format criteria
            if recv_slot_data(31 downto 28) = "1000" then
                
                -- Single-channel pipeline accumulation (No channel splitting!)
                v_sum := resize(unsigned(recv_slot_data(11 downto 0)), 14) + 
                         resize(regs(0), 14) + resize(regs(1), 14) + resize(regs(2), 14);
                
                -- Shift new sample into the history array
                regs <= unsigned(recv_slot_data(11 downto 0)) & regs(0 to 1);

                -- Divide by 4 (Shift Right by 2)
                v_avg := resize(shift_right(v_sum, 2), 12);
                
                -- Forward the filtered unsigned power wave sample back onto the NoC bus
                send_slot_addr <= TARGET_PORT; 
                send_slot_data <= recv_slot_data(31 downto 12) & std_logic_vector(v_avg);
            end if;
        end if;
    end process;
end architecture rtl;