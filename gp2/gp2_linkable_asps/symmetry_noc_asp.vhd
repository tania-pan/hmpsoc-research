library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gp2_packet_pkg.all;

-- Linkable GP2 ASP wrapper around symmetry_core.
-- Input:  MSG_DATA with sample in payload bits 11..0.
-- Output: MSG_DATA with 32-bit correlation result in payload bits 31..0.
entity symmetry_noc_asp is
    generic (
        DEFAULT_NEXT_DEST : std_logic_vector(2 downto 0) := "100"
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;

        noc_recv  : in  std_logic_vector(39 downto 0);
        noc_send  : out std_logic_vector(39 downto 0);
        noc_ready : in  std_logic
    );
end entity;

architecture rtl of symmetry_noc_asp is

    component symmetry_core is
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            sample_valid : in  std_logic;
            sample_in    : in  std_logic_vector(11 downto 0);
            corr_done    : out std_logic;
            corr_out     : out std_logic_vector(31 downto 0)
        );
    end component;

    signal core_reset      : std_logic;
    signal sample_valid_s  : std_logic := '0';
    signal sample_in_s     : std_logic_vector(11 downto 0) := (others => '0');
    signal corr_done_s     : std_logic;
    signal corr_out_s      : std_logic_vector(31 downto 0);

    signal enabled         : std_logic := '1';
    signal next_dest       : std_logic_vector(2 downto 0) := DEFAULT_NEXT_DEST;

    signal pending_valid   : std_logic := '0';
    signal pending_payload : std_logic_vector(31 downto 0) := (others => '0');

begin

    -- symmetry_core uses active-high reset.
    core_reset <= not reset_n;

    u_symmetry_core : symmetry_core
        port map (
            clk          => clk,
            reset        => core_reset,
            sample_valid => sample_valid_s,
            sample_in    => sample_in_s,
            corr_done    => corr_done_s,
            corr_out     => corr_out_s
        );

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sample_valid_s  <= '0';
            sample_in_s     <= (others => '0');
            enabled         <= '1';
            next_dest       <= DEFAULT_NEXT_DEST;
            pending_valid   <= '0';
            pending_payload <= (others => '0');
            noc_send        <= (others => '0');

        elsif rising_edge(clk) then
            noc_send       <= (others => '0');
            sample_valid_s <= '0';

            -- Configuration packet
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_CONF then
                next_dest <= noc_recv(31 downto 29);
                enabled   <= noc_recv(0);
            end if;

            -- Feed input samples into the existing core.
            if noc_recv(39) = '1' and noc_recv(38 downto 35) = MSG_DATA and enabled = '1' then
                sample_in_s    <= noc_recv(11 downto 0);
                sample_valid_s <= '1';
            end if;

            -- Hold result until the next node/NoC can accept it.
            if corr_done_s = '1' then
                pending_payload <= corr_out_s;
                pending_valid   <= '1';
            end if;

            if pending_valid = '1' and noc_ready = '1' then
                noc_send      <= make_packet(MSG_DATA, next_dest, pending_payload);
                pending_valid <= '0';
            end if;
        end if;
    end process;

end architecture;
