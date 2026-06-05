library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TdmaMinTypes.all;

-- Nios receive mailbox for peak-detector NoC packets.
-- This block converts the one-cycle TDMA-MIN receive packet into stable
-- registers that Nios software can poll/read/clear.
--
-- Register meaning for Nios PIO/Qsys connection:
--   peak_valid_o   = 1 when a packet has been latched and not cleared
--   peak_payload_o = 32-bit peak detector payload/count
--   peak_count_o   = number of peak packets received, useful for debug
--   overflow_o     = new packet arrived before Nios cleared previous one
--   peak_clear_i   = pulse high from Nios to clear peak_valid_o/overflow_o
entity nios_noc_mailbox is
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;

        recv_port      : in  tdma_min_port;

        peak_clear_i   : in  std_logic;
        peak_valid_o   : out std_logic;
        peak_payload_o : out std_logic_vector(31 downto 0);
        peak_count_o   : out std_logic_vector(31 downto 0);
        overflow_o     : out std_logic;
        packet_pulse_o : out std_logic
    );
end entity;

architecture rtl of nios_noc_mailbox is
    signal valid_r   : std_logic := '0';
    signal payload_r : std_logic_vector(31 downto 0) := (others => '0');
    signal count_r   : unsigned(31 downto 0) := (others => '0');
    signal overflow_r: std_logic := '0';
    signal pulse_r   : std_logic := '0';
begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            valid_r    <= '0';
            payload_r  <= (others => '0');
            count_r    <= (others => '0');
            overflow_r <= '0';
            pulse_r    <= '0';

        elsif rising_edge(clk) then
            pulse_r <= '0';

            if peak_clear_i = '1' then
                valid_r    <= '0';
                overflow_r <= '0';
            end if;

            -- data(data'high) is the valid / packet-present bit in the
            -- payload32 TDMA-MIN format.
            if recv_port.data(recv_port.data'high) = '1' then
                payload_r <= recv_port.data(31 downto 0);
                count_r   <= count_r + 1;
                pulse_r   <= '1';

                if valid_r = '1' and peak_clear_i = '0' then
                    overflow_r <= '1';
                end if;

                valid_r <= '1';
            end if;
        end if;
    end process;

    peak_valid_o   <= valid_r;
    peak_payload_o <= payload_r;
    peak_count_o   <= std_logic_vector(count_r);
    overflow_o     <= overflow_r;
    packet_pulse_o <= pulse_r;

end architecture;
