library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simulation/debug version of the direct ASP chain.
-- Same chain as gp2_asp_chain_stub, but exposes the internal packets so the
-- self-checking testbench can automatically verify each stage.
entity gp2_asp_chain_probe is
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        tick_16khz : in  std_logic;

        config_pkt : in  std_logic_vector(39 downto 0);

        sig_to_avg  : out std_logic_vector(39 downto 0);
        avg_to_sym  : out std_logic_vector(39 downto 0);
        sym_to_peak : out std_logic_vector(39 downto 0);
        peak_out    : out std_logic_vector(39 downto 0);

        final_pkt   : out std_logic_vector(39 downto 0);
        peak_irq    : out std_logic
    );
end entity;

architecture rtl of gp2_asp_chain_probe is
    signal sig_to_avg_s  : std_logic_vector(39 downto 0);
    signal avg_to_sym_s  : std_logic_vector(39 downto 0);
    signal sym_to_peak_s : std_logic_vector(39 downto 0);
    signal peak_out_s    : std_logic_vector(39 downto 0);
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
            noc_send   => sig_to_avg_s,
            noc_ready  => '1'
        );

    u_avg : entity work.moving_average_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "011"
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            noc_recv  => sig_to_avg_s,
            noc_send  => avg_to_sym_s,
            noc_ready => '1'
        );

    u_sym : entity work.symmetry_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "100"
        )
        port map (
            clk       => clk,
            reset_n   => reset_n,
            noc_recv  => avg_to_sym_s,
            noc_send  => sym_to_peak_s,
            noc_ready => '1'
        );

    u_peak : entity work.peak_detector_noc_asp
        generic map (
            DEFAULT_NEXT_DEST => "101"
        )
        port map (
            clk           => clk,
            reset_n       => reset_n,
            noc_recv      => sym_to_peak_s,
            noc_send      => peak_out_s,
            noc_ready     => '1',
            peak_detected => peak_irq
        );

    sig_to_avg  <= sig_to_avg_s;
    avg_to_sym  <= avg_to_sym_s;
    sym_to_peak <= sym_to_peak_s;
    peak_out    <= peak_out_s;
    final_pkt   <= peak_out_s;

end architecture;
