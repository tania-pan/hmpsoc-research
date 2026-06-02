library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Direct-chain integration stub.
-- This is NOT the final TDMA-MIN. It is a quick compile/simulation top level
-- showing that the ASPs are now linkable with the same 40-bit interface.
--
-- Replace the direct wires with TDMA-MIN network ports later.
entity gp2_asp_chain_stub is
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        tick_16khz : in  std_logic;

        -- Simple external config packet input, usually from ReCOP/config FSM later.
        config_pkt : in  std_logic_vector(39 downto 0);

        final_pkt  : out std_logic_vector(39 downto 0);
        peak_irq   : out std_logic
    );
end entity;

architecture rtl of gp2_asp_chain_stub is

    signal sig_to_avg  : std_logic_vector(39 downto 0);
    signal avg_to_sym  : std_logic_vector(39 downto 0);
    signal sym_to_peak : std_logic_vector(39 downto 0);
    signal peak_out    : std_logic_vector(39 downto 0);

begin

    u_signal : entity work.asp_signal_noc
        generic map (
            DEFAULT_NEXT_DEST => "010"
        )
        port map (
            clk        => clk,
            reset_n    => reset_n,
            tick_16khz => tick_16khz,
            noc_recv   => config_pkt,
            noc_send   => sig_to_avg,
            noc_ready  => '1'
        );

    u_avg : entity work.moving_average_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "011"
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            noc_recv  => sig_to_avg,
            noc_send  => avg_to_sym,
            noc_ready => '1'
        );

    u_sym : entity work.symmetry_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "100"
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            noc_recv  => avg_to_sym,
            noc_send  => sym_to_peak,
            noc_ready => '1'
        );

    u_peak : entity work.peak_detector_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "101"
        )
        port map (
            clk           => clk,
            reset_n       => reset_n,
            noc_recv      => sym_to_peak,
            noc_send      => peak_out,
            noc_ready     => '1',
            peak_detected => peak_irq
        );

    final_pkt <= peak_out;

end architecture;
