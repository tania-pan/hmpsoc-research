library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gp2_packet_pkg.all;

-- Linkable GP2 ASP for peak detection on a stream of correlation values.
-- Input:  MSG_DATA with current correlation value in payload bits 31..0.
-- Output: MSG_EVENT when a local peak is detected. Payload contains the counter value.
entity peak_detector_noc_asp is
    generic (
        DEFAULT_NEXT_DEST : std_logic_vector(2 downto 0) := "101"
    );
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;

        noc_recv      : in  std_logic_vector(39 downto 0);
        noc_send      : out std_logic_vector(39 downto 0);
        noc_ready     : in  std_logic;

        peak_detected : out std_logic
    );
end entity;

architecture rtl of peak_detector_noc_asp is

    signal enabled         : std_logic := '1';
    signal next_dest       : std_logic_vector(2 downto 0) := DEFAULT_NEXT_DEST;

    signal last_corr       : unsigned(31 downto 0) := (others => '0');
    signal counter         : unsigned(31 downto 0) := (others => '0');
    signal positive_slope  : std_logic := '0';

    signal pending_valid   : std_logic := '0';
    signal pending_payload : std_logic_vector(31 downto 0) := (others => '0');
    signal peak_reg        : std_logic := '0';

begin

    process(clk, reset_n)
        variable current_corr_v : unsigned(31 downto 0);
    begin
        if reset_n = '0' then
            enabled         <= '1';
            next_dest       <= DEFAULT_NEXT_DEST;
            last_corr       <= (others => '0');
            counter         <= (others => '0');
            positive_slope  <= '0';
            pending_valid   <= '0';
            pending_payload <= (others => '0');
            peak_reg        <= '0';
            noc_send        <= (others => '0');

        elsif rising_edge(clk) then
            noc_send <= (others => '0');
            peak_reg <= '0';

            -- Configuration packet
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_CONF then
                next_dest <= noc_recv(31 downto 29);
                enabled   <= noc_recv(0);
            end if;

            -- Data packet containing correlation.
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_DATA and enabled = '1' then
                current_corr_v := unsigned(noc_recv(31 downto 0));

                if current_corr_v > last_corr then
                    positive_slope <= '1';
                    counter <= counter + 1;

                elsif current_corr_v < last_corr and positive_slope = '1' then
                    -- Falling after a rising slope = local peak.
                    pending_payload <= std_logic_vector(counter);
                    pending_valid   <= '1';
                    peak_reg        <= '1';
                    counter         <= (others => '0');
                    positive_slope  <= '0';

                else
                    counter <= counter + 1;
                end if;

                last_corr <= current_corr_v;
            end if;

            if pending_valid = '1' and noc_ready = '1' then
                noc_send      <= make_packet(MSG_EVENT, next_dest, pending_payload);
                pending_valid <= '0';
            end if;
        end if;
    end process;

    peak_detected <= peak_reg;

end architecture;
