library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gp2_packet_pkg.all;

-- Linkable GP2 ASP wrapper for the signal generator.
-- This replaces/adapts the older asp_signal packet convention.
entity asp_signal_noc is
    generic (
        DEFAULT_NEXT_DEST : std_logic_vector(2 downto 0) := "010"
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        tick_16khz : in  std_logic;

        noc_recv   : in  std_logic_vector(39 downto 0);
        noc_send   : out std_logic_vector(39 downto 0);
        noc_ready  : in  std_logic
    );
end entity;

architecture rtl of asp_signal_noc is

    component signal_gen is
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            tick_16khz  : in  std_logic;
            signal_out  : out std_logic_vector(11 downto 0);
            data_ready  : out std_logic
        );
    end component;

    signal core_signal_out : std_logic_vector(11 downto 0);
    signal core_data_ready : std_logic;

    signal enabled         : std_logic := '0';
    signal next_dest       : std_logic_vector(2 downto 0) := DEFAULT_NEXT_DEST;
    signal use_8_bit_mode  : std_logic := '0';

    signal pending_valid   : std_logic := '0';
    signal pending_payload : std_logic_vector(31 downto 0) := (others => '0');

    signal reset_core      : std_logic;

begin

    -- Original signal_gen uses active-low reset named "reset".
    reset_core <= reset_n;

    u_signal_gen : signal_gen
        port map (
            clk         => clk,
            reset       => reset_core,
            tick_16khz  => tick_16khz,
            signal_out  => core_signal_out,
            data_ready  => core_data_ready
        );

    process(clk, reset_n)
        variable payload_v : std_logic_vector(31 downto 0);
    begin
        if reset_n = '0' then
            enabled         <= '0';
            next_dest       <= DEFAULT_NEXT_DEST;
            use_8_bit_mode  <= '0';
            pending_valid   <= '0';
            pending_payload <= (others => '0');
            noc_send        <= (others => '0');

        elsif rising_edge(clk) then
            noc_send <= (others => '0');

            -- Configuration packet
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_CONF then
                next_dest      <= noc_recv(31 downto 29);
                use_8_bit_mode <= noc_recv(1);
                enabled        <= noc_recv(0);
            end if;

            -- Capture a generated sample. If noc_ready is low, hold it.
            if core_data_ready = '1' and enabled = '1' and pending_valid = '0' then
                payload_v := (others => '0');

                if use_8_bit_mode = '1' then
                    -- keep the upper 8 bits, zero-extended in the payload
                    payload_v(15 downto 0) := "00000000" & core_signal_out(11 downto 4);
                else
                    -- keep the upper 10 bits, zero-extended in the payload
                    payload_v(15 downto 0) := "000000" & core_signal_out(11 downto 2);
                end if;

                pending_payload <= payload_v;
                pending_valid   <= '1';
            end if;

            -- Send pending data packet.
            if pending_valid = '1' and noc_ready = '1' then
                noc_send      <= make_packet(MSG_DATA, next_dest, pending_payload);
                pending_valid <= '0';
            end if;
        end if;
    end process;

end architecture;
