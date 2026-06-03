--Moving Average Filter ASP

-- The entity processes streaming 12-bit ADC payloads wrapped inside a 32-bit input packet (recv_slot_data) 
-- synchronized to a 1-bit clock, and routes the resulting 12-bit filtered average out via a 32-bit 
-- destination packet (send_slot_data) directed by 8-bit slot addressing signals (recv_slot_addr and send_slot_addr).

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
    -- Allocated to support the maximum history required (L=16 requires 15 past samples)
    type sample_reg is array (0 to 14) of unsigned(11 downto 0);
    signal regs : sample_reg := (others => (others => '0')); 
begin
    process(clock)
        -- Sized to cleanly hold the maximum sum of 16 12-bit samples without overflow (12 bits + 4 bits = 16 bits)
        variable v_sum       : unsigned(15 downto 0);
        variable v_avg       : unsigned(11 downto 0);
        variable shift_bits  : integer range 0 to 4;
        variable window_sel  : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clock) then
            send_slot_addr <= (others => '0');
            send_slot_data <= (others => '0');

            -- Packet Validation Protocol (Checks for Data Packet Command Prefix "1000")
            if recv_slot_data(31 downto 28) = "1000" then
                
                -- Extract the programmable window configuration selection bits
                window_sel := recv_slot_data(21 downto 20);
                
                -- Multiplexed Accumulator Tree and Division Configuration
                case window_sel is
                    when "00" => -- Mode: L = 4
                        v_sum := resize(unsigned(recv_slot_data(11 downto 0)), 16) + 
                                 resize(regs(0), 16) + resize(regs(1), 16) + resize(regs(2), 16);
                        shift_bits := 2; -- Arithmetic division by 4

                    when "01" => -- Mode: L = 8
                        v_sum := resize(unsigned(recv_slot_data(11 downto 0)), 16);
                        for i in 0 to 6 loop
                            v_sum := v_sum + resize(regs(i), 16);
                        end loop;
                        shift_bits := 3; -- Arithmetic division by 8

                    when "10" => -- Mode: L = 16
                        v_sum := resize(unsigned(recv_slot_data(11 downto 0)), 16);
                        for i in 0 to 14 loop
                            v_sum := v_sum + resize(regs(i), 16);
                        end loop;
                        shift_bits := 4; -- Arithmetic division by 16

                    when others => -- Fallback protective state default to L = 4
                        v_sum := resize(unsigned(recv_slot_data(11 downto 0)), 16) + 
                                 resize(regs(0), 16) + resize(regs(1), 16) + resize(regs(2), 16);
                        shift_bits := 2;
                end case;
                
                -- Shift the newest 12-bit sample into the full historical data register trace
                regs <= unsigned(recv_slot_data(11 downto 0)) & regs(0 to 13);

                -- Dynamic division executing via variable barrel shifter routing
                v_avg := resize(shift_right(v_sum, shift_bits), 12);
                
                -- Packet Assembler: Combines the original control headers with the new average payload
                send_slot_addr <= TARGET_PORT; 
                send_slot_data <= recv_slot_data(31 downto 12) & std_logic_vector(v_avg);
            end if;
        end if;
    end process;
end architecture rtl;